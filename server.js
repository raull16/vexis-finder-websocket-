const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const BLACKLIST_FILE = path.join(__dirname, 'blacklist.json');

// Load or create blacklist
let blacklistedJobs = new Set();
if (fs.existsSync(BLACKLIST_FILE)) {
    try {
        const data = JSON.parse(fs.readFileSync(BLACKLIST_FILE, 'utf8'));
        blacklistedJobs = new Set(data);
        console.log(`[BLACKLIST] Loaded ${blacklistedJobs.size} blacklisted jobs`);
    } catch(e) {}
}

// Save blacklist
function saveBlacklist() {
    fs.writeFileSync(BLACKLIST_FILE, JSON.stringify([...blacklistedJobs]), 'utf8');
}

// Decryption (reverse of Lua encryption: Base64 → Hex → XOR)
const decryptionSeed = 0x7F3A9C2E;
function decryptData(encryptedBase64) {
    try {
        // Layer 1: Base64 decode
        const hex = Buffer.from(encryptedBase64, 'base64').toString('utf-8');
        
        // Layer 2: Hex decode
        let xorBytes = '';
        for (let i = 0; i < hex.length; i += 2) {
            xorBytes += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        }
        
        // Layer 3: XOR with rolling key
        let seed = decryptionSeed;
        let json = '';
        for (let i = 0; i < xorBytes.length; i++) {
            const key = (seed % 255) + 1;
            seed = (seed * 1103515245 + 12345) >>> 0;
            json += String.fromCharCode(xorBytes.charCodeAt(i) ^ key);
        }
        
        return JSON.parse(json);
    } catch (e) {
        console.error('[DECRYPT] Failed:', e.message);
        return null;
    }
}

// Create HTTP server
const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // Health check
    if (req.url === '/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', connectedClients: clients.size, blacklisted: blacklistedJobs.size }));
        return;
    }
    
    // Get blacklist
    if (req.url === '/blacklist' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ blacklisted: [...blacklistedJobs] }));
        return;
    }
    
    // Add to blacklist (from scanner)
    if (req.url === '/blacklist' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => body += chunk);
        req.on('end', () => {
            try {
                const data = JSON.parse(body);
                if (data.jobId) {
                    blacklistedJobs.add(data.jobId);
                    saveBlacklist();
                    console.log(`[BLACKLIST] Added: ${data.jobId}`);
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ success: true, count: blacklistedJobs.size }));
                } else {
                    res.writeHead(400);
                    res.end('Missing jobId');
                }
            } catch(e) {
                res.writeHead(400);
                res.end('Invalid JSON');
            }
        });
        return;
    }
    
    // Default response
    res.writeHead(426, { 'Content-Type': 'text/plain' });
    res.end('WebSocket server only. Use wss://vexisfinder13.onrender.com for WebSocket connections');
});

// WebSocket server
const wss = new WebSocket.Server({ server });
const clients = new Set();

wss.on('connection', (ws, req) => {
    const clientIP = req.socket.remoteAddress;
    console.log(`[WS] Client connected from ${clientIP}`);
    clients.add(ws);
    
    ws.on('message', (data) => {
        const decrypted = decryptData(data.toString());
        if (decrypted) {
            // Check if job is blacklisted
            const isBlacklisted = blacklistedJobs.has(decrypted.jobId);
            
            const logEntry = {
                ...decrypted,
                isBlacklisted,
                receivedAt: Date.now()
            };
            
            console.log('\n═══════════════════════════════════════');
            console.log(`📡 PET SCAN RECEIVED [${new Date().toLocaleTimeString()}]`);
            console.log(`   Pet: ${logEntry.duelIcon || '💰'} ${logEntry.petName}`);
            console.log(`   Money: ${logEntry.moneyPerSecond?.toLocaleString()} ${logEntry.moneyFormatted ? `(${logEntry.moneyFormatted}/s)` : ''}`);
            console.log(`   Mutation: ${logEntry.mutation || 'None'}`);
            console.log(`   Traits: ${logEntry.traits?.length || 0} traits`);
            console.log(`   Duel: ${logEntry.isDuel ? '⚔️ YES' : 'NO'}`);
            console.log(`   Owner: ${logEntry.owner}`);
            console.log(`   Job ID: ${logEntry.jobId?.substring(0, 16)}...`);
            console.log(`   Players: ${logEntry.playerCount}`);
            console.log(`   Blacklisted: ${isBlacklisted ? '⚠️ YES' : 'NO'}`);
            console.log('═══════════════════════════════════════\n');
            
            // Broadcast to other clients (optional)
            clients.forEach(client => {
                if (client !== ws && client.readyState === WebSocket.OPEN) {
                    client.send(data);
                }
            });
        }
    });
    
    ws.on('close', () => {
        console.log(`[WS] Client disconnected from ${clientIP}`);
        clients.delete(ws);
    });
    
    ws.on('error', (err) => {
        console.error(`[WS] Error from ${clientIP}:`, err.message);
        clients.delete(ws);
    });
    
    // Send welcome
    ws.send(JSON.stringify({ 
        type: 'welcome', 
        message: 'Connected to VexisFinder WebSocket',
        blacklistCount: blacklistedJobs.size,
        timestamp: Date.now() 
    }));
});

// Periodic blacklist backup
setInterval(() => saveBlacklist(), 60000);

server.listen(PORT, () => {
    console.log(`\n═══════════════════════════════════════`);
    console.log(`🚀 VEXISFINDER WEBSOCKET SERVER`);
    console.log(`   Port: ${PORT}`);
    console.log(`   WebSocket: wss://vexisfinder13.onrender.com`);
    console.log(`   HTTP Health: https://vexisfinder13.onrender.com/health`);
    console.log(`   Blacklist Size: ${blacklistedJobs.size}`);
    console.log(`═══════════════════════════════════════\n`);
});
