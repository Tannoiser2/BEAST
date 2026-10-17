extends SceneTree
## Prova di blocco: la Bestia è umana (risponde l'IA passando dall'interfaccia), i cacciatori IA.
## BS_BEAST=<id> BS_CONTRACT=<id> BS_SEED=<n> godot --path . -s res://tests/human_beast.gd
## Stampa «BLOCCO» se il motore aspetta una decisione umana che l'interfaccia non mostra,
## o se la partita non avanza più.

var main
var ai := BSAI.new()


func _initialize() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func _run() -> void:
	var beast := OS.get_environment("BS_BEAST") if OS.get_environment("BS_BEAST") != "" else "bolgin"
	var contract := OS.get_environment("BS_CONTRACT") if OS.get_environment("BS_CONTRACT") != "" else "regent"
	var sd := int(OS.get_environment("BS_SEED")) if OS.get_environment("BS_SEED") != "" else 1
	seed(sd)
	await wait(10)
	var m = main.current
	m.contract = contract
	var K: Dictionary = BD.CONTRACTS[contract]
	m.nplayers = K["players"][0]
	var others := BD.BEASTS.keys()
	others.erase(beast)
	m.beasts = [beast, others[sd % others.size()]]
	var hs := BD.HUNTERS.keys()
	hs.shuffle()
	hs.erase("esmeria_h")
	m.hunters = hs.slice(0, 3)
	m.beast_ai = [false, true]
	m.hunter_ai = [true, true, true]
	m.speed = 3
	m.level = 1
	m._on_start()
	await wait(10)
	var g = main.current
	var t0 := Time.get_ticks_msec()
	var last_ev := -1
	var last_change := Time.get_ticks_msec()
	var hidden_since := 0
	var answered := 0
	var last_print := 0
	while Time.get_ticks_msec() - t0 < 1500000:
		await process_frame
		var e = g.eng
		if Time.get_ticks_msec() - last_print > 30000:
			last_print = Time.get_ticks_msec()
			print("… giorno %d fase %s eventi %d risposte %d fps %d" % [e.day, e.phase, e.events.size(), answered, Engine.get_frames_per_second()])
		if g.end_panel != null and is_instance_valid(g.end_panel):
			print("FINE %s %s seed %d: %s giorno %d, risposte %d" % [beast, contract, sd, str(e.results.get("why", "")), e.day, answered])
			quit()
			return
		if e.events.size() != last_ev or not g.pending.is_empty():
			last_ev = e.events.size()
			last_change = Time.get_ticks_msec()
		if not e.current_req.is_empty() and not e.controller(int(e.current_req["ci"]))["ai"] and g.pending.is_empty():
			if hidden_since == 0:
				hidden_since = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - hidden_since > 4000:
				print("BLOCCO (richiesta non mostrata) %s %s seed %d: %s" % [beast, contract, sd, str(e.current_req).left(400)])
				quit(2)
				return
		else:
			hidden_since = 0
		if Time.get_ticks_msec() - last_change > 20000:
			print("BLOCCO (fermo) %s %s seed %d giorno %d fase %s richiesta %s" % [beast, contract, sd, e.day, e.phase, str(e.current_req).left(300)])
			quit(3)
			return
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		if not g.dec_panel.visible:
			print("BLOCCO (pannello nascosto) ", str(req).left(300))
			quit(4)
			return
		await wait(1)
		var r = ai.decide(e, int(req["ci"]), req)
		answered += 1
		if OS.get_environment("BS_VERBOSE") != "":
			print("  [%d ms] %s: %s -> %s" % [Time.get_ticks_msec() - t0, req.get("type", ""), str(req.get("prompt", "")).left(60), str(r)])
		g._choose(r)
	print("TEMPO SCADUTO %s %s seed %d" % [beast, contract, sd])
	quit(5)
