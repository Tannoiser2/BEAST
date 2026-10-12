class_name OnlineServer
extends Node
## Arbitro della partita online: gira sul dispositivo della Bestia (o di chi crea la stanza se la Bestia
## è dell'IA). Il motore e lo stato segreto esistono SOLO qui. Agli altri si pubblicano:
##  - gli eventi pubblici (ev/000123), scritti una volta sola (non si possono riscrivere dopo);
##  - a ogni persona la vista della sua squadra (box/<uid>), con la decisione che le spetta.
## Le risposte arrivano in cmd/<uid>/<n>. Se una persona tace per un minuto gioca l'IA al suo posto.
## Per uscire e rientrare: tutte le decisioni sono salvate sul dispositivo (user://beast_<codice>.json)
## e al rientro il motore le rigioca con lo stesso seme fino al punto in cui si era.

var net: Net
var code := ""
var seats: Array = []        # posti umani: [{chars: [...]}], indice = posto nel database
var my_seat := 0
var eng: BSEngine
var gv
var alive := true
var dn := 0                  # numero della decisione (contatore globale)
var replay: Array = []
var saved: Array = []
var ev_sent := 0
var last_box := {}           # uid -> testo della vista già inviata
var box_v := {}
var uids := {}               # posto -> uid
var away := {}
var dirty := false
var flushing := false
var save_path := ""


func setup(p_net: Net, p_code: String, p_seats: Array, p_my_seat: int, rejoin: bool) -> void:
	net = p_net
	code = p_code
	seats = p_seats
	my_seat = p_my_seat
	save_path = "user://beast_%s.json" % code
	if FileAccess.file_exists(save_path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if j is Dictionary:
			replay = j.get("answers", [])
			saved = replay.duplicate()


## Collega il motore: da qui in poi ogni decisione passa da decide().
func attach(p_eng: BSEngine, p_gv) -> void:
	eng = p_eng
	gv = p_gv
	eng.online = self
	# il sale deve restare lo stesso anche se si rientra: si salva sul dispositivo
	var j = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	if j is Dictionary and j.get("salt", "") != "":
		eng.salt = str(j["salt"])
	_save()
	eng.changed.connect(_mark)
	eng.event_added.connect(func(_e): _mark())
	_loop()


func _exit_tree() -> void:
	alive = false


func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"salt": eng.salt, "answers": saved}))


func _mark() -> void:
	dirty = true


func _loop() -> void:
	var t := 0
	while alive:
		if dirty and not flushing:
			await flush()
		t += 1
		if t % 25 == 0:
			_refresh_seats()
		await get_tree().create_timer(0.2).timeout


func _refresh_seats() -> void:
	var r := await net.room(code)
	var st := Net._as_dict(r.get("seats", {}))
	for k in st:
		if st[k] is Dictionary:
			uids[int(k)] = str(st[k].get("uid", ""))


func _seat_of(ci: int) -> int:
	for k in range(seats.size()):
		if seats[k]["chars"].has(ci):
			return k
	return -1


func _team_of_seat(k: int) -> String:
	for ci in seats[k]["chars"]:
		return eng.side(ci)
	return "H"


## Pubblica eventi nuovi e viste cambiate.
func flush(req_for := {}) -> void:
	flushing = true
	dirty = false
	if uids.is_empty():
		await _refresh_seats()
	var paths := {}
	while ev_sent < eng.events.size():
		paths["ev/" + Net.ev_key(ev_sent)] = eng.events[ev_sent]
		ev_sent += 1
	for k in range(seats.size()):
		if k == my_seat or not uids.has(k) or uids[k] == "":
			continue
		var u: String = uids[k]
		var team := _team_of_seat(k)
		var v := eng.view_for(team)
		v["log"] = (v["log"] as Array).slice(max(0, v["log"].size() - 40))
		var req: Dictionary = req_for.get(k, {})
		var txt := JSON.stringify(v)
		var rq := JSON.stringify(req) if not req.is_empty() else ""
		if last_box.get(u, "") != txt + "|" + rq:
			last_box[u] = txt + "|" + rq
			box_v[u] = int(box_v.get(u, 0)) + 1
			paths["box/" + u] = {"v": box_v[u], "view": txt, "req": rq}
	if eng.game_over and not paths.is_empty():
		paths["reveal"] = eng.results.get("reveal", {})
	var tries := 0
	while alive and not paths.is_empty() and not await net.publish(code, paths):
		tries += 1
		if gv != null:
			gv.online_waiting("Rete non raggiungibile, riprovo… (%s)" % net.last_error)
		if eng.game_over and tries > 1:
			paths.erase("reveal")
		await get_tree().create_timer(1.5).timeout
	flushing = false


## Decisione richiesta dal motore.
func decide(e: BSEngine, ci: int, req: Dictionary):
	var n := dn
	dn += 1
	if n < replay.size():
		return str_to_var(str(replay[n]))
	var r
	var k := _seat_of(ci)
	var ctrl: Dictionary = e.controller(ci)
	if ctrl.get("ai", true) or (k >= 0 and away.has(k)):
		if e.ai_delay > 0.0 and is_inside_tree():
			await get_tree().create_timer(e.ai_delay * 0.6).timeout
		r = e.ais[ci].decide(e, ci, req)
	elif k == my_seat:
		e.decision_requested.emit(req)
		r = await e.decision_provided
	else:
		r = await _remote(e, ci, k, n, req)
	saved.append(var_to_str(r))
	_save()
	return r


func _remote(e: BSEngine, ci: int, k: int, n: int, req: Dictionary):
	var send := req.duplicate()
	send["n"] = n
	await flush({k: send})
	var u: String = uids.get(k, "")
	var t0 := Time.get_ticks_msec()
	var last_seen = null
	var seen_t := t0
	var polls := 0
	if gv != null:
		gv.online_waiting("Tocca a %s…" % e.cname(ci))
	while alive:
		var a = await net.get_cmd(code, u, n)
		if a is Dictionary and a.has("r"):
			if gv != null:
				gv.online_waiting("")
			await flush({})
			return str_to_var(str(a["r"]))
		polls += 1
		if polls % 4 == 0:
			var st := await net.seat(code, k)
			if not st.is_empty():
				if str(st.get("uid", "")) != u:
					u = str(st.get("uid", ""))
					uids[k] = u
					last_box.erase(u)
					await flush({k: send})
				var seen = st.get("seen", null)
				if seen != last_seen:
					last_seen = seen
					seen_t = Time.get_ticks_msec()
				var now := Time.get_ticks_msec()
				if st.get("away", false) or (now - seen_t > 45000 and now - t0 > 60000):
					await net.set_away(code, k, true)
					away[k] = true
					if gv != null:
						gv.online_waiting("")
						gv._toast("%s non risponde: per ora gioca l'IA." % e.cname(ci))
					_watch_return(k)
					return e.ais[ci].decide(e, ci, req)
		await get_tree().create_timer(0.4).timeout
	return e.ais[ci].decide(e, ci, req)


## Quando chi era assente rientra, torna a giocare lui.
func _watch_return(k: int) -> void:
	while alive and away.has(k):
		await get_tree().create_timer(4.0).timeout
		var st := await net.seat(code, k)
		if not st.is_empty() and not st.get("away", false):
			away.erase(k)
			uids[k] = str(st.get("uid", ""))
			last_box.erase(uids[k])
			_mark()


func finish() -> void:
	await flush({})
	net.set_status(code, "over")
	net.remember_room("")
