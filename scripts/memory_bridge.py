#!/usr/bin/env python3
"""
KlawAqua Memory Bridge - Persistencia entre Local↔Cloud
Syncs conversation context between ThePopeBot SQLite and persistent memory
"""

import sqlite3
import json
import os
from datetime import datetime

MEMORY_DB = "/opt/klawaqua/data/klawaqua_persistent_memory.db"
POPEBOT_DB = "/opt/klawaqua/projects/thepopebot-instance/data/db/thepopebot.sqlite"

def get_memory_conn():
    os.makedirs(os.path.dirname(MEMORY_DB), exist_ok=True)
    conn = sqlite3.connect(MEMORY_DB)
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_memory():
    conn = get_memory_conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS conversation_context (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            role TEXT,
            content TEXT,
            model_used TEXT,
            source TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS agent_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id TEXT,
            status TEXT,
            result TEXT,
            model_at_time TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS model_state (
            key TEXT PRIMARY KEY,
            value TEXT,
            last_model TEXT,
            last_fallback TEXT,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE TABLE IF NOT EXISTS pending_work (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_name TEXT,
            description TEXT,
            priority INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            completed_at DATETIME,
            status TEXT DEFAULT 'pending'
        );
        
        CREATE INDEX IF NOT EXISTS idx_ctx_session ON conversation_context(session_id);
    """)
    conn.commit()
    conn.close()

def log_message(session_id, role, content, model="unknown", source="local"):
    conn = get_memory_conn()
    try:
        conn.execute(
            "INSERT INTO conversation_context (session_id, role, content, model_used, source) VALUES (?,?,?,?,?)",
            (session_id, role, str(content), model, source)
        )
        conn.commit()
    finally:
        conn.close()

def save_work(job_name, description, priority=0):
    conn = get_memory_conn()
    try:
        conn.execute(
            "INSERT INTO pending_work (job_name, description, priority) VALUES (?,?,?)",
            (job_name, str(description), priority)
        )
        conn.commit()
    finally:
        conn.close()

def complete_work(job_name):
    conn = get_memory_conn()
    try:
        conn.execute(
            "UPDATE pending_work SET status='completed', completed_at=CURRENT_TIMESTAMP WHERE job_name=? AND status='pending'",
            (job_name,)
        )
        conn.commit()
    finally:
        conn.close()

def get_active_work():
    conn = get_memory_conn()
    try:
        rows = conn.execute(
            "SELECT * FROM pending_work WHERE status='pending' ORDER BY priority DESC, created_at"
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()

def get_context(session_id, limit=50):
    conn = get_memory_conn()
    try:
        rows = conn.execute(
            "SELECT * FROM conversation_context WHERE session_id=? ORDER BY timestamp DESC LIMIT ?",
            (session_id, limit)
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()

def record_model_change(from_model, to_model, reason):
    conn = get_memory_conn()
    try:
        conn.execute(
            "INSERT OR REPLACE INTO model_state (key, value, last_model, last_fallback) VALUES (?, ?, ?, ?)",
            ("active", f"Switched {reason}", from_model, to_model)
        )
        conn.commit()
    finally:
        conn.close()

if __name__ == "__main__":
    import sys
    init_memory()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    
    if cmd == "log":
        # log session role content [model] [source]
        session = sys.argv[2] if len(sys.argv) > 2 else "default"
        role = sys.argv[3] if len(sys.argv) > 3 else "user"
        content = sys.argv[4] if len(sys.argv) > 4 else ""
        model = sys.argv[5] if len(sys.argv) > 5 else "unknown"
        source = sys.argv[6] if len(sys.argv) > 6 else "local"
        log_message(session, role, content, model, source)
        print(f"OK")
    elif cmd == "save_work":
        name = sys.argv[2]
        desc = sys.argv[3] if len(sys.argv) > 3 else ""
        prio = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        save_work(name, desc, prio)
        print(f"OK: {name}")
    elif cmd == "complete_work":
        complete_work(sys.argv[2])
        print(f"OK: {sys.argv[2]}")
    elif cmd == "active_work":
        work = get_active_work()
        for w in work:
            print(f"  [{w['priority']}] {w['job_name']}: {w['description']} ({w['created_at']})")
        if not work:
            print("  (none)")
    elif cmd == "context":
        session = sys.argv[2] if len(sys.argv) > 2 else "default"
        msgs = get_context(session)
        for m in msgs:
            print(f"  [{m['model_used']}] {m['role']}: {m['content'][:100]}...")
    elif cmd == "stats":
        conn = get_memory_conn()
        try:
            msgs = conn.execute("SELECT COUNT(*) FROM conversation_context").fetchone()[0]
            jobs = conn.execute("SELECT COUNT(*) FROM pending_work WHERE status='pending'").fetchone()[0]
            completed = conn.execute("SELECT COUNT(*) FROM pending_work WHERE status='completed'").fetchone()[0]
            models = conn.execute("SELECT last_model, last_fallback FROM model_state WHERE key='active'").fetchone()
            print(f"Memoria persistente stats:")
            print(f"  Mensajes guardados: {msgs}")
            print(f"  Trabajos pendientes: {jobs}")
            print(f"  Trabajos completados: {completed}")
            if models:
                print(f"  Último modelo: {models[0]} -> fallback: {models[1]}")
        finally:
            conn.close()
    else:
        print("Uso: memory_bridge.py [init|log|save_work|complete_work|active_work|context|stats]")
