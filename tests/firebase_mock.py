#!/usr/bin/env python3
"""Finto Firebase (Realtime Database REST + accesso anonimo) per provare il gioco online in locale.

Uso:  python3 tests/firebase_mock.py 8765
Poi avviare Godot con
  BS_DB_URL=http://127.0.0.1:8765/db
  BS_AUTH_URL=http://127.0.0.1:8765/signup
  BS_REFRESH_URL=http://127.0.0.1:8765/refresh

Applica le regole di firebase/database.rules.json per BEAST (stanze sotto beast/rooms):
info scritta solo da chi crea la stanza; eventi pubblici e caselle private scritti solo dall'arbitro
(il dispositivo della Bestia, info/game/auth), eventi scrivibili una volta sola; ogni casella privata
leggibile solo dal suo titolare; le risposte cmd/<uid>/<n> scritte una volta dal titolare e lette
solo dall'arbitro. Supporta le interrogazioni orderBy="$key"&startAt="…" usate per gli eventi.
"""
import gzip
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

TREE = {}
TOKENS = {}
LOCK = threading.Lock()
COUNT = [0]
DENIED = [0]


def resolve(value):
    if isinstance(value, dict):
        if value.get(".sv") == "timestamp":
            return int(time.time() * 1000)
        return {k: resolve(v) for k, v in value.items()}
    return value


def get_node(path):
    node = TREE
    for p in path:
        if not isinstance(node, dict) or p not in node:
            return None
        node = node[p]
    return node


def set_node(path, value):
    if not path:
        raise ValueError("radice")
    node = TREE
    for p in path[:-1]:
        node = node.setdefault(p, {})
    if value is None:
        node.pop(path[-1], None)
    else:
        node[path[-1]] = value


def firebase_json(v):
    """Come Firebase: oggetti con chiavi numeriche dense diventano array."""
    if isinstance(v, dict):
        conv = {k: firebase_json(x) for k, x in v.items()}
        if conv and all(k.isdigit() for k in conv):
            mx = max(int(k) for k in conv)
            if len(conv) * 2 > mx + 1:
                return [conv.get(str(i)) for i in range(mx + 1)]
        return conv
    return v


def room_of(path):
    """beast/rooms/<code>/... -> (code, resto del percorso)"""
    if path[:2] != ["beast", "rooms"] or len(path) < 3:
        return None, None
    return path[2], path[3:]


def info(code):
    return get_node(["beast", "rooms", code, "info"]) or {}


def auth_uid(code):
    return (info(code).get("game") or {}).get("auth")


def allowed_write(uid, path, new, patch_info=None):
    """Regole di firebase/database.rules.json (sezione beast), semplificate ma equivalenti."""
    code, rest = room_of(path)
    if code is None or len(code) != 4:
        return False
    inf = info(code)
    host = inf.get("host")
    if not rest:
        return new is None and host == uid
    key = rest[0]
    if key == "info":
        # creazione (host = chi scrive) oppure modifica da parte dell'host
        if not inf:
            if len(rest) == 1:
                return isinstance(new, dict) and new.get("host") == uid
            return False
        return host == uid
    if key == "seats" and len(rest) >= 2:
        cur = get_node(["beast", "rooms", code, "seats", rest[1]])
        if len(rest) == 2:
            if cur is None:
                return (isinstance(new, dict) and new.get("uid") == uid) or host == uid
            return cur.get("uid") == uid or cur.get("away") is True or host == uid
        return (cur or {}).get("uid") == uid or host == uid
    if key == "ev" and len(rest) == 2:
        return get_node(path) is None and new is not None and auth_uid(code) == uid
    if key == "box" and len(rest) >= 2:
        return auth_uid(code) == uid
    if key == "cmd" and len(rest) == 3:
        return rest[1] == uid and get_node(path) is None and new is not None
    if key == "reveal" and len(rest) == 1:
        return get_node(path) is None and auth_uid(code) == uid
    return False


def allowed_read(uid, path):
    code, rest = room_of(path)
    if code is None:
        return False
    if not rest:
        return False
    key = rest[0]
    if key in ("info", "seats", "ev", "reveal"):
        return True
    if key == "box":
        return len(rest) >= 2 and rest[1] == uid
    if key == "cmd":
        return len(rest) >= 2 and auth_uid(code) == uid
    return False


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        gz = "gzip" in (self.headers.get("Accept-Encoding") or "")
        if gz:  # come i server di Google: risposta compressa se il client la accetta
            body = gzip.compress(body)
        self.send_response(code)
        self._cors()
        if gz:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors(self):
        # come Firebase: risposte leggibili da qualunque pagina web
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Expose-Headers", "*")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _body(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        return self.rfile.read(n).decode() if n else ""

    def _db(self, method):
        u = urlparse(self.path)
        if not u.path.startswith("/db/") or not u.path.endswith(".json"):
            return self._send(404, {"error": "not found"})
        path = [p for p in u.path[4:-5].split("/") if p]
        uid = TOKENS.get(parse_qs(u.query).get("auth", [""])[0])
        if uid is None:
            return self._send(401, {"error": "Permission denied"})
        q = parse_qs(u.query)
        with LOCK:
            if method == "GET":
                if not allowed_read(uid, path):
                    DENIED[0] += 1
                    sys.stderr.write("NEGATO GET %s %s\n" % (uid, "/".join(path)))
                    return self._send(401, {"error": "Permission denied"})
                node = get_node(path)
                if "orderBy" in q and isinstance(node, dict):
                    start = json.loads(q.get("startAt", ['""'])[0])
                    node = {k: v for k, v in node.items() if k >= start}
                    return self._send(200, node)
                return self._send(200, firebase_json(node))
            if method == "DELETE":
                if not allowed_write(uid, path, None):
                    return self._send(401, {"error": "Permission denied"})
                set_node(path, None)
                return self._send(200, None)
            data = resolve(json.loads(self._body() or "null"))
            if method == "PUT":
                if not allowed_write(uid, path, data):
                    DENIED[0] += 1
                    sys.stderr.write("NEGATO PUT %s %s\n" % (uid, "/".join(path)))
                    return self._send(401, {"error": "Permission denied"})
                set_node(path, data)
                return self._send(200, data)
            if method == "PATCH":
                # aggiornamento a più percorsi: ogni chiave si controlla da sola, tutto o niente
                items = [(path + [p for p in k.split("/") if p], v) for k, v in data.items()]
                for p, v in items:
                    if not allowed_write(uid, p, v):
                        DENIED[0] += 1
                        sys.stderr.write("NEGATO PATCH %s %s\n" % (uid, "/".join(p)))
                        return self._send(401, {"error": "Permission denied"})
                for p, v in items:
                    set_node(p, v)
                return self._send(200, data)
        self._send(405, {"error": "method"})

    def do_GET(self):
        self._db("GET")

    def do_PUT(self):
        self._db("PUT")

    def do_PATCH(self):
        self._db("PATCH")

    def do_DELETE(self):
        self._db("DELETE")

    def do_POST(self):
        u = urlparse(self.path)
        body = self._body()
        with LOCK:
            COUNT[0] += 1
            n = COUNT[0]
        if u.path == "/dump":
            # solo per le prove: tutto il database (per controllare che i segreti non escano)
            return self._send(200, {"tree": TREE, "denied": DENIED[0]})
        if u.path == "/signup":
            tok = "tok%d" % n
            TOKENS[tok] = "uid%d" % n
            return self._send(200, {"idToken": tok, "localId": "uid%d" % n, "refreshToken": "r" + tok, "expiresIn": "3600"})
        if u.path == "/refresh":
            # la stessa identità di prima, con un gettone nuovo
            old = parse_qs(body).get("refresh_token", [""])[0]
            uid = TOKENS.get(old[1:]) if old.startswith("r") else None
            if uid is None:
                return self._send(400, {"error": {"message": "INVALID_REFRESH_TOKEN"}})
            tok = "tok%d" % n
            TOKENS[tok] = uid
            return self._send(200, {"id_token": tok, "refresh_token": "r" + tok, "user_id": uid})
        self._send(404, {"error": "not found"})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
