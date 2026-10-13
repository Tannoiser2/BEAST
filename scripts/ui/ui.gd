class_name UI
extends RefCounted
## Tavolozza, font, tema e immagini (carte sostituibili tramite il manifesto e la cartella «it»).

const D = preload("res://scripts/data/bs_data.gd")

const GOLD := Color("#d9b45a")
const BONE := Color("#efe3c8")
const DARK := Color("#0f1311")
const PANEL := Color("#151a17")
const RED := Color("#e0553f")
const BLOOD := Color("#a3271f")
const TEAL := Color("#4fb3a6")
const GREEN := Color("#7fd36f")
const MUTED := Color("#a7a493")
const BEAST_COL := Color("#d9583f")
const HUNTER_COL := Color("#53b6c9")

static var _tex := {}
static var _manifest := {}
static var font_title: Font
static var font_body: Font
static var font_bold: Font
static var font_italic: Font


static func init_fonts() -> void:
	if font_title != null:
		return
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Cinzel.ttf")
	fv.variation_opentype = {"wght": 700}
	font_title = fv
	font_body = load("res://assets/fonts/BarlowCondensed-Medium.ttf")
	font_bold = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
	font_italic = load("res://assets/fonts/BarlowCondensed-BoldItalic.ttf")
	# frecce e simboli (→ ▲ ♥ ✔ …) mancano nei font del gioco: sul web non ci sono font di sistema
	var sym: Font = load("res://assets/fonts/SimboliDejaVu.ttf")
	for f in [fv, font_body, font_bold, font_italic]:
		f.fallbacks = [sym]


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


# ------------------------------------------------------------------ carte sostituibili

## Immagine di una chiave del manifesto. Se in assets/cards/it/ c'è un file con lo stesso nome
## (.webp, .png o .jpg) si usa quello: così le scansioni italiane sostituiscono le carte senza
## toccare il codice.
static func art(key: String) -> Texture2D:
	var k := "art:" + key
	if _tex.has(k):
		return _tex[k]
	var t: Texture2D = null
	for ext in [".webp", ".png", ".jpg", ".jpeg"]:
		var p = "res://assets/cards/it/" + key + ext
		if ResourceLoader.exists(p):
			t = load(p)
			break
	if t == null:
		if _manifest.is_empty():
			var f := FileAccess.open("res://assets/cards/manifest.json", FileAccess.READ)
			if f != null:
				var j = JSON.parse_string(f.get_as_text())
				if j is Dictionary:
					_manifest = j.get("cards", {})
		var p2: String = _manifest.get(key, "")
		if p2 != "" and ResourceLoader.exists(p2):
			t = load(p2)
	_tex[k] = t
	return t


static func card_tex(cid: String) -> Texture2D:
	var t := art(D.img_key(cid))
	if t == null:
		# carte con più copie: si ripiega sulla prima copia
		var b := D.base_id(cid)
		match D.kind(cid):
			"item":
				t = art("item_%s_1" % b)
			"talent":
				t = art("talent_%s_1" % b)
	return t


static func back_tex(kind: String) -> Texture2D:
	return art("back_" + kind)


static func standee_tex(id: String) -> Texture2D:
	return art("standee_" + id)


static func token_tex(id: String) -> Texture2D:
	return art("token_" + id)


static func board_tex(key: String) -> Texture2D:
	return art(key)


# ------------------------------------------------------------------ widget

static func panel_style(bg: Color, border: Color, bw := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


static func label(text: String, size := 20, col := Color("#eeeeee"), font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func title(text: String, size := 40, col := GOLD) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func rich(size := 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	return r


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func primary(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", panel_style(GOLD, GOLD, 2, 6))
	b.add_theme_stylebox_override("hover", panel_style(Color("#efcf7c"), Color.WHITE, 2, 6))
	b.add_theme_color_override("font_color", DARK)
	b.add_theme_color_override("font_hover_color", DARK)
	return b


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_body
	th.default_font_size = 20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d2421")
	sb.border_color = Color("#8a7a4a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	th.set_stylebox("normal", "Button", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("#34402f")
	sbh.border_color = GOLD
	th.set_stylebox("hover", "Button", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = GOLD
	th.set_stylebox("pressed", "Button", sbp)
	var sbd := sb.duplicate()
	sbd.bg_color = Color("#151816")
	sbd.border_color = Color("#444a44")
	th.set_stylebox("disabled", "Button", sbd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", GOLD)
	th.set_color("font_pressed_color", "Button", DARK)
	th.set_color("font_disabled_color", "Button", Color("#777777"))
	th.set_font("font", "Button", font_bold)
	th.set_font_size("font_size", "Button", 22)
	th.set_color("font_color", "Label", Color("#eeeeee"))
	var pn := StyleBoxFlat.new()
	pn.bg_color = PANEL
	pn.border_color = Color("#000000")
	pn.set_border_width_all(1)
	th.set_stylebox("panel", "Panel", pn)
	th.set_stylebox("panel", "PanelContainer", pn)
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	th.set_font_size("normal_font_size", "RichTextLabel", 20)
	th.set_font_size("bold_font_size", "RichTextLabel", 20)
	th.set_font_size("italics_font_size", "RichTextLabel", 20)
	th.set_color("default_color", "RichTextLabel", Color("#e8e2d2"))
	th.set_font("font", "LineEdit", font_bold)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_stylebox("normal", "LineEdit", panel_style(Color("#0b0e0c"), Color("#5a5a3a"), 1, 4))
	th.set_stylebox("focus", "LineEdit", panel_style(Color("#0b0e0c"), GOLD, 2, 4))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 19)
	var tp := StyleBoxFlat.new()
	tp.bg_color = Color("#0d100eee")
	tp.border_color = GOLD
	tp.set_border_width_all(1)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color("#4a5a3a")
	vs.set_corner_radius_all(4)
	th.set_stylebox("grabber", "VScrollBar", vs)
	th.set_stylebox("grabber_highlight", "VScrollBar", vs)
	var vbg := StyleBoxFlat.new()
	vbg.bg_color = Color("#00000055")
	th.set_stylebox("scroll", "VScrollBar", vbg)
	return th


## Sfondo sfumato verticale.
static func shade(size: Vector2, a0 := 0.3, a1 := 0.94) -> TextureRect:
	var r := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.03, a0))
	g.set_color(1, Color(0.02, 0.03, 0.03, a1))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	r.texture = grad
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func team_col(side: String) -> Color:
	return BEAST_COL if side == "B" else HUNTER_COL


## Testo con i segni [b] del registro convertito per un'etichetta semplice.
static func plain(t: String) -> String:
	return t.replace("[b]", "").replace("[/b]", "")


## Anteprima 3D che gira lentamente (miniatura .glb in assets/miniatures/); null se il modello non c'è.
static func mini_view(id: String, sz: Vector2) -> Control:
	var glb := "res://assets/miniatures/%s.glb" % id
	if not ResourceLoader.exists(glb):
		return null
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = sz
	box.size = sz
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(sz)
	box.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#d8cdb4")
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.light_color = Color("#9fc8ff")
	rim.rotation_degrees = Vector3(-20, 200, 0)
	vp.add_child(rim)
	var spin := Node3D.new()
	vp.add_child(spin)
	var inst: Node3D = (load(glb) as PackedScene).instantiate()
	var hold := Node3D.new()
	hold.add_child(inst)
	spin.add_child(hold)
	var ab := AABB()
	var first := true
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var a: AABB = mi.transform * mi.get_aabb()
		var p := mi.get_parent()
		while p != null and p != hold:
			if p is Node3D:
				a = (p as Node3D).transform * a
			p = p.get_parent()
		ab = a if first else ab.merge(a)
		first = false
	var s: float = 1.0 / max(ab.size.y, 0.0001)
	hold.scale = Vector3.ONE * s
	hold.position = Vector3(-(ab.position.x + ab.size.x / 2) * s, -ab.position.y * s, -(ab.position.z + ab.size.z / 2) * s)
	var cam := Camera3D.new()
	cam.fov = 30
	var wide: float = max(ab.size.x, ab.size.z) * s
	var dist: float = max(1.0 / (2.0 * tan(deg_to_rad(15.0))), wide * 1.4)
	cam.position = Vector3(0, 0.6, dist)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 0), Vector3.UP)
	box.tree_entered.connect(func():
		var tw := box.create_tween().set_loops()
		tw.tween_property(spin, "rotation:y", TAU, 14.0).from(0.0))
	return box
