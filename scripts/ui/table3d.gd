class_name Table3D
extends Node3D
## Il tavolo in 3D: tavolo «Kraken» estratto dal modulo TTS, plancia, luci calde, telecamera libera,
## animali e coloni dai modelli .obj, cacciatori/Bestie/evocati come sagome di cartone su basetta
## (sostituibili da un modello in assets/miniatures/<id>.glb), segnalini come pedine 3D.
## Disegna SOLO ciò che c'è nella vista ricevuta (view_for della squadra che guarda).

signal loc_clicked(loc: String)
signal piece_hovered(text: String)

const D = preload("res://scripts/data/bs_data.gd")
const BW := 12.0                     # larghezza della plancia (unità del mondo)

var M: Dictionary
var BD_H := 8.0
var cam: Camera3D
var yaw := 0.0
var pitch := 52.0
var dist := 13.5
var target := Vector3.ZERO
var pieces := {}                     # chiave -> Node3D
var tweens := {}
var marks: Node3D
var fx_root: Node3D
var fx_live := {}                    # luogo -> scritte fluttuanti ancora visibili
var highlights := {}                 # luogo -> anello
var hl_locs: Array = []
var view: Dictionary = {}
var dragging := 0
var drag_from := Vector2.ZERO
var board_top := 0.06
var upright: Array = []              # pezzi verticali che guardano la telecamera
var _mesh_cache := {}
var _mat_cache := {}


func setup(map_id: String) -> void:
	M = D.MAPS[map_id]
	BD_H = BW / float(M["aspect"])
	_build_environment()
	_build_table()
	_build_board()
	marks = Node3D.new()
	add_child(marks)
	fx_root = Node3D.new()
	add_child(fx_root)
	cam = Camera3D.new()
	cam.fov = 42
	cam.near = 0.05
	cam.far = 200
	add_child(cam)
	cam.current = true
	reset_camera()


# ================================================================== ambiente e luci

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#120e0a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6b5640")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffd9a8")
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 40
	add_child(sun)
	# lampade calde intorno al tavolo
	for p in [Vector3(-9, 6, -6), Vector3(9, 6, 6), Vector3(0, 7, 9)]:
		var o := OmniLight3D.new()
		o.light_color = Color("#ffb46a")
		o.light_energy = 1.6
		o.omni_range = 22
		o.omni_attenuation = 1.3
		o.position = p
		add_child(o)


func _mat(tex: Texture2D, alpha := false, rough := 0.85) -> StandardMaterial3D:
	var key := str(tex.get_rid()) if tex != null else "none"
	key += "|%s|%s" % [alpha, rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


func _col_mat(c: Color, emissive := false, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Il tavolo estratto con UnityPy dal pacchetto «The Kraken Table» del modulo TTS.
func _build_table() -> void:
	var tm = load("res://assets/table/Table.obj")
	if tm == null:
		var floor := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(30, 1, 22)
		floor.mesh = bm
		floor.position.y = -0.5
		floor.material_override = _col_mat(Color("#4a3423"))
		add_child(floor)
		return
	var holder := Node3D.new()
	add_child(holder)
	var tex := UI.tex("res://assets/table/table_diffuse.jpg")
	var aabb: AABB = tm.get_aabb()
	var s = 30.0 / max(aabb.size.x, aabb.size.z)
	holder.scale = Vector3.ONE * s
	var top := aabb.end.y
	holder.position = Vector3(-(aabb.position.x + aabb.size.x / 2) * s, -top * s, -(aabb.position.z + aabb.size.z / 2) * s)
	for n in ["Table", "Trim", "Legs"]:
		var m = load("res://assets/table/%s.obj" % n)
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = _mat(tex, false, 0.6)
		holder.add_child(mi)
	# un pavimento scuro sotto il tavolo
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	fl.mesh = pm
	fl.position.y = -9
	fl.material_override = _col_mat(Color("#17110c"))
	add_child(fl)


func _build_board() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BW + 0.3, 0.1, BD_H + 0.3)
	base.mesh = bm
	base.position.y = 0.03
	base.material_override = _col_mat(Color("#1a1612"))
	add_child(base)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(BW, BD_H)
	top.mesh = pm
	top.position.y = board_top + 0.021
	var t := UI.tex(str(M["image"]))
	var m := _mat(t, false, 0.9)
	top.material_override = m
	add_child(top)


# ================================================================== coordinate

func loc_pos(l: String) -> Vector3:
	var L: Dictionary = M["locs"].get(l, {})
	if L.is_empty():
		return Vector3(0, board_top, 0)
	return Vector3((float(L["x"]) - 0.5) * BW, board_top + 0.03, (float(L["y"]) - 0.5) * BD_H)


## Posto n-esimo intorno a un luogo (i pezzi nello stesso luogo non si sovrappongono).
func slot(l: String, i: int, n: int, r := 0.36) -> Vector3:
	var p := loc_pos(l)
	if n <= 1:
		return p
	var a := TAU * float(i) / float(n) + 0.5
	return p + Vector3(cos(a) * r, 0, sin(a) * r)


# ================================================================== telecamera

func reset_camera() -> void:
	yaw = 0.0
	pitch = 54.0
	dist = 13.0
	target = Vector3(0, 0, 0.6)
	_update_cam()


func _update_cam() -> void:
	pitch = clamp(pitch, 18.0, 88.0)
	dist = clamp(dist, 3.0, 26.0)
	target.x = clamp(target.x, -BW * 0.7, BW * 0.7)
	target.z = clamp(target.z, -BD_H * 0.8, BD_H * 0.8)
	var r := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	var off := Vector3(sin(y) * cos(r), sin(r), cos(y) * cos(r)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func rotate_cam(dyaw: float, dpitch: float) -> void:
	yaw += dyaw
	pitch += dpitch
	_update_cam()


func zoom_cam(f: float) -> void:
	dist *= f
	_update_cam()


func pan_cam(dx: float, dz: float) -> void:
	var y := deg_to_rad(yaw)
	var right := Vector3(cos(y), 0, -sin(y))
	var fwd := Vector3(-sin(y), 0, -cos(y))
	target += right * dx * dist * 0.08 + fwd * dz * dist * 0.08
	_update_cam()


func focus(l: String) -> void:
	var p := loc_pos(l)
	target = Vector3(p.x, 0, p.z)
	dist = min(dist, 8.5)
	_update_cam()


## Input della telecamera (chiamato dalla vista con gli eventi non consumati dall'interfaccia).
func handle_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zoom_cam(0.9)
			return true
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zoom_cam(1.1)
			return true
		if ev.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT]:
			if ev.pressed:
				dragging = ev.button_index
				drag_from = ev.position
			else:
				if ev.button_index == MOUSE_BUTTON_LEFT and dragging == MOUSE_BUTTON_LEFT and ev.position.distance_to(drag_from) < 8:
					var l := pick_loc(ev.position)
					if l != "":
						loc_clicked.emit(l)
				dragging = 0
			return true
	if ev is InputEventMouseMotion:
		if dragging == MOUSE_BUTTON_RIGHT:
			rotate_cam(-ev.relative.x * 0.3, ev.relative.y * 0.25)
			return true
		if dragging == MOUSE_BUTTON_MIDDLE:
			rotate_cam(0, ev.relative.y * 0.3)
			return true
		if dragging == MOUSE_BUTTON_LEFT and ev.position.distance_to(drag_from) >= 8:
			pan_cam(-ev.relative.x * 0.02, -ev.relative.y * 0.02)
			return true
		var l2 := pick_loc(ev.position)
		_hover(l2)
	if ev is InputEventMagnifyGesture:
		zoom_cam(1.0 / ev.factor)
		return true
	if ev is InputEventPanGesture:
		pan_cam(ev.delta.x * 0.2, ev.delta.y * 0.2)
		return true
	if ev is InputEventKey and ev.pressed:
		match ev.keycode:
			KEY_Q:
				rotate_cam(-8, 0)
			KEY_E:
				rotate_cam(8, 0)
			KEY_R:
				rotate_cam(0, 5)
			KEY_F:
				rotate_cam(0, -5)
			KEY_W, KEY_UP:
				pan_cam(0, 1)
			KEY_S, KEY_DOWN:
				pan_cam(0, -1)
			KEY_A, KEY_LEFT:
				pan_cam(-1, 0)
			KEY_D, KEY_RIGHT:
				pan_cam(1, 0)
			KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
				zoom_cam(0.88)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_cam(1.12)
			KEY_HOME:
				reset_camera()
			_:
				return false
		return true
	return false


## Luogo sotto il puntatore (raggio della telecamera sul piano della plancia).
func pick_loc(sp: Vector2) -> String:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if abs(d.y) < 0.001:
		return ""
	var t := (board_top - o.y) / d.y
	if t < 0:
		return ""
	var p := o + d * t
	var best := ""
	var bd := 0.62
	var pool: Array = hl_locs if not hl_locs.is_empty() else M["locs"].keys()
	for l in pool:
		var q := loc_pos(l)
		var dd := Vector2(p.x - q.x, p.z - q.z).length()
		if dd < bd:
			bd = dd
			best = l
	return best


var _hover_loc := ""

func _hover(l: String) -> void:
	if l == _hover_loc:
		return
	_hover_loc = l
	for k in highlights:
		var r: MeshInstance3D = highlights[k]
		r.scale = Vector3.ONE * (1.25 if k == l else 1.0)
	piece_hovered.emit(_loc_text(l) if l != "" else "")


func _loc_text(l: String) -> String:
	var L: Dictionary = M["locs"][l]
	var hs := []
	var hab: Array = L["hab"]
	if view.get("tokens", {}).has(l):
		hab = [view["tokens"][l]]
	for h in hab:
		hs.append(D.HAB_IT.get(h, h))
	var s := "/".join(hs).capitalize()
	if L.has("name"):
		s = str(L["name"]).replace("_", " ").capitalize() + " · " + s
	if L["zone"] != "*":
		s += " · zona " + str(M["zones"][L["zone"]])
	else:
		s += " · centro (tutte le zone)"
	if L.has("ruin"):
		s += " · Rovina: " + str(M["ruins"][L["ruin"]])
	var n := int(view.get("trails", {}).get(l, 0))
	if n > 0:
		s += " · %d Tracc%s" % [n, "ia" if n == 1 else "e"]
	return s


# ================================================================== evidenziazione delle scelte

func set_highlights(locs: Array, col := Color("#ffd36b")) -> void:
	for k in highlights:
		highlights[k].queue_free()
	highlights.clear()
	hl_locs = locs.duplicate()
	for l in locs:
		if not M["locs"].has(l):
			continue
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.30
		tm.outer_radius = 0.38
		ring.mesh = tm
		ring.material_override = _col_mat(col, true)
		ring.position = loc_pos(l) + Vector3(0, 0.02, 0)
		marks.add_child(ring)
		highlights[l] = ring


# ================================================================== pezzi

func _piece(key: String, make: Callable) -> Node3D:
	if pieces.has(key) and is_instance_valid(pieces[key]):
		return pieces[key]
	var n: Node3D = make.call()
	n.name = key.replace(":", "_")
	add_child(n)
	pieces[key] = n
	return n


func _place(n: Node3D, pos: Vector3, instant := false) -> void:
	if instant or n.position.distance_to(pos) < 0.01 or n.get_meta("new", false):
		n.position = pos
		n.set_meta("new", false)
		return
	if tweens.has(n) and tweens[n].is_valid():
		tweens[n].kill()
	var tw := create_tween()
	var mid := (n.position + pos) / 2 + Vector3(0, 0.35, 0)
	tw.tween_property(n, "position", mid, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position", pos, 0.18).set_trans(Tween.TRANS_SINE)
	tweens[n] = tw


## Sagoma di cartone su basetta (oppure miniatura .glb se presente in assets/miniatures/).
func make_standee(id: String, tex_key: String, height := 0.95, base_col := Color("#2b2620")) -> Node3D:
	var root := Node3D.new()
	root.set_meta("new", true)
	var glb := "res://assets/miniatures/%s.glb" % id
	if ResourceLoader.exists(glb):
		var ps: PackedScene = load(glb)
		var inst: Node3D = ps.instantiate()
		var hold := Node3D.new()
		hold.add_child(inst)
		root.add_child(hold)
		var ab := _scene_aabb(inst)
		if ab.size.y > 0.0001:
			var s := height / ab.size.y
			hold.scale = Vector3.ONE * s
			hold.position = Vector3(-(ab.position.x + ab.size.x / 2) * s, -ab.position.y * s, -(ab.position.z + ab.size.z / 2) * s)
		return root
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.22
	cm.height = 0.06
	base.mesh = cm
	base.position.y = 0.03
	base.material_override = _col_mat(base_col, false, 0.4)
	root.add_child(base)
	var t := UI.art(tex_key)
	var asp := 0.7
	if t != null:
		asp = float(t.get_width()) / float(t.get_height())
	var card := Node3D.new()
	card.position.y = 0.06
	root.add_child(card)
	var q := QuadMesh.new()
	q.size = Vector2(height * asp, height)
	var front := MeshInstance3D.new()
	front.mesh = q
	front.position = Vector3(0, height / 2, 0.012)
	front.material_override = _mat(t, true, 0.95)
	card.add_child(front)
	# spessore del cartone
	var bx := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(height * asp * 0.86, height * 0.94, 0.018)
	bx.mesh = bm
	bx.position = Vector3(0, height * 0.49, 0)
	bx.material_override = _col_mat(Color("#3a2c1e"), false, 0.95)
	card.add_child(bx)
	var back := MeshInstance3D.new()
	back.mesh = q
	back.position = Vector3(0, height / 2, -0.012)
	back.rotation_degrees.y = 180
	back.material_override = _mat(t, true, 0.95)
	card.add_child(back)
	root.set_meta("card", card)
	return root


func _scene_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var a := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


## Animali e coloni: i modelli .obj del modulo (sagome spesse in legno dipinto).
func make_meeple(kind: String, height := 0.42) -> Node3D:
	var root := Node3D.new()
	root.set_meta("new", true)
	var mesh = _mesh_cache.get(kind)
	if mesh == null:
		mesh = load("res://assets/models/%s.obj" % kind)
		_mesh_cache[kind] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var ab: AABB = mesh.get_aabb() if mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
	var s = height / max(ab.size.y, 0.001)
	mi.scale = Vector3.ONE * s
	mi.position = Vector3(-(ab.position.x + ab.size.x / 2) * s, -ab.position.y * s, -(ab.position.z + ab.size.z / 2) * s)
	mi.material_override = _mat(UI.tex("res://assets/models/%s.png" % kind), false, 0.75)
	var spin := Node3D.new()
	spin.add_child(mi)
	root.add_child(spin)
	return root


## Pedina tonda (tracce, segnalini habitat, rovine…): cilindro con l'immagine sopra.
func make_disc(tex: Texture2D, r := 0.15, h := 0.04, edge := Color("#3a2c1e")) -> Node3D:
	var root := Node3D.new()
	root.set_meta("new", true)
	var cy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 28
	cy.mesh = cm
	cy.position.y = h / 2
	cy.material_override = _col_mat(edge, false, 0.6)
	root.add_child(cy)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 2, r * 2)
	top.mesh = pm
	top.position.y = h + 0.002
	var m := _mat(tex, true, 0.6)
	top.material_override = m
	root.add_child(top)
	return root


func _process(_d: float) -> void:
	if cam == null:
		return
	pass  # i pezzi restano fissi sulla plancia (niente rotazione verso la telecamera)


# ================================================================== aggiornamento dalla vista

func update_view(v: Dictionary) -> void:
	view = v
	if replay_on:
		return
	var seen := {}
	var team: String = v.get("team", "P")
	# segnalini habitat
	for l in v.get("tokens", {}):
		var h: String = v["tokens"][l]
		var key := "hab:%s:%s" % [l, h]
		seen[key] = true
		var n := _piece(key, func(): return make_disc(UI.token_tex("hab_" + h), 0.27, 0.035))
		_place(n, loc_pos(l) + Vector3(0, 0, 0), true)
	# rovine controllate
	for r in v.get("ruins", {}):
		var team_r: String = v["ruins"][r]
		if team_r == "":
			continue
		var rl := ""
		for l in M["locs"]:
			if M["locs"][l].get("ruin", "") == r:
				rl = l
		var key2 := "ruin:%s:%s" % [r, team_r]
		seen[key2] = true
		var n2 := _piece(key2, func(): return make_disc(UI.token_tex("ruin_red" if team_r == "B" else "ruin_blue"), 0.17, 0.05))
		_place(n2, loc_pos(rl) + Vector3(-0.42, 0, -0.3), true)
	# torri di guardia
	var tcount := {}
	for t in v.get("towers", []):
		var k := int(tcount.get(t, 0))
		tcount[t] = k + 1
		var key3 := "tower:%s:%d" % [t, k]
		seen[key3] = true
		var n3 := _piece(key3, func(): return make_standee("watchtower", "token_watchtower", 0.75, Color("#4a3a2a")))
		_place(n3, loc_pos(t) + Vector3(0.4, 0, -0.38 - k * 0.1))
	# tracce
	for l in v.get("trails", {}):
		var cnt := int(v["trails"][l])
		for i in range(cnt):
			var key4 := "trail:%s:%d" % [l, i]
			seen[key4] = true
			var who := _trail_owner(v, l)
			var n4 := _piece(key4, func(): return make_disc(UI.token_tex("trail_" + who), 0.16, 0.04))
			_place(n4, loc_pos(l) + Vector3(0.3, 0.045 * i, 0.3), true)
	# esseri: raggruppati per luogo
	var by_loc := {}
	var add := func(l: String, key: String, mk: Callable, extra := {}):
		if l == "":
			return
		if not by_loc.has(l):
			by_loc[l] = []
		by_loc[l].append({"key": key, "mk": mk, "extra": extra})
	for a in v.get("animals", []):
		add.call(a["loc"], "animal:%d" % a["id"], func(): return make_meeple(a["kind"], 0.40 if a["kind"] != "sheep" else 0.32), {"wounds": a["wounds"]})
	for s in v.get("settlers", []):
		add.call(s["loc"], "settler:%d" % s["id"], func(): return make_meeple(s["kind"], 0.5), {"wounds": s["wounds"], "armor": s.get("armor", 0)})
	for su in v.get("summons", []):
		var kind: String = su["kind"]
		add.call(su["loc"], "summon:%d" % su["id"], func(): return make_standee(kind, "standee_" + kind, 0.62, Color("#5a1f1a")), {"wounds": su["wounds"]})
	for c in v.get("chars", []):
		if c["side"] == "H":
			if not c["dead"]:
				var hid: String = c["id"]
				add.call(c.get("loc", ""), "hunter:%d" % c["i"], func(): return make_standee(hid, "standee_" + hid, 0.92, Color("#1f3e4a")))
		else:
			var bid: String = c["id"]
			if c.get("reborn", false):
				bid = "fk_reborn"
			# sagoma della Bestia: ultima posizione nota (per tutti)
			var bkey := "beast:%d:%s" % [c["i"], bid]
			add.call(c.get("standee", ""), bkey, func(): return make_standee(c["id"], "standee_" + bid, 1.15, Color("#5a1f1a")), {"hidden": not c["revealed"]})
			# la Bestia vede anche dove si trova davvero
			if team == "B" and not c["revealed"] and c.has("loc") and c["loc"] != c.get("standee", ""):
				add.call(c["loc"], "ghost:%d" % c["i"], func(): return _make_ghost(bid), {})
	if v.get("companion", "") != "":
		add.call(v["companion"], "companion", func(): return make_standee("fylgja", "standee_fylgja", 0.55, Color("#1f3e4a")))
	for l in by_loc:
		var arr: Array = by_loc[l]
		for i in range(arr.size()):
			var it: Dictionary = arr[i]
			seen[it["key"]] = true
			var n5 := _piece(it["key"], it["mk"])
			_place(n5, slot(l, i, arr.size(), 0.34 if arr.size() < 5 else 0.42))
			_set_wounds(n5, int(it["extra"].get("wounds", 0)), int(it["extra"].get("armor", 0)))
			if it["extra"].get("hidden", false) != n5.get_meta("hidden", false):
				_set_hidden(n5, it["extra"].get("hidden", false))
	# carte Movimento attive (coperte) sul bordo della plancia
	var mv_i := 0
	for c in v.get("chars", []):
		if c["side"] != "B":
			continue
		var nmv: int = c.get("moves_n", 0)
		for k in range(nmv):
			var key6 := "mcard:%d:%d" % [c["i"], k]
			seen[key6] = true
			var mine: Array = c.get("moves", [])
			var face := ""
			if k < mine.size():
				face = "%s%s" % [D.DIR_IT[mine[k]["dir"]].left(1) if mine[k]["dir"] != "X" else "·", "*" if mine[k]["fake"] else ""]
			var n6 := _piece(key6 + face, func(): return _make_move_card(face))
			# sezione «Active Movement» stampata ai lati della plancia (a sinistra la prima Bestia)
			var colx := 0.105 if c["i"] == 0 else 0.895
			var row: int = k % 7
			_place(n6, Vector3((colx - 0.5) * BW + (k / 7) * 0.12, board_top + 0.03 + (k / 7) * 0.02, (0.535 + row * 0.058 - 0.5) * BD_H), true)
			seen[key6 + face] = true
			mv_i += 1
	for k in pieces.keys():
		if not seen.has(k):
			if is_instance_valid(pieces[k]):
				pieces[k].queue_free()
			pieces.erase(k)


func _trail_owner(v: Dictionary, l: String) -> String:
	if v.has("trails_by") and v["trails_by"].has(l):
		for b in v["trails_by"][l]:
			return str(v["chars"][int(b)]["id"])
	for c in v.get("chars", []):
		if c["side"] == "B":
			return str(c["id"])
	return "bolgin"


func _make_ghost(id: String) -> Node3D:
	var n := make_standee(id, "standee_" + id, 1.15, Color("#ffb070"))
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = (mi as MeshInstance3D).material_override.duplicate()
		m.albedo_color = Color(1, 0.85, 0.7, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color("#ff9a40")
		m.emission_energy_multiplier = 0.6
		(mi as MeshInstance3D).material_override = m
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.3
	ring.mesh = tm
	ring.material_override = _col_mat(Color("#ff7a30"), true)
	ring.position.y = 0.03
	n.add_child(ring)
	return n


func _make_move_card(face: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("new", true)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.02, 0.27)
	mi.mesh = bm
	mi.material_override = _col_mat(Color("#3b2a22") if face == "" else Color("#d8c9a6"))
	root.add_child(mi)
	if face != "":
		var lb := Label3D.new()
		lb.text = face
		lb.font = UI.font_bold
		lb.font_size = 48
		lb.pixel_size = 0.003
		lb.modulate = Color("#401010")
		lb.rotation_degrees.x = -90
		lb.position.y = 0.02
		root.add_child(lb)
	return root


func _set_hidden(n: Node3D, hidden: bool) -> void:
	n.set_meta("hidden", hidden)
	var q: Node3D = n.get_node_or_null("q")
	if hidden:
		if q == null:
			var lb := Label3D.new()
			lb.name = "q"
			lb.text = "?"
			lb.font = UI.font_bold
			lb.font_size = 160
			lb.pixel_size = 0.004
			lb.modulate = Color("#ffcf6a")
			lb.outline_size = 14
			lb.outline_render_priority = 0
			lb.render_priority = 1
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.position.y = 1.45
			n.add_child(lb)
	elif q != null:
		q.queue_free()


func _set_wounds(n: Node3D, w: int, armor := 0) -> void:
	var cur := int(n.get_meta("w", -1))
	var ca := int(n.get_meta("a", -1))
	if cur == w and ca == armor:
		return
	n.set_meta("w", w)
	n.set_meta("a", armor)
	for c in n.get_children():
		if c.name.begins_with("wound") or c.name.begins_with("armor"):
			c.queue_free()
	for i in range(w):
		var d := make_disc(UI.token_tex("wound"), 0.09, 0.03, Color("#5a1010"))
		d.name = "wound%d" % i
		d.position = Vector3(-0.16 + i * 0.12, 0, 0.2)
		n.add_child(d)
	for i in range(armor):
		var d2 := make_disc(UI.token_tex("armor"), 0.09, 0.03)
		d2.name = "armor%d" % i
		d2.position = Vector3(0.16 + i * 0.12, 0, 0.2)
		n.add_child(d2)


# ================================================================== effetti

## Testo fluttuante e anello pulsante (attacchi, perlustrazioni, rivelazioni).
func fx_text(l: String, text: String, col := Color("#ffcf6a")) -> void:
	if not M["locs"].has(l):
		return
	# più scritte nello stesso luogo a breve distanza (rivelata due volte, ricerca e attacco…) si
	# sovrapponevano e diventavano illeggibili: la stessa scritta non si ripete, le altre si impilano
	var live: Array = (fx_live.get(l, []) as Array).filter(func(x): return is_instance_valid(x))
	for x in live:
		if x.text == text:
			return
	fx_live[l] = live
	var lb := Label3D.new()
	live.append(lb)
	lb.text = text
	# font del gioco (quello di sistema si vedeva male: lettere sovrapposte) e bordo sottile disegnato prima
	lb.font = UI.font_bold
	lb.font_size = 64
	lb.pixel_size = 0.005
	lb.modulate = col
	lb.outline_size = 8
	lb.outline_modulate = Color(0, 0, 0, 0.85)
	lb.render_priority = 2
	lb.outline_render_priority = 1
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = loc_pos(l) + Vector3(0, 1.4 + 0.42 * (live.size() - 1), 0)
	fx_root.add_child(lb)
	var tw := create_tween()
	tw.tween_property(lb, "position", lb.position + Vector3(0, 0.8, 0), 1.6)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(lb.queue_free)


func fx_ring(l: String, col := Color("#ff5a3a")) -> void:
	if not M["locs"].has(l):
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.36
	ring.mesh = tm
	var m := _col_mat(col, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = loc_pos(l) + Vector3(0, 0.05, 0)
	fx_root.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 2.4, 0.9)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(ring.queue_free)


## Percorso della Bestia (fine partita o rivelazione): frecce fra i luoghi.
func show_path(moves: Array, col := Color("#ff6a3a")) -> void:
	for m in moves:
		if str(m.get("from", "")) == str(m.get("to", "")):
			continue
		var a := loc_pos(m["from"]) + Vector3(0, 0.08, 0)
		var b := loc_pos(m["to"]) + Vector3(0, 0.08, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.03, a.distance_to(b))
		mi.mesh = bm
		var c2 := col
		if m.get("fake", false):
			c2 = Color("#9a9aff")
		mi.material_override = _col_mat(c2, true)
		mi.position = (a + b) / 2
		marks.add_child(mi)
		mi.look_at(b, Vector3.UP)
		var tw := create_tween()
		tw.tween_interval(6.0)
		tw.tween_callback(mi.queue_free)


# ================================================================== replay di fine partita

var replay_on := false
var rp := {}                         # chiave -> pezzo
var rp_loc := {}                     # chiave -> luogo
var rp_order: Array = []             # ordine d'arrivo (per disporre i pezzi nello stesso luogo)
var rp_marks: Node3D
const RP_COL := [Color("#e8321a"), Color("#8a2be2")]


## Svuota il tavolo dai pezzi della partita: il replay mette i suoi.
func replay_start() -> void:
	replay_stop()
	replay_on = true
	for k in pieces:
		if is_instance_valid(pieces[k]):
			pieces[k].visible = false
	for l in highlights:
		if is_instance_valid(highlights[l]):
			highlights[l].visible = false
	for c in marks.get_children():
		c.visible = false
	rp_marks = Node3D.new()
	add_child(rp_marks)


func replay_stop() -> void:
	for k in rp:
		if is_instance_valid(rp[k]):
			rp[k].queue_free()
	rp.clear()
	rp_loc.clear()
	rp_order.clear()
	if rp_marks != null and is_instance_valid(rp_marks):
		rp_marks.queue_free()
	rp_marks = null
	if replay_on:
		replay_on = false
		for k in pieces:
			if is_instance_valid(pieces[k]):
				pieces[k].visible = true
		for c in marks.get_children():
			c.visible = true
		var v := view
		view = {}
		update_view(v)


func rp_add(key: String, piece: Dictionary, loc: String, dur: float) -> void:
	if rp.has(key) or not M["locs"].has(loc):
		return
	var id: String = piece.get("id", "")
	var n: Node3D
	match str(piece.get("kind", "")):
		"beast":
			n = make_standee(id, "standee_" + id, 1.15, Color("#5a1f1a"))
		"hunter":
			n = make_standee(id, "standee_" + id, 0.92, Color("#1f3e4a"))
		"companion":
			n = make_standee("fylgja", "standee_fylgja", 0.55, Color("#1f3e4a"))
		"animal":
			n = make_meeple(id, 0.40 if id != "sheep" else 0.32)
		"settler":
			n = make_meeple(id, 0.5)
		_:
			n = make_standee(id, "standee_" + id, 0.62, Color("#5a1f1a"))
	add_child(n)
	rp[key] = n
	rp_loc[key] = loc
	rp_order.append(key)
	n.position = loc_pos(loc)
	n.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, max(0.05, dur))
	_rp_layout(loc, dur, "")


func rp_move(key: String, to: String, dur: float, beast := -1, jump := false) -> void:
	if not rp.has(key) or not M["locs"].has(to):
		return
	var from: String = rp_loc[key]
	rp_loc[key] = to
	rp_order.erase(key)
	rp_order.append(key)
	var n: Node3D = rp[key]
	var dest := _rp_slot(to, key)
	if tweens.has(n) and tweens[n].is_valid():
		tweens[n].kill()
	var tw := create_tween()
	if jump:
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, dur * 0.4)
		tw.tween_callback(func(): n.position = dest)
		tw.tween_property(n, "scale", Vector3.ONE, dur * 0.4)
	else:
		# arco morbido: sale un poco a metà strada
		var a := n.position
		tw.tween_method(func(t: float):
			if is_instance_valid(n):
				n.position = a.lerp(dest, t) + Vector3(0, sin(t * PI) * 0.28, 0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tweens[n] = tw
	if beast >= 0 and not jump:
		_rp_segment(from, to, RP_COL[beast % RP_COL.size()], dur)
	_rp_layout(from, dur, "")
	_rp_layout(to, dur, key)


func rp_del(key: String, dur: float) -> void:
	if not rp.has(key):
		return
	var n: Node3D = rp[key]
	var l: String = rp_loc[key]
	rp.erase(key)
	rp_loc.erase(key)
	rp_order.erase(key)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.01, max(0.05, dur))
	tw.tween_callback(n.queue_free)
	_rp_layout(l, dur, "")


## Posto del pezzo key nel luogo l (i pezzi presenti si dispongono a cerchio).
func _rp_slot(l: String, key: String) -> Vector3:
	var here := rp_order.filter(func(k): return rp_loc.get(k, "") == l)
	var i := here.find(key)
	return slot(l, max(0, i), here.size(), 0.34 if here.size() < 5 else 0.42)


func _rp_layout(l: String, dur: float, skip: String) -> void:
	for k in rp_order:
		if k == skip or rp_loc.get(k, "") != l:
			continue
		var n: Node3D = rp[k]
		var p := _rp_slot(l, k)
		if n.position.distance_to(p) < 0.01:
			continue
		var tw := create_tween()
		tw.tween_property(n, "position", p, max(0.05, dur * 0.6)).set_trans(Tween.TRANS_SINE)


## Tratto del percorso della Bestia, che si allunga mentre lei si muove.
func _rp_segment(from: String, to: String, col: Color, dur: float) -> void:
	if rp_marks == null:
		return
	var a := loc_pos(from) + Vector3(0, 0.07, 0)
	var b := loc_pos(to) + Vector3(0, 0.07, 0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.03, 1.0)
	mi.mesh = bm
	# colore pieno, senza luci: sulla mappa chiara un materiale illuminato sembrava bianco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mi.material_override = mat
	rp_marks.add_child(mi)
	mi.position = a
	mi.look_at(b, Vector3.UP)
	var L := a.distance_to(b)
	mi.scale = Vector3(1, 1, 0.001)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(mi):
			mi.scale = Vector3(1, 1, max(0.001, L * t))
			mi.position = a.lerp(b, t * 0.5), 0.0, 1.0, max(0.05, dur))
