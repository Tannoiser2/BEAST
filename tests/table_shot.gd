extends SceneTree
## Foto del tavolo 3D da vicino (pezzi, segnalini, carte Movimento) dopo qualche decisione.
## BS_CONTRACT=<id> BS_N=<risposte> xvfb-run godot --path . -s res://tests/table_shot.gd

var main
var ai := BSAI.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func shot(name: String) -> void:
	await wait(4)
	root.get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/shots/t_%s.png" % name)
	print("shot ", name)


func _run() -> void:
	var contract := OS.get_environment("BS_CONTRACT") if OS.get_environment("BS_CONTRACT") != "" else "regent"
	var n := int(OS.get_environment("BS_N")) if OS.get_environment("BS_N") != "" else 25
	await wait(5)
	var m = main.current
	m.contract = contract
	m.nplayers = BD.CONTRACTS[contract]["players"][0]
	m.beasts = ["bolgin", "vacker"]
	m.hunters = ["assar", "iona", "grimgeir"]
	m.beast_ai = [false, true]
	m.hunter_ai = [true, true, true]
	m.speed = 3
	m.level = 1
	m._on_start()
	await wait(5)
	var g = main.current
	var answered := 0
	while answered < n:
		await process_frame
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		g._choose(ai.decide(g.eng, int(req["ci"]), req))
		answered += 1
	await wait(10)
	g.table.reset_camera()
	await shot("insieme")
	# da vicino sul luogo più affollato
	var best := ""
	var bn := 0
	var cnt := {}
	for k in g.table.pieces:
		var p: Node3D = g.table.pieces[k]
		if not is_instance_valid(p):
			continue
		var key := "%d_%d" % [int(p.position.x * 2), int(p.position.z * 2)]
		cnt[key] = int(cnt.get(key, 0)) + 1
	var bl := ""
	var bc := 0
	for l in g.table.M["locs"]:
		var pos: Vector3 = g.table.loc_pos(l)
		var c := 0
		for k in g.table.pieces:
			var p: Node3D = g.table.pieces[k]
			if is_instance_valid(p) and Vector2(p.position.x, p.position.z).distance_to(Vector2(pos.x, pos.z)) < 0.6:
				c += 1
		if c > bc:
			bc = c
			bl = l
	g.table.focus(bl)
	g.table.dist = 4.0
	g.table.rotate_cam(0, -10)
	await shot("vicino")
	g.table.rotate_cam(70, 0)
	await shot("vicino_lato")
	g.table.dist = 2.2
	g.table.zoom_cam(1.0)
	await shot("vicinissimo")
	quit()
