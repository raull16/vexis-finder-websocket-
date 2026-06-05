const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;
let blacklistedJobs = new Set();

const decryptionSeed = 0x7F3A9C2E;
function decryptData(encryptedBase64) {
    try {
        const hex = Buffer.from(encryptedBase64, 'base64').toString('utf-8');
        let xorBytes = '';
        for (let i = 0; i < hex.length; i += 2) {
            xorBytes += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        let seed = decryptionSeed;
        let json = '';
        for (let i = 0; i < xorBytes.length; i++) {
            const key = (seed % 255) + 1;
            seed = (seed * 1103515245 + 12345) >>> 0;
            json += String.fromCharCode(xorBytes.charCodeAt(i) ^ key);
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
        res.end(JSON.stringify({ status: 'ok', clients: clients.size, blacklisted: blacklistedJobs.size }));
    } else if (req.url === '/blacklist' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                if (data.jobId) {
                    blacklistedJobs.add(data.jobId);
                    res.end(JSON.stringify({ success: true }));
                }
            } catch(e) { res.end('error'); }
        });
    } else {
        res.writeHead(426);
        res.end('WebSocket server');
    }
});

const wss = new WebSocket.Server({ server });
const clients = new Set();

wss.on('connection', (ws) => {
    clients.add(ws);
    ws.on('message', (data) => {
        const decrypted = decryptData(data.toString());
        if (decrypted) {
            console.log(`\n[SCAN] ${decrypted.duelIcon || '💰'} ${decrypted.petName} | ${decrypted.moneyFormatted}/s | Duel:${decrypted.isDuel} | Job:${decrypted.jobId?.substring(0,12)}...`);
            clients.forEach(client => {
                if (client !== ws && client.readyState === WebSocket.OPEN) client.send(data);
            });
        }
    });
    ws.on('close', () => clients.delete(ws));
    ws.send(JSON.stringify({ type: 'welcome', timestamp: Date.now() }));
});

server.listen(PORT, () => console.log(`Server on port ${PORT}`));
