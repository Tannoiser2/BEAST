class_name BSEngine
extends BSFx
## Motore delle regole di BEAST + SHATTERED ISLES: preparazione, Alba (draft), Giorno (turni),
## Notte (ricompense del contratto, riordino, cure, potenziamenti) e fine della partita.
## Nessuna dipendenza dall'interfaccia: ogni scelta passa da `decide()`.


# ================================================================== preparazione

## config: {
##   contract: "regent" | "brave" | "titan",
##   beasts: ["bolgin", …], hunters: ["assar", …],
##   ctrl: [{ai: bool, level: 0-2, who: nome, player: n}, …]  (uno per personaggio: prima le Bestie),
##   seed: int }
func setup(config: Dictionary) -> void:
	if config.has("seed"):
		seed_used = int(config["seed"])
	else:
		seed_used = randi()
	rng.seed = seed_used
	salt = str(config.get("salt", ""))
	if salt == "":
		salt = Crypto.new().generate_random_bytes(16).hex_encode()
	contract_id = str(config.get("contract", "regent"))
	K = D.CONTRACTS[contract_id]
	M = D.MAPS[K["map"]].duplicate()
	M["id"] = K["map"]
	LOCS = M["locs"]
	var bs: Array = config.get("beasts", ["bolgin"])
	var hs: Array = config.get("hunters", ["assar", "iona"])
	nb = bs.size()
	var ctrl: Array = config.get("ctrl", [])
	ch.clear()
	ais.clear()
	var idx := 0
	for b in bs:
		var d: Dictionary = D.BEASTS[b]
		var c := {"id": b, "name": d["n"], "side": "B", "loc": center(), "standee": center(), "revealed": true, "moves": [],
			"hand": d["abil"].duplicate(), "abil_disc": [], "grudges": 0, "ap": 0, "upg": {}, "dead": false, "wounds": 0}
		if d.has("souls"):
			c["souls"] = int(d["souls"])
			c["drained"] = 0
			c["on_map"] = 0
		if d.get("abyss", false):
			c["abyss"] = true
		ch.append(c)
	for h in hs:
		var d2: Dictionary = D.HUNTERS[h]
		var hand := []
		for a in d2["abil"]:
			hand.append(a)
		var c2 := {"id": h, "name": d2["n"], "side": "H", "loc": "", "hand": hand, "abil_disc": [], "grudges": 0, "ap": 0,
			"upg": {}, "dead": false, "wounds": 0, "skip": 0, "armor": 0, "blood": 0 if d2.get("blood", false) else -1}
		if d2.get("companion", false):
			c2["companion"] = true
		ch.append(c2)
	for i in range(ch.size()):
		var cc: Dictionary = ctrl[i] if i < ctrl.size() else {"ai": true, "level": 1}
		ch[i]["ctrl"] = {"ai": bool(cc.get("ai", true)), "level": int(cc.get("level", 1)), "who": str(cc.get("who", "")), "player": int(cc.get("player", i))}
		var a := BSAI.new()
		a.level = ch[i]["ctrl"]["level"]
		a.rng.seed = seed_used * 7 + i * 131 + 17
		ais[i] = a
	order = range(ch.size())
	# partecipanti al draft: una persona per giocatore (in 2 giocatori un umano ha due cacciatori)
	participants.clear()
	var by_player := {}
	for i in range(ch.size()):
		var p: int = ch[i]["ctrl"]["player"]
		if not by_player.has(p):
			by_player[p] = []
			participants.append({"chars": by_player[p], "pick": 1})
		by_player[p].append(i)
	for p in participants:
		p["pick"] = p["chars"].size()
	n_players = participants.size()
	# salute della Bestia (in 5 giocatori: riserva comune = somma − 2)
	beast_hp = 0
	for b in bs:
		beast_hp += int(D.BEASTS[b]["hp"])
	if nb > 1:
		beast_hp -= 2
	beast_wounds = 0
	# mappa
	tokens.clear()
	animals.clear()
	settlers.clear()
	summons.clear()
	towers.clear()
	trails.clear()
	traps.clear()
	ruins.clear()
	for l in LOCS:
		var L: Dictionary = LOCS[l]
		if L.has("animal"):
			animals.append({"id": new_id(), "kind": L["animal"], "loc": l, "wounds": 0, "armor": 0})
		if L.has("settler"):
			settlers.append({"id": new_id(), "kind": L["settler"], "loc": l, "wounds": 0, "armor": 0, "start": l})
		if L.has("ruin"):
			ruins[L["ruin"]] = ""
	# mazzi
	action_deck = D.action_deck()
	item_deck = D.item_deck()
	talent_deck = D.talent_deck()
	shuffle(action_deck)
	shuffle(item_deck)
	shuffle(talent_deck)
	unused = []
	action_disc = []
	item_disc = []
	talent_disc = []
	_refill_arsenal()
	ap_supply = 3
	day = 0
	night_no = 0
	kills = {}
	dom = {"red": 0, "blue": 0}
	log_msg("[b]%s[/b] — %s." % [K["n"], M["name"]])


func _refill_arsenal() -> void:
	item_disc.append_array(item_up)
	talent_disc.append_array(talent_up)
	item_up.clear()
	talent_up.clear()
	for i in range(3 + arsenal_extra):
		if item_deck.is_empty() and not item_disc.is_empty():
			item_deck.append_array(item_disc)
			item_disc.clear()
			shuffle(item_deck)
		if not item_deck.is_empty():
			item_up.append(item_deck.pop_back())
	for i in range(3):
		if talent_deck.is_empty() and not talent_disc.is_empty():
			talent_deck.append_array(talent_disc)
			talent_disc.clear()
			shuffle(talent_deck)
		if not talent_deck.is_empty():
			talent_up.append(talent_deck.pop_back())


# ================================================================== partita

func run() -> void:
	await initial_setup()
	while not game_over and not abort:
		await dawn()
		if game_over or abort:
			break
		await day_phase()
		if game_over or abort:
			break
		await night()
	changed.emit()


func initial_setup() -> void:
	phase = "setup"
	var st: Dictionary = K.get("setup", {})
	for b in beasts():
		if int(st.get("beast_grudge", 0)) > 0:
			ch[b]["grudges"] = int(st["beast_grudge"])
		if st.has("beast_talent"):
			for c in talent_deck.duplicate():
				if D.base_id(c) == st["beast_talent"]:
					talent_deck.erase(c)
					ch[b]["hand"].append(c)
					break
	for h in hunters():
		ch[h]["grudges"] = int(st.get("hunter_grudge", 0))
	if st.get("titan", false):
		await _titan_setup()
	await _extra_setup(st)
	if st.get("beast_summon", false):
		for b in beasts():
			await place_summon(b, summon_spots(b))
	ev({"t": "setup", "commit": BSState.salt_commit(salt)})
	# disposizione iniziale (pubblica) di animali e coloni: serve al replay di fine partita
	ev({"t": "board",
		"animals": animals.map(func(a): return {"id": a["id"], "kind": a["kind"], "loc": a["loc"]}),
		"settlers": settlers.map(func(x): return {"id": x["id"], "kind": x["kind"], "loc": x["loc"]})})
	changed.emit()
	# la Bestia parte dal centro e muove di due passi con le carte Movimento
	for b in beasts():
		ch[b]["revealed"] = false
		log_msg("%s parte dal centro della mappa e si muove di nascosto." % cname(b))
		await beast_move(b, 2, {"label": "Mossa iniziale"})
	# i cacciatori scelgono un insediamento
	for h in hunters():
		var l := ""
		if st.get("titan", false):
			l = _titan_loc()
		else:
			l = await pick_loc(h, "%s: in quale insediamento inizi?" % cname(h), settlements(), false, "start")
		ch[h]["loc"] = l
		ev({"t": "hplace", "ci": h, "to": l})
		log_msg("%s inizia in %s." % [cname(h), loc_label(l)])
	await refresh_trails()
	changed.emit()


func _titan_loc() -> String:
	for l in LOCS:
		if LOCS[l].get("name", "") == "titan":
			return l
	return settlements()[0]


func _titan_setup() -> void:
	settlers.clear()
	var t := _titan_loc()
	settlers.append({"id": new_id(), "kind": "noble", "loc": t, "wounds": 0, "armor": 0, "start": t})
	settlers.append({"id": new_id(), "kind": "farmer", "loc": t, "wounds": 0, "armor": 0, "start": t})
	for l in LOCS:
		var nm: String = LOCS[l].get("name", "")
		if nm in ["east_camp", "aurelia", "elysara"]:
			var opts := []
			for b in beasts():
				var h := beast_hab(b)
				if not opts.any(func(o): return o["id"] == h):
					opts.append({"id": h, "label": D.HAB_IT[h].capitalize()})
			var r = await decide(0, {"type": "choice", "prompt": "Titan: %s diventa…" % loc_label(l), "opts": opts, "ask_single": true})
			tokens[l] = str(r)
			titan_hab[l] = str(r)
			protected.append(l)
			ev({"t": "tf", "loc": l, "hab": str(r)})


# ================================================================== Alba

func dawn() -> void:
	day += 1
	phase = "dawn"
	deaths_today = 0
	flags.erase("yagi_bonus_day")
	for h in hunters():
		ch[h]["predicted"] = false
		ch[h]["resonated"] = false
	ev({"t": "dawn", "day": day})
	log_msg("[b]— Alba del giorno %d —[/b]" % day)
	changed.emit()
	for b in beasts():
		if has_up(b, "cloudshift") and not ch[b]["moves"].is_empty() and await yesno(b, "Nubi mutevoli: rivelare l'ultima carta Movimento per muovere di 1 passo?"):
			await reveal_last_moves(b, 1)
			await beast_move(b, 1)
	await draft()
	if game_over:
		return
	# effetti «dopo l'Alba»
	for b in beasts():
		if has_up(b, "drowner"):
			var t := await pick_loc(b, "Annegatrice: trasformare un luogo vicino?", nearby(ch[b]["loc"]), true)
			if t != "":
				await transform(t, b)
				if has_up(b, "torrential"):
					await beast_move(b, 1, {"label": "Torrenziale"})
		if has_up(b, "soul_harvest_v") and int(ch[b].get("drained", 0)) > 0:
			ch[b]["drained"] -= 1
			ch[b]["souls"] += 1
			log_msg("Mietitura d'anime: un'anima torna attiva.")
			await souls_returned(b)
		if flags.get("mesmerise", -1) == b:
			flags.erase("mesmerise")
			var o := []
			for h in alive_hunters():
				o.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
			if not o.is_empty():
				var h2 := int(str(await decide(b, {"type": "hunter", "prompt": "Ipnotizzare: quale cacciatore controlli nel suo prossimo turno?", "opts": o})))
				ch[h2]["mesmerised_by"] = b
				log_msg("[b]%s è ipnotizzato![/b]" % cname(h2))
	for h in alive_hunters():
		if has_up(h, "crepuscular"):
			await hunter_move(h, 1, {"may": true, "label": "Crepuscolare: %s" % cname(h)})
		if has_up(h, "extract"):
			await hunter_move(h, 1, {"may": true, "label": "Estrarre: %s" % cname(h)})
			ch[h]["blood"] = mini(4, int(ch[h]["blood"]) + 1)
		if has_up(h, "tormenting_visions") and not unused.is_empty() and await yesno(h, "Visioni tormentose: subire 1 ferita per prendere una carta Azione inutilizzata?"):
			await damage({"t": "hunter", "ci": h}, 1, {"kind": "effect"})
			if not ch[h]["dead"]:
				ch[h]["hand"].append(unused.pop_at(rng.randi_range(0, unused.size() - 1)))
		if ch[h].get("companion", false) and companion == "" and await yesno(h, "Mettere Fylgja nel tuo luogo?"):
			companion = ch[h]["loc"]
			ev({"t": "cmove", "to": companion})
			await refresh_trails()
		if has_up(h, "resonance"):
			var o2 := []
			for x in alive_hunters():
				if x != h:
					o2.append({"id": str(x), "label": cname(x)})
			if not o2.is_empty():
				ch[h]["resonance_target"] = int(str(await decide(h, {"type": "hunter", "prompt": "Risonanza: quale cacciatore copi oggi?", "opts": o2})))
	changed.emit()


## Draft delle carte Azione (regole di Shattered Isles).
func draft() -> void:
	# tutte le carte Azione tornano nel mazzo e si mescolano
	action_deck = D.action_deck()
	for c in ch:
		for x in c["hand"]:
			if D.kind(x) == "action":
				action_deck.erase(x)
	shuffle(action_deck)
	action_disc.clear()
	unused.clear()
	var deal := {2: 6, 3: 5, 4: 4, 5: 4}.get(n_players, 4)
	var aside := ""
	if n_players == 4:
		aside = action_deck.pop_back()
	var packs := []
	var picked := []
	for p in participants:
		var pk := []
		for i in range(deal):
			if not action_deck.is_empty():
				pk.append(action_deck.pop_back())
		packs.append(pk)
		picked.append([])
	if aside != "":
		var bp := _participant_of(0)
		var b0: int = participants[bp]["chars"][0]
		ev({"t": "aside", "ci": b0})
		log_msg("La Bestia mette da parte una carta Azione.")
	unused = action_deck.duplicate()
	action_deck.clear()
	ev({"t": "draft_start", "deal": deal})
	log_msg("Draft: %d carte Azione a testa." % deal)
	var guard := 0
	while packs.any(func(pk): return not pk.is_empty()) and guard < 50 and not game_over:
		guard += 1
		for i in range(participants.size()):
			var p: Dictionary = participants[i]
			var who: int = p["chars"][0]
			for k in range(int(p["pick"])):
				if packs[i].is_empty():
					break
				var opts := []
				for c in packs[i]:
					opts.append({"id": c, "label": D.cname(c), "card": c})
				var r = await decide(who, {"type": "draft", "prompt": "Draft: scegli una carta da tenere (%d nel pacchetto)" % packs[i].size(), "opts": opts, "secret": true, "pack": packs[i].duplicate(), "kept": picked[i].duplicate(), "ask_single": true})
				packs[i].erase(str(r))
				picked[i].append(str(r))
		# i pacchetti passano in senso orario
		var last = packs.pop_back()
		packs.push_front(last)
	# assegnazione delle carte
	for i in range(participants.size()):
		var p: Dictionary = participants[i]
		if p["chars"].size() == 1:
			ch[p["chars"][0]]["hand"].append_array(picked[i])
		else:
			# un giocatore con due cacciatori divide le carte a metà
			var a: int = p["chars"][0]
			var b: int = p["chars"][1]
			var half := int(picked[i].size() / 2)
			for c in picked[i]:
				var na = ch[a]["hand"].filter(func(x): return D.kind(x) == "action").size()
				var nbb = ch[b]["hand"].filter(func(x): return D.kind(x) == "action").size()
				var to := a
				if na >= half:
					to = b
				elif nbb < half:
					var r2 = await decide(a, {"type": "assign", "prompt": "A chi va %s?" % D.cname(c), "opts": [{"id": str(a), "label": cname(a)}, {"id": str(b), "label": cname(b)}], "secret": true, "card": c, "ask_single": true})
					to = int(str(r2))
				ch[to]["hand"].append(c)
	if aside != "":
		ch[0]["hand"].append(aside)
	match n_players:
		2:
			for i in range(3):
				if not unused.is_empty():
					action_disc.append(unused.pop_back())
			log_msg("Si scartano 3 carte inutilizzate.")
		3, 4:
			for i in range(participants.size()):
				for c2 in participants[i]["chars"]:
					await _draft_discard(c2, false)
		5:
			for i in range(participants.size()):
				for c3 in participants[i]["chars"]:
					await _draft_discard(c3, true)
	ev({"t": "draft_end"})
	changed.emit()


func _participant_of(ci: int) -> int:
	for i in range(participants.size()):
		if participants[i]["chars"].has(ci):
			return i
	return 0


func _draft_discard(ci: int, to_unused: bool) -> void:
	var acts: Array = ch[ci]["hand"].filter(func(x): return D.kind(x) == "action")
	if acts.is_empty():
		return
	var opts := []
	for c in acts:
		opts.append({"id": c, "label": D.cname(c), "card": c})
	var pr := "Rimetti coperta fra le inutilizzate una carta Azione" if to_unused else "Scarta una carta Azione"
	var r = await decide(ci, {"type": "draft_discard", "prompt": pr, "opts": opts, "secret": to_unused, "ask_single": true})
	ch[ci]["hand"].erase(str(r))
	if to_unused:
		unused.append(str(r))
	else:
		action_disc.append(str(r))
		log_msg("%s scarta %s." % [cname(ci), D.cname(str(r))])


# ================================================================== Giorno

func day_phase() -> void:
	phase = "day"
	ev({"t": "day", "day": day})
	log_msg("[b]— Giorno %d —[/b]" % day)
	changed.emit()
	var extra := {"extra": []}
	await offer_reaction("day_start", extra)
	for h in extra["extra"]:
		if not ch[h]["dead"] and not game_over:
			log_msg("%s gioca prima della Bestia." % cname(h))
			await take_turn(h, true)
	var consec := 0
	var idx := 0
	var guard := 0
	while consec < order.size() and not game_over and not abort and guard < 400:
		guard += 1
		var ci: int = order[idx]
		var r := await take_turn(ci)
		if is_beast(ci):
			await beast_turn_end(ci)
		if game_over:
			return
		if ch[ci].get("mesmerised_by", -1) >= 0:
			ch[ci]["mesmerised_by"] = -1
			r = await take_turn(ci)
		consec = consec + 1 if r == "pass" else 0
		idx = (idx + 1) % order.size()
	turn_ci = -1


func can_pass(ci: int) -> bool:
	var mine := n_actions(ci)
	for i in range(ch.size()):
		if i == ci or ch[i]["dead"]:
			continue
		if n_actions(i) < mine:
			return false
	return true


## Un turno: giocare carte (fino a una rossa e una blu), Fuggire o Passare.
func take_turn(ci: int, single := false) -> String:
	turn_ci = ci
	var c: Dictionary = ch[ci]
	if c["dead"]:
		return "pass"
	ev({"t": "turn", "ci": ci})
	changed.emit()
	if int(c.get("skip", 0)) > 0:
		c["skip"] -= 1
		log_msg("%s salta il turno." % cname(ci))
		return "pass"
	await turn_start(ci)
	if game_over or c["dead"]:
		return "pass"
	var red_free := true
	var blue_free := true
	var played := false
	while not game_over and not c["dead"]:
		var opts := []
		for cid in c["hand"]:
			for m in card_modes(ci, cid, red_free, blue_free):
				opts.append({"id": "play|%s|%s" % [cid, m], "label": mode_label(cid, m), "card": cid, "mode": m})
		if not played:
			if not c["hand"].is_empty():
				opts.append({"id": "flee", "label": "Fuggi: scarta una carta per muovere di 1 passo"})
			if can_pass(ci) or opts.is_empty():
				opts.append({"id": "pass", "label": "Passa"})
		else:
			opts.append({"id": "end", "label": "Termina il turno"})
		var pr := "Il tuo turno: gioca una carta, fuggi o passa" if not played else "Puoi giocare una carta %s" % ("blu" if blue_free else "rossa")
		var r = await decide(ci, {"type": "turn", "prompt": pr, "opts": opts, "ask_single": true, "red_free": red_free, "blue_free": blue_free, "secret": is_beast(ci)})
		var s := str(r)
		if s == "pass":
			log_msg("%s passa." % cname(ci))
			ev({"t": "pass", "ci": ci})
			return "pass"
		if s == "end":
			break
		if s == "flee":
			await flee(ci)
			played = true
			break
		var parts := s.split("|")
		var cid2 := parts[1]
		var m2 := parts[2]
		if m2.begins_with("C"):
			m2 = m2.substr(1) if m2.length() > 1 else m2
		match parts[2]:
			"R", "CR":
				red_free = false
			"B", "CB":
				blue_free = false
			"O":
				red_free = false
				blue_free = false
		played = true
		await play_card(ci, cid2, parts[2])
		if single or (not red_free and not blue_free):
			break
	if not is_beast(ci) and not game_over:
		await offer_reaction("hunter_turn_end", {"ci": ci})
	changed.emit()
	return "act"


func flee(ci: int) -> void:
	var opts := []
	for cid in ch[ci]["hand"]:
		opts.append({"id": cid, "label": D.cname(cid), "card": cid})
	var r = await decide(ci, {"type": "discard", "prompt": "Fuga: quale carta scartare?", "opts": opts, "ask_single": true, "secret": is_beast(ci)})
	ch[ci]["hand"].erase(str(r))
	_discard_card(ci, str(r))
	ev({"t": "flee", "ci": ci})
	log_msg("%s fugge." % cname(ci))
	if is_beast(ci):
		await beast_move(ci, 1)
	else:
		await hunter_move(ci, 1)


## Inizio del turno: Rovine, Rifugio, Passo del vuoto, segnalini della Titan.
func turn_start(ci: int) -> void:
	var c: Dictionary = ch[ci]
	await claim_ruins_at_turn_start(ci)
	if is_beast(ci):
		if has_up(ci, "void_step") and is_abyss(c["loc"]) and await yesno(ci, "Passo del vuoto: muovere di 1 passo?"):
			await beast_move(ci, 1)
	else:
		for h in hunters():
			if has_up(h, "refuge") and towers.has(c["loc"]) and c["wounds"] > 0:
				heal({"t": "hunter", "ci": ci}, 1)
				log_msg("Rifugio: %s recupera 1 ferita sulla torre." % cname(ci))
				break
		if K.get("setup", {}).get("titan", false):
			for l in titan_hab.keys():
				if not settlers_at(l).is_empty():
					titan_hab.erase(l)
					tokens.erase(l)
					contract_tokens += 1
					ev({"t": "ctoken", "loc": l, "n": contract_tokens})
					log_msg("[b]Un colono ha raggiunto %s: segnalino sul contratto (%d/3).[/b]" % [loc_label(l), contract_tokens])
					await check_contract_end()


# ================================================================== Notte

func night() -> void:
	phase = "night"
	night_no += 1
	ev({"t": "night", "n": night_no})
	log_msg("[b]— Notte %d —[/b]" % night_no)
	changed.emit()
	var nights: Array = K["nights"]
	if night_no > nights.size():
		# Notte finale
		var w: String = "H" if K["final"] == "hunters" else "B"
		await end_game(w, "È arrivata la Notte finale.")
		return
	var N: Dictionary = nights[night_no - 1]
	# 1. ricompense del contratto: prima la Bestia, poi i cacciatori
	if req_met(N["b_req"], "B"):
		log_msg("Ricompensa della Bestia: %s" % N["b_rw_t"])
		ev({"t": "reward", "team": "B", "night": night_no})
		for b in beasts():
			if not ch[b]["dead"]:
				await run_ops(b, N["b_rw"], {"card": "night", "night": night_no})
	else:
		log_msg("La Bestia non ottiene la ricompensa (%s)." % N["b_req_t"])
	if game_over:
		return
	if req_met(N["h_req"], "H"):
		log_msg("Ricompensa dei cacciatori: %s" % N["h_rw_t"])
		ev({"t": "reward", "team": "H", "night": night_no})
		for h in alive_hunters():
			await run_ops(h, N["h_rw"], {"card": "night", "night": night_no})
	else:
		log_msg("I cacciatori non ottengono la ricompensa (%s)." % N["h_req_t"])
	if game_over:
		return
	# 2. scarti e riordino
	for i in range(ch.size()):
		var c: Dictionary = ch[i]
		for x in c["hand"].duplicate():
			if D.kind(x) == "action":
				c["hand"].erase(x)
				action_disc.append(x)
		c["hand"].append_array(c["abil_disc"])
		c["abil_disc"] = []
	_refill_arsenal()
	# 3. cure: animali e coloni guariscono, i cacciatori morti tornano in un insediamento
	for a in animals:
		a["wounds"] = 0
	for s in settlers:
		s["wounds"] = 0
	for h in hunters():
		if ch[h]["dead"]:
			ch[h]["dead"] = false
			ch[h]["wounds"] = 0
			var l := await pick_loc(h, "%s torna in gioco: in quale insediamento?" % cname(h), settlements(), false, "start")
			ch[h]["loc"] = l
			ev({"t": "hplace", "ci": h, "to": l})
			log_msg("%s torna in gioco in %s." % [cname(h), loc_label(l)])
	await refresh_trails()
	# 4. potenziamenti: prima la Bestia
	for b in beasts():
		await buy_upgrades(b, 99, 0)
	for h in alive_hunters():
		await buy_upgrades(h, 99, 0)
	for b in beasts():
		if ch[b].get("reborn", false):
			var pool := unused + action_disc
			if not pool.is_empty():
				var c2: String = pool[rng.randi_range(0, pool.size() - 1)]
				unused.erase(c2)
				action_disc.erase(c2)
				ch[b]["hand"].append(c2)
				log_msg("Collezionista d'anime: il Re Piumato tiene una carta Azione.")
	changed.emit()


## Requisiti del contratto (basta un'alternativa).
func req_met(alts: Array, team: String) -> bool:
	for alt in alts:
		var ok := true
		for k in alt:
			var need := int(alt[k])
			var have := 0
			match k:
				"kill_sheep":
					have = int(kills.get("sheep", 0))
				"kill_sabertooth":
					have = int(kills.get("sabertooth", 0))
				"kill_boar":
					have = int(kills.get("boar", 0))
				"kill_settler":
					have = int(kills.get("settler", 0))
				"kill_farmer":
					have = int(kills.get("farmer", 0))
				"kill_noble":
					have = int(kills.get("noble", 0))
				"ruins":
					have = ruins_of(team)
				"beast_dmg":
					have = beast_dmg
				"dom_blue":
					have = int(dom["blue"])
				"tokens":
					have = contract_tokens
				"no_settler_dead":
					have = 1 if int(kills.get("settler_any", 0)) == 0 else 0
				"no_hunter_died":
					have = 1 if int(kills.get("hunter_any", 0)) == 0 else 0
				_:
					if k.begins_with("kill_settler_in_"):
						have = int(kills.get("settler_in_" + k.substr(16), 0))
					elif k.begins_with("start_alive_"):
						have = 1 if _start_settler_alive(k.substr(12)) else 0
					elif k.begins_with("settler_in_"):
						have = settlers.filter(func(s): return zone_of(s["loc"]) == k.substr(11)).size()
			if have < need:
				ok = false
		if ok:
			return true
	return false


## Operazioni speciali delle ricompense dei contratti.
func run_special(ci: int, op: Array, ctx: Dictionary) -> void:
	var k: String = op[0]
	match k:
		"noble_to_farmer":
			var ns: Array = settlers.filter(func(s): return s["kind"] == "noble")
			if not ns.is_empty():
				var o := []
				for s in ns:
					o.append({"id": str(s["id"]), "label": "Nobile in " + loc_label(s["loc"]), "loc": s["loc"]})
				var s2 := find_obj(settlers, int(str(await decide(ci, {"type": "settler", "prompt": "Quale Nobile diventa Contadino?", "opts": o}))))
				s2["kind"] = "farmer"
				s2["wounds"] = mini(int(s2["wounds"]), 1)
				ev({"t": "skind", "id": s2["id"], "kind": "farmer"})
				log_msg("Un Nobile diventa Contadino.")
		"dom_per_ruin":
			var n := ruins_of(side(ci))
			if n > 0:
				await dominion(op[1], n, "Rovine controllate")
		"dom_per_ruin_once":
			var key := "dom_once_%d" % night_no
			if not flags.get(key, false):
				flags[key] = true
				var n2 := ruins_of("H")
				if n2 > 0:
					await dominion(op[1], n2, "Rovine controllate")
		"arsenal_plus":
			if not flags.get("arsenal_plus", false):
				flags["arsenal_plus"] = true
				arsenal_extra = 1
		"talent_per_ruin":
			for i in range(ruins_of("B")):
				await gain_talent(ci)
		"tf_near_settlement":
			var t := await pick_loc(ci, "%s: trasformare un luogo vicino in insediamento?" % cname(ci), nearby(ch[ci]["loc"], "settlement"), true)
			if t != "":
				await transform(t, ci)
		"settlers_mv1_once":
			var key2 := "smv_%d" % night_no
			if not flags.get(key2, false):
				flags[key2] = true
				for s in settlers.duplicate():
					await settler_step(ci, s, "Il colono può muovere di 1 passo")
		"two_hunters_mv1":
			var moved := 0
			for h in alive_hunters():
				if moved >= 2:
					break
				if await hunter_move(h, 1, {"may": true, "label": "Rupi degli Yagi: %s" % cname(h)}) > 0:
					moved += 1
		"all_mv1":
			for h in alive_hunters():
				await hunter_move(h, 1, {"may": true, "label": "%s" % cname(h)})
			for s in settlers.duplicate():
				await settler_step(ci, s, "Il colono può muovere di 1 passo")
		"beasts_summons_mv2":
			for b in beasts():
				if not ch[b]["dead"]:
					await beast_move(b, 2, {"upto": true})
					for su in summons_of(b):
						for j in range(2):
							if not await summon_step(b, su, "L'evocato può muovere", true):
								break
		"heal_settler_full":
			var o2 := []
			for s in settlers:
				if s["wounds"] > 0:
					o2.append({"id": str(s["id"]), "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
			if not o2.is_empty():
				var s3 := find_obj(settlers, int(str(await decide(ci, {"type": "settler", "prompt": "Quale colono guarisce del tutto?", "opts": o2}))))
				s3["wounds"] = 0
		"both_summon":
			for b in beasts():
				if not ch[b]["dead"]:
					await do_summon(b)
		"settler_tf":
			var o3 := []
			for s in settlers:
				o3.append({"id": str(s["id"]), "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
			if not o3.is_empty():
				var s4 := find_obj(settlers, int(str(await decide(ci, {"type": "settler", "prompt": "Quale colono trasforma il suo luogo?", "opts": o3}))))
				await transform(s4["loc"], ci, "settlement")
		_:
			if not await _contract_op(ci, op, ctx):
				push_warning("Operazione sconosciuta: " + str(op))
	if k == "grudge" and ctx.get("card", "") == "ruin:sunken_ruins" and contract_id == "titan":
		flags["no_settler_hp"] = true


func claim_ruin(ci: int, r: String) -> void:
	await super.claim_ruin(ci, r)
	if contract_id == "titan" and r == "sunken_ruins":
		flags["no_settler_hp"] = ruins[r] == "B"


# ================================================================== fine partita

func check_contract_end() -> void:
	if game_over:
		return
	if K.get("setup", {}).get("dominion", false):
		var goal := int(K.get("dominion_goal", 12))
		if dom["red"] >= goal:
			await end_game("B", "Il segnalino rosso del Dominio è arrivato a %d." % goal)
			return
		if dom["blue"] >= goal:
			await end_game("H", "Il segnalino blu del Dominio è arrivato a %d." % goal)
			return
	if K.has("beast_wins_settlers") and int(kills.get("settler", 0)) >= int(K["beast_wins_settlers"]):
		await end_game("B", "Sono morti %d coloni." % int(K["beast_wins_settlers"]))
		return
	if K.get("setup", {}).get("titan", false):
		if settlers.is_empty():
			await end_game("B", "Tutti i coloni sono morti.")
			return
		if contract_tokens >= 3:
			await end_game("H", "Tre segnalini habitat sono sul contratto.")
			return


func end_game(winner: String, why: String) -> void:
	if game_over:
		return
	game_over = true
	phase = "end"
	results = {"winner": winner, "why": why, "day": day, "kills": kills.duplicate(), "beast_wounds": beast_wounds, "beast_hp": beast_hp,
		"dom": dom.duplicate(), "tokens": contract_tokens}
	# a fine partita la Bestia si rivela a tutti (anche la parte segreta della partita diventa pubblica)
	var where := {}
	for b in beasts():
		where[str(b)] = ch[b]["loc"]
	results["beast_locs"] = where
	# rivelazione: sale e registro segreto (i cacciatori li confrontano con gli impegni pubblicati)
	results["reveal"] = {"salt": salt, "log": secret_log.duplicate(true)}
	ev({"t": "end", "winner": winner, "why": why, "beast_locs": where})
	log_msg("[b]%s![/b] %s" % ["Vince la Bestia" if winner == "B" else "Vincono i cacciatori", why])
	changed.emit()
	game_ended.emit(results)


# ================================================================== contratti delle mappe Isole superiori, Terre sommerse, Distese del Nord

## Preparazione aggiuntiva dei contratti (armature, naufragio, palude abissale, talenti, potenziamenti).
func _extra_setup(st: Dictionary) -> void:
	if st.get("shipwreck", false):
		settlers.clear()
		var wl: String = M.get("shipwreck_loc", "")
		if wl == "":
			wl = settlements()[0]
		for i in range(2):
			settlers.append({"id": new_id(), "kind": "farmer", "loc": wl, "wounds": 0, "armor": 0, "start": wl})
		log_msg("Due Contadini naufraghi sono sulla costa in %s." % loc_label(wl))
	var armor := int(st.get("settler_armor", 0))
	if st.get("abyss_setup", false) and beasts().any(func(b): return ch[b].get("abyss", false)):
		armor = maxi(armor, 1)
	if armor > 0:
		for s in settlers:
			s["armor"] = int(s.get("armor", 0)) + armor
		log_msg("Ogni colono riceve un'Armatura.")
	for b in beasts():
		var nt := int(st.get("beast_talents_random", 0))
		for i in range(nt):
			if not talent_deck.is_empty():
				ch[b]["hand"].append(talent_deck.pop_back())
		if nt > 0:
			log_msg("%s riceve %d Talenti bestiali a caso." % [cname(b), nt])
		if st.get("abyss_setup", false):
			var h := beast_hab(b)
			for l in LOCS:
				if LOCS[l].has("ruin") and has_hab(l, h):
					await transform(l, b, "abyss")
			if ch[b].get("abyss", false):
				var any_l: Array = LOCS.keys().filter(func(x): return not has_hab(x, "settlement") and not is_abyss(x))
				var l1 := await pick_loc(b, "Palude abissale: quale luogo trasformare?", any_l, false)
				if l1 != "":
					await transform(l1, b, "abyss")
			else:
				for i in range(3):
					var pl: Array = LOCS.keys().filter(func(x): return has_hab(x, h) and not is_abyss(x) and not has_hab(x, "settlement"))
					var l2 := await pick_loc(b, "Palude abissale: quale luogo del tuo habitat trasformare? (%d/3)" % (i + 1), pl, false)
					if l2 != "":
						await transform(l2, b, "abyss")
		if st.has("summons_zone"):
			var z: String = st["summons_zone"][0]
			for i in range(int(st["summons_zone"][1])):
				var sp: Array = LOCS.keys().filter(func(x): return has_hab(x, beast_hab(b)) and zone_of(x) == z)
				if not sp.is_empty():
					await place_summon(b, sp)
		if int(st.get("beast_buy_upgrade", 0)) > 0:
			await buy_upgrades(b, int(st["beast_buy_upgrade"]), 0)


func _start_settler_alive(nm: String) -> bool:
	for s in settlers:
		if LOCS.get(s["start"], {}).get("name", "") == nm:
			return true
	return false


func _once(key: String) -> bool:
	var k := "%s_%d" % [key, night_no]
	if flags.get(k, false):
		return false
	flags[k] = true
	return true


func _beings(wounded := false) -> Array:
	var out := []
	for h in alive_hunters():
		if ch[h]["loc"] != "" and (not wounded or int(ch[h]["wounds"]) > 0):
			out.append({"t": "hunter", "ci": h, "at": ch[h]["loc"]})
	for s in settlers:
		if not wounded or int(s["wounds"]) > 0:
			out.append({"t": "settler", "id": s["id"], "kind": s["kind"], "at": s["loc"]})
	for a in animals:
		if not wounded or int(a["wounds"]) > 0:
			out.append({"t": "animal", "id": a["id"], "kind": a["kind"], "at": a["loc"]})
	return out


func _pick_being(ci: int, prompt: String, list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var opts := []
	for t in list:
		opts.append({"id": being_key(t), "label": "%s in %s" % [target_label(t), loc_label(t["at"])], "ref": t, "loc": t["at"]})
	var r = await decide(ci, {"type": "target", "prompt": prompt, "opts": opts})
	for o in opts:
		if str(o["id"]) == str(r):
			return o["ref"]
	return list[0]


func _abyss_locs() -> Array:
	return LOCS.keys().filter(func(x): return is_abyss(x))


## Operazioni dei contratti aggiunti. Restituisce false se l'operazione non è di questi contratti.
func _contract_op(ci: int, op: Array, ctx: Dictionary) -> bool:
	var k: String = op[0]
	match k:
		"mvu_per_ruin":
			var n := ruins_of("H")
			if n > 0:
				await hunter_move(ci, n, {"upto": true, "may": true, "label": "%s può muovere fino a %d passi" % [cname(ci), n]})
		"grudge_per_ruin":
			var n2 := ruins_of("B")
			if n2 > 0:
				await gain_grudge(ci, n2, "Rovine controllate")
		"abyss_zone_pref":
			var z := zone_of(ch[ci]["loc"])
			var h := beast_hab(ci)
			for i in range(int(op[1])):
				var pl: Array = LOCS.keys().filter(func(x): return in_zone(x, z) and has_hab(x, h) and not is_abyss(x) and not has_hab(x, "settlement"))
				var l := await pick_loc(ci, "Quale luogo diventa palude abissale? (%d/%d)" % [i + 1, int(op[1])], pl, true)
				if l == "":
					break
				await transform(l, ci, "abyss")
		"summon_on_abyss":
			var al := _abyss_locs()
			if not al.is_empty():
				await place_summon(ci, al)
		"abyss_any_pref":
			var h2 := beast_hab(ci)
			var pl2: Array = LOCS.keys().filter(func(x): return has_hab(x, h2) and not is_abyss(x) and not has_hab(x, "settlement"))
			var l2 := await pick_loc(ci, "Dove mettere una palude abissale?", pl2, true)
			if l2 != "":
				await transform(l2, ci, "abyss")
		"abyss_near_abyss":
			var cand := {}
			for a in _abyss_locs():
				for x in dist_map(a, 2, ""):
					if not is_abyss(x) and not has_hab(x, "settlement"):
						cand[x] = true
			var l3 := await pick_loc(ci, "Dove mettere una palude abissale (fino a 2 passi da un'altra)?", cand.keys(), true)
			if l3 != "":
				await transform(l3, ci, "abyss")
		"abyss_to_settlement":
			var l4 := await pick_loc(ci, "Quale palude abissale diventa insediamento?", _abyss_locs(), true)
			if l4 != "":
				await transform(l4, ci, "settlement")
		"heal_any":
			var t := await _pick_being(ci, "A chi togliere 1 ferita?", _beings(true))
			if not t.is_empty():
				if t["t"] == "animal":
					var an := find_obj(animals, t["id"])
					an["wounds"] = maxi(0, int(an["wounds"]) - int(op[1]))
				else:
					heal(t, int(op[1]))
				log_msg("%s recupera 1 ferita." % target_label(t))
		"dmg_any":
			var t2 := await _pick_being(ci, "A chi infliggere 1 danno?", _beings())
			if not t2.is_empty():
				await damage(t2, int(op[1]), {"kind": "effect", "ci": ci})
		"beasts_summons_mv1":
			for b in beasts():
				if not ch[b]["dead"]:
					await beast_move(b, 1, {"upto": true})
					for su in summons_of(b):
						await summon_step(b, su, "L'evocato può muovere", true)
		"atk_or_summon":
			var r = await decide(ci, {"type": "choice", "prompt": "Attaccare o evocare?", "opts": [{"id": "s", "label": "Evoca"}, {"id": "a", "label": "Attacca"}], "ask_single": true})
			if str(r) == "a":
				await run_op(ci, ["atk"], ctx)
			else:
				await do_summon(ci)
		"one_tower":
			if _once("one_tower"):
				var hs: Array = alive_hunters().filter(func(x): return ch[x]["loc"] != "")
				if not hs.is_empty():
					var l5 := await pick_loc(ci, "Su quale luogo di un cacciatore mettere la torre di guardia?", hs.map(func(x): return ch[x]["loc"]), true)
					if l5 != "":
						await place_tower(l5)
		"two_towers":
			if _once("two_towers"):
				var ls: Array = []
				for x in alive_hunters():
					if ch[x]["loc"] != "" and not ls.has(ch[x]["loc"]):
						ls.append(ch[x]["loc"])
				for i in range(2):
					var l6 := await pick_loc(ci, "Torre di guardia sul luogo di un cacciatore (%d/2)" % (i + 1), ls, true)
					if l6 == "":
						break
					ls.erase(l6)
					await place_tower(l6)
		"grudge_per_sheep_talent_per_boar":
			var sh := int(kills.get("sheep", 0))
			if sh > 0:
				await gain_grudge(ci, sh, "pecore uccise")
			for i in range(int(kills.get("boar", 0))):
				await gain_talent(ci)
		"farmer_to_noble":
			if _once("farmer_to_noble"):
				var fs: Array = settlers.filter(func(s): return s["kind"] == "farmer")
				if not fs.is_empty():
					var o := []
					for s in fs:
						o.append({"id": str(s["id"]), "label": "Contadino in " + loc_label(s["loc"]), "loc": s["loc"]})
					var s2 := find_obj(settlers, int(str(await decide(ci, {"type": "settler", "prompt": "Quale Contadino diventa Nobile?", "opts": o}))))
					s2["kind"] = "noble"
					ev({"t": "skind", "id": s2["id"], "kind": "noble"})
					log_msg("Un Contadino diventa Nobile.")
		"farmers_to_noble_at":
			if _once("farmers_at"):
				for s in settlers:
					if s["kind"] == "farmer" and LOCS[s["loc"]].get("name", "") == str(op[1]):
						s["kind"] = "noble"
						ev({"t": "skind", "id": s["id"], "kind": "noble"})
						log_msg("Un Contadino in %s diventa Nobile." % loc_label(s["loc"]))
		"free_upgrade":
			await buy_upgrades(ci, 1, 99)
		_:
			return false
	return true


## Naufragio: i cacciatori vincono se alla fine di un turno della Bestia c'è un colono nell'insediamento obiettivo.
func beast_turn_end(ci: int) -> void:
	var goal: String = K.get("goal_settlement", "")
	if goal == "" or game_over:
		return
	for s in settlers:
		if LOCS[s["loc"]].get("name", "") == goal:
			await end_game("H", "Un colono ha raggiunto %s alla fine del turno della Bestia." % loc_label(s["loc"]))
			return
