## Collegamento a Firebase (Realtime Database) per il gioco online.
## Usa solo le chiamate web standard (REST), quindi funziona sia nell'app sia nella versione web.
## Accesso anonimo: ogni dispositivo riceve un identificativo, senza registrazione.
##
## Ricavato dal modulo di Churchill. In BEAST NON si usa il lockstep: il motore gira solo sul dispositivo
## della Bestia (l'arbitro), che pubblica gli eventi pubblici (ev/000123) e a ogni giocatore la vista
## della sua squadra in una casella leggibile solo da lui (box/<uid>); le risposte arrivano in cmd/<uid>/<n>.
## Struttura di una stanza (beast/rooms/<codice>):
##   info  {host, created, status, open, cfg, game:{auth, cfg}}   leggibile da tutti, scrive chi la crea
##   seats/<i> {uid, name, away, seen}                             posti delle persone
##   ev/<nnnnnn>    eventi pubblici, scritti una volta sola dall'arbitro
##   box/<uid>      {v, view, req} vista privata della squadra, leggibile solo da <uid>
##   cmd/<uid>/<n>  risposta n-esima di <uid>, leggibile solo dall'arbitro
##   reveal         sale e registro segreto della Bestia a fine partita (verifica)
class_name Net
extends Node

# Configurazione pubblica del progetto Firebase del gioco (non è un segreto: la protezione la fanno
# le regole del database, in firebase/database.rules.json).
const API_KEY := "AIzaSyCf1NQodB-J3OrdU_gHYQ1I6VJtXBk1ciU"
const DB_URL := "https://flammerouge-f8669-default-rtdb.europe-west1.firebasedatabase.app"
const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key="
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
## Radice del gioco nel database: Ultimo chilometro usa "rooms", Snow Tails "snowtails/rooms",
## STATUS "status/rooms", Kingsburg "kingsburg/rooms", Churchill "churchill/rooms", Beast "beast/rooms".
const ROOT := "beast/rooms"

var db_url := DB_URL
var auth_url := AUTH_URL + API_KEY
var refresh_url := REFRESH_URL + API_KEY
var uid := ""
var id_token := ""
var refresh_token := ""
var token_at := 0.0
var last_error := ""
var last_room := {}

func _init() -> void:
	# per le prove automatiche si può puntare a un finto Firebase locale
	var test_db := OS.get_environment("BS_DB_URL")
	if OS.has_feature("web"):
		# nella versione web: ?bsdb=<indirizzo> nella pagina
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('bsdb') || ''")
		test_db = str(q) if q != null else ""
		if test_db != "":
			var base := test_db.get_base_dir()
			OS.set_environment("BS_AUTH_URL", base + "/signup")
			OS.set_environment("BS_REFRESH_URL", base + "/refresh")
	if test_db != "":
		db_url = test_db
		auth_url = OS.get_environment("BS_AUTH_URL")
		refresh_url = OS.get_environment("BS_REFRESH_URL")

const RESULT_NAMES := {
	HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "risposta incompleta",
	HTTPRequest.RESULT_CANT_CONNECT: "connessione rifiutata",
	HTTPRequest.RESULT_CANT_RESOLVE: "indirizzo del server non trovato",
	HTTPRequest.RESULT_CONNECTION_ERROR: "connessione interrotta o bloccata",
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "errore di sicurezza TLS",
	HTTPRequest.RESULT_NO_RESPONSE: "nessuna risposta",
	HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "risposta troppo grande",
	HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "risposta compressa illeggibile",
	HTTPRequest.RESULT_REQUEST_FAILED: "richiesta bloccata (CORS o rete)",
	HTTPRequest.RESULT_TIMEOUT: "tempo scaduto",
}

## Una richiesta HTTP: restituisce {code, data}. code 0 = rete non raggiungibile.
## Se la rete fa le bizze riprova una volta; last_error dice quale passo è fallito e perché.
func _request(method: int, url: String, body = null, form := false) -> Dictionary:
	var r := await _request_once(method, url, body, form)
	if r["code"] == 0:
		await get_tree().create_timer(1.0).timeout
		r = await _request_once(method, url, body, form)
	return r

func _request_once(method: int, url: String, body = null, form := false) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	# nel browser la risposta arriva già decompressa: se Godot ci riprova fallisce (errore 8)
	http.accept_gzip = not OS.has_feature("web")
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	var payload := ""
	if body != null:
		payload = body if form else JSON.stringify(body)
	var where := _where(url)
	var err := http.request(url, headers, method, payload)
	if err != OK:
		http.queue_free()
		last_error = "%s: richiesta non partita, errore %d" % [where, err]
		push_warning("Net " + last_error)
		return {"code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		last_error = "%s: %s [%d]" % [where, RESULT_NAMES.get(res[0], "rete non raggiungibile"), res[0]]
		push_warning("Net " + last_error)
		return {"code": 0, "data": null}
	if code >= 300:
		var msg := text.substr(0, 160)
		if data is Dictionary and data.get("error") is Dictionary:
			msg = str(data["error"].get("message", msg))
		elif data is Dictionary and data.has("error"):
			msg = str(data["error"])
		last_error = "%s: errore %d, %s" % [where, code, msg]
		push_warning("Net " + last_error)
	return {"code": code, "data": data}

## Nome breve del passo, per i messaggi d'errore.
func _where(url: String) -> String:
	if url.begins_with(auth_url.get_slice("?", 0)):
		return "accesso anonimo"
	if url.begins_with(refresh_url.get_slice("?", 0)):
		return "rinnovo accesso"
	return "database"

const SESSION_FILE := "user://online.cfg"
## Prefisso delle chiavi del browser (sessionStorage), distinto da quello degli altri giochi.
const WEB_PREFIX := "bs_"

## Accesso anonimo (una volta per sessione). L'identità si conserva sul dispositivo:
## chi ricarica la pagina o riapre il gioco resta lo stesso giocatore e può rientrare nella sua stanza.
func sign_in() -> bool:
	if id_token != "":
		return await _fresh()
	var saved := load_session()
	if saved.get("refresh", "") != "":
		var rr := await _request(HTTPClient.METHOD_POST, refresh_url, "grant_type=refresh_token&refresh_token=" + str(saved["refresh"]).uri_encode(), true)
		if rr["code"] == 200 and rr["data"] is Dictionary and rr["data"].get("id_token", "") != "":
			id_token = rr["data"]["id_token"]
			refresh_token = rr["data"].get("refresh_token", saved["refresh"])
			uid = rr["data"].get("user_id", saved.get("uid", ""))
			token_at = Time.get_unix_time_from_system()
			_save({"refresh": refresh_token, "uid": uid})
			return true
	var r := await _request(HTTPClient.METHOD_POST, auth_url, {"returnSecureToken": true})
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return false
	id_token = r["data"].get("idToken", "")
	refresh_token = r["data"].get("refreshToken", "")
	uid = r["data"].get("localId", "")
	token_at = Time.get_unix_time_from_system()
	_save({"refresh": refresh_token, "uid": uid})
	return id_token != ""

## Dati salvati sul dispositivo: identità, ultima stanza (codice e posto), nome.
## Nel browser identità e stanza stanno nella scheda (sessionStorage): sopravvivono al ricaricamento,
## ma due schede aperte sono due giocatori diversi. Il nome resta per tutte.
const TAB_KEYS := ["refresh", "uid", "room", "seat"]

func _session_file() -> String:
	var f := OS.get_environment("BS_SESSION")
	return f if f != "" else SESSION_FILE

func load_session() -> Dictionary:
	var out := {}
	var c := ConfigFile.new()
	if c.load(_session_file()) == OK and c.has_section("s"):
		for k in c.get_section_keys("s"):
			out[k] = c.get_value("s", k)
	if OS.has_feature("web"):
		for k in TAB_KEYS:
			out.erase(k)
			var v = JavaScriptBridge.eval("sessionStorage.getItem('%s%s') || ''" % [WEB_PREFIX, k])
			if v != null and str(v) != "":
				out[k] = int(str(v)) if k == "seat" else str(v)
	return out

func _save(values: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(_session_file())
	for k in values:
		if OS.has_feature("web") and k in TAB_KEYS:
			JavaScriptBridge.eval("sessionStorage.setItem('%s%s', %s)" % [WEB_PREFIX, k, JSON.stringify(str(values[k]))])
		else:
			c.set_value("s", k, values[k])
	c.save(_session_file())

## Ricorda la stanza in cui si sta giocando (per rientrare), oppure la dimentica con code = "".
func remember_room(code: String, seat := -1) -> void:
	_save({"room": code, "seat": seat})

## Il gettone d'accesso dura un'ora: lo si rinnova dopo 50 minuti.
func _fresh() -> bool:
	if refresh_token == "" or Time.get_unix_time_from_system() - token_at < 3000:
		return true
	var r := await _request(HTTPClient.METHOD_POST, refresh_url, "grant_type=refresh_token&refresh_token=" + refresh_token.uri_encode(), true)
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return false
	id_token = r["data"].get("id_token", id_token)
	refresh_token = r["data"].get("refresh_token", refresh_token)
	token_at = Time.get_unix_time_from_system()
	_save({"refresh": refresh_token})
	return true

func _url(path: String) -> String:
	return "%s/%s.json?auth=%s" % [db_url, path, id_token]

func db_get(path: String) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_GET, _url(path))

func db_put(path: String, value) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_PUT, _url(path), value)

func db_patch(path: String, value: Dictionary) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_PATCH, _url(path), value)

func db_delete(path: String) -> Dictionary:
	await _fresh()
	return await _request(HTTPClient.METHOD_DELETE, _url(path))

# ---------- stanze ----------

## Crea una stanza con un codice di 4 lettere. seats: indici dei posti per le persone (il primo è
## dell'host). cfg: configurazione della partita (testo). Restituisce il codice, oppure "".
func create_room(player: String, seats: Array, cfg: String) -> String:
	last_error = ""
	if not await sign_in():
		return ""
	var g := RandomNumberGenerator.new()
	g.randomize()
	for attempt in 6:
		var code := ""
		for k in 4:
			code += CODE_LETTERS[g.randi() % CODE_LETTERS.length()]
		var existing := await db_get((ROOT + "/%s/info/host") % code)
		if existing["code"] == 200 and existing["data"] != null:
			continue
		var body := {"info": {"host": uid, "created": {".sv": "timestamp"}, "status": "lobby", "open": seats, "cfg": cfg},
			"seats/%d" % seats[0]: {"uid": uid, "name": player}}
		var r := await db_patch(ROOT + "/" + code, body)
		if r["code"] == 200:
			return code
	return ""


## Entra in una stanza: occupa il primo posto libero. Restituisce il posto, -1 se non c'è posto,
## -2 se la stanza non esiste o la partita è già iniziata (e non si aveva un posto).
func join_room(code: String, player: String) -> int:
	last_error = ""
	if not await sign_in():
		return -2
	var room := await room(code)
	if room.is_empty():
		return -2
	last_room = room
	var seats: Dictionary = _as_dict(room.get("seats", {}))
	for k in seats:
		if seats[k] is Dictionary and seats[k].get("uid", "") == uid:
			return int(k)
	if room.get("status", "") != "lobby":
		# partita già iniziata: si può riprendere un posto lasciato (assente) con lo stesso nome
		for k in seats:
			var st = seats[k]
			if st is Dictionary and st.get("away", false) and str(st.get("name", "")).strip_edges().to_lower() == player.strip_edges().to_lower():
				var w := await db_put((ROOT + "/%s/seats/%s") % [code, k], {"uid": uid, "name": st["name"], "away": false})
				if w["code"] == 200:
					return int(k)
		return -2
	for idx in room.get("open", []):
		if not seats.has(str(int(idx))):
			var w := await db_put((ROOT + "/%s/seats/%d") % [code, int(idx)], {"uid": uid, "name": player})
			if w["code"] == 200:
				return int(idx)
	return -1


## Parte pubblica della stanza: info + posti, in un solo dizionario.
func room(code: String) -> Dictionary:
	var r := await db_get(ROOT + "/" + code + "/info")
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return {}
	var out: Dictionary = r["data"]
	var s := await db_get(ROOT + "/" + code + "/seats")
	out["seats"] = s["data"] if s["code"] == 200 and s["data"] != null else {}
	return out


func start_room(code: String, game: Dictionary) -> bool:
	var r := await db_patch(ROOT + "/" + code + "/info", {"game": game, "status": "playing"})
	return r["code"] == 200


func set_status(code: String, status: String) -> void:
	await db_patch(ROOT + "/" + code + "/info", {"status": status})


## Un posto della stanza ({uid, name, away, seen}), oppure {}.
func seat(code: String, idx: int) -> Dictionary:
	var r := await db_get((ROOT + "/%s/seats/%d") % [code, idx])
	return r["data"] if r["code"] == 200 and r["data"] is Dictionary else {}


func set_away(code: String, seat: int, away: bool) -> bool:
	var r := await db_patch((ROOT + "/%s/seats/%d") % [code, seat], {"away": away})
	return r["code"] == 200


func heartbeat(code: String, seat: int) -> void:
	await db_patch((ROOT + "/%s/seats/%d") % [code, seat], {"seen": {".sv": "timestamp"}, "away": false})


func close_room(code: String) -> void:
	await db_delete(ROOT + "/" + code)


# ---------- arbitro (dispositivo della Bestia) ----------

static func ev_key(n: int) -> String:
	return "%06d" % n


## Scrive in un colpo solo eventi nuovi e caselle private: {"ev/000012": {...}, "box/<uid>": {...}}.
func publish(code: String, paths: Dictionary) -> bool:
	if paths.is_empty():
		return true
	var r := await db_patch(ROOT + "/" + code, paths)
	return r["code"] == 200


## Risposta n-esima di un giocatore, oppure null se non è ancora arrivata ({"_err": true} se la rete tace).
func get_cmd(code: String, who: String, n: int):
	var r := await db_get((ROOT + "/%s/cmd/%s/%d") % [code, who, n])
	if r["code"] != 200:
		return {"_err": true}
	return r["data"]


# ---------- clienti ----------

func box_version(code: String) -> int:
	var r := await db_get((ROOT + "/%s/box/%s/v") % [code, uid])
	if r["code"] != 200 or r["data"] == null:
		return -1
	return int(r["data"])


func box(code: String) -> Dictionary:
	var r := await db_get((ROOT + "/%s/box/%s") % [code, uid])
	return r["data"] if r["code"] == 200 and r["data"] is Dictionary else {}


## Eventi pubblici a partire dal numero from (chiavi a 6 cifre: l'ordine alfabetico è quello giusto).
func events_from(code: String, from: int) -> Array:
	var url := "%s/%s/ev.json?auth=%s&orderBy=%s&startAt=%s" % [db_url, ROOT + "/" + code, id_token, "%22%24key%22", ("%22" + ev_key(from) + "%22")]
	await _fresh()
	url = "%s/%s/ev.json?auth=%s&orderBy=%s&startAt=%s" % [db_url, ROOT + "/" + code, id_token, "%22%24key%22", ("%22" + ev_key(from) + "%22")]
	var r := await _request(HTTPClient.METHOD_GET, url)
	if r["code"] != 200 or not (r["data"] is Dictionary):
		return []
	var keys: Array = r["data"].keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append(r["data"][k])
	return out


func send_cmd(code: String, n: int, value) -> bool:
	var r := await db_put((ROOT + "/%s/cmd/%s/%d") % [code, uid, n], {"r": var_to_str(value)})
	return r["code"] == 200


func get_reveal(code: String) -> Dictionary:
	var r := await db_get(ROOT + "/" + code + "/reveal")
	return r["data"] if r["code"] == 200 and r["data"] is Dictionary else {}


## Firebase restituisce gli elenchi con chiavi numeriche come array (con buchi a null): li riporta a dizionario.
static func _as_dict(v) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			if v[k] != null:
				out[str(k)] = v[k]
	elif v is Array:
		for i in v.size():
			if v[i] != null:
				out[str(i)] = v[i]
	return out
