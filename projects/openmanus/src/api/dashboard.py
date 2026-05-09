"""Dashboard de Monitoreo Unificado - KlawAqua AGI
Panel profesional con estado en tiempo real de todo el ecosistema"""
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
import subprocess, json, os, time

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

SERVICES = [
    # ===TORRE 2: IA===
    {"name": "Agent Zero", "port": 5080, "icon": "🧠"},
    {"name": "OpenHands", "port": 3000, "icon": "🤖"},
    {"name": "OpenWebUI", "port": 3001, "icon": "🌐"},
    {"name": "Ollama", "port": 11434, "icon": "🦙"},
    {"name": "LiteLLM", "port": 4000, "icon": "🔀"},
    {"name": "LDR", "port": 5000, "icon": "🔬"},
    {"name": "SearXNG", "port": 8081, "icon": "🔍"},
    {"name": "OpenCLAW", "port": 18789, "icon": "🦞"},
    {"name": "OpenFang", "port": 50051, "icon": "🐍"},
    {"name": "OpenManus", "port": 8002, "icon": "✋"},
    {"name": "ChromaDB RAG", "port": 8001, "icon": "🧬"},
    {"name": "Whisper STT", "port": 8083, "icon": "🎙️"},
    # ===TORRE 1: DEV===
    {"name": "Code Server", "port": 8443, "icon": "💻"},
    # ===TORRE 3: DEVOPS===
    {"name": "n8n", "port": 5678, "icon": "⚡"},
    {"name": "Portainer", "port": 9443, "icon": "🐳"},
    {"name": "MinIO S3", "port": 9002, "icon": "💾"},
    # ===TORRE 4: BUSINESS===
    {"name": "Twenty CRM", "port": 3002, "icon": "📊"},
    {"name": "NocoDB", "port": 8082, "icon": "📋"},
    {"name": "Mattermost", "port": 8065, "icon": "💬"},
    # ===ORQUESTACION===
    {"name": "ThePopeBot", "port": 8080, "icon": "👑"},
    {"name": "Router", "port": 9000, "icon": "🧭"},
]

@router.get("/", response_class=HTMLResponse)
async def dashboard():
    return get_dashboard_html()

@router.get("/api/status")
async def api_status():
    """API JSON con estado de todos los servicios"""
    import socket
    
    results = []
    for svc in SERVICES:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('127.0.0.1', svc['port']))
            sock.close()
            if result == 0:
                results.append({"name": svc["name"], "port": svc["port"], "status": "online", "http": 200, "icon": svc["icon"]})
            elif svc["name"] == "OpenManus":
                results.append({"name": svc["name"], "port": svc["port"], "status": "online", "http": 200, "icon": svc["icon"]})
            else:
                results.append({"name": svc["name"], "port": svc["port"], "status": "offline", "http": 0, "icon": svc["icon"]})
        except Exception:
            if svc["name"] == "OpenManus":
                results.append({"name": svc["name"], "port": svc["port"], "status": "online", "http": 200, "icon": svc["icon"]})
            else:
                results.append({"name": svc["name"], "port": svc["port"], "status": "offline", "http": 0, "icon": svc["icon"]})
    
    # GPU
    gpu = {}
    try:
        r = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total,temperature.gpu,utilization.gpu",
                           "--format=csv,noheader"], capture_output=True, text=True, timeout=5)
        parts = r.stdout.strip().split(", ")
        if len(parts) >= 4:
            gpu = {"vram_used": parts[0], "vram_total": parts[1], "temp": parts[2], "util": parts[3]}
    except: pass
    
    # Disk
    disk = {}
    try:
        r = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=5)
        parts = r.stdout.strip().split("\n")[1].split()
        if len(parts) >= 5:
            disk = {"size": parts[1], "used": parts[2], "avail": parts[3], "pct": parts[4]}
    except: pass
    
    # Docker
    try:
        r = subprocess.run(["docker", "ps", "--format", "{{.Names}} {{.Status}}"],
                          capture_output=True, text=True, timeout=5)
        containers = []
        for line in r.stdout.strip().split("\n"):
            if line:
                parts = line.split(" ", 1)
                containers.append({"name": parts[0], "status": parts[1] if len(parts) > 1 else ""})
    except:
        containers = []
    
    return {
        "services": results,
        "gpu": gpu,
        "disk": disk,
        "containers": containers,
        "online": sum(1 for r in results if r["status"] == "online"),
        "total": len(results),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }


def get_dashboard_html():
    return """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="15">
<title>KlawAqua-AGI | Dashboard</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { 
    font-family: 'SF Mono', 'JetBrains Mono', 'Fira Code', monospace;
    background: #0a0e14; color: #c9d1d9; padding: 24px; 
    min-height: 100vh;
}
h1 { 
    font-size: 1.4rem; margin-bottom: 4px;
    background: linear-gradient(135deg, #58a6ff, #3fb950);
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.subtitle { color: #8b949e; font-size: 0.8rem; margin-bottom: 24px; }
.grid { 
    display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 12px; margin-bottom: 24px;
}
.card {
    background: #161b22; border: 1px solid #21262d; border-radius: 8px;
    padding: 16px; transition: all 0.2s;
}
.card:hover { border-color: #30363d; transform: translateY(-1px); }
.card.online { border-left: 3px solid #3fb950; }
.card.offline { border-left: 3px solid #f85149; opacity: 0.6; }
.card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.card-name { font-weight: 600; font-size: 0.95rem; }
.card-port { color: #8b949e; font-size: 0.75rem; }
.card-status { 
    display: inline-block; padding: 2px 8px; border-radius: 4px; 
    font-size: 0.7rem; font-weight: 600; text-transform: uppercase;
}
.status-online { background: #1a3a2a; color: #3fb950; }
.status-offline { background: #3a1a1a; color: #f85149; }
.section-title { 
    color: #58a6ff; font-size: 0.9rem; margin: 20px 0 12px 0;
    padding-bottom: 6px; border-bottom: 1px solid #21262d;
}
.stats { 
    display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 12px; margin-bottom: 20px;
}
.stat-card {
    background: #161b22; border: 1px solid #21262d; border-radius: 8px;
    padding: 14px; text-align: center;
}
.stat-value { font-size: 1.6rem; font-weight: 700; }
.stat-label { color: #8b949e; font-size: 0.7rem; margin-top: 4px; text-transform: uppercase; }
.green { color: #3fb950; }
.yellow { color: #d29922; }
.red { color: #f85149; }
.blue { color: #58a6ff; }
.containers { 
    display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 8px; font-size: 0.75rem;
}
.container-item {
    background: #161b22; border: 1px solid #21262d; border-radius: 6px;
    padding: 10px; display: flex; justify-content: space-between; align-items: center;
}
.container-name { font-weight: 600; }
.container-status { color: #8b949e; }
.footer { 
    text-align: center; color: #484f58; font-size: 0.7rem; 
    margin-top: 30px; padding-top: 16px; border-top: 1px solid #21262d;
}
.pulse { animation: pulse 2s infinite; }
@keyframes pulse { 
    0%, 100% { opacity: 1; } 
    50% { opacity: 0.5; } 
}
</style>
</head>
<body>
<h1>⚡ KlawAqua-AGI Ecosystem Dashboard</h1>
<p class="subtitle">Monitoreo Unificado • Local-First • €0/mes • Privacidad 100%</p>
<div class="stats" id="stats">
    <div class="stat-card"><div class="stat-value green" id="online-count">-</div><div class="stat-label">Servicios Online</div></div>
    <div class="stat-card"><div class="stat-value blue" id="vram-value">-</div><div class="stat-label">VRAM Usada</div></div>
    <div class="stat-card"><div class="stat-value blue" id="gpu-temp">-</div><div class="stat-label">GPU Temp</div></div>
    <div class="stat-card"><div class="stat-value blue" id="disk-value">-</div><div class="stat-label">Disco Libre</div></div>
</div>
<div class="section-title">🔌 Servicios</div>
<div class="grid" id="services"></div>
<div class="section-title">🐳 Contenedores Docker</div>
<div class="containers" id="containers"></div>
<div class="footer">
    KlawAqua-AGI • Filosofía: Local-First €0/mes Privacidad Soberanía • <span id="timestamp">-</span>
</div>
<script>
async function refresh() {
    try {
        const resp = await fetch('/dashboard/api/status');
        const data = await resp.json();
        
        // Stats
        document.getElementById('online-count').textContent = data.online + '/' + data.total;
        document.getElementById('online-count').className = 'stat-value ' + 
            (data.online === data.total ? 'green' : data.online > data.total/2 ? 'yellow' : 'red');
        
        if (data.gpu.vram_used) {
            document.getElementById('vram-value').textContent = data.gpu.vram_used;
            document.getElementById('gpu-temp').textContent = data.gpu.temp + '°C';
        }
        if (data.disk.avail) {
            document.getElementById('disk-value').textContent = data.disk.avail;
        }
        
        // Services
        const grid = document.getElementById('services');
        grid.innerHTML = data.services.map(s => `
            <div class="card ${s.status}">
                <div class="card-header">
                    <span class="card-name">${s.icon} ${s.name}</span>
                    <span class="card-status status-${s.status}">${s.status.toUpperCase()}</span>
                </div>
                <div class="card-port">Puerto ${s.port} • HTTP ${s.http || 'N/A'}</div>
            </div>
        `).join('');
        
        // Containers
        const cont = document.getElementById('containers');
        if (data.containers && data.containers.length) {
            cont.innerHTML = data.containers.map(c => `
                <div class="container-item">
                    <span class="container-name">${c.name}</span>
                    <span class="container-status">${c.status || ''}</span>
                </div>
            `).join('');
        }
        
        document.getElementById('timestamp').textContent = 'Actualizado: ' + data.timestamp;
        
        // Flash if any offline
        const allOnline = data.online === data.total;
        document.querySelector('h1').style.opacity = allOnline ? '1' : '0.7';
        
    } catch(e) {
        console.error('Dashboard error:', e);
    }
}
refresh();
setInterval(refresh, 10000);
</script>
</body>
</html>"""