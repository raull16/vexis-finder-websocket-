const WebSocket = require('ws');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;

const WS_SECRET = "cabinetdoorpinkponyunicorn";
const SALT = "VEXIS_ONLY_ADMINS";

const clients = new Map();

function generateKeyStream(length, seed_offset) {
    let seed = 0;
    for (let i = 0; i < WS_SECRET.length; i++) {
        seed = (seed * 31 + WS_SECRET.charCodeAt(i)) % 2147483647;
    }
    seed = (seed + seed_offset) >>> 0;
    
    let a = seed, b = seed * 1664525 + 1013904223, c = seed * 1103515245 + 12345;
    const stream = [];
    for (let i = 0; i < length; i++) {
        a = (a * 1664525 + 1013904223) >>> 0;
        b = (b * 1103515245 + 12345) >>> 0;
        c = (c * 134775813 + 1) >>> 0;
        stream.push((a & 0xFF) ^ (b & 0xFF) ^ (c & 0xFF));
    }
    return stream;
}

function chaoticShuffle(data, forward) {
    let bytes = [...data];
    let seed = 0;
    for (let i = 0; i < SALT.length; i++) {
        seed = (seed * 31 + SALT.charCodeAt(i)) % 2147483647;
    }
    
    const swaps = [];
    for (let i = bytes.length - 1; i >= 1; i--) {
        seed = (seed * 1664525 + 1013904223) >>> 0;
        const j = (seed % i) + 1;
        swaps.push([i, j]);
    }
    
    if (forward) {
        for (const [i, j] of swaps) {
            [bytes[i], bytes[j]] = [bytes[j], bytes[i]];
        }
    } else {
        for (let k = swaps.length - 1; k >= 0; k--) {
            const [i, j] = swaps[k];
            [bytes[i], bytes[j]] = [bytes[j], bytes[i]];
        }
    }
    return Buffer.from(bytes);
}

function tripleDecrypt(ciphertext) {
    if (!ciphertext || ciphertext.length < 4) {
        return null;
    }
    
    try {
        const timestamp = ciphertext.readUInt32LE(0);
        const data = ciphertext.subarray(4);
        
        if (data.length === 0) return null;
        
        const stream3 = generateKeyStream(data.length, Math.floor(timestamp / 1000000));
        const layer2_bytes = Buffer.alloc(data.length);
        for (let i = 0; i < data.length; i++) {
            layer2_bytes[i] = data[i] ^ stream3[i];
        }
        
        const layer1 = chaoticShuffle(layer2_bytes, false);
        
        const stream1 = generateKeyStream(layer1.length, timestamp % 1000000);
        const plaintext_bytes = Buffer.alloc(layer1.length);
        for (let i = 0; i < layer1.length; i++) {
            plaintext_bytes[i] = layer1[i] ^ stream1[i];
        }
        
        return plaintext_bytes.toString('utf8');
    } catch (err) {
        console.log('Decryption error:', err.message);
        return null;
    }
}

function verifySignature(ts, jobId, sig) {
    const raw = WS_SECRET + ts + jobId;
    let h = 5381;
    for (let i = 0; i < raw.length; i++) {
        h = (h * 33 + raw.charCodeAt(i)) % 2147483647;
    }
    let h2 = 52711;
    for (let i = raw.length - 1; i >= 0; i--) {
        h2 = (h2 * 31 + raw.charCodeAt(i)) % 2147483647;
    }
    const expected = h.toString(16) + h2.toString(16);
    return sig === expected;
}

const wss = new WebSocket.Server({ port: PORT });
console.log(`WebSocket server running on port ${PORT}`);

wss.on('connection', (ws, req) => {
    const clientId = crypto.randomBytes(8).toString('hex');
    clients.set(clientId, ws);
    console.log(`[${clientId}] Client connected`);

    ws.on('message', async (data) => {
        // Ensure data is a buffer
        let buffer = data;
        if (typeof data === 'string') {
            buffer = Buffer.from(data);
        }
        
        console.log(`[${clientId}] Received ${buffer.length} bytes`);
        
        const decrypted = tripleDecrypt(buffer);
        if (!decrypted) {
            console.log(`[${clientId}] Decryption failed - invalid format`);
            return;
        }
        
        try {
            const payload = JSON.parse(decrypted);
            
            if (!verifySignature(payload.ts, payload.jobid, payload.sig)) {
                console.log(`[${clientId}] Invalid signature`);
                return;
            }
            
            console.log(`[${clientId}] 📡 ${payload.name} | ${payload.money.toLocaleString()}/s | ${payload.players}/${payload.maxplayers} players`);
            
            // Broadcast to all other clients
            for (const [id, client] of clients) {
                if (id !== clientId && client.readyState === WebSocket.OPEN) {
                    client.send(buffer);
                }
            }
        } catch (err) {
            console.log(`[${clientId}] JSON parse error:`, err.message);
        }
    });

    ws.on('close', () => {
        clients.delete(clientId);
        console.log(`[${clientId}] Client disconnected | ${clients.size} remaining`);
    });
    
    ws.on('error', (err) => {
        console.log(`[${clientId}] WebSocket error:`, err.message);
    });
});
