#!/usr/bin/env python3
"""
KlawAqua Auto-Router v3 - Core Router
Local-first, fallback instantaneo a cloud free
Modos: local | auto | cloud | paid
"""

import json, time, urllib.request, urllib.error, sqlite3, os, sys
from datetime import datetime

# Config
CONFIG_DIR = "/opt/klawaqua/data"
MEMORY_DB = f"{CONFIG_DIR}/router_persistent.db"
MODE_FILE = f"{CONFIG_DIR}/router_mode.txt"
OR_KEY_FILE = f"{CONFIG_DIR}/openrouter_key.txt"
OLLAMA_URL = "http://localhost:11434"
OR_URL = "https://openrouter.ai/api/v1/chat/completions"

FREE_KEY = os.environ.get("OPENROUTER_API_KEY", "")

LOCAL_MODELS = ["qwen3.5:4b", "qwen3:4b", "qwen2.5-coder:1.5b", "qwen2.5:0.5b", "llama3.2:3b"]
CLOUD_FREE = [
    # Verified working 2026-05-09
    "qwen/qwen3-coder:free",              # 262K ctx, best free coder
    "poolside/laguna-m.1:free",           # 131K ctx, coding optimized
    "poolside/laguna-xs.2:free",          # 131K ctx, ultra fast
    "nvidia/nemotron-3-super-120b-a12b:free",  # 262K ctx, 120B params
    "google/gemma-4-31b-it:free",         # 262K ctx, good balance
    "meta-llama/llama-3.2-3b-instruct:free",   # 131K ctx, fast simple tasks
    "qwen/qwen3-next-80b-a3b-instruct:free",   # 262K ctx, 80B params
    "nousresearch/hermes-3-llama-3.1-405b:free", # 131K ctx, 405B params
]


def _cfg_file(name):
    return os.path.join(CONFIG_DIR, name)


# --- Modo ---
def get_mode():
    try:
        with open(_cfg_file("router_mode.txt")) as f:
            m = f.read().strip()
            return m if m in ("local","auto","cloud","paid") else "auto"
    except: return "auto"

def set_mode(m):
    if m not in ("local","auto","cloud","paid"): return
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(_cfg_file("router_mode.txt"), "w") as f: f.write(m)


# --- DB ---
def _db():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    c = sqlite3.connect(MEMORY_DB)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, last_model TEXT, last_source TEXT, messages JSON, updated TEXT)")
    c.execute("CREATE TABLE IF NOT EXISTS stats(model TEXT, source TEXT, ok INT, fail INT, ms REAL, last TEXT, PRIMARY KEY(model,source))")
    c.commit()
    return c


def get_ctx(sid):
    c = _db()
    try:
        r = c.execute("SELECT messages FROM sessions WHERE id=?", (sid,)).fetchone()
        return json.loads(r[0]) if r and r[0] else []
    except: return []
    finally: c.close()


def save_ctx(sid, model, source, msgs):
    c = _db()
    c.execute("INSERT OR REPLACE INTO sessions VALUES(?,?,?,?,?)",
        (sid, model, source, json.dumps(msgs[-50:], ensure_ascii=False), datetime.now().isoformat()))
    c.commit(); c.close()


def hit(model, source, ok, ms):
    c = _db()
    r = c.execute("SELECT * FROM stats WHERE model=? AND source=?", (model, source)).fetchone()
    if r:
        o = r["ok"]+(1 if ok else 0); f = r["fail"]+(0 if ok else 1)
        avg = (r["ms"]*(o+f-1) + ms)/(o+f) if o+f>0 and r["ms"] else ms
        c.execute("UPDATE stats SET ok=?,fail=?,ms=?,last=? WHERE model=? AND source=?", (o,f,avg,datetime.now().isoformat(),model,source))
    else:
        c.execute("INSERT INTO stats VALUES(?,?,?,?,?,?)", (model,source,1 if ok else 0,0 if ok else 1,ms,datetime.now().isoformat()))
    c.commit(); c.close()


# --- Deteccion ---
def ollama_up():
    """GET /api/tags, 2s timeout -> instant decision"""
    try:
        resp = urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=2)
        return resp.status == 200
    except:
        return False


def best_local():
    """Mejor modelo local disponible, 3s"""
    try:
        resp = urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=3)
        avail = [m["name"] for m in json.loads(resp.read()).get("models", [])]
        for m in LOCAL_MODELS:
            if m in avail: return m
    except: pass
    return None


# --- Chat ---
def _ollama(msgs, model, timeout=45):
    d = json.dumps({"model":model, "messages":msgs, "stream":False, "options":{"num_ctx":4096}}).encode()
    req = urllib.request.Request(f"{OLLAMA_URL}/api/chat", data=d, headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())["message"]["content"]


def _openrouter(msgs, model, timeout=25):
    d = json.dumps({"model":model, "messages":msgs, "max_tokens":2048}).encode()
    req = urllib.request.Request(OR_URL, data=d, headers={
        "Content-Type":"application/json", "Authorization":f"Bearer {FREE_KEY}",
        "HTTP-Referer":"https://klawaqua.ai", "X-Title":"KlawAqua"})
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())["choices"][0]["message"]["content"]


def _try_cloud(msgs, pool):
    for m in pool:
        try:
            resp = _openrouter(msgs, m)
            return m, resp
        except: continue
    return None, None


# --- Core ---
def route(query, sid="default"):
    mode = get_mode()
    t0 = time.time()
    ctx = get_ctx(sid)
    msgs = ctx + [{"role":"user", "content":query}]
    
    src, mod, resp = "unknown", "unknown", ""
    
    if mode == "local":
        lm = best_local()
        if not lm: return _err("Modo local pero Ollama no responde")
        try:
            resp = _ollama(msgs, lm)
            ms = _ms(t0)
            hit(lm, "local", True, ms); src, mod = "local", lm
        except Exception as e: return _err(f"Local fallo: {e}")
    
    elif mode in ("cloud", "paid"):
        pool = CLOUD_FREE if mode == "cloud" else [
            "anthropic/claude-sonnet-4", "openai/gpt-4o", "google/gemini-2.5-flash-preview-05-20"
        ]
        mod, resp = _try_cloud(msgs, pool)
        src = mod and "cloud" or "error"
        if mod: hit(mod, "cloud", True, _ms(t0))
    
    else:  # auto - local primero, fallback instantaneo
        if ollama_up():
            lm = best_local()
            if lm:
                try:
                    resp = _ollama(msgs, lm)
                    ms = _ms(t0)
                    hit(lm, "local", True, ms); src, mod = "local", lm
                except:
                    mod, resp = _try_cloud(msgs, CLOUD_FREE)
                    src = mod and "cloud" or "error"
                    if mod: hit(mod, "cloud", True, _ms(t0))
            else:
                mod, resp = _try_cloud(msgs, CLOUD_FREE)
                src = mod and "cloud" or "error"
        else:
            mod, resp = _try_cloud(msgs, CLOUD_FREE)
            src = mod and "cloud" or "error"
    
    if resp: save_ctx(sid, mod, src, msgs + [{"role":"assistant","content":resp}])
    return _ok(resp, mod, src, t0, mode, sid)


def _ms(t0): return round((time.time()-t0)*1000)
def _ok(resp, model, source, t0, mode, sid):
    return {"response":resp, "model":model, "source":source, 
        "latency_ms":_ms(t0), "mode":mode, "session_id":sid}
def _err(msg):
    return {"response":"", "model":"none", "source":"error", 
        "latency_ms":0, "error":msg, "mode":get_mode()}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv)>1 else "test"
    if cmd == "mode":
        a = sys.argv[2] if len(sys.argv)>2 else ""
        if a in ("local","auto","cloud","paid"):
            set_mode(a); print(f"Modo: {a}")
        else:
            print(f"Modo actual: {get_mode()}"); print("mode [local|auto|cloud|paid]")
    elif cmd == "test":
        q = " ".join(sys.argv[2:]) if len(sys.argv)>2 else "Di hola"
        r = route(q)
        print(f"Modo: {r['mode']} | {r['model']} ({r['source']}) | {r['latency_ms']}ms\n---\n{r.get('response',r.get('error',''))}")
    elif cmd == "stats":
        c = _db()
        rows = c.execute("SELECT * FROM stats ORDER BY ok DESC").fetchall()
        print(f"{'Model':<50} {'Src':<6} {'OK':<4} {'Fail':<4} {'ms':<8}")
        for s in rows: print(f"{s[0]:<50} {s[1]:<6} {s[2]:<4} {s[3]:<4} {s[4] or '-':<8}")
        c.close()
