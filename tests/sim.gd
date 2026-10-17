extends SceneTree
## Partite IA contro IA senza grafica (per tarare l'IA):
## godot --headless -s res://tests/sim.gd -- <partite> <contratto> <livello Bestia> <livello cacciatori> [bestia] [cacciatori,…]
## Esempio: godot --headless -s res://tests/sim.gd -- 20 regent 2 1

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 10
	var contract := str(args[1]) if args.size() > 1 else "regent"
	var lb := int(args[2]) if args.size() > 2 else 1
	var lh := int(args[3]) if args.size() > 3 else 1
	var fixed_b := str(args[4]) if args.size() > 4 else ""
	var fixed_h := str(args[5]).split(",", false) if args.size() > 5 else []
	var K: Dictionary = BD.CONTRACTS[contract]
	var nplayers: int = K["players"][0]
	var nbeasts: int = int(K.get("beasts", 1))
	var wins := {"B": 0, "H": 0}
	var days := 0
	var ver_ok := 0
	var red := 0
	var skills := 0
	var t0 := Time.get_ticks_msec()
	var all_b := BD.BEASTS.keys()
	var all_h := BD.HUNTERS.keys()
	if OS.get_environment("BS_BASE") != "":
		all_b = all_b.filter(func(x): return not BD.is_expansion(x))
		all_h = all_h.filter(func(x): return not BD.is_expansion(x))
	var from := int(OS.get_environment("BS_FROM")) if OS.get_environment("BS_FROM") != "" else 0
	for g in range(from, from + games):
		var r := RandomNumberGenerator.new()
		r.seed = 5000 + g
		var bs := []
		var pool_b := all_b.duplicate()
		for i in range(nbeasts):
			var b: String = fixed_b if fixed_b != "" and i == 0 else pool_b[r.randi_range(0, pool_b.size() - 1)]
			pool_b.erase(b)
			bs.append(b)
		var nh := 2 if nplayers == 2 else (nplayers - nbeasts)
		var hs := []
		var pool_h := all_h.duplicate()
		for x in bs:
			if x == "esmeria":
				pool_h.erase("esmeria_h")
		for i in range(nh):
			var h: String = fixed_h[i] if i < fixed_h.size() else pool_h[r.randi_range(0, pool_h.size() - 1)]
			pool_h.erase(h)
			hs.append(h)
		var ctrl := []
		for i in range(bs.size()):
			ctrl.append({"ai": true, "level": lb, "player": i})
		for i in range(hs.size()):
			ctrl.append({"ai": true, "level": lh, "player": bs.size() + (0 if nplayers == 2 else i)})
		var eng := BSEngine.new()
		eng.headless = true
		root.add_child(eng)
		eng.setup({"contract": contract, "beasts": bs, "hunters": hs, "ctrl": ctrl, "seed": 1000 + g, "base_only": OS.get_environment("BS_BASE") != ""})
		if OS.get_environment("BS_LOG") != "":
			eng.log_added.connect(func(t): print("  ", t))
		await eng.run()
		var res: Dictionary = eng.results
		var w: String = res.get("winner", "?")
		wins[w] = int(wins.get(w, 0)) + 1
		days += eng.day
		red += int(eng.dom["red"])
		skills += int(eng.kills.get("settler", 0))
		var vr: Dictionary = BSVerify.run(eng.events, res.get("reveal", {}), eng.M["id"])
		if not vr["ok"]:
			print("VERIFICA FALLITA: ", vr["errors"].slice(0, 5))
		else:
			ver_ok += 1
		print("partita %d: %s vs %s → %s (%s) giorno %d, ferite Bestia %d/%d, uccisioni %s dominio %s rovine %s" % [g, ",".join(bs), ",".join(hs), "Bestia" if w == "B" else "cacciatori", res.get("why", ""), eng.day, eng.beast_wounds, eng.beast_hp, str(eng.kills), str(eng.dom), str(eng.ruins)])
		eng.queue_free()
	print("RISULTATO %s Bestia liv.%d vs cacciatori liv.%d: Bestia %d, cacciatori %d (giorni medi %.1f) · coloni uccisi %.2f · dominio rosso %.1f · verifiche superate %d/%d · %d ms" % [contract, lb, lh, wins["B"], wins["H"], days / float(games), skills / float(games), red / float(games), ver_ok, games, Time.get_ticks_msec() - t0])
	quit()
