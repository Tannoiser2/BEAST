extends SceneTree
## Compila tutti gli script e stampa gli errori (godot --headless -s res://tests/chk.gd).
func _init() -> void:
	var bad := 0
	for d in ["res://scripts/data", "res://scripts/core", "res://scripts/net", "res://scripts/ui"]:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("ERRORE in ", d, "/", f)
					bad += 1
	print("script con errori: ", bad)
	quit(1 if bad > 0 else 0)
