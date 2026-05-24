const WebSocket = require('ws');
const crypto = require('crypto');

const PORT = process.env.PORT || 8080;
const clients = new Map();

const wss = new WebSocket.Server({ port: PORT });
console.log(`WebSocket server running on port ${PORT}`);

wss.on('connection', (ws, req) => {
    const clientId = crypto.randomBytes(8).toString('hex');
    clients.set(clientId, ws);
    console.log(`[${clientId}] Client connected`);

    ws.on('message', async (data) => {
        try {
            // Convert to string if needed
            let message = data;
            if (Buffer.isBuffer(data)) {
                message = data.toString('utf8');
            }
            
            const payload = JSON.parse(message);
            
            console.log(`[${clientId}] 📡 ${payload.name} | ${payload.money.toLocaleString()}/s | ${payload.players}/${payload.maxplayers} players | Job: ${payload.jobid}`);
            
            // Broadcast to all other clients
            for (const [id, client] of clients) {
                if (id !== clientId && client.readyState === WebSocket.OPEN) {
                    client.send(message);
                }
            }
        } catch (err) {
            console.log(`[${clientId}] Error:`, err.message);
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
