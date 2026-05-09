#!/usr/bin/env python3
"""
Persistent Memory Manager para KlawAqua
Gestiona memoria compartida entre local y cloud - nada se pierde en transiciones.
"""

import sqlite3
import json
import os
from datetime import datetime

DB_PATH = "/opt/klawaqua/data/klawaqua_persistent_memory.db"

def get_conn():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_db():
    conn = get_conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS context_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS conversation_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            role TEXT,
            content TEXT,
            model_used TEXT,
            source TEXT,
            tokens_used INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS agent_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT,
            agent_name TEXT,
            status TEXT DEFAULT 'pending',
            task_description TEXT,
            result TEXT,
            local_failures INTEGER DEFAULT 0,
            cloud_failures INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS model_switches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_model TEXT,
            to_model TEXT,
            reason TEXT,
            duration_seconds INTEGER,
            context_preserved INTEGER DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS system_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS idx_conv_user ON conversation_history(user_id, created_at);
        CREATE INDEX IF NOT EXISTS idx_jobs_status ON agent_jobs(status);
    """)
    conn.commit()
    conn.close()

def save_context(key, value):
    conn = get_conn()
    conn.execute(
        "INSERT OR REPLACE INTO context_state (key, value) VALUES (?, ?)",
        (key, json.dumps(value))
    )
    conn.commit()
    conn.close()

def load_context(key):
    conn = get_conn()
    row = conn.execute("SELECT value FROM context_state WHERE key = ?", (key,)).fetchone()
    conn.close()
    if row:
        return json.loads(row["value"])
    return None

def log_message(user_id, role, content, model_used="unknown", source="local"):
    conn = get_conn()
    conn.execute(
        "INSERT INTO conversation_history (user_id, role, content, model_used, source) VALUES (?, ?, ?, ?, ?)",
        (user_id, role, content, model_used, source)
    )
    conn.commit()
    conn.close()

def log_switch(from_model, to_model, reason, duration=0):
    conn = get_conn()
    conn.execute(
        "INSERT INTO model_switches (from_model, to_model, reason, duration_seconds) VALUES (?, ?, ?, ?)",
        (from_model, to_model, reason, duration)
    )
    conn.commit()
    conn.close()

def save_system_state(key, value):
    conn = get_conn()
    conn.execute(
        "INSERT OR REPLACE INTO system_state (key, value) VALUES (?, ?)",
        (key, json.dumps(value))
    )
    conn.commit()
    conn.close()

def load_system_state(key):
    conn = get_conn()
    row = conn.execute("SELECT value FROM system_state WHERE key = ?", (key,)).fetchone()
    conn.close()
    if row:
        return json.loads(row["value"])
    return None

def get_active_jobs():
    conn = get_conn()
    rows = conn.execute(
        "SELECT * FROM agent_jobs WHERE status IN ('pending', 'running') ORDER BY created_at"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]

def update_job(job_id, status, result=None):
    conn = get_conn()
    conn.execute(
        "UPDATE agent_jobs SET status = ?, result = ?, updated_at = CURRENT_TIMESTAMP WHERE job_id = ?",
        (status, result, job_id)
    )
    conn.commit()
    conn.close()

def stats():
    conn = get_conn()
    data = {}
    data["total_messages"] = conn.execute("SELECT COUNT(*) FROM conversation_history").fetchone()[0]
    data["total_switches"] = conn.execute("SELECT COUNT(*) FROM model_switches").fetchone()[0]
    data["pending_jobs"] = conn.execute("SELECT COUNT(*) FROM agent_jobs WHERE status='pending'").fetchone()[0]
    data["running_jobs"] = conn.execute("SELECT COUNT(*) FROM agent_jobs WHERE status='running'").fetchone()[0]
    data["model_usage"] = conn.execute(
        "SELECT model_used, COUNT(*) as cnt FROM conversation_history GROUP BY model_used ORDER BY cnt DESC"
    ).fetchall()
    data["last_switch"] = conn.execute(
        "SELECT * FROM model_switches ORDER BY id DESC LIMIT 1"
    ).fetchone()
    conn.close()
    result = {}
    for k, v in data.items():
        if isinstance(v, list):
            result[k] = [dict(r) for r in v]
        elif isinstance(v, sqlite3.Row):
            result[k] = dict(v)
        else:
            result[k] = v
    return result

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "stats"
    
    if cmd == "init":
        init_db()
        print("✅ Memoria persistente inicializada")
        print(f"   DB: {DB_PATH}")
    elif cmd == "stats":
        init_db()
        s = stats()
        print(f"📊 Estadísticas memoria persistente:")
        print(f"   Mensajes: {s['total_messages']}")
        print(f"   Cambios modelo: {s['total_switches']}")
        print(f"   Trabajos pendientes: {s['pending_jobs']}")
        print(f"   Trabajos corriendo: {s['running_jobs']}")
        if s['last_switch']:
            print(f"   Último cambio: {s['last_switch']['from_model']} -> {s['last_switch']['to_model']}")
        if s['model_usage']:
            print(f"   Uso por modelo:")
            for m in s['model_usage'][:5]:
                print(f"     {m['model_used']}: {m['cnt']} mensajes")
    elif cmd == "save":
        key, val = sys.argv[2], sys.argv[3]
        save_context(key, val)
        print(f"✅ Contexto guardado: {key}")
    elif cmd == "load":
        val = load_context(sys.argv[2])
        print(json.dumps(val, indent=2, ensure_ascii=False))
    else:
        print("Uso: python3 persistent_memory.py [init|stats|save KEY VALUE|load KEY]")
