const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;

// Decryption function
const WS_SECRET = "cabinetdoorpinkponyunicorn";
const WS_SALT = "VEXIS_ONLY_ADMINS";

function buildKeyStream(length) {
    let stream = [];
    let seed = 0;
    let combined = WS_SECRET + WS_SALT;
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

function decryptData(encryptedHex) {
    try {
        let xorBytes = '';
        for (let i = 0; i < encryptedHex.length; i += 2) {
            xorBytes += String.fromCharCode(parseInt(encryptedHex.substr(i, 2), 16));
        }
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
    } else if (req.url === '/logs') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Check Render logs for scan data');
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
            // LOGS SHOW HERE IN RENDER (unencrypted)
            console.log('\n═══════════════════════════════════════════════════');
            console.log(`[SCAN] JobID: ${decrypted.jobid}`);
            console.log(`[SCAN] Players: ${decrypted.players}`);
            console.log(`[SCAN] Pet Name: ${decrypted.petName}`);
            console.log(`[SCAN] Money/s: ${decrypted.moneyPerSecond}`);
            console.log(`[SCAN] InDuel: ${decrypted.inDuel}`);
            console.log(`[SCAN] Mutation: ${decrypted.mutation}`);
            console.log(`[SCAN] Traits: ${decrypted.traits}`);
            console.log('═══════════════════════════════════════════════════\n');
        }
    });
    
    ws.on('close', () => {
        console.log('[WS] Client disconnected');
        clients.delete(ws);
    });
});

server.listen(PORT, () => {
    console.log(`[SERVER] Running on port ${PORT}`);
    console.log(`[SERVER] WebSocket: wss://vexisfinder13.onrender.com`);
    console.log('[SERVER] Waiting for scanner data...\n');
});
