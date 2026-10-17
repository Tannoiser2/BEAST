extends SceneTree
## Foto delle decisioni con le carte (draft al centro, mano in basso, Arsenale…), la Bestia umana.
## BS_CONTRACT=<id> BS_BASE=1 BS_N=<risposte> xvfb-run godot --path . -s res://tests/ui_shot.gd

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
	root.get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/shots/u_%s.png" % name)
	print("shot ", name)


func _run() -> void:
	var contract := OS.get_environment("BS_CONTRACT") if OS.get_environment("BS_CONTRACT") != "" else "regent"
	var n := int(OS.get_environment("BS_N")) if OS.get_environment("BS_N") != "" else 60
	await wait(5)
	var m = main.current
	if OS.get_environment("BS_BASE") != "":
		m._set_expansion(false)
	m.contract = contract
	m.nplayers = BD.CONTRACTS[contract]["players"][0]
	m.beast_ai = [false, true]
	m.hunter_ai = [true, true, true]
	m.speed = 3
	m.level = 1
	m._on_start()
	await wait(5)
	var g = main.current
	var answered := 0
	var seen := {}
	while answered < n:
		await process_frame
		var req: Dictionary = g.pending
		if req.is_empty():
			continue
		var t: String = req.get("type", "")
		var has_card := false
		for o in req.get("opts", []):
			if o.has("card"):
				has_card = true
		if has_card and not seen.has(t):
			seen[t] = true
			await wait(6)
			await shot("%02d_%s" % [answered, t])
		g._choose(ai.decide(g.eng, int(req["ci"]), req))
		answered += 1
	print("tipi visti: ", seen.keys(), " base_only=", g.eng.base_only)
	quit()
