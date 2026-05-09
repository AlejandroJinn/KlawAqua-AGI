#!/usr/bin/env python3
"""
KLAWAQUA-AGI: Coordinación Hermes ↔ OpenCLAW
Memoria compartida y contexto sincronizado
"""

import sqlite3
import json
import os
from datetime import datetime
from pathlib import Path

SHARED_DB = "/opt/klawaqua/data/klawaqua_shared_memory.db"

def init_shared_memory():
    """Inicializar base de datos compartida"""
    Path(SHARED_DB).parent.mkdir(parents=True, exist_ok=True)
    
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    # Conversaciones compartidas
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS shared_conversations (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            messages JSON,
            context JSON,
            last_agent TEXT,
            last_model TEXT,
            source TEXT,
            updated_at TIMESTAMP
        )
    ''')
    
    # Contexto persistente global
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS global_context (
            key TEXT PRIMARY KEY,
            value JSON,
            updated_by TEXT,
            updated_at TIMESTAMP
        )
    ''')
    
    # Historial de agentes
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS agent_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id TEXT,
            agent TEXT,
            model TEXT,
            action TEXT,
            success BOOLEAN,
            latency_ms INTEGER,
            timestamp TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()
    print(f"✅ Memoria compartida inicializada: {SHARED_DB}")

def save_conversation(conv_id, user_id, messages, context, agent, model, source):
    """Guardar conversación compartida"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT OR REPLACE INTO shared_conversations 
        (id, user_id, messages, context, last_agent, last_model, source, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        conv_id,
        user_id,
        json.dumps(messages),
        json.dumps(context) if context else None,
        agent,
        model,
        source,
        datetime.now().isoformat()
    ))
    
    conn.commit()
    conn.close()

def get_conversation(conv_id):
    """Obtener conversación compartida"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    cursor.execute(
        'SELECT messages, context, last_agent, last_model, source FROM shared_conversations WHERE id = ?',
        (conv_id,)
    )
    result = cursor.fetchone()
    conn.close()
    
    if result:
        return {
            'messages': json.loads(result[0]),
            'context': json.loads(result[1]) if result[1] else {},
            'last_agent': result[2],
            'last_model': result[3],
            'source': result[4]
        }
    return None

def save_global_context(key, value, agent="system"):
    """Guardar contexto global compartido"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT OR REPLACE INTO global_context 
        (key, value, updated_by, updated_at)
        VALUES (?, ?, ?, ?)
    ''', (key, json.dumps(value), agent, datetime.now().isoformat()))
    
    conn.commit()
    conn.close()

def get_global_context(key):
    """Obtener contexto global"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    cursor.execute('SELECT value FROM global_context WHERE key = ?', (key,))
    result = cursor.fetchone()
    conn.close()
    
    return json.loads(result[0]) if result else None

def log_agent_action(conv_id, agent, model, action, success, latency_ms):
    """Registrar acción de agente"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO agent_history 
        (conversation_id, agent, model, action, success, latency_ms, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', (conv_id, agent, model, action, success, latency_ms, datetime.now().isoformat()))
    
    conn.commit()
    conn.close()

def get_shared_stats():
    """Obtener estadísticas compartidas"""
    conn = sqlite3.connect(SHARED_DB)
    cursor = conn.cursor()
    
    stats = {}
    
    # Total conversaciones
    cursor.execute('SELECT COUNT(*) FROM shared_conversations')
    stats['total_conversations'] = cursor.fetchone()[0]
    
    # Conversaciones por agente
    cursor.execute('SELECT last_agent, COUNT(*) FROM shared_conversations GROUP BY last_agent')
    stats['by_agent'] = dict(cursor.fetchall())
    
    # Últimas acciones
    cursor.execute('SELECT agent, model, action, success, timestamp FROM agent_history ORDER BY id DESC LIMIT 10')
    stats['recent_actions'] = [
        {'agent': r[0], 'model': r[1], 'action': r[2], 'success': bool(r[3]), 'timestamp': r[4]}
        for r in cursor.fetchall()
    ]
    
    conn.close()
    return stats

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python3 shared_memory.py <command> [args]")
        print("\nComandos:")
        print("  init              - Inicializar memoria compartida")
        print("  stats             - Ver estadísticas")
        print("  save_context key  - Guardar contexto")
        print("  get_context key   - Obtener contexto")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "init":
        init_shared_memory()
        
    elif cmd == "stats":
        stats = get_shared_stats()
        print("\n📊 ESTADÍSTICAS COMPARTIDAS")
        print("=" * 50)
        print(f"Total conversaciones: {stats['total_conversations']}")
        print(f"\nPor agente:")
        for agent, count in stats['by_agent'].items():
            print(f"  {agent}: {count}")
        print(f"\nÚltimas acciones:")
        for action in stats['recent_actions'][:5]:
            status = "✅" if action['success'] else "❌"
            print(f"  {status} {action['agent']} ({action['model']}): {action['action']}")
        print("=" * 50)
        
    elif cmd == "save_context":
        if len(sys.argv) < 4:
            print("Uso: save_context <key> <json_value>")
            sys.exit(1)
        key = sys.argv[2]
        value = json.loads(sys.argv[3])
        save_global_context(key, value)
        print(f"✅ Contexto '{key}' guardado")
        
    elif cmd == "get_context":
        if len(sys.argv) < 3:
            print("Uso: get_context <key>")
            sys.exit(1)
        key = sys.argv[2]
        value = get_global_context(key)
        if value:
            print(f"✅ Contexto '{key}':")
            print(json.dumps(value, indent=2))
        else:
            print(f"❌ Contexto '{key}' no encontrado")
