extends SceneTree
## Prova del gioco online sul finto Firebase (tests/firebase_mock.py): due istanze di Beast.
## BS_ROLE=host: crea la stanza e gioca la Bestia (è l'arbitro: il motore gira solo qui).
## BS_ROLE=guest: entra e gioca i due cacciatori (nessun motore: riceve solo la vista dei cacciatori).
## BS_CODEFILE=file per passarsi il codice. BS_PHASE=drop: l'ospite esce a metà; BS_PHASE=back: rientra.
## Le persone sono simulate: la Bestia dall'IA, i cacciatori con scelte a caso.
## L'ospite controlla a ogni vista che la posizione e le carte della Bestia nascosta non arrivino mai,
## e a fine partita esegue la verifica commit-reveal.

var main
var t0 := 0
var ai := BSAI.new()
var rng := RandomNumberGenerator.new()

func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	rng.seed = 7
	_run()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("BS_ROLE")
	var cf := OS.get_environment("BS_CODEFILE")
	var phase := OS.get_environment("BS_PHASE")
	var menu = main.current
	menu.contract = "regent"
	menu.nplayers = 2
	menu.beasts = ["vacker", "raaga"]
	menu.hunters = ["helga", "iona", "assar"]
	menu.beast_ai = [false, true]
	menu.hunter_ai = [false, false, true]
	menu.speed = 3
	menu._online_panel()
	menu.on_name.text = "Bestia" if role == "host" else "Cacciatori"
	if role == "host":
		await menu._online_create()
		var code: String = main.lobby.get("code", "")
		print("BSTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._online_start()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.on_code.text = code
		await menu._online_join()
	var leaks := 0
	var views := 0
	var answered := 0
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 1500000:
			print("BSTEST tempo scaduto")
			quit(2)
			return
		var g = main.current
		if g == null or not ("table" in g):
			continue
		if role == "guest":
			var v: Dictionary = g.view
			if not v.is_empty():
				views += 1
				for c in v.get("chars", []):
					if c["side"] == "B" and not c["revealed"] and (c.has("loc") or c.has("hand") or c.has("moves")):
						leaks += 1
				if v.has("trails_by"):
					leaks += 1
			if phase == "drop" and int(v.get("day", 0)) >= 2:
				print("BSTEST esco a metà partita")
				quit(0)
				return
		var req: Dictionary = g.pending
		if not req.is_empty():
			var r
			if role == "host":
				r = ai.decide(g.eng, int(req["ci"]), req)
			else:
				var opts: Array = req["opts"]
				var pick: Dictionary = opts[rng.randi_range(0, opts.size() - 1)]
				# i cacciatori simulati preferiscono giocare carte che passare
				for o in opts:
					if str(o["id"]) == "pass" and opts.size() > 1 and rng.randf() < 0.7:
						pick = opts[0]
				r = pick["id"]
			answered += 1
			g._choose(r)
		var over: bool = (g.eng != null and g.eng.game_over) or (g.view.get("over", false))
		if over and (g.end_panel != null and is_instance_valid(g.end_panel)):
			await _wait(3.0)
			if role == "host":
				print("BSTEST arbitro: fine partita, vince ", g.eng.results["winner"], " · eventi ", g.eng.events.size(), " · decisioni ", g.server.dn)
			else:
				var evs: Array = g.client.all_events()
				var reveal: Dictionary = g.view.get("results", {}).get("reveal", {})
				var vr: Dictionary = BSVerify.run(evs, reveal, "lsi")
				print("BSTEST ospite: viste %d, fughe di segreti %d, risposte %d, eventi %d, verifica %s %s" % [views, leaks, answered, evs.size(), vr["ok"], str(vr["errors"].slice(0, 3))])
			quit(0)
			return
