extends SceneTree
## Prova veloce del replay: una partita IA contro IA senza interfaccia, poi il replay sul tavolo 3D
## con qualche screenshot (serve un display: xvfb-run).
## godot --path . -s res://tests/replay_shot.gd -- [contratto]

var table: Table3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var contract := args[0] if args.size() > 0 else "regent"
	var K: Dictionary = BD.CONTRACTS[contract]
	var nb := int(K.get("beasts", 1))
	var bs := ["bolgin", "vacker"].slice(0, nb)
	var hs := ["assar", "iona", "grimgeir"].slice(0, 2 if contract == "regent" else 3)
	var ctrl := []
	for i in range(bs.size() + hs.size()):
		ctrl.append({"ai": true, "level": 1, "player": i})
	var eng := BSEngine.new()
	eng.headless = true
	root.add_child(eng)
	eng.setup({"contract": contract, "beasts": bs, "hunters": hs, "ctrl": ctrl, "seed": 77})
	await eng.run()
	var v := eng.view_for("B")
	var steps := BSReplay.build(eng.events, eng.results["reveal"], eng.M["id"], v["chars"])
	var kinds := {}
	for s in steps:
		kinds[s["k"]] = int(kinds.get(s["k"], 0)) + 1
	print("REPLAY passi %d %s" % [steps.size(), str(kinds)])
	# controllo: la posizione finale della Bestia nel replay coincide con quella vera
	var last := {}
	for s in steps:
		if s["k"] in ["add", "move", "jump"] and str(s["key"]).begins_with("B"):
			last[s["key"]] = s.get("to", s.get("loc", ""))
	for b in eng.beasts():
		print("REPLAY Bestia %d: fine replay %s, vera %s" % [b, last.get("B%d" % b, "?"), eng.ch[b]["loc"]])
	UI.init_fonts()
	table = Table3D.new()
	root.add_child(table)
	table.setup(eng.M["id"])
	table.update_view(v)
	table.replay_start()
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	var n := steps.size()
	var marks := [int(n * 0.3), int(n * 0.7), n - 1]
	for i in range(n):
		var st: Dictionary = steps[i]
		match str(st["k"]):
			"add":
				table.rp_add(st["key"], st["piece"], st["loc"], 0.02)
			"move":
				table.rp_move(st["key"], st["to"], 0.05, int(st.get("beast", -1)))
			"jump":
				table.rp_move(st["key"], st["to"], 0.05, -1, true)
			"del":
				table.rp_del(st["key"], 0.02)
		if marks.has(i):
			await create_timer(0.4).timeout
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(OS.get_user_data_dir() + "/shots/replay_%s_%d.png" % [contract, i])
			print("shot replay ", i)
		elif i % 6 == 0:
			await process_frame
	table.replay_stop()
	quit()
