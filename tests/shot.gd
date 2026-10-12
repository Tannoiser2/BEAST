extends SceneTree
## Screenshot automatici (serve un display: xvfb-run).
## godot --path . -s res://tests/shot.gd -- <modo> [contratto]
##  modo «game»: la Bestia è umana (le decisioni le prende l'IA passando dall'interfaccia), i cacciatori IA;
##               foto del tavolo, del turno della Bestia, di un combattimento e della fine partita.
##  modo «hotseat»: Bestia e cacciatori umani sullo stesso dispositivo (schermata «passa il dispositivo»).
##  modo «menu»: il menu.

var main
var n := 0
var ai := BSAI.new()
var shots := {}
var mode := "game"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func shot(name: String) -> void:
	for i in range(4):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(OS.get_user_data_dir() + "/shots/%02d_%s.png" % [n, name])
	print("shot ", name)


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "game"
	var contract := args[1] if args.size() > 1 else "regent"
	await wait(20)
	await shot("menu")
	if mode == "menu":
		quit()
		return
	var m = main.current
	m.contract = contract
	var K: Dictionary = BD.CONTRACTS[contract]
	m.nplayers = K["players"][0] if contract != "regent" else 3
	m.beasts = ["bolgin", "vacker"]
	m.hunters = ["assar", "iona", "grimgeir"]
	m.beast_ai = [false, true]
	m.hunter_ai = [mode != "hotseat", true, true]
	m.speed = 3
	m.level = 1
	m._on_start()
	await wait(30)
	var g = main.current
	var t0 := Time.get_ticks_msec()
	var combat := false
	var turned := false
	var answered := 0
	var passed := false
	var fr := 0
	while Time.get_ticks_msec() - t0 < 900000:
		await process_frame
		fr += 1
		if fr % 200 == 0:
			print("fotogrammi %d, fps %d, giorno %d, eventi %d" % [fr, Engine.get_frames_per_second(), g.eng.day, g.eng.events.size()])
		if g.end_panel != null and is_instance_valid(g.end_panel):
			await wait(40)
			await shot("fine_partita")
			g.end_panel.get_child(0).visible = false
			await wait(10)
			await shot("fine_percorso_bestia")
			break
		if is_instance_valid(g.pass_screen):
			if not passed:
				passed = true
				await shot("passa_dispositivo")
			var b: Button = null
			for c in g.pass_screen.get_children():
				if c is Button:
					b = c
			await wait(5)
			b.pressed.emit()
			await wait(5)
			continue
		var e = g.eng
		if not shots.has("tavolo") and e.phase == "day":
			shots["tavolo"] = true
			g.table.reset_camera()
			await wait(10)
			await shot("tavolo_3d")
		if not combat and e.events.size() > 0:
			var last: Dictionary = e.events.back()
			if str(last.get("t", "")) in ["attack", "sattack", "dmg"] and e.phase == "day":
				combat = true
				var l: String = last.get("loc", "")
				if l != "":
					g.table.focus(l)
					g.table.dist = 5.5
					g.table.rotate_cam(20, -14)
					g.table.fx_ring(l)
					g.table.fx_text(l, "−%d" % int(last.get("dmg", 1)), Color("#ff6a4a"))
				await wait(8)
				await shot("combattimento")
				g.table.reset_camera()
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		if not turned and req.get("type", "") == "turn" and req.get("side", "") == "B" and e.day >= 1:
			turned = true
			await wait(10)
			await shot("turno_bestia")
		if mode == "hotseat" and req.get("side", "") == "H" and not shots.has("mano_cacciatori"):
			shots["mano_cacciatori"] = true
			await wait(8)
			await shot("mano_cacciatori")
		var r = ai.decide(e, int(req["ci"]), req)
		answered += 1
		g._choose(r)
	print("risposte date: ", answered)
	quit()
