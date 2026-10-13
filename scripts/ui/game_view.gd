extends Control
## Vista di gioco: tavolo 3D + interfaccia (mano, scelte, schede dei personaggi, registro).
## Funziona allo stesso modo in locale (motore su questo dispositivo) e da cliente online
## (nessun motore: riceve solo la vista della propria squadra). Mostra sempre e solo view_for(squadra).

const D = preload("res://scripts/data/bs_data.gd")

var main
var config: Dictionary = {}
var eng: BSEngine = null         # motore locale (solitario, hotseat, dispositivo della Bestia online)
var client = null                # OnlineClient (dispositivo senza motore)
var server = null                # OnlineServer (questo dispositivo fa da arbitro)
var team := "H"                  # squadra che sta guardando lo schermo
var humans := {}                 # squadra -> true se ha giocatori umani su questo dispositivo
var pending: Dictionary = {}
var view: Dictionary = {}
var ev_seen := 0
var hand_ci := -1

var vp: SubViewport
var vpc: SubViewportContainer
var table: Table3D
var hud: Control
var top_lbl: RichTextLabel
var chars_box: VBoxContainer
var hand_box: HBoxContainer
var hand_tabs: HBoxContainer
var dec_panel: PanelContainer
var dec_title: Label
var dec_prompt: RichTextLabel
var dec_opts: VBoxContainer
var log_panel: PanelContainer
var log_lbl: RichTextLabel
var zoom: TextureRect
var zoom_txt: Label
var hover_lbl: Label
var toast_lbl: Label
var pass_screen: Control
var end_panel: Control
var modal: Control
var waiting_lbl: Label
var log_visible := true


func _ready() -> void:
	size = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var map_id: String = D.CONTRACTS[config.get("contract", "regent")]["map"]
	# --- mondo 3D
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	vpc.add_child(vp)
	table = Table3D.new()
	vp.add_child(table)
	table.setup(map_id)
	table.loc_clicked.connect(_on_loc_clicked)
	table.piece_hovered.connect(func(t): hover_lbl.text = t)
	_build_hud()
	# --- sorgente della partita
	if config.has("client"):
		client = config["client"]
		add_child(client)
		team = client.team
		client.view_changed.connect(_on_remote_view)
		client.status.connect(func(t): _toast(t))
		client.start()
	else:
		eng = BSEngine.new()
		add_child(eng)
		eng.setup(config)
		eng.ai_delay = float(config.get("ai_delay", 0.6))
		eng.changed.connect(_refresh)
		eng.decision_requested.connect(_on_request)
		eng.game_ended.connect(_on_end)
		eng.log_added.connect(func(_t): _refresh_log())
		for i in range(eng.ch.size()):
			if not eng.ch[i]["ctrl"]["ai"]:
				humans[eng.side(i)] = true
		if config.has("server"):
			server = config["server"]
			add_child(server)
			server.attach(eng, self)
			humans.clear()
			for i in config.get("local_chars", []):
				humans[eng.side(i)] = true
		if humans.size() == 1:
			team = humans.keys()[0]
		elif humans.is_empty():
			team = "P"
		else:
			team = "H"
		_refresh()
		_start.call_deferred()


func _start() -> void:
	if humans.size() > 1:
		await _pass_device(team, "Inizia la partita: prima si preparano i cacciatori.")
	await eng.run()


# ================================================================== interfaccia

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var W := size.x
	var H := size.y
	# barra in alto
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0e0cdd"), Color("#3a3a2a"), 1, 0))
	bar.position = Vector2(0, 0)
	bar.size = Vector2(W, 54)
	hud.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	bar.add_child(hb)
	top_lbl = UI.rich(22)
	top_lbl.custom_minimum_size = Vector2(W - 560, 36)
	top_lbl.fit_content = false
	hb.add_child(top_lbl)
	for b in [["ARSENALE", _show_arsenal], ["REGOLE", _show_rules], ["DIARIO", _toggle_log], ["MENU", _confirm_menu]]:
		var bt := Button.new()
		bt.text = b[0]
		bt.custom_minimum_size = Vector2(118, 36)
		bt.add_theme_font_size_override("font_size", 19)
		bt.pressed.connect(b[1])
		hb.add_child(bt)
	# personaggi a sinistra
	var sc := ScrollContainer.new()
	sc.position = Vector2(8, 62)
	sc.size = Vector2(300, H - 62 - 250)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(sc)
	chars_box = VBoxContainer.new()
	chars_box.add_theme_constant_override("separation", 6)
	chars_box.custom_minimum_size = Vector2(290, 0)
	sc.add_child(chars_box)
	# pannello delle decisioni a destra
	dec_panel = PanelContainer.new()
	dec_panel.add_theme_stylebox_override("panel", UI.panel_style(Color("#0c100ee8"), UI.GOLD, 2, 8))
	dec_panel.position = Vector2(W - 470, 62)
	dec_panel.size = Vector2(460, 10)
	dec_panel.custom_minimum_size = Vector2(460, 0)
	hud.add_child(dec_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dec_panel.add_child(dv)
	dec_title = UI.label("", 24, UI.GOLD, UI.font_bold)
	dv.add_child(dec_title)
	dec_prompt = UI.rich(21)
	dec_prompt.custom_minimum_size = Vector2(436, 0)
	dv.add_child(dec_prompt)
	var osc := ScrollContainer.new()
	osc.custom_minimum_size = Vector2(440, 0)
	osc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	osc.name = "osc"
	dv.add_child(osc)
	dec_opts = VBoxContainer.new()
	dec_opts.add_theme_constant_override("separation", 5)
	dec_opts.custom_minimum_size = Vector2(430, 0)
	osc.add_child(dec_opts)
	dec_panel.visible = false
	waiting_lbl = UI.label("", 22, Color("#d8d0c0"), UI.font_italic)
	waiting_lbl.position = Vector2(W - 470, 66)
	waiting_lbl.size = Vector2(460, 30)
	waiting_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(waiting_lbl)
	# registro
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.panel_style(Color("#0b0e0cd0"), Color("#3a3a2a"), 1, 6))
	log_panel.position = Vector2(W - 470, H - 430)
	log_panel.size = Vector2(460, 180)
	hud.add_child(log_panel)
	var lsc := ScrollContainer.new()
	lsc.custom_minimum_size = Vector2(440, 160)
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(lsc)
	log_lbl = UI.rich(17)
	log_lbl.custom_minimum_size = Vector2(430, 0)
	lsc.add_child(log_lbl)
	log_lbl.resized.connect(func(): lsc.scroll_vertical = int(log_lbl.size.y))
	# mano in basso
	hand_tabs = HBoxContainer.new()
	hand_tabs.position = Vector2(320, H - 306)
	hand_tabs.add_theme_constant_override("separation", 6)
	hud.add_child(hand_tabs)
	var hsc := ScrollContainer.new()
	hsc.position = Vector2(316, H - 270)
	hsc.size = Vector2(W - 316 - 480, 266)
	hsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud.add_child(hsc)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 8)
	hsc.add_child(hand_box)
	hover_lbl = UI.label("", 20, Color("#f0e6c8"), UI.font_bold)
	hover_lbl.position = Vector2(320, 60)
	hover_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hover_lbl.add_theme_constant_override("outline_size", 6)
	hud.add_child(hover_lbl)
	toast_lbl = UI.label("", 30, Color("#ffe2a0"), UI.font_bold)
	toast_lbl.position = Vector2(320, 96)
	toast_lbl.size = Vector2(W - 800, 40)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	hud.add_child(toast_lbl)
	# ingrandimento delle carte
	zoom = TextureRect.new()
	zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zoom.size = Vector2(430, 602)
	zoom.position = Vector2(W - 920, H - 250 - 610)
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.visible = false
	hud.add_child(zoom)
	zoom_txt = UI.label("", 20, Color.WHITE, UI.font_bold)
	zoom_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zoom_txt.size = Vector2(430, 120)
	zoom_txt.position = zoom.position + Vector2(0, 600)
	zoom_txt.add_theme_color_override("font_outline_color", Color.BLACK)
	zoom_txt.add_theme_constant_override("outline_size", 6)
	zoom_txt.visible = false
	hud.add_child(zoom_txt)


## Il mouse sul tavolo: la vista è un Control a tutto schermo, quindi i clic e la rotella che non
## finiscono su un pannello arrivano qui (non in _unhandled_input) e si passano alla telecamera.
func _gui_input(ev: InputEvent) -> void:
	if is_instance_valid(pass_screen) or is_instance_valid(modal):
		return
	if table.handle_input(ev):
		accept_event()


## La tastiera (e il mouse se un giorno la vista non fosse più un Control che lo riceve).
func _unhandled_input(ev: InputEvent) -> void:
	if is_instance_valid(pass_screen) or is_instance_valid(modal):
		return
	if table.handle_input(ev):
		get_viewport().set_input_as_handled()


# ================================================================== aggiornamento

func _cur_view() -> Dictionary:
	if eng != null:
		return eng.view_for(team)
	return view


func _refresh() -> void:
	if is_instance_valid(pass_screen):
		return
	view = _cur_view()
	if view.is_empty():
		return
	table.update_view(view)
	_play_events()
	_refresh_top()
	_refresh_chars()
	_refresh_hand()
	_refresh_log()


func _on_remote_view(v: Dictionary, req: Dictionary, evs: Array) -> void:
	view = v
	_remote_events = evs
	table.update_view(view)
	_play_events()
	_refresh_top()
	_refresh_chars()
	_refresh_hand()
	_refresh_log()
	if not req.is_empty() and (pending.is_empty() or int(pending.get("n", -1)) != int(req.get("n", -2))):
		_present(req)
	elif req.is_empty() and not pending.is_empty():
		_clear_decision()
	if view.get("over", false) and not is_instance_valid(end_panel):
		_on_end(view.get("results", {}))


var _remote_events: Array = []

## Effetti visivi degli eventi pubblici nuovi.
func _play_events() -> void:
	var evs: Array = eng.events if eng != null else _remote_events
	if ev_seen > evs.size():
		ev_seen = 0
	while ev_seen < evs.size():
		var e: Dictionary = evs[ev_seen]
		ev_seen += 1
		match str(e.get("t", "")):
			"attack", "sattack":
				table.fx_ring(e["loc"])
				table.fx_text(e["loc"], "−%d" % int(e.get("dmg", 1)), Color("#ff6a4a"))
			"search":
				table.fx_ring(e["loc"], Color("#ffd36b") if not e["found"] else Color("#ff4030"))
				table.fx_text(e["loc"], "Trovata!" if e["found"] else "Niente", Color("#ffe9a0"))
			"reveal":
				table.fx_ring(e["loc"], Color("#ff3020"))
				table.fx_text(e["loc"], "RIVELATA", Color("#ff5040"))
				table.show_path(e.get("moves", []))
				_toast("%s si rivela!" % _char_name(int(e["ci"])))
			"death":
				table.fx_text(e["loc"], "✝", Color("#ffffff"))
			"check":
				for l in e.get("found", {}):
					table.fx_ring(l, Color("#f0b040"))
					table.fx_text(l, "Traccia!", Color("#f7c060"))
			"trap_fire":
				_toast("Scatta una trappola!")
			"dawn":
				_toast("Alba del giorno %d" % int(e["day"]))
			"night":
				_toast("Notte %d" % int(e["n"]))
			"seer":
				var txt := []
				for m in e.get("moves", []):
					txt.append(D.DIR_IT[m["dir"]] + (" (falsa)" if m["fake"] else ""))
				_toast("Ultima carta Movimento: " + ", ".join(txt))


func _char_name(i: int) -> String:
	for c in view.get("chars", []):
		if c["i"] == i:
			return c["name"]
	return "?"


func _refresh_top() -> void:
	var v := view
	var K: Dictionary = D.CONTRACTS[v["contract"]]
	var ph := {"setup": "Preparazione", "dawn": "Alba", "day": "Giorno", "night": "Notte", "end": "Fine"}.get(v["phase"], v["phase"])
	var t := "[b]%s[/b] · giorno %d · %s" % [K["n"], int(v["day"]), ph]
	var who := int(v.get("turn", -1))
	if who >= 0 and v["phase"] == "day":
		t += " · turno di [b]%s[/b]" % _char_name(who)
	t += " · Bestia [color=#ff8a70]%d/%d[/color]" % [int(v["beast_hp"]) - int(v["beast_wounds"]), int(v["beast_hp"])]
	if K.get("setup", {}).get("dominion", false):
		t += " · Dominio [color=#ff6a5a]rosso %d[/color] / [color=#6ad0ff]blu %d[/color] (12)" % [int(v["dom"]["red"]), int(v["dom"]["blue"])]
	if K.get("setup", {}).get("titan", false):
		t += " · segnalini sul contratto %d/3 · coloni %d" % [int(v["ctokens"]), v["settlers"].size()]
	if K.has("beast_wins_settlers"):
		t += " · coloni morti %d/%d" % [int(v["kills"].get("settler", 0)), int(K["beast_wins_settlers"])]
	var tn = {"H": "cacciatori", "B": "Bestia", "P": "spettatore"}[team]
	t += " · [i]vista: %s[/i]" % tn
	top_lbl.text = t


func _refresh_chars() -> void:
	for c in chars_box.get_children():
		c.queue_free()
	for c in view.get("chars", []):
		var p := PanelContainer.new()
		var active: bool = int(view.get("turn", -1)) == c["i"]
		p.add_theme_stylebox_override("panel", UI.panel_style(Color("#0c100ed8"), UI.team_col(c["side"]) if active else Color("#333a33"), 2 if active else 1, 6))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		p.add_child(hb)
		var sid: String = c["id"]
		if c.get("reborn", false):
			sid = "fk_reborn"
		var por := UI.icon_rect(UI.standee_tex(sid), Vector2(54, 74))
		hb.add_child(por)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		hb.add_child(vb)
		var hp: int
		var wounds: int
		if c["side"] == "B":
			hp = int(view["beast_hp"])
			wounds = int(view["beast_wounds"])
		else:
			hp = int(D.HUNTERS[c["id"]]["hp"])
			wounds = int(c["wounds"])
		var nm := UI.label("%s%s" % [c["name"], " ✝" if c["dead"] else ""], 21, UI.team_col(c["side"]).lightened(0.25), UI.font_bold)
		vb.add_child(nm)
		var info := "♥ %d/%d · rancori %d" % [hp - wounds, hp, int(c["grudges"])]
		if int(c["ap"]) > 0:
			info += " · poteri %d" % int(c["ap"])
		vb.add_child(UI.label(info, 17, Color("#d8d0c0")))
		var info2 := "carte %d (Azione %d)" % [int(c["hand_n"]), int(c["actions_n"])]
		if c["side"] == "B":
			info2 += " · " + ("rivelata" if c["revealed"] else "nascosta, %d mosse" % int(c["moves_n"]))
			if int(c.get("souls", -1)) >= 0:
				info2 += " · anime %d" % int(c["souls"])
		if int(c.get("blood", -1)) > 0:
			info2 += " · sangue %d" % int(c["blood"])
		if int(c.get("skip", 0)) > 0:
			info2 += " · salta il turno"
		vb.add_child(UI.label(info2, 16, Color("#a8a290")))
		var who := "IA" if c.get("ai", true) else str(c.get("player", ""))
		vb.add_child(UI.label(who if who != "" else "umano", 15, Color("#8a8676")))
		vb.add_child(_chips(c))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.tooltip_text = _upgrades_text(c)
		var ci: int = c["i"]
		p.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_show_board(ci))
		chars_box.add_child(p)


## Abilità e potenziamenti del personaggio, a colpo d'occhio:
##  - abilità pronte: bordo del colore della squadra; già usate oggi: spente con «usata»;
##    della Bestia ferme perché non è nel suo habitat: «bloccata» (lo vede solo chi conosce la posizione);
##  - potenziamenti sbloccati: ★ su fondo oro. Passa il mouse su una voce per il testo.
func _chips(c: Dictionary) -> Control:
	var fl := HFlowContainer.new()
	fl.custom_minimum_size = Vector2(214, 0)
	fl.add_theme_constant_override("h_separation", 4)
	fl.add_theme_constant_override("v_separation", 3)
	fl.mouse_filter = Control.MOUSE_FILTER_PASS
	var data: Dictionary = D.BEASTS[c["id"]] if c["side"] == "B" else D.HUNTERS[c["id"]]
	var used := {}
	for a in c.get("abil_disc", []):
		used[D.base_id(str(a))] = true
	var col := UI.team_col(c["side"])
	for aid in data.get("abil", []):
		var card := D.card(aid)
		var state := ""
		if used.has(aid):
			state = "usata"
		elif c["side"] == "B" and c.has("loc") and str(card.get("lock", "")) != "":
			var lk: String = card["lock"]
			if lk == "*":
				lk = str(data["hab"])
			if not _loc_habs(str(c["loc"])).has(lk):
				state = "bloccata"
		var txt := str(card.get("n", aid)) + ("" if state == "" else " · " + state)
		var tip := "%s\n%s" % [card.get("n", aid), card.get("t", card.get("bt", card.get("ht", "")))]
		if state == "usata":
			tip += "\n(già usata oggi: torna in mano di notte)"
		elif state == "bloccata":
			tip += "\n(si gioca solo in un luogo %s)" % D.HAB_IT.get(card["lock"] if card["lock"] != "*" else data["hab"], "")
		fl.add_child(_chip(txt, tip, Color("#151a17"), col if state == "" else Color("#3a3a36"), Color("#e8e2d0") if state == "" else Color("#77736a")))
	var ups: Dictionary = data.get("up", {})
	for u in c.get("upg", []):
		if ups.has(u):
			fl.add_child(_chip("★ " + str(ups[u][0]), "%s (potenziamento sbloccato)\n%s" % [ups[u][0], ups[u][3]], Color("#5a4718"), Color("#d8b25a"), Color("#fff1c8")))
	return fl


func _chip(text: String, tip: String, bg: Color, border: Color, fg: Color) -> Control:
	var pc := PanelContainer.new()
	var sb := UI.panel_style(bg, border, 1, 4)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	var lb := UI.label(text, 14, fg, UI.font_bold)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(lb)
	pc.tooltip_text = tip
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	return pc


func _loc_habs(l: String) -> Array:
	var tk: Dictionary = view.get("tokens", {})
	if tk.has(l):
		return ["swamp", "abyss"] if tk[l] == "abyss" else [tk[l]]
	var locs: Dictionary = D.MAPS[view.get("map", "lsi")]["locs"]
	return locs[l]["hab"] if locs.has(l) else []


func _upgrades_text(c: Dictionary) -> String:
	var tab: Dictionary = D.BEASTS[c["id"]]["up"] if c["side"] == "B" else D.HUNTERS[c["id"]]["up"]
	var lines := ["Potenziamenti (clic per la plancia):"]
	for u in tab:
		var on: bool = (c["upg"] as Array).has(u)
		lines.append("%s %s (%d): %s" % ["✔" if on else "·", tab[u][0], int(tab[u][1]), tab[u][3]])
	return "\n".join(lines)


func _refresh_log() -> void:
	var lines: Array = eng.log_lines.slice(max(0, eng.log_lines.size() - 60)) if eng != null else view.get("log", [])
	log_lbl.text = "\n".join(lines)


## Mano: le carte della propria squadra (i cacciatori possono mostrarsi le carte fra loro).
func _refresh_hand() -> void:
	for c in hand_tabs.get_children():
		c.queue_free()
	for c in hand_box.get_children():
		c.queue_free()
	var mine := []
	for c in view.get("chars", []):
		if c["side"] == team and c.has("hand"):
			mine.append(c)
	if mine.is_empty():
		return
	if not pending.is_empty() and pending.get("side", "") == team:
		hand_ci = int(pending["ci"])
	var ok := false
	for c in mine:
		if c["i"] == hand_ci:
			ok = true
	if not ok:
		hand_ci = mine[0]["i"]
	if mine.size() > 1:
		for c in mine:
			var b := Button.new()
			b.text = "%s (%d)" % [c["name"], c["hand"].size()]
			b.custom_minimum_size = Vector2(150, 32)
			b.add_theme_font_size_override("font_size", 18)
			if c["i"] == hand_ci:
				UI.primary(b)
			var ci: int = c["i"]
			b.pressed.connect(func():
				hand_ci = ci
				_refresh_hand())
			hand_tabs.add_child(b)
	var cur: Dictionary = {}
	for c in mine:
		if c["i"] == hand_ci:
			cur = c
	var playable := {}
	if not pending.is_empty() and int(pending["ci"]) == hand_ci:
		for o in pending.get("opts", []):
			if o.has("card"):
				if not playable.has(o["card"]):
					playable[o["card"]] = []
				playable[o["card"]].append(o)
	for cid in cur.get("hand", []):
		hand_box.add_child(_card_widget(cid, playable.get(cid, [])))


func _card_widget(cid: String, opts: Array) -> Control:
	var w := Control.new()
	w.custom_minimum_size = Vector2(184, 258)
	var t := UI.card_tex(cid)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(184, 258)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(r)
	if t == null:
		var l := UI.label(D.cname(cid), 18, Color.WHITE, UI.font_bold)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(172, 246)
		l.position = Vector2(6, 6)
		w.add_child(l)
	var frame := Panel.new()
	frame.size = Vector2(184, 258)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.panel_style(Color(0, 0, 0, 0), UI.GOLD if not opts.is_empty() else Color(0, 0, 0, 0), 3 if not opts.is_empty() else 0, 8))
	w.add_child(frame)
	if opts.is_empty() and not pending.is_empty():
		r.modulate = Color(0.72, 0.72, 0.72)
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.mouse_entered.connect(func():
		_show_zoom(t, _card_text(cid))
		w.position.y = -14)
	w.mouse_exited.connect(func():
		_hide_zoom()
		w.position.y = 0)
	w.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not opts.is_empty():
			if opts.size() == 1:
				_choose(opts[0]["id"])
			else:
				_pick_mode(cid, opts))
	return w


func _card_text(cid: String) -> String:
	var c := D.card(cid)
	var s := "%s" % c.get("n", cid)
	if c.has("ht"):
		if team == "B":
			s += "\nBestia: " + c["bt"]
		else:
			s += "\nCacciatori: " + c["ht"]
	elif c.has("t"):
		s += "\n" + str(c["t"])
	if c.has("ot"):
		s += "\nSovraccarica: " + str(c["ot"])
	if c.has("cht"):
		s += "\nCarica d'anime (%d): %s" % [int(c["ch"]), c["cht"]]
	if int(c.get("cost", 0)) > 0:
		s += "\nCosto: %d rancor%s" % [int(c["cost"]), "e" if int(c["cost"]) == 1 else "i"]
	return s


func _show_zoom(t: Texture2D, text: String) -> void:
	zoom.texture = t
	zoom.visible = t != null
	zoom_txt.text = text
	zoom_txt.visible = true


func _hide_zoom() -> void:
	zoom.visible = false
	zoom_txt.visible = false


func _pick_mode(cid: String, opts: Array) -> void:
	_modal_choice("Come giochi %s?" % D.cname(cid), opts)


func _toast(t: String) -> void:
	toast_lbl.text = t
	toast_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.8)


# ================================================================== decisioni

func _on_request(req: Dictionary) -> void:
	var side: String = req.get("side", "H")
	if humans.size() > 1 and side != team:
		await _pass_device(side)
	_present(req)


func _present(req: Dictionary) -> void:
	pending = req
	_refresh()
	dec_panel.visible = true
	waiting_lbl.text = ""
	var who := _char_name(int(req["ci"]))
	dec_title.text = who
	dec_title.add_theme_color_override("font_color", UI.team_col(req.get("side", "H")).lightened(0.2))
	dec_prompt.text = str(req.get("prompt", ""))
	for c in dec_opts.get_children():
		c.queue_free()
	var locs := []
	for o in req.get("opts", []):
		if o.has("loc") and str(o["id"]) != "stop":
			locs.append(o["loc"])
		var b := Button.new()
		b.text = UI.plain(str(o["label"]))
		b.custom_minimum_size = Vector2(420, 40)
		b.add_theme_font_size_override("font_size", 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if o.has("card"):
			var cid: String = o["card"]
			b.mouse_entered.connect(func(): _show_zoom(UI.card_tex(cid), _card_text(cid)))
			b.mouse_exited.connect(_hide_zoom)
		if o.has("loc"):
			var l: String = o["loc"]
			b.mouse_entered.connect(func(): table.fx_ring(l, Color("#ffe080")))
		var id = o["id"]
		b.pressed.connect(func(): _choose(id))
		dec_opts.add_child(b)
	var osc: ScrollContainer = dec_panel.find_child("osc", true, false)
	osc.custom_minimum_size.y = min(560.0, req.get("opts", []).size() * 45.0 + 6)
	table.set_highlights(locs, Color("#ffd36b") if req.get("side", "H") == "H" else Color("#ff7a50"))
	if req.get("type", "") in ["beast_step", "step", "loc", "summon_loc", "start"] and not locs.is_empty():
		pass


func _on_loc_clicked(l: String) -> void:
	if pending.is_empty():
		return
	for o in pending.get("opts", []):
		if str(o.get("loc", "")) == l and str(o["id"]) != "stop":
			_choose(o["id"])
			return


func _choose(id) -> void:
	if pending.is_empty():
		return
	var req := pending
	_clear_decision()
	if eng != null:
		eng.provide_decision(id)
	elif client != null:
		client.answer(req, id)


func _clear_decision() -> void:
	pending = {}
	dec_panel.visible = false
	table.set_highlights([])
	if is_instance_valid(modal):
		modal.queue_free()
	_hide_zoom()
	_refresh_hand()


func online_waiting(text: String) -> void:
	waiting_lbl.text = text


# ================================================================== schermate

## «Passa il dispositivo»: copre tutto finché la persona giusta non è davanti allo schermo.
func _pass_device(side: String, extra := "") -> void:
	_clear_overlay_for_pass()
	pass_screen = Control.new()
	pass_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pass_screen)
	var bg := ColorRect.new()
	bg.color = Color("#070908")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_screen.add_child(bg)
	var img := UI.icon_rect(UI.token_tex("trail_" + _first_beast_id()) if side == "B" else UI.token_tex("watchtower"), Vector2(220, 220))
	img.position = Vector2(size.x / 2 - 110, 210)
	pass_screen.add_child(img)
	var t := UI.title("PASSA IL DISPOSITIVO", 54)
	t.size = Vector2(size.x, 70)
	t.position = Vector2(0, 470)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_screen.add_child(t)
	var who := "alla BESTIA" if side == "B" else "ai CACCIATORI"
	var s := UI.label("Tocca %s. %s\nGli altri non guardano: lo schermo mostra la mano e i segreti di chi gioca." % [who, extra], 28, Color("#e0d6c0"))
	s.size = Vector2(size.x, 100)
	s.position = Vector2(0, 560)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pass_screen.add_child(s)
	var b := Button.new()
	b.text = "SONO %s: MOSTRA" % ("LA BESTIA" if side == "B" else "UN CACCIATORE")
	b.custom_minimum_size = Vector2(560, 80)
	b.add_theme_font_override("font", UI.font_title)
	b.add_theme_font_size_override("font_size", 30)
	UI.primary(b)
	b.position = Vector2(size.x / 2 - 280, 700)
	pass_screen.add_child(b)
	await b.pressed
	team = side
	pass_screen.queue_free()
	pass_screen = null
	_refresh()


func _clear_overlay_for_pass() -> void:
	_hide_zoom()
	if is_instance_valid(modal):
		modal.queue_free()


func _first_beast_id() -> String:
	for c in view.get("chars", []):
		if c["side"] == "B":
			return c["id"]
	return "bolgin"


func _modal_box(title_text: String, w := 900.0) -> VBoxContainer:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.72)
	sh.set_anchors_preset(Control.PRESET_FULL_RECT)
	sh.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			modal.queue_free())
	modal.add_child(sh)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d110ff4"), UI.GOLD, 2, 8))
	box.custom_minimum_size = Vector2(w, 0)
	box.position = Vector2((size.x - w) / 2, 70)
	modal.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)
	vb.add_child(UI.title(title_text, 32))
	return vb


func _modal_choice(title_text: String, opts: Array) -> void:
	var vb := _modal_box(title_text, 700)
	for o in opts:
		var b := Button.new()
		b.text = UI.plain(str(o["label"]))
		b.custom_minimum_size = Vector2(660, 50)
		var id = o["id"]
		b.pressed.connect(func():
			modal.queue_free()
			_choose(id))
		vb.add_child(b)


func _show_board(ci: int) -> void:
	var c: Dictionary = {}
	for x in view.get("chars", []):
		if x["i"] == ci:
			c = x
	if c.is_empty():
		return
	var key: String = (D.BEASTS[c["id"]] if c["side"] == "B" else D.HUNTERS[c["id"]])["board"]
	if c.get("reborn", false):
		key = D.BEASTS["fk"]["board2"]
	var vb := _modal_box("%s — %s" % [c["name"], (D.BEASTS[c["id"]] if c["side"] == "B" else D.HUNTERS[c["id"]])["sub"]], 1500)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var t := UI.board_tex(key)
	var r := UI.icon_rect(t, Vector2(820 if c["side"] == "H" else 520, 780))
	hb.add_child(r)
	var info := UI.rich(21)
	info.custom_minimum_size = Vector2(620, 0)
	var d: Dictionary = D.BEASTS[c["id"]] if c["side"] == "B" else D.HUNTERS[c["id"]]
	var s := "[i]%s[/i]\n\n" % d.get("lore", "")
	s += "[b]Abilità[/b]\n"
	for a in d["abil"]:
		var cd := D.card(a)
		s += "• [b]%s[/b]: %s\n" % [cd.get("n", a), cd.get("t", "")]
	s += "\n[b]Potenziamenti[/b]\n"
	for u in d["up"]:
		var on: bool = (c["upg"] as Array).has(u)
		s += "%s [b]%s[/b] (%d%s): %s\n" % ["[color=#7fd36f]✔[/color]" if on else "·", d["up"][u][0], int(d["up"][u][1]), ", subito" if d["up"][u][2] == "y" else "", d["up"][u][3]]
	if c["side"] == "B":
		var sm: Dictionary = D.SUMMONS[d["summon"]]
		s += "\n[b]Evocati: %s[/b] (fino a %d)\n%s: %s" % [sm["n"], int(d["ns"]), sm["an"], sm["at"]]
	info.text = s
	hb.add_child(info)


func _show_arsenal() -> void:
	var vb := _modal_box("ARSENALE E SCARTI", 1500)
	vb.add_child(UI.label("Oggetti del cacciatore scoperti", 24, UI.HUNTER_COL, UI.font_bold))
	var r1 := HBoxContainer.new()
	vb.add_child(r1)
	for c in view.get("item_up", []):
		r1.add_child(_card_widget(c, []))
	vb.add_child(UI.label("Talenti bestiali scoperti", 24, UI.BEAST_COL, UI.font_bold))
	var r2 := HBoxContainer.new()
	vb.add_child(r2)
	for c in view.get("talent_up", []):
		r2.add_child(_card_widget(c, []))
	vb.add_child(UI.label("Carte Azione scartate (informazione pubblica)", 24, UI.GOLD, UI.font_bold))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1440, 214)
	vb.add_child(sc)
	var r3 := HBoxContainer.new()
	sc.add_child(r3)
	for c in view.get("action_disc", []) + view.get("item_disc", []) + view.get("talent_disc", []):
		r3.add_child(_card_widget(c, []))
	var dk: Dictionary = view.get("decks", {})
	vb.add_child(UI.label("Mazzi: Oggetti %d · Talenti %d · Azioni inutilizzate %d · Poteri antichi nella riserva %d · trappole per zona %s" % [int(dk.get("item", 0)), int(dk.get("talent", 0)), int(dk.get("unused", 0)), int(view.get("ap_supply", 0)), str(view.get("traps_n", {}))], 20, Color("#cfc6b4")))


func _show_rules() -> void:
	var vb := _modal_box("REGOLE IN BREVE", 1300)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1260, 820)
	vb.add_child(sc)
	var r := UI.rich(21)
	r.custom_minimum_size = Vector2(1230, 0)
	r.text = RulesText.text(view.get("contract", "regent"))
	sc.add_child(r)


func _toggle_log() -> void:
	log_visible = not log_visible
	log_panel.visible = log_visible


func _confirm_menu() -> void:
	var vb := _modal_box("Tornare al menu?", 640)
	vb.add_child(UI.label("La partita in corso andrà persa (online si può rientrare con il codice).", 22, Color("#d8d0c0")))
	var b := Button.new()
	b.text = "SÌ, TORNA AL MENU"
	b.custom_minimum_size = Vector2(600, 56)
	b.pressed.connect(func():
		if eng != null:
			eng.abort = true
			eng.provide_decision(null)
		main.show_menu())
	vb.add_child(b)


func _on_end(res: Dictionary) -> void:
	if is_instance_valid(end_panel):
		return
	if server != null:
		server.finish()
	_clear_decision()
	team = "P" if eng != null else team
	if eng != null:
		view = eng.view_for("B")
		table.update_view(view)
	end_panel = Control.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_panel)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d110ff0"), UI.GOLD, 2, 10))
	box.position = Vector2(size.x / 2 - 430, 140)
	box.custom_minimum_size = Vector2(860, 0)
	end_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)
	var w: String = res.get("winner", "?")
	var t := UI.title("VINCE LA BESTIA" if w == "B" else "VINCONO I CACCIATORI", 52, UI.BEAST_COL if w == "B" else UI.HUNTER_COL)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var why := UI.label(str(res.get("why", "")), 28, Color.WHITE)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(why)
	var k: Dictionary = res.get("kills", {})
	var parts := []
	for x in ["farmer", "noble", "sheep", "boar", "sabertooth", "hunter"]:
		if int(k.get(x, 0)) > 0:
			parts.append("%s %d" % [{"farmer": "Contadini", "noble": "Nobili", "sheep": "Pecore", "boar": "Cinghiali", "sabertooth": "Tigri", "hunter": "Cacciatori"}[x], int(k[x])])
	var st := UI.label("Giorno %d · ferite della Bestia %d/%d · vittime della Bestia: %s" % [int(res.get("day", 0)), int(res.get("beast_wounds", 0)), int(res.get("beast_hp", 0)), ", ".join(parts) if not parts.is_empty() else "nessuna"], 22, Color("#d8d0c0"))
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(820, 0)
	vb.add_child(st)
	# verifica commit-reveal
	var evs: Array = eng.events if eng != null else _remote_events_all()
	var vr: Dictionary = BSVerify.run(evs, res.get("reveal", {}), D.CONTRACTS[view.get("contract", "regent")]["map"]) if not evs.is_empty() else {"ok": false, "errors": ["registro non disponibile"], "checked": 0}
	var vt := UI.label(("✔ Verifica superata: la Bestia ha giocato pulito (%d controlli sugli impegni salati e sulle tracce)." % int(vr["checked"])) if vr["ok"] else ("✘ Verifica NON superata: " + "; ".join(vr["errors"].slice(0, 3))), 22, UI.GREEN if vr["ok"] else UI.RED, UI.font_bold)
	vt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vt.custom_minimum_size = Vector2(820, 0)
	vb.add_child(vt)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var b := Button.new()
	b.text = "MENU"
	b.custom_minimum_size = Vector2(260, 60)
	UI.primary(b)
	b.pressed.connect(func(): main.show_menu())
	hb.add_child(b)
	var b3 := Button.new()
	b3.text = "RIVEDI LA PARTITA"
	b3.tooltip_text = "Replay continuo con la Bestia sempre visibile e il suo percorso sulla mappa."
	b3.custom_minimum_size = Vector2(300, 60)
	UI.primary(b3)
	b3.pressed.connect(func(): _replay_open(res, evs, box))
	hb.add_child(b3)
	var b2 := Button.new()
	b2.text = "GUARDA IL TAVOLO"
	b2.custom_minimum_size = Vector2(260, 60)
	b2.pressed.connect(func():
		box.visible = false
		_back_button(box))
	hb.add_child(b2)
	# percorso segreto della Bestia
	for e in res.get("reveal", {}).get("log", []):
		if e.has("moves"):
			table.show_path(e["moves"])


## Pulsante per tornare al riepilogo dopo «Guarda il tavolo».
func _back_button(box: Control) -> void:
	var bb := Button.new()
	bb.text = "RISULTATI"
	bb.custom_minimum_size = Vector2(200, 50)
	UI.primary(bb)
	bb.position = Vector2(size.x / 2 - 100, size.y - 300)
	end_panel.add_child(bb)
	bb.pressed.connect(func():
		box.visible = true
		bb.queue_free())


# ================================================================== replay

var rp_bar: Control
var rp_lbl: Label
var rp_steps: Array = []
var rp_i := 0
var rp_speed := 1.0
var rp_paused := false
var rp_run := 0                     # cambia a ogni avvio: ferma il ciclo precedente
var rp_pause_btn: Button
var rp_speed_btn: Button


func _replay_open(res: Dictionary, evs: Array, box: Control) -> void:
	var chars: Array = view.get("chars", [])
	rp_steps = BSReplay.build(evs, res.get("reveal", {}), D.CONTRACTS[view.get("contract", "regent")]["map"], chars)
	box.visible = false
	hud.visible = false
	table.reset_camera()
	rp_bar = PanelContainer.new()
	rp_bar.add_theme_stylebox_override("panel", UI.panel_style(Color("#0d110fe8"), UI.GOLD, 2, 10))
	rp_bar.position = Vector2(size.x / 2 - 470, size.y - 120)
	rp_bar.custom_minimum_size = Vector2(940, 0)
	end_panel.add_child(rp_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	rp_bar.add_child(hb)
	rp_lbl = UI.label("", 24, Color.WHITE, UI.font_bold)
	rp_lbl.custom_minimum_size = Vector2(300, 0)
	hb.add_child(rp_lbl)
	rp_pause_btn = _rp_button("PAUSA", func():
		rp_paused = not rp_paused
		rp_pause_btn.text = "RIPRENDI" if rp_paused else "PAUSA")
	hb.add_child(rp_pause_btn)
	rp_speed_btn = _rp_button("VELOCITÀ ×1", func():
		rp_speed = {1.0: 2.0, 2.0: 4.0, 4.0: 0.5, 0.5: 1.0}.get(rp_speed, 1.0)
		rp_speed_btn.text = "VELOCITÀ ×%s" % (str(int(rp_speed)) if rp_speed >= 1.0 else "½"))
	hb.add_child(rp_speed_btn)
	hb.add_child(_rp_button("RICOMINCIA", func(): _replay_play()))
	hb.add_child(_rp_button("CHIUDI", func(): _replay_close(box)))
	_replay_play()


func _rp_progress() -> float:
	return float(rp_i) / max(1, rp_steps.size())


func _rp_button(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(140, 52)
	b.pressed.connect(f)
	return b


func _replay_close(box: Control) -> void:
	rp_run += 1
	table.replay_stop()
	if is_instance_valid(rp_bar):
		rp_bar.queue_free()
	hud.visible = true
	box.visible = true


## Il replay scorre senza fermarsi ai turni: i passi si susseguono, ognuno con una breve animazione.
func _replay_play() -> void:
	rp_run += 1
	var run := rp_run
	rp_paused = false
	if is_instance_valid(rp_pause_btn):
		rp_pause_btn.text = "PAUSA"
	table.replay_start()
	rp_i = 0
	var day_txt := "Inizio"
	var n := rp_steps.size()
	for i in range(n):
		while rp_paused and run == rp_run:
			await get_tree().create_timer(0.1).timeout
		if run != rp_run or not is_inside_tree():
			return
		var st: Dictionary = rp_steps[i]
		var wait := 0.0
		match str(st["k"]):
			"add":
				table.rp_add(st["key"], st["piece"], st["loc"], 0.25 / rp_speed)
				wait = 0.08
			"move":
				var beast := int(st.get("beast", -1))
				wait = (0.55 if beast >= 0 else 0.32)
				table.rp_move(st["key"], st["to"], wait / rp_speed, beast)
			"jump":
				table.rp_move(st["key"], st["to"], 0.4 / rp_speed, -1, true)
				wait = 0.4
			"del":
				table.rp_del(st["key"], 0.35 / rp_speed)
				wait = 0.2
			"fx":
				table.fx_ring(st["loc"], Color(st["col"]))
				table.fx_text(st["loc"], st["text"], Color(st["col"]))
				wait = 0.3
			"day":
				day_txt = st["text"]
				wait = 0.6
		rp_i = i + 1
		if is_instance_valid(rp_lbl):
			rp_lbl.text = "%s · %d%%" % [day_txt, int(100.0 * (i + 1) / max(1, n))]
		if wait > 0.0:
			await get_tree().create_timer(wait / rp_speed).timeout


func _remote_events_all() -> Array:
	return client.all_events() if client != null else []
