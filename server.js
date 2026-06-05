const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;

// Decryption keys (must match Lua encryption)
const WS_SECRET = "cabinetdoorpinkponyunicorn_VEXIS_2025";
const WS_SALT = "VEXIS_ONLY_ADMINS_ULTRA_SECURE";
const decryptionSeed = 0x7F3A9C2E;

function buildKeyStream(length) {
    let stream = [];
    let seed = decryptionSeed;
    let combined = WS_SECRET + WS_SALT + (Math.floor(Date.now() / 10000) % 10000);
    for (let i = 0; i < combined.length; i++) {
        seed = (seed * 31 + combined.charCodeAt(i)) % 2147483647;
    }
    let a = seed;
    for (let i = 0; i < length; i++) {
        a = (a * 1664525 + 1013904223) >>> 0;
        stream.push(a % 256);
    }
    return stream;
}

function decryptData(encryptedBase64) {
    try {
        // Layer 1: Base64 decode
        let hex = Buffer.from(encryptedBase64, 'base64').toString('utf-8');
        
        // Remove garbage prefix/suffix (4 hex chars each)
        if (hex.length > 8) {
            hex = hex.substring(4, hex.length - 4);
        }
        
        // Layer 2: Hex decode
        let reversed = '';
        for (let i = 0; i < hex.length; i += 2) {
            reversed += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        
        // Layer 3: Reverse string
        let xorBytes = reversed.split('').reverse().join('');
        
        // Layer 4: XOR decryption
        let stream = buildKeyStream(xorBytes.length);
        let json = '';
        for (let i = 0; i < xorBytes.length; i++) {
            json += String.fromCharCode(xorBytes.charCodeAt(i) ^ stream[i]);
        }
        
        return JSON.parse(json);
    } catch (e) {
        return null;
    }
}

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', clients: clients.size }));
    } else {
        res.writeHead(426);
        res.end('WebSocket server');
    }
});

const wss = new WebSocket.Server({ server });
const clients = new Set();

wss.on('connection', (ws) => {
    console.log('[WS] Client connected');
    clients.add(ws);
    
    ws.on('message', (data) => {
        const decrypted = decryptData(data.toString());
        if (decrypted) {
            // CLEAN LOGS ON RENDER - Shows everything decrypted
            console.log('\n═══════════════════════════════════════════════════');
            console.log(`📡 SCAN DATA RECEIVED [${new Date().toLocaleTimeString()}]`);
            console.log(`   Job ID: ${decrypted.jobid}`);
            console.log(`   Players in server: ${decrypted.players}`);
            console.log(`   Pet name: ${decrypted.petName}`);
            console.log(`   Money per second: ${decrypted.money}`);
            console.log(`   In duel: ${decrypted.inDuel === true ? 'true' : 'false'}`);
            console.log('═══════════════════════════════════════════════════\n');
        }
    });
    
    ws.on('close', () => {
        console.log('[WS] Client disconnected');
        clients.delete(ws);
    });
    
    ws.on('error', (err) => {
        console.error('[WS] Error:', err.message);
        clients.delete(ws);
    });
});

server.listen(PORT, () => {
    console.log(`\n═══════════════════════════════════════`);
    console.log(`🚀 VEXIS FINDER WEBSOCKET SERVER`);
    console.log(`   Port: ${PORT}`);
    console.log(`   WebSocket: wss://vexisfinder13.onrender.com`);
    console.log(`═══════════════════════════════════════\n`);
});
