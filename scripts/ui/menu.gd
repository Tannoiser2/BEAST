extends Control
## Menu: contratto, numero di giocatori, Bestie e cacciatori (Umano/IA), livello dell'IA, gioco online.

const D = preload("res://scripts/data/bs_data.gd")
const PLAYABLE := ["regent", "brave", "titan", "ruins", "release", "alliance", "great_cleansing", "shipwreck", "northern_settlements", "northern_gods"]
const MAP_ORDER := [["lsi", "Isole inferiori"], ["usi", "Isole superiori"], ["dl", "Terre inondate"], ["ne", "Distesa del Nord"]]

var main
var contract := "regent"
var nplayers := 2
var beasts := ["bolgin", "raaga"]
var hunters := ["assar", "iona", "helga"]
var beast_ai := [false, true]
var hunter_ai := [true, true, true]
var level := 1
var speed := 1
var msg: Label
var slots_root: Control
var contract_name: Label
var contract_img: TextureRect
var expansion := true                # false: solo gioco base (mappe, personaggi e carte)
var subtitle: Label
var np_row: HBoxContainer


func _ready() -> void:
	size = Vector2(1920, 1080)
	if main.menu_state.has("contract"):
		var s: Dictionary = main.menu_state
		contract = s["contract"]
		nplayers = s["nplayers"]
		beasts = s["beasts"].duplicate()
		hunters = s["hunters"].duplicate()
		beast_ai = s["beast_ai"].duplicate()
		hunter_ai = s["hunter_ai"].duplicate()
		level = s["level"]
		speed = s["speed"]
		expansion = s.get("expansion", true)
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/board/lower_shattered_isles.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size
	bg.modulate = Color(0.28, 0.27, 0.25)
	add_child(bg)
	add_child(UI.shade(size, 0.35, 0.95))
	var t := UI.title("BEAST", 104, Color("#e8c46a"))
	t.position = Vector2(60, 18)
	add_child(t)
	subtitle = UI.label("", 27, Color("#d8cdb4"), UI.font_italic)
	subtitle.position = Vector2(66, 150)
	add_child(subtitle)
	# contratto: la carta grande, sfogliata con le frecce
	var cbox := PanelContainer.new()
	cbox.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0e0cdd"), Color("#4a4632"), 1, 8))
	cbox.position = Vector2(1300, 30)
	cbox.custom_minimum_size = Vector2(580, 900)
	add_child(cbox)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	cbox.add_child(cv)
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 10)
	exp_row.add_child(UI.label("Espansione Isole Frantumate", 22, Color("#7fd3e8"), UI.font_bold))
	exp_row.add_child(_segmented(["Sì", "No"], 0 if expansion else 1, func(k): _set_expansion(k == 0), 100))
	cv.add_child(exp_row)
	contract_name = UI.label("", 22, Color.WHITE, UI.font_bold)
	contract_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(contract_name)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 8)
	cv.add_child(crow)
	for k in [-1, 1]:
		var b := Button.new()
		b.text = "◀" if k < 0 else "▶"
		b.custom_minimum_size = Vector2(60, 140)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 30)
		var kk: int = k
		b.pressed.connect(func(): _cycle_contract(kk))
		if k > 0:
			contract_img = TextureRect.new()
			contract_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			contract_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			contract_img.custom_minimum_size = Vector2(380, 720)
			contract_img.mouse_filter = Control.MOUSE_FILTER_STOP
			contract_img.tooltip_text = "Clic per ingrandire"
			contract_img.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_zoom_contract())
			crow.add_child(contract_img)
		crow.add_child(b)
	np_row = HBoxContainer.new()
	np_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(np_row)
	# livello e velocità dell'IA: a sinistra, accanto alle Bestie (dove si sceglie Umano o IA)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lv.position = Vector2(690, 268)
	add_child(lv)
	lv.add_child(UI.label("Livello IA", 24, Color.WHITE, UI.font_bold))
	lv.add_child(_segmented(["Facile", "Normale", "Difficile"], level, func(k): level = k, 186))
	lv.add_child(UI.label("Velocità IA", 24, Color.WHITE, UI.font_bold))
	lv.add_child(_segmented(["Lenta", "Normale", "Veloce", "Istantanea"], speed, func(k): speed = k, 136))
	slots_root = Control.new()
	slots_root.position = Vector2(60, 210)
	add_child(slots_root)
	msg = UI.label("", 25, UI.RED, UI.font_bold)
	msg.position = Vector2(62, 902)
	add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 18)
	btns.position = Vector2(60, 950)
	add_child(btns)
	var b_start := _big_button("INIZIA PARTITA", 420, true)
	b_start.pressed.connect(_on_start)
	btns.add_child(b_start)
	var b_rules := _big_button("REGOLE", 240)
	b_rules.pressed.connect(_show_rules)
	btns.add_child(b_rules)
	if not OS.has_feature("web"):
		var b_quit := _big_button("ESCI", 200)
		b_quit.pressed.connect(func(): get_tree().quit())
		btns.add_child(b_quit)
	var b_online := _big_button("GIOCA ONLINE", 420)
	b_online.position = Vector2(1460, 950)
	b_online.pressed.connect(_online_panel)
	add_child(b_online)
	var credits := UI.label("Adattamento digitale non ufficiale per uso personale · BEAST e Shattered Isles di Aron Midhall, Elon Midhall, Assar Pettersson (e Albin Larsson) · © Studio Midhall · F11 schermo intero", 17, Color("#8a8476"))
	credits.position = Vector2(62, 1046)
	add_child(credits)
	_refresh()
	if not main.lobby.is_empty():
		_online_panel.call_deferred()


func _store() -> void:
	main.menu_state = {"contract": contract, "nplayers": nplayers, "beasts": beasts.duplicate(), "hunters": hunters.duplicate(),
		"beast_ai": beast_ai.duplicate(), "hunter_ai": hunter_ai.duplicate(), "level": level, "speed": speed, "expansion": expansion}


func n_beasts() -> int:
	return int(D.CONTRACTS[contract].get("beasts", 1))


func n_hunters() -> int:
	if nplayers == 2:
		return 2
	return nplayers - n_beasts()


func _refresh() -> void:
	var K: Dictionary = D.CONTRACTS[contract]
	subtitle.text = ("con l'espansione Shattered Isles" if expansion else "gioco base") + " · Studio Midhall · uno contro tutti, con il movimento nascosto gestito dal motore"
	contract_img.texture = UI.board_tex(K["img"])
	var list := _contracts()
	contract_name.text = "%s · %d di %d" % [D.MAPS[K["map"]]["name"], list.find(contract) + 1, list.size()]
	for c in np_row.get_children():
		c.queue_free()
	var lab := UI.label("Giocatori  ", 24, Color.WHITE, UI.font_bold)
	np_row.add_child(lab)
	var opts := []
	for p in K["players"]:
		opts.append("%d giocatori" % p)
	np_row.add_child(_segmented(opts, K["players"].find(nplayers), func(k):
		nplayers = K["players"][k]
		_refresh(), 180))
	_build_slots()


## Contratti selezionabili (con o senza espansione), nell'ordine delle mappe.
func _contracts() -> Array:
	var out := []
	for m in MAP_ORDER:
		for k in PLAYABLE:
			if D.CONTRACTS[k]["map"] == m[0] and (expansion or D.contract_is_base(k)):
				out.append(k)
	return out


func _cycle_contract(k: int) -> void:
	var list := _contracts()
	var i := list.find(contract)
	contract = list[(i + k + list.size()) % list.size()]
	var pl: Array = D.CONTRACTS[contract]["players"]
	if not pl.has(nplayers):
		nplayers = pl[0]
	msg.text = ""
	_refresh()


## Con l'espansione spenta restano le mappe, i personaggi e le carte del gioco base.
func _set_expansion(on: bool) -> void:
	expansion = on
	if not on:
		if not D.contract_is_base(contract):
			contract = _contracts()[0]
			var pl: Array = D.CONTRACTS[contract]["players"]
			if not pl.has(nplayers):
				nplayers = pl[0]
		for arr in [beasts, hunters]:
			var pool: Array = (D.BEASTS.keys() if arr == beasts else D.HUNTERS.keys()).filter(func(x): return not D.is_expansion(x))
			for i in range(arr.size()):
				if D.is_expansion(arr[i]):
					for cand in pool:
						if not arr.has(cand):
							arr[i] = cand
							break
	_refresh()


func _build_slots() -> void:
	for c in slots_root.get_children():
		c.queue_free()
	var head := UI.title("BESTI%s" % ("A" if n_beasts() == 1 else "E"), 30, UI.BEAST_COL)
	slots_root.add_child(head)
	for i in range(n_beasts()):
		_slot(true, i, Vector2(i * 300, 46))
	var hh := UI.title("CACCIATORI" + ("  (una persona li guida entrambi)" if nplayers == 2 else ""), 30, UI.HUNTER_COL)
	hh.position = Vector2(0, 372)
	slots_root.add_child(hh)
	for i in range(n_hunters()):
		_slot(false, i, Vector2(i * 300, 418))


func _slot(is_beast: bool, i: int, pos: Vector2) -> void:
	var root := Control.new()
	root.position = pos
	root.size = Vector2(286, 320)
	slots_root.add_child(root)
	var id: String = beasts[i] if is_beast else hunters[i]
	var d: Dictionary = D.BEASTS[id] if is_beast else D.HUNTERS[id]
	var ai: bool = beast_ai[i] if is_beast else hunter_ai[i]
	var frame := Panel.new()
	frame.size = root.size
	frame.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0e0ce6"), (UI.BEAST_COL if is_beast else UI.HUNTER_COL) if not ai else Color("#3a3f3a"), 3 if not ai else 1, 8))
	root.add_child(frame)
	var por: Control = UI.mini_view(id, Vector2(150, 170))
	if por == null:
		por = UI.icon_rect(UI.standee_tex(id), Vector2(150, 170))
	por.position = Vector2(68, 8)
	por.mouse_filter = Control.MOUSE_FILTER_STOP
	por.tooltip_text = str(d.get("lore", ""))
	root.add_child(por)
	var is_exp := D.is_expansion(id)
	var tag := UI.label("ISOLE FRANTUMATE" if is_exp else "GIOCO BASE", 15, Color("#7fd3e8") if is_exp else Color("#e8c97f"), UI.font_bold)
	tag.position = Vector2(0, 156)
	tag.size = Vector2(286, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 5)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tag)
	for k in [-1, 1]:
		var b := Button.new()
		b.text = "◀" if k < 0 else "▶"
		b.custom_minimum_size = Vector2(46, 60)
		b.position = Vector2(8 if k < 0 else 232, 64)
		var kk: int = k
		b.pressed.connect(func(): _cycle(is_beast, i, kk))
		root.add_child(b)
	var nm := UI.title(str(d["n"]).to_upper(), 24, Color.WHITE)
	nm.position = Vector2(0, 180)
	nm.size = Vector2(286, 32)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(nm)
	var sb := UI.label(str(d["sub"]), 18, Color("#cfc6b4"), UI.font_italic)
	sb.position = Vector2(0, 212)
	sb.size = Vector2(286, 24)
	sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sb)
	var info := ""
	if is_beast:
		info = "%s · salute %d · complessità %s" % [D.HAB_IT[d["hab"]], int(d["hp"]), d["cplx"]]
	else:
		info = "salute %d · turno: %s" % [int(d["hp"]), d["order"]]
	var il := UI.label(info, 16, Color("#a8a290"))
	il.position = Vector2(0, 236)
	il.size = Vector2(286, 22)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(il)
	var bar := HBoxContainer.new()
	bar.position = Vector2(18, 264)
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var shared := not is_beast and nplayers == 2 and i == 1
	for k2 in range(2):
		var b2 := Button.new()
		b2.text = ["UMANO", "IA"][k2]
		b2.custom_minimum_size = Vector2(120, 46)
		var sel := (k2 == 1) == ai
		b2.add_theme_stylebox_override("normal", UI.panel_style(UI.GOLD if sel else Color("#1a1f1c"), UI.GOLD if sel else Color("#4a4a3a"), 2, 4))
		b2.add_theme_color_override("font_color", UI.DARK if sel else Color("#dddddd"))
		b2.disabled = shared
		var want := k2 == 1
		b2.pressed.connect(func():
			if is_beast:
				beast_ai[i] = want
			else:
				hunter_ai[i] = want
				if nplayers == 2:
					hunter_ai[1] = want
					hunter_ai[0] = want
			msg.text = ""
			_build_slots())
		bar.add_child(b2)


func _cycle(is_beast: bool, i: int, k: int) -> void:
	var pool: Array = D.BEASTS.keys() if is_beast else D.HUNTERS.keys()
	if not expansion:
		pool = pool.filter(func(x): return not D.is_expansion(x))
	var cur: String = beasts[i] if is_beast else hunters[i]
	var idx := pool.find(cur)
	for n in range(pool.size()):
		idx = (idx + k + pool.size()) % pool.size()
		var cand: String = pool[idx]
		var used: Array = (beasts.slice(0, n_beasts()) if is_beast else hunters.slice(0, n_hunters()))
		if used.has(cand):
			continue
		# Esmeria non può essere insieme Bestia e cacciatrice
		if (is_beast and cand == "esmeria" and hunters.slice(0, n_hunters()).has("esmeria_h")) or (not is_beast and cand == "esmeria_h" and beasts.slice(0, n_beasts()).has("esmeria")):
			continue
		if is_beast:
			beasts[i] = cand
		else:
			hunters[i] = cand
		break
	_build_slots()


func _segmented(items: Array, cur: int, cb: Callable, w := 200) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var btns := []
	for k in range(items.size()):
		var b := Button.new()
		b.text = items[k]
		b.custom_minimum_size = Vector2(w, 46)
		b.add_theme_font_size_override("font_size", 20)
		hb.add_child(b)
		btns.append(b)
	var paint := func(sel: int):
		for k in range(btns.size()):
			var on: bool = k == sel
			btns[k].add_theme_stylebox_override("normal", UI.panel_style(UI.GOLD if on else Color("#1a1f1c"), UI.GOLD if on else Color("#4a4a3a"), 2, 4))
			btns[k].add_theme_color_override("font_color", UI.DARK if on else Color("#dddddd"))
			btns[k].add_theme_color_override("font_hover_color", UI.DARK if on else UI.GOLD)
	for k in range(btns.size()):
		btns[k].pressed.connect(func():
			paint.call(k)
			cb.call(k))
	paint.call(cur)
	return hb


func _big_button(text: String, w: float, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 76)
	b.add_theme_font_override("font", UI.font_title)
	b.add_theme_font_size_override("font_size", 32)
	if primary:
		UI.primary(b)
	return b


## Configurazione del motore. Ogni personaggio ha un controllore; «player» raggruppa i personaggi
## della stessa persona (in 2 giocatori i due cacciatori).
func _config() -> Dictionary:
	var bs: Array = beasts.slice(0, n_beasts())
	var hs: Array = hunters.slice(0, n_hunters())
	var ctrl := []
	var p := 0
	for i in range(bs.size()):
		ctrl.append({"ai": beast_ai[i], "level": level, "who": "Bestia" if not beast_ai[i] else "", "player": p})
		p += 1
	for i in range(hs.size()):
		ctrl.append({"ai": hunter_ai[i], "level": level, "who": "", "player": p if nplayers == 2 else p + i})
	var speeds := [1.1, 0.55, 0.18, 0.0]
	return {"contract": contract, "beasts": bs, "hunters": hs, "ctrl": ctrl, "ai_delay": speeds[speed], "level": level, "base_only": not expansion}


func _on_start() -> void:
	_store()
	main.start_game(_config())


func _show_rules() -> void:
	var m := Control.new()
	m.size = size
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(m)
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.8)
	sh.size = size
	sh.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			m.queue_free())
	m.add_child(sh)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d110ff4"), UI.GOLD, 2, 8))
	box.position = Vector2(260, 50)
	box.custom_minimum_size = Vector2(1400, 0)
	m.add_child(box)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1380, 960)
	box.add_child(sc)
	var r := UI.rich(21)
	r.custom_minimum_size = Vector2(1340, 0)
	r.text = RulesText.text(contract)
	sc.add_child(r)


func _zoom_contract() -> void:
	var m := Control.new()
	m.size = size
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(m)
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.85)
	sh.size = size
	m.add_child(sh)
	var r := UI.icon_rect(UI.board_tex(D.CONTRACTS[contract]["img"]), Vector2(520, 1040))
	r.position = Vector2(700, 20)
	m.add_child(r)
	sh.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			m.queue_free())


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


## Posti online = persone (in 2 giocatori i due cacciatori sono un posto solo). Restituisce
## [{chars: [indici], beast: bool}] per i posti umani; il primo è di chi crea la stanza.
func _human_seats(cfg: Dictionary) -> Array:
	var by := {}
	var order := []
	for i in range(cfg["ctrl"].size()):
		var c: Dictionary = cfg["ctrl"][i]
		if c["ai"]:
			continue
		var p := int(c["player"])
		if not by.has(p):
			by[p] = []
			order.append(p)
		by[p].append(i)
	var out := []
	for p in order:
		out.append({"player": p, "chars": by[p]})
	return out


func _online_panel() -> void:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.size = size
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.size = size
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d110ff4"), UI.GOLD, 2, 8))
	box.position = Vector2(540, 110)
	box.custom_minimum_size = Vector2(840, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)
	vb.add_child(UI.title("GIOCA ONLINE", 44))
	var info := UI.label("Chi crea la stanza sceglie prima nel menu contratto, personaggi e livello dell'IA: i personaggi su UMANO diventano i posti per gli amici (il primo è il suo). Gli amici entrano con il codice; i posti liberi li gioca l'IA.\nIl segreto della Bestia resta sul dispositivo di chi la gioca (se la Bestia è dell'IA, su quello di chi crea la stanza): agli altri arrivano solo gli eventi pubblici, e a fine partita si verifica che non abbia barato.", 21, Color("#cccccc"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(800, 0)
	vb.add_child(info)
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := Button.new()
	b_create.text = "CREA UNA STANZA"
	b_create.custom_minimum_size = Vector2(0, 58)
	b_create.add_theme_font_size_override("font_size", 26)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := Button.new()
	b_join.text = "ENTRA"
	b_join.custom_minimum_size = Vector2(200, 58)
	b_join.add_theme_font_size_override("font_size", 26)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.label("", 23, Color.WHITE)
	on_lbl.custom_minimum_size = Vector2(800, 120)
	on_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = _big_button("INIZIA ONLINE", 420, true)
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := _big_button("INDIETRO", 300)
	b_close.pressed.connect(func(): on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi ENTRA per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 58)
	le.add_theme_font_size_override("font_size", 26)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_name(cfg: Dictionary, seat: Dictionary) -> String:
	var names := []
	for i in seat["chars"]:
		var id: String = (cfg["beasts"] + cfg["hunters"])[i]
		names.append((D.BEASTS[id] if i < cfg["beasts"].size() else D.HUNTERS[id])["n"])
	return " e ".join(names)


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var cfg = str_to_var(str(room.get("cfg", "")))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		var nm := "posto %d" % (int(idx) + 1)
		if cfg is Dictionary:
			nm = _seat_name(cfg, _human_seats(cfg)[int(idx)])
		parts.append("%s: %s" % [nm, who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var cfg := _config()
	var hs := _human_seats(cfg)
	if hs.size() < 2:
		_say("Metti su UMANO almeno due persone (per esempio la Bestia e un cacciatore): il primo posto è tuo, gli altri sono per gli amici.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var seats := range(hs.size())
	var code := await net.create_room(nm, seats, var_to_str(cfg))
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": 0}
	net.remember_room(code, 0)
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room, true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi INIZIA ONLINE: i posti liberi li gioca l'IA." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room, false)
				return
			_say("Sei nella stanza [ %s ].\nPosti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, _seats_text(room)])
		await get_tree().create_timer(2.0).timeout


## Chi crea la stanza avvia: i posti vuoti passano all'IA; l'arbitro è il dispositivo della Bestia.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var cfg = str_to_var(str(room.get("cfg", "")))
	var seats_db := Net._as_dict(room.get("seats", {}))
	var hs := _human_seats(cfg)
	var auth: String = room["host"]
	for k in range(hs.size()):
		var s: Dictionary = hs[k]
		var taken: bool = seats_db.has(str(k)) and seats_db[str(k)] is Dictionary
		for i in s["chars"]:
			if taken:
				cfg["ctrl"][i]["who"] = str(seats_db[str(k)].get("name", ""))
			else:
				cfg["ctrl"][i]["ai"] = true
		# il dispositivo che gioca la (prima) Bestia fa da arbitro
		if taken and s["chars"].has(0):
			auth = str(seats_db[str(k)]["uid"])
	cfg["seed"] = 1 + randi() % 2000000000
	var g := {"auth": auth, "cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	room["game"] = g
	room["status"] = "playing"
	_begin(room, false)


## Avvio o rientro: il dispositivo arbitro fa girare il motore, gli altri sono clienti.
func _begin(room: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var g: Dictionary = room["game"]
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var hs := _human_seats(cfg)
	var my: Dictionary = hs[int(lob["seat"])] if int(lob["seat"]) < hs.size() else {"chars": []}
	main.lobby = {}
	if str(g.get("auth", "")) == net.uid:
		var srv := OnlineServer.new()
		srv.setup(net, lob["code"], hs, int(lob["seat"]), rejoin)
		cfg["server"] = srv
		cfg["local_chars"] = my["chars"]
		# solo i personaggi di questo dispositivo sono «umani locali»; gli altri umani rispondono dalla rete
		main.start_game(cfg)
	else:
		var cl := OnlineClient.new()
		var t := "B" if my["chars"].has(0) or (cfg["beasts"].size() > 1 and my["chars"].has(1)) else "H"
		cl.setup(net, lob["code"], int(lob["seat"]), t, cfg)
		main.start_game({"contract": cfg["contract"], "client": cl})
