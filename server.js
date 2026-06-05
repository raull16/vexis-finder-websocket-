const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;

// Create HTTP server
const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
    } else {
        res.writeHead(426, { 'Content-Type': 'text/plain' });
        res.end('WebSocket server only');
    }
});

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// Decrypt function (reverse of Lua encryption)
function decryptData(encryptedBase64) {
    try {
        const hex = Buffer.from(encryptedBase64, 'base64').toString('utf-8');
        let json = '';
        for (let i = 0; i < hex.length; i += 2) {
            json += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        return JSON.parse(json);
    } catch (e) {
        return null;
    }
}

// Store connected clients
const clients = new Set();

wss.on('connection', (ws, req) => {
    console.log(`[WS] Client connected from ${req.socket.remoteAddress}`);
    clients.add(ws);
    
    ws.on('message', (data) => {
        try {
            const decoded = decryptData(data.toString());
            if (decoded) {
                // Log to console
                console.log('\n=== SCAN DATA ===');
                console.log(`Job ID (encrypted): ${decoded.jobId}`);
                console.log(`Player Count: ${decoded.playerCount}`);
                console.log(`Pets Found: ${decoded.pets.length}`);
                decoded.pets.forEach((pet, i) => {
                    console.log(`  ${i+1}. ${pet.petName} | ${pet.genValue} | InDuel: ${pet.inDuel}`);
                });
                console.log(`Timestamp: ${new Date(decoded.timestamp * 1000).toISOString()}`);
                console.log('=================\n');
                
                // Broadcast to all other clients (optional)
                clients.forEach(client => {
                    if (client !== ws && client.readyState === WebSocket.OPEN) {
                        client.send(data);
                    }
                });
            }
        } catch (err) {
            console.error('[WS] Parse error:', err.message);
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
    
    // Send welcome
    ws.send(Buffer.from(JSON.stringify({ status: 'connected', timestamp: Date.now() })));
});

server.listen(PORT, () => {
    console.log(`[SERVER] WebSocket server running on port ${PORT}`);
    console.log(`[SERVER] wss://vexisfinder13.onrender.com (or localhost:${PORT})`);
});
