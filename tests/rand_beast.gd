extends SceneTree
## Bestia «umana» che sceglie a caso fra le opzioni (scelte che l'IA non farebbe mai), cacciatori IA.
## Senza grafica: cerca cicli infiniti e partite che non finiscono.
## godot --headless --path . -s res://tests/rand_beast.gd -- <partite> [contratto|all] [primo seme]

var eng: BSEngine
var rng := RandomNumberGenerator.new()
var asked := 0


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var which := str(args[1]) if args.size() > 1 else "all"
	var s0 := int(args[2]) if args.size() > 2 else 1
	var contracts: Array = BD.CONTRACTS.keys() if which == "all" else [which]
	var bad := 0
	for g in range(s0, s0 + games):
		var contract: String = contracts[g % contracts.size()]
		var K: Dictionary = BD.CONTRACTS[contract]
		rng.seed = 777 + g
		var nb := int(K.get("beasts", 1))
		var pool_b: Array = BD.BEASTS.keys()
		var bs := []
		for i in range(nb):
			var b: String = pool_b[rng.randi_range(0, pool_b.size() - 1)]
			pool_b.erase(b)
			bs.append(b)
		var pool_h: Array = BD.HUNTERS.keys()
		if "esmeria" in bs:
			pool_h.erase("esmeria_h")
		var np: int = K["players"][0]
		var nh := 2 if np == 2 else np - nb
		var hs := []
		for i in range(nh):
			var h: String = pool_h[rng.randi_range(0, pool_h.size() - 1)]
			pool_h.erase(h)
			hs.append(h)
		var ctrl := []
		for i in range(bs.size()):
			ctrl.append({"ai": i != 0, "level": 1, "player": i})
		for i in range(hs.size()):
			ctrl.append({"ai": true, "level": 1, "player": bs.size() + (0 if np == 2 else i)})
		eng = BSEngine.new()
		eng.headless = true
		root.add_child(eng)
		eng.decision_requested.connect(_answer)
		eng.setup({"contract": contract, "beasts": bs, "hunters": hs, "ctrl": ctrl, "seed": 3000 + g})
		asked = 0
		var t0 := Time.get_ticks_msec()
		var done := [false]
		var run_it := func():
			await eng.run()
			done[0] = true
		run_it.call()
		var last_ev := -1
		var still := 0
		while not done[0]:
			await process_frame
			if eng.events.size() == last_ev and eng.current_req.is_empty():
				still += 1
			else:
				still = 0
			last_ev = eng.events.size()
			if still > 3000 or Time.get_ticks_msec() - t0 > 120000:
				print("BLOCCO partita %d %s %s vs %s: giorno %d fase %s eventi %d domande %d ultimo evento %s" % [g, contract, ",".join(bs), ",".join(hs), eng.day, eng.phase, eng.events.size(), asked, str(eng.events.back() if eng.events.size() > 0 else {}).left(200)])
				bad += 1
				eng.abort = true
				break
		if done[0]:
			print("partita %d %s %s vs %s → %s (%s) giorno %d, domande alla Bestia %d" % [g, contract, ",".join(bs), ",".join(hs), eng.results.get("winner", "?"), eng.results.get("why", ""), eng.day, asked])
		eng.queue_free()
		await process_frame
	print("BLOCCHI: %d su %d" % [bad, games])
	quit()


func _answer(req: Dictionary) -> void:
	asked += 1
	var opts: Array = req.get("opts", [])
	var id = opts[rng.randi_range(0, opts.size() - 1)]["id"]
	(func(): eng.provide_decision(id)).call_deferred()
