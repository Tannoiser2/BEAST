class_name OnlineClient
extends Node
## Dispositivo senza motore (cacciatori, o seconda Bestia): legge la propria casella privata
## (vista della squadra + decisione da prendere) e gli eventi pubblici, e risponde in cmd/<uid>/<n>.
## Non riceve mai la posizione della Bestia né le sue carte (se gioca i cacciatori).

signal view_changed(view: Dictionary, req: Dictionary, events: Array)
signal status(text: String)

var net: Net
var code := ""
var seat := 0
var team := "H"
var cfg: Dictionary
var alive := true
var ver := -2
var events: Array = []
var view: Dictionary = {}
var req: Dictionary = {}
var answered := {}


func setup(p_net: Net, p_code: String, p_seat: int, p_team: String, p_cfg: Dictionary) -> void:
	net = p_net
	code = p_code
	seat = p_seat
	team = p_team
	cfg = p_cfg


func _exit_tree() -> void:
	alive = false


func start() -> void:
	net.set_away(code, seat, false)
	_heartbeat()
	_poll()


func _heartbeat() -> void:
	while alive:
		net.heartbeat(code, seat)
		await get_tree().create_timer(5.0).timeout


func _poll() -> void:
	var quiet := 0
	while alive:
		var v := await net.box_version(code)
		var evs := await net.events_from(code, events.size())
		if not alive:
			return
		events.append_array(evs)
		if v != ver and v >= 0:
			ver = v
			var b := await net.box(code)
			var pv = JSON.parse_string(str(b.get("view", "")))
			if pv is Dictionary:
				view = pv
			var pr = JSON.parse_string(str(b.get("req", ""))) if str(b.get("req", "")) != "" else {}
			req = pr if pr is Dictionary else {}
			if answered.has(int(req.get("n", -1))):
				req = {}
			quiet = 0
		elif v < 0:
			quiet += 1
			if quiet % 10 == 5:
				status.emit("In attesa del dispositivo della Bestia…")
		if not view.is_empty():
			view_changed.emit(view, req, events)
		if view.get("over", false):
			await get_tree().create_timer(2.0).timeout
		await get_tree().create_timer(0.5 if req.is_empty() else 1.0).timeout


func answer(r: Dictionary, id) -> void:
	var n := int(r.get("n", -1))
	answered[n] = true
	req = {}
	while alive and not await net.send_cmd(code, n, id):
		status.emit("Rete non raggiungibile, riprovo…")
		await get_tree().create_timer(1.5).timeout


func all_events() -> Array:
	return events
