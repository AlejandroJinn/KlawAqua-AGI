#!/usr/bin/env python3
"""
KLAWAQUA-AGI: CRM Ligero
Servicio HTTP de gestión de clientes, leads, pipeline y actividades
SQLite, <50MB RAM, integrado con todo el ecosistema
Puerto: 3008
"""

import os, json, sqlite3, time
from pathlib import Path
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

KLAWAQUA = "/opt/klawaqua"
DB_PATH = f"{KLAWAQUA}/data/klawaqua_crm.db"
LOG_FILE = f"{KLAWAQUA}/logs/crm.log"
PORT = 3008
HOST = "0.0.0.0"

def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        Path(LOG_FILE).parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a") as f: f.write(line + "\n")
    except: pass


class CRM:
    def __init__(self):
        Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
        self._init()

    def _conn(self):
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn

    def _init(self):
        c = self._conn()
        c.executescript("""
            CREATE TABLE IF NOT EXISTS contacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT DEFAULT 'contact',
                name TEXT NOT NULL,
                email TEXT, phone TEXT, company TEXT,
                status TEXT DEFAULT 'new',
                source TEXT, notes TEXT,
                tags TEXT DEFAULT '[]',
                pipeline_stage TEXT DEFAULT 'lead',
                created_at TEXT, updated_at TEXT
            );
            CREATE TABLE IF NOT EXISTS activities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                contact_id INTEGER REFERENCES contacts(id),
                type TEXT, title TEXT, description TEXT,
                due_date TEXT, completed INTEGER DEFAULT 0,
                created_at TEXT
            );
            CREATE TABLE IF NOT EXISTS deals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                contact_id INTEGER REFERENCES contacts(id),
                title TEXT, value REAL DEFAULT 0,
                stage TEXT DEFAULT 'prospecting',
                probability REAL DEFAULT 10,
                close_date TEXT, created_at TEXT
            );
        """)
        c.commit()
        c.close()

    # CONTACTS
    def add_contact(self, data):
        c = self._conn()
        cur = c.cursor()
        cur.execute("INSERT INTO contacts (name,email,phone,company,status,source,notes,tags,pipeline_stage,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                  (data.get("name",""), data.get("email",""), data.get("phone",""), data.get("company",""),
                   data.get("status","new"), data.get("source",""), data.get("notes",""),
                   json.dumps(data.get("tags",[])), data.get("pipeline_stage","lead"),
                   datetime.now().isoformat(), datetime.now().isoformat()))
        c.commit()
        rid = cur.lastrowid
        c.close()
        return self.get_contact(rid)

    def get_contact(self, cid):
        c = self._conn()
        r = c.execute("SELECT * FROM contacts WHERE id=?", (cid,)).fetchone()
        c.close()
        return dict(r) if r else None

    def list_contacts(self, stage=None, status=None, search=None):
        c = self._conn()
        q = "SELECT * FROM contacts WHERE 1=1"
        params = []
        if stage: q += " AND pipeline_stage=?"; params.append(stage)
        if status: q += " AND status=?"; params.append(status)
        if search: q += " AND (name LIKE ? OR email LIKE ? OR company LIKE ?)"; params.extend([f"%{search}%"]*3)
        q += " ORDER BY created_at DESC"
        rows = [dict(r) for r in c.execute(q, params).fetchall()]
        c.close()
        return rows

    def update_contact(self, cid, data):
        sets, vals = [], []
        for k in ["name","email","phone","company","status","source","notes","pipeline_stage","tags"]:
            if k in data:
                sets.append(f"{k}=?")
                vals.append(json.dumps(data[k]) if k=="tags" else data[k])
        if not sets: return self.get_contact(cid)
        sets.append("updated_at=?"); vals.append(datetime.now().isoformat())
        vals.append(cid)
        c = self._conn()
        c.execute(f"UPDATE contacts SET {', '.join(sets)} WHERE id=?", vals)
        c.commit()
        c.close()
        return self.get_contact(cid)

    def delete_contact(self, cid):
        c = self._conn()
        c.execute("DELETE FROM contacts WHERE id=?", (cid,))
        c.execute("DELETE FROM activities WHERE contact_id=?", (cid,))
        c.execute("DELETE FROM deals WHERE contact_id=?", (cid,))
        c.commit()
        c.close()
        return True

    # ACTIVITIES
    def add_activity(self, data):
        c = self._conn()
        cur = c.cursor()
        cur.execute("INSERT INTO activities (contact_id,type,title,description,due_date,created_at) VALUES (?,?,?,?,?,?)",
                  (data.get("contact_id"), data.get("type","call"), data.get("title",""),
                   data.get("description",""), data.get("due_date",""), datetime.now().isoformat()))
        c.commit()
        rid = cur.lastrowid
        c.close()
        return {"id": rid, **data}

    def list_activities(self, contact_id=None):
        c = self._conn()
        if contact_id:
            rows = [dict(r) for r in c.execute("SELECT * FROM activities WHERE contact_id=? ORDER BY due_date", (contact_id,)).fetchall()]
        else:
            rows = [dict(r) for r in c.execute("SELECT * FROM activities ORDER BY due_date").fetchall()]
        c.close()
        return rows

    def complete_activity(self, aid):
        c = self._conn()
        c.execute("UPDATE activities SET completed=1 WHERE id=?", (aid,))
        c.commit()
        c.close()

    # DEALS
    def add_deal(self, data):
        c = self._conn()
        c.execute("INSERT INTO deals (contact_id,title,value,stage,probability,close_date,created_at) VALUES (?,?,?,?,?,?,?)",
                  (data.get("contact_id"), data.get("title",""), data.get("value",0),
                   data.get("stage","prospecting"), data.get("probability",10),
                   data.get("close_date",""), datetime.now().isoformat()))
        c.commit()
        rid = c.lastrowid
        c.close()
        return {"id": rid, **data}

    def list_deals(self, stage=None):
        c = self._conn()
        if stage:
            rows = [dict(r) for r in c.execute("SELECT * FROM deals WHERE stage=? ORDER BY value DESC", (stage,)).fetchall()]
        else:
            rows = [dict(r) for r in c.execute("SELECT * FROM deals ORDER BY value DESC").fetchall()]
        c.close()
        return rows

    def update_deal(self, did, data):
        sets, vals = [], []
        for k in ["title","value","stage","probability","close_date"]:
            if k in data:
                sets.append(f"{k}=?"); vals.append(data[k])
        if not sets: return None
        vals.append(did)
        c = self._conn()
        c.execute(f"UPDATE deals SET {', '.join(sets)} WHERE id=?", vals)
        c.commit()
        c.close()
        return True

    # DASHBOARD
    def stats(self):
        c = self._conn()
        total_contacts = c.execute("SELECT COUNT(*) FROM contacts").fetchone()[0]
        total_deals = c.execute("SELECT COUNT(*) FROM deals").fetchone()[0]
        pipeline_value = c.execute("SELECT COALESCE(SUM(value),0) FROM deals").fetchone()[0]
        weighted = c.execute("SELECT COALESCE(SUM(value * probability / 100),0) FROM deals").fetchone()[0]
        open_activities = c.execute("SELECT COUNT(*) FROM activities WHERE completed=0").fetchone()[0]
        by_stage = {}
        for row in c.execute("SELECT pipeline_stage, COUNT(*) cnt FROM contacts GROUP BY pipeline_stage"):
            by_stage[row[0]] = row[1]
        c.close()
        return {
            "contacts": total_contacts,
            "deals": total_deals,
            "pipeline_value": round(pipeline_value, 2),
            "weighted_value": round(weighted, 2),
            "open_activities": open_activities,
            "by_stage": by_stage
        }


crm = CRM()


class Handler(BaseHTTPRequestHandler):
    def _respond(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())

    def _read_body(self):
        n = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(n).decode()) if n else {}

    def do_GET(self):
        p = self.path.rstrip("/")
        if p == "/health":
            self._respond({"status": "running", "db": DB_PATH, "port": PORT})
        elif p == "/stats":
            self._respond(crm.stats())
        elif p == "/contacts":
            self._respond(crm.list_contacts())
        elif p.startswith("/contacts/"):
            cid = int(p.split("/")[-1])
            self._respond(crm.get_contact(cid) or {"error": "not found"})
        elif p == "/activities":
            self._respond(crm.list_activities())
        elif p == "/deals":
            self._respond(crm.list_deals())
        else:
            self._respond({"error": "not found"}, 404)

    def do_POST(self):
        p = self.path.rstrip("/")
        body = self._read_body()

        if p == "/contacts":
            self._respond(crm.add_contact(body), 201)
        elif p == "/activities":
            self._respond(crm.add_activity(body), 201)
        elif p == "/deals":
            self._respond(crm.add_deal(body), 201)
        elif p.startswith("/contacts/") and p.endswith("/complete"):
            aid = int(p.split("/")[-2])
            crm.complete_activity(aid)
            self._respond({"ok": True})
        else:
            self._respond({"error": "not found"}, 404)

    def do_PUT(self):
        p = self.path.rstrip("/")
        body = self._read_body()
        parts = p.split("/")

        if parts[1] == "contacts":
            cid = int(parts[2])
            self._respond(crm.update_contact(cid, body))
        elif parts[1] == "deals":
            did = int(parts[2])
            self._respond({"ok": crm.update_deal(did, body)})
        else:
            self._respond({"error": "not found"}, 404)

    def do_DELETE(self):
        p = self.path.rstrip("/")
        if p.startswith("/contacts/"):
            cid = int(p.split("/")[-1])
            self._respond({"ok": crm.delete_contact(cid)})
        else:
            self._respond({"error": "not found"}, 404)

    def log_message(self, *a): pass


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    log(f"CRM service on {HOST}:{PORT}")
    server.serve_forever()
