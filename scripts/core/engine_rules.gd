class_name BSRules
extends BSState
## Meccaniche di base: movimento nascosto della Bestia, tracce, rivelazione, perlustrazione,
## attacchi e danni, evocati, trasformazioni, torri di guardia, trappole, rovine.


# ================================================================== movimento della Bestia

## Opzioni per un passo della Bestia dal luogo l.
## o: {same: direzione obbligata, nomove: "Nessun movimento" ammesso sempre, zone: zona da non lasciare}
func beast_step_opts(ci: int, l: String, o: Dictionary) -> Array:
	var out := []
	var h := beast_hab(ci)
	var st := step_targets(l, h)
	for d in DIRS:
		if not st.has(d):
			continue
		if o.get("same", "") != "" and o["same"] != d:
			continue
		var t: String = st[d]
		if o.get("zone", "") != "" and not in_zone(t, o["zone"]):
			continue
		var via := " (Sentiero nascosto)" if LOCS[l]["nb"].get(d, "") != t else ""
		out.append({"id": d, "label": "%s → %s%s" % [D.DIR_IT[d], loc_label(t), via], "loc": t, "dir": d})
	# rete delle paludi abissali (Akkeron): da una palude abissale a un'altra conta un solo passo
	if ch[ci].get("abyss", false) and is_abyss(l) and o.get("same", "") == "":
		for t in tokens:
			if tokens[t] == "abyss" and t != l and (o.get("zone", "") == "" or in_zone(t, o["zone"])):
				out.append({"id": "A:" + t, "label": "Abisso → " + loc_label(t), "loc": t, "dir": "A"})
	var sharing := not hunters_at(l).is_empty() or not settlers_at(l).is_empty()
	if o.get("nomove", false) or not sharing:
		out.append({"id": "X", "label": "Nessun movimento", "dir": "X", "loc": l})
	return out


## La Bestia muove di n passi (carte Movimento coperte). Restituisce i passi fatti.
## o: {upto, same(bool: tutti nella stessa direzione), nomove, zone, fake (dopo ogni passo una carta falsa)}
func beast_move(ci: int, n: int, o := {}) -> int:
	var c: Dictionary = ch[ci]
	if c["dead"] or n <= 0:
		return 0
	var done := 0
	var dir_lock := ""
	var zone := ""
	if o.get("zone", false):
		zone = zone_of(c["loc"]) if zone_of(c["loc"]) != "*" else ""
	var placed := 0
	var abyss_trails := []
	var batch := []
	for i in range(n):
		var l: String = c["loc"]
		var so := {"nomove": o.get("nomove", false), "zone": zone}
		if o.get("same", false) and dir_lock != "":
			so["same"] = dir_lock
		var opts := beast_step_opts(ci, l, so)
		if o.get("upto", false) or opts.is_empty():
			if opts.is_empty():
				break
			opts.append({"id": "stop", "label": "Fermati qui"})
		var pr := "Muovi la Bestia (passo %d di %d)" % [i + 1, n]
		if o.get("label", "") != "":
			pr = "%s: passo %d di %d" % [o["label"], i + 1, n]
		var r = await decide(ci, {"type": "beast_step", "prompt": pr, "opts": opts, "ask_single": true, "secret": true})
		if str(r) == "stop":
			break
		var pick: Dictionary = {}
		for op in opts:
			if str(op["id"]) == str(r):
				pick = op
		var d: String = pick["dir"]
		var t: String = pick["loc"]
		if d != "X" and d != "A" and o.get("same", false):
			dir_lock = d
		if c.get("visible_move", false) or souls_empty(ci):
			# Vacker senza anime attive: è rivelata e muove la sagoma passo per passo
			if d != "X":
				c["loc"] = t
				c["standee"] = t
				c["revealed"] = true
				ev({"t": "bvis", "ci": ci, "to": t})
		else:
			var m := {"dir": d, "from": l, "to": t, "fake": false, "pair": 0, "found": false}
			c["moves"].append(m)
			c["revealed"] = false
			c["loc"] = t
			placed += 1
			batch.append(m)
			if d == "A":
				# attraverso l'abisso: carta di traverso e Traccia subito sul luogo d'arrivo
				m["found"] = true
				_add_trail(ci, t)
				abyss_trails.append(t)
			if o.get("fake", false):
				batch.append(await place_false(ci, l, m))
		done += 1
		if d != "X":
			await _after_beast_step(ci, l, t)
	if placed > 0:
		ev({"t": "bmove", "ci": ci, "n": placed, "pairs": c["moves"].map(func(m): return int(m.get("pair", 0))), "abyss": abyss_trails, "h": commit_moves(ci, batch)})
		log_msg("%s gioca %d carte Movimento coperte." % [cname(ci), placed])
	await refresh_trails()
	if done > 0 and has_up(ci, "kins_pursuit"):
		await summon_free_move(ci, "wolf", 1, "Inseguimento del branco: un Lupo può muovere di 1 passo")
	return done


func _after_beast_step(ci: int, from: String, to: String) -> void:
	pass


## Carta Movimento falsa accanto alla vera: parte dallo stesso luogo d'origine.
func place_false(ci: int, origin: String, real: Dictionary) -> Dictionary:
	var opts := []
	var st := step_targets(origin, beast_hab(ci))
	for d in DIRS:
		if st.has(d):
			opts.append({"id": d, "label": "Falsa: %s → %s" % [D.DIR_IT[d], loc_label(st[d])], "loc": st[d], "dir": d})
	opts.append({"id": "X", "label": "Falsa: Nessun movimento", "dir": "X", "loc": origin})
	var r = await decide(ci, {"type": "beast_false", "prompt": "Scegli la carta Movimento FALSA (parte dallo stesso luogo)", "opts": opts, "ask_single": true, "secret": true})
	var pick: Dictionary = opts[0]
	for op in opts:
		if str(op["id"]) == str(r):
			pick = op
	var pid := new_id()
	real["pair"] = pid
	var f := {"dir": pick["dir"], "from": origin, "to": pick["loc"], "fake": true, "pair": pid, "found": false}
	ch[ci]["moves"].append(f)
	return f


## Impegno (commit) su un gruppo di carte Movimento coperte: hash salato pubblicato nell'evento
## «bmove». A fine partita la Bestia rivela sale e mosse e ognuno può ricontrollare tutto (verify.gd).
func commit_moves(ci: int, batch: Array) -> String:
	var mv := []
	for m in batch:
		mv.append({"dir": m["dir"], "from": m["from"], "to": m["to"], "fake": m["fake"]})
	var n := events.size()
	secret_log.append({"ev": n, "ci": ci, "moves": mv})
	return BSState.commit_hash(salt, n, ci, mv)


## Spostamento segreto della Bestia fuori dalle carte Movimento (subito seguito da una rivelazione).
func secret_relocate(ci: int, l: String) -> void:
	ch[ci]["loc"] = l
	secret_log.append({"ev": events.size(), "ci": ci, "relocate": l})


func souls_empty(ci: int) -> bool:
	return ch[ci].get("souls", -1) == 0


func _add_trail(b: int, l: String) -> void:
	if not trails.has(l):
		trails[l] = {}
	trails[l][b] = int(trails[l].get(b, 0)) + 1
	if ch[b].get("souls", -1) > 0:
		ch[b]["souls"] -= 1
		ch[b]["on_map"] = int(ch[b].get("on_map", 0)) + 1
		if ch[b]["souls"] == 0:
			# senza anime attive Vacker è rivelata
			await_reveal_later(b)


var _pending_reveal: Array = []

func await_reveal_later(b: int) -> void:
	if not _pending_reveal.has(b):
		_pending_reveal.append(b)


## C'è una Traccia (o la sagoma di una Bestia nascosta, che conta come Traccia)?
func trail_at(l: String) -> bool:
	if trails.has(l):
		for b in trails[l]:
			if int(trails[l][b]) > 0:
				return true
	for b in beasts():
		if not ch[b]["revealed"] and not ch[b]["dead"] and ch[b]["standee"] == l:
			return true
	return false


## Luoghi osservati: cacciatori, coloni, Fylgja e i luoghi vicini alle torri di guardia attive.
func observed_locs(for_beast: int) -> Array:
	var out := []
	for i in alive_hunters():
		if not out.has(ch[i]["loc"]):
			out.append(ch[i]["loc"])
	var fear := has_up(for_beast, "fear_night")
	for s in settlers:
		if not fear and not out.has(s["loc"]):
			out.append(s["loc"])
	if companion != "" and not out.has(companion):
		out.append(companion)
	var townswatch := false
	for i in hunters():
		if has_up(i, "townswatch"):
			townswatch = true
	for t in towers:
		var active := not hunters_at(t).is_empty() or (townswatch and not settlers_at(t).is_empty())
		if active:
			for l in nearby(t, "settlement"):
				if not out.has(l):
					out.append(l)
	return out


## Mette le Tracce dovute: ogni carta Movimento attiva che porta in un luogo osservato.
func refresh_trails() -> void:
	for b in beasts():
		var c: Dictionary = ch[b]
		if c["dead"] or c["moves"].is_empty():
			continue
		var obs := observed_locs(b)
		var found := {}
		for m in c["moves"]:
			if m["found"] or m["dir"] == "X":
				continue
			if obs.has(m["to"]):
				m["found"] = true
				_add_trail(b, m["to"])
				found[m["to"]] = int(found.get(m["to"], 0)) + 1
		ev({"t": "check", "ci": b, "locs": obs, "found": found})
		if not found.is_empty():
			var names := []
			for l in found:
				names.append("%s (%d)" % [loc_label(l), found[l]])
			log_msg("Tracce di %s: %s." % [cname(b), ", ".join(names)])
			for l in found:
				if not settlers_at(l).is_empty():
					await offer_reaction("trail_on_settler", {"loc": l})
	for b in _pending_reveal.duplicate():
		_pending_reveal.erase(b)
		await reveal(b, "anime esaurite")


# ================================================================== rivelazione e perlustrazione

## La Bestia si rivela: mostra le carte Movimento, toglie le sue Tracce, la sagoma va nel luogo vero.
func reveal(b: int, why := "") -> void:
	var c: Dictionary = ch[b]
	if c["dead"]:
		return
	var was_hidden = not c["revealed"]
	if not was_hidden and c["standee"] == c["loc"]:
		return
	var shown := []
	for m in c["moves"]:
		shown.append({"dir": m["dir"], "from": m["from"], "to": m["to"], "fake": m["fake"], "pair": m["pair"]})
	c["moves"] = []
	# via le Tracce di questa Bestia (quelle di Vacker tornano alle anime attive)
	var back := 0
	for l in trails.keys():
		if trails[l].has(b):
			back += int(trails[l][b])
			trails[l].erase(b)
		if trails[l].is_empty():
			trails.erase(l)
	if c.get("souls", -1) >= 0:
		c["souls"] += back
		c["on_map"] = 0
	c["standee"] = c["loc"]
	c["revealed"] = true
	ev({"t": "reveal", "ci": b, "loc": c["loc"], "moves": shown, "why": why})
	log_msg("[b]%s si rivela in %s[/b]%s." % [cname(b), loc_label(c["loc"]), (" (" + why + ")") if why != "" else ""])
	changed.emit()
	if was_hidden:
		await on_revealed(b)


## Effetti che scattano alla rivelazione: trappole, Radunare, Adorazione, Segugio eccezionale.
func on_revealed(b: int) -> void:
	var l: String = ch[b]["loc"]
	await trigger_traps(b)
	if has_up(b, "amass"):
		for a in animals.duplicate():
			if a["kind"] == "boar" and nearby(l).has(a["loc"]) and summons_of(b).size() < 3:
				animals.erase(a)
				summons.append({"id": new_id(), "owner": b, "kind": "warhog", "loc": a["loc"], "wounds": 0})
				ev({"t": "summon", "ci": b, "kind": "warhog", "loc": a["loc"]})
				log_msg("Radunare: un Cinghiale diventa Cinghiale da guerra.")
	if ch[b].get("reborn", false):
		for s in nearby(l):
			if has_hab(s, "settlement") and summons_of(b).size() < 3:
				summons.append({"id": new_id(), "owner": b, "kind": "dreamer", "loc": s, "wounds": 0})
				ev({"t": "summon", "ci": b, "kind": "dreamer", "loc": s})
				log_msg("Adorazione: un Sognatore compare in %s." % loc_label(s))
				break
	for h in hunters():
		if has_up(h, "exceptional_tracker") and not ch[h]["dead"]:
			for a in ch[h]["abil_disc"].duplicate():
				if D.is_track(a):
					ch[h]["abil_disc"].erase(a)
					ch[h]["hand"].append(a)
					log_msg("Segugio eccezionale: %s riprende Seguire le tracce." % cname(h))


## Perlustra il luogo l: se una Bestia nascosta è lì, si rivela.
func search(ci: int, l: String) -> bool:
	var found := false
	for b in beasts():
		if not ch[b]["dead"] and ch[b]["loc"] == l:
			found = true
	ev({"t": "search", "ci": ci, "loc": l, "found": found})
	if found:
		log_msg("%s perlustra %s e trova la Bestia!" % [cname(ci), loc_label(l)])
		for b in beasts():
			if not ch[b]["dead"] and ch[b]["loc"] == l and not ch[b]["revealed"]:
				await reveal(b, "perlustrazione")
	else:
		log_msg("%s perlustra %s: nessuna Bestia." % [cname(ci), loc_label(l)])
	return found


## Rivela l'ultima carta Movimento giocata (n ultime con Indovina).
func reveal_last_moves(b: int, n: int) -> void:
	var c: Dictionary = ch[b]
	var real := []
	for i in range(c["moves"].size() - 1, -1, -1):
		var m: Dictionary = c["moves"][i]
		real.append(m)
		# una carta falsa si rivela insieme alla sua coppia
		if m["pair"] != 0:
			for m2 in c["moves"]:
				if m2 != m and m2["pair"] == m["pair"] and not real.has(m2):
					real.append(m2)
		if real.filter(func(x): return not x["fake"]).size() >= n:
			break
	var shown := []
	for m in real:
		shown.append({"dir": m["dir"], "from": m["from"], "to": m["to"], "fake": m["fake"], "idx": c["moves"].find(m)})
	ev({"t": "seer", "ci": b, "moves": shown, "total": c["moves"].size()})
	var txt := []
	for m in shown:
		txt.append(D.DIR_IT[m["dir"]] + (" (falsa)" if m["fake"] else ""))
	if shown.is_empty():
		log_msg("%s non ha carte Movimento attive." % cname(b))
	else:
		log_msg("Rivelata l'ultima carta Movimento di %s: %s." % [cname(b), ", ".join(txt)])


# ================================================================== movimento dei cacciatori e degli altri esseri

## Opzioni di un passo per un cacciatore (o colono/Fylgja) dal luogo l.
func walker_opts(l: String, hab: String, zone := "", same := "", abyss := true) -> Array:
	var out := []
	var st := step_targets(l, hab)
	for d in DIRS:
		if not st.has(d) or (same != "" and d != same):
			continue
		var t: String = st[d]
		if zone != "" and not in_zone(t, zone):
			continue
		out.append({"id": t, "label": "%s → %s" % [D.DIR_IT[d], loc_label(t)], "loc": t, "dir": d})
	if abyss and is_abyss(l) and same == "":
		for t in tokens:
			if tokens[t] == "abyss" and t != l:
				out.append({"id": t, "label": "Abisso → " + loc_label(t) + " (1 ferita)", "loc": t, "dir": "A"})
	return out


## Il cacciatore h muove di n passi (upto: può fermarsi). Ogni passo rivela le Tracce.
func hunter_move(h: int, n: int, o := {}) -> int:
	var done := 0
	var lock := ""
	for i in range(n):
		if ch[h]["dead"]:
			break
		var l: String = ch[h]["loc"]
		var opts := walker_opts(l, "settlement", o.get("zone", ""), lock if o.get("same", false) else "")
		if opts.is_empty():
			break
		if o.get("upto", false) or o.get("may", false):
			opts.append({"id": "stop", "label": "Fermati qui"})
		var pr: String = o.get("label", "Muovi %s" % cname(h))
		var r = await decide(h, {"type": "step", "prompt": "%s (passo %d di %d)" % [pr, i + 1, n], "opts": opts, "ask_single": true, "mover": "hunter:%d" % h})
		if str(r) == "stop":
			break
		var d := dir_between(l, str(r), "settlement")
		if o.get("same", false) and d != "":
			lock = d
		await move_hunter_to(h, str(r), true)
		done += 1
	return done


## Sposta un cacciatore (passo o ricollocamento) e rivela le Tracce nel nuovo luogo.
func move_hunter_to(h: int, t: String, step := true) -> void:
	var from: String = ch[h]["loc"]
	if from == t:
		return
	ch[h]["loc"] = t
	ev({"t": "hmove", "ci": h, "from": from, "to": t, "step": step})
	var spire_safe: bool = K.get("abyss_pref", false) and ruins.get("abyssal_spire", "") == "H"
	if step and not spire_safe and is_abyss(from) and is_abyss(t) and not adjacent(from, t, "settlement"):
		log_msg("%s attraversa l'abisso e subisce 1 ferita." % cname(h))
		await damage({"t": "hunter", "ci": h}, 1, {"kind": "abyss"})
	await refresh_trails()


func move_settler_to(s: Dictionary, t: String) -> void:
	var from: String = s["loc"]
	s["loc"] = t
	ev({"t": "smove", "id": s["id"], "from": from, "to": t})
	await refresh_trails()


func move_being_to(b: Dictionary, t: String) -> void:
	match str(b["t"]):
		"hunter":
			await move_hunter_to(int(b["ci"]), t, false)
		"settler":
			var s := find_obj(settlers, b["id"])
			if not s.is_empty():
				await move_settler_to(s, t)
		"animal":
			var a := find_obj(animals, b["id"])
			if not a.is_empty():
				var from: String = a["loc"]
				a["loc"] = t
				ev({"t": "amove", "id": a["id"], "from": from, "to": t})
		"summon":
			var s2 := find_obj(summons, b["id"])
			if not s2.is_empty():
				var from2: String = s2["loc"]
				s2["loc"] = t
				ev({"t": "summove", "id": s2["id"], "from": from2, "to": t})
		"companion":
			companion = t
			ev({"t": "cmove", "to": t})
			await refresh_trails()
		"beast":
			# una Bestia rivelata spostata da un effetto: resta rivelata
			var c: Dictionary = ch[b["ci"]]
			c["loc"] = t
			c["standee"] = t
			ev({"t": "bvis", "ci": b["ci"], "to": t})


## Un colono muove di 1 passo (scelta del giocatore ci).
func settler_step(ci: int, s: Dictionary, prompt: String, zone := "") -> bool:
	var no_hp := flags.get("no_settler_hp", false)
	var opts := walker_opts(s["loc"], "" if no_hp else "settlement", zone, "", false)
	if opts.is_empty():
		return false
	opts.append({"id": "stop", "label": "Resta"})
	var r = await decide(ci, {"type": "step", "prompt": prompt, "opts": opts, "ask_single": true, "mover": "settler:%d" % s["id"]})
	if str(r) == "stop":
		return false
	await move_settler_to(s, str(r))
	return true


## Spostamento di un animale di 1 passo (gli animali non usano i Sentieri nascosti).
func animal_step(ci: int, a: Dictionary, prompt: String, zone := "") -> bool:
	var opts := walker_opts(a["loc"], "", zone, "", false)
	if opts.is_empty():
		return false
	opts.append({"id": "stop", "label": "Resta"})
	var r = await decide(ci, {"type": "step", "prompt": prompt, "opts": opts, "ask_single": true})
	if str(r) == "stop":
		return false
	await move_being_to({"t": "animal", "id": a["id"]}, str(r))
	return true


# ================================================================== attacchi e danni

func beast_damage(b: int) -> int:
	var c: Dictionary = ch[b]
	for u in ["withering_maw", "enraged", "soul_harvest_m", "leviathan", "infernal_tusks", "accursed_wrath", "golden_beak"]:
		if c["upg"].has(u):
			return 2
	if c.get("reborn", false):
		return 2
	return 1


## Bersagli d'attacco nel luogo l per l'attaccante ci.
func attack_targets(ci: int, l: String, filter := "") -> Array:
	var out := []
	if is_beast(ci):
		for h in hunters_at(l):
			out.append({"t": "hunter", "ci": h})
		for s in settlers_at(l):
			out.append({"t": "settler", "id": s["id"], "kind": s["kind"]})
		for a in animals_at(l):
			out.append({"t": "animal", "id": a["id"], "kind": a["kind"]})
		if towers_at(l) > 0:
			out.append({"t": "tower", "loc": l})
		if companion == l:
			out.append({"t": "companion"})
	else:
		var mes = ch[ci].get("mesmerised_by", -1) >= 0
		if filter != "animal":
			for s in summons_at(l):
				out.append({"t": "summon", "id": s["id"], "kind": s["kind"]})
			if filter != "summon":
				for b in beasts_at(l, true):
					out.append({"t": "beast", "ci": b})
		if filter == "animal" or (filter == "" and ch[ci].get("blood", -1) >= 0):
			for a in animals_at(l):
				out.append({"t": "animal", "id": a["id"], "kind": a["kind"]})
		if mes:
			for h in hunters_at(l):
				if h != ci:
					out.append({"t": "hunter", "ci": h})
			for s in settlers_at(l):
				out.append({"t": "settler", "id": s["id"], "kind": s["kind"]})
	return out


func target_label(t: Dictionary) -> String:
	if t["t"] == "tower":
		return "Torre di guardia"
	var n := being_name(t)
	var w := 0
	var hp := 0
	match str(t["t"]):
		"hunter":
			w = ch[t["ci"]]["wounds"]
			hp = D.HUNTERS[ch[t["ci"]]["id"]]["hp"]
		"settler":
			var s := find_obj(settlers, t["id"])
			w = s.get("wounds", 0)
			hp = D.SETTLERS[s["kind"]]["hp"]
		"animal":
			var a := find_obj(animals, t["id"])
			w = a.get("wounds", 0)
			hp = D.ANIMALS[a["kind"]]["hp"]
		"summon":
			var su := find_obj(summons, t["id"])
			w = su.get("wounds", 0)
			hp = summon_hp(su["kind"])
		"beast":
			w = beast_wounds
			hp = beast_hp
	if hp > 0:
		return "%s (%d/%d)" % [n, hp - w, hp]
	return n


## Attacco. o: {bonus, animal_bonus, filter ("summon", "animal"), card, near (bersaglio in un luogo vicino)}.
## Restituisce {killed: bool, target: Dictionary}.
func attack(ci: int, o := {}) -> Dictionary:
	var res := {"killed": false, "target": {}}
	if ch[ci]["dead"]:
		return res
	var l: String = ch[ci]["loc"]
	if is_beast(ci) and not ch[ci]["revealed"]:
		await reveal(ci, "attacco")
		l = ch[ci]["loc"]
	if is_beast(ci) and ch[ci].get("souls", -1) >= 0:
		pass
	var targets := []
	if o.get("near", false):
		for nl in nearby(l, "settlement"):
			targets.append_array(attack_targets(ci, nl, o.get("filter", "")).map(func(t): t["at"] = nl; return t))
	else:
		targets = attack_targets(ci, l, o.get("filter", ""))
	if targets.is_empty():
		log_msg("%s attacca, ma non c'è nessun bersaglio." % cname(ci))
		return res
	var opts := []
	for t in targets:
		var lab := target_label(t)
		if t.has("at") and t["at"] != l:
			lab += " in " + loc_label(t["at"])
		opts.append({"id": being_key(t) if t["t"] != "tower" else "tower", "label": lab, "ref": t, "loc": t.get("at", l)})
	var r = await decide(ci, {"type": "target", "prompt": "Scegli il bersaglio dell'attacco", "opts": opts})
	var tgt: Dictionary = targets[0]
	for op in opts:
		if str(op["id"]) == str(r):
			tgt = op["ref"]
	res["target"] = tgt
	var dmg := 1
	if is_beast(ci):
		dmg = beast_damage(ci)
	dmg += int(o.get("bonus", 0))
	if tgt["t"] == "animal":
		dmg += int(o.get("animal_bonus", 0))
		if has_up(ci, "blood_craft"):
			dmg += 1
	# Poteri antichi: +1 danno ciascuno
	if ch[ci]["ap"] > 0 and tgt["t"] != "tower":
		var ap_opts := []
		for k in range(ch[ci]["ap"] + 1):
			ap_opts.append({"id": str(k), "label": "Nessun Potere antico" if k == 0 else "Usa %d Poter%s antic%s (+%d)" % [k, "e" if k == 1 else "i", "o" if k == 1 else "hi", k]})
		var a = await decide(ci, {"type": "ap", "prompt": "Usare Poteri antichi in questo attacco?", "opts": ap_opts, "ask_single": true})
		var k2 := int(str(a))
		ch[ci]["ap"] -= k2
		ap_supply += k2
		dmg += k2
	var tl: String = being_loc(tgt) if tgt["t"] != "tower" else str(tgt["loc"])
	ev({"t": "attack", "ci": ci, "loc": tl, "target": tgt, "dmg": dmg})
	log_msg("%s attacca %s." % [cname(ci), target_label(tgt)])
	# reazioni all'attacco della Bestia (Fumogeno, Legame antico, Difensore, armatura)
	if is_beast(ci):
		var prev := {"n": 0}
		await offer_reaction("beast_attack_near", {"loc": tl, "prevent": prev, "target": tgt})
		dmg -= int(prev["n"])
		for h in hunters_at(tl):
			if ch[h].get("defender", false):
				ch[h]["defender"] = false
				dmg -= 1
				log_msg("Difensore: %s previene 1 danno." % cname(h))
	if dmg <= 0:
		log_msg("Il danno è prevenuto.")
		return res
	res["killed"] = await damage(tgt, dmg, {"kind": "attack", "ci": ci})
	if is_beast(ci) and has_up(ci, "great_howl"):
		await wolf_charge_after(ci)
	return res


## Infligge danni. src: {kind: attack|summon|trap|effect|abyss, ci?, sid?}. Restituisce true se il bersaglio muore.
func damage(t: Dictionary, n: int, src := {}) -> bool:
	if n <= 0:
		return false
	var by_beast_attack = src.get("kind", "") == "attack" and is_beast(int(src.get("ci", -1)))
	match str(t["t"]):
		"tower":
			towers.erase(t.get("loc", ""))
			ev({"t": "tower_down", "loc": t.get("loc", "")})
			log_msg("La torre di guardia è distrutta.")
			return false
		"companion":
			companion = ""
			ev({"t": "cdead"})
			log_msg("Fylgja è ferita e torna da Eivind.")
			return true
		"hunter":
			var h: int = t["ci"]
			var c: Dictionary = ch[h]
			var a := mini(int(c.get("armor", 0)), n)
			c["armor"] = int(c.get("armor", 0)) - a
			n -= a
			c["wounds"] += n
			ev({"t": "dmg", "target": t, "n": n})
			if c.get("rebirth_fire", false) and c["wounds"] >= 3:
				c["rebirth_fire"] = false
				c["wounds"] -= 1
				_gain_ap(h)
				log_msg("Rinascita nel fuoco: %s recupera 1 ferita e prende un Potere antico." % cname(h))
			if c["wounds"] >= int(D.HUNTERS[c["id"]]["hp"]):
				await kill_hunter(h, src)
				return true
			return false
		"beast":
			var b: int = t["ci"]
			# Martire (Re Piumato rinato): il danno può passare a un Sognatore nel suo luogo
			if ch[b].get("reborn", false):
				for s in summons_at(ch[b]["loc"], b):
					if s["kind"] == "dreamer" and await yesno(b, "Martire: trasferire il danno al Sognatore?"):
						await damage({"t": "summon", "id": s["id"], "kind": "dreamer"}, n, src)
						return false
			beast_wounds += n
			beast_dmg += n
			ev({"t": "dmg", "target": t, "n": n})
			log_msg("[b]%s subisce %d dann%s[/b] (%d/%d)." % [cname(b), n, "o" if n == 1 else "i", beast_hp - beast_wounds, beast_hp])
			if K.get("setup", {}).get("dominion", false):
				var adv := 1
				if ruins.get("admirer_glade", "") == "H":
					adv += 1
				await dominion("blue", adv, "la Bestia è ferita")
			if src.get("kind", "") == "attack" and not is_beast(int(src.get("ci", 0))):
				for v in hunters():
					if has_up(v, "hunters_bane"):
						await gain_grudge(int(src["ci"]), 1, "Rovina della Bestia")
						break
			if beast_wounds >= beast_hp:
				for bb in beasts():
					ch[bb]["dead"] = true
				await end_game("H", "La Bestia è morta.")
				return true
			return false
		"settler":
			var s: Dictionary = find_obj(settlers, t["id"])
			if s.is_empty():
				return false
			var a2 := mini(int(s.get("armor", 0)), n)
			s["armor"] = int(s.get("armor", 0)) - a2
			n -= a2
			s["wounds"] += n
			ev({"t": "dmg", "target": t, "n": n})
			if s["wounds"] >= int(D.SETTLERS[s["kind"]]["hp"]):
				settlers.erase(s)
				deaths_today += 1
				_count_kill(s["kind"], by_beast_attack)
				_count_kill("settler", by_beast_attack or src.get("kind", "") != "hunter")
				_count_kill("settler_any", true)
				_count_kill("settler_in_" + zone_of(s["loc"]), by_beast_attack or src.get("kind", "") != "hunter")
				ev({"t": "death", "target": t, "loc": s["loc"]})
				log_msg("[b]Muore un %s in %s.[/b]" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])])
				if by_beast_attack:
					await gain_grudge(int(src["ci"]), int(D.SETTLERS[s["kind"]]["gr"]), "uccisione")
				if K.get("setup", {}).get("dominion", false):
					await dominion("red", 3 if s["kind"] == "farmer" else 4, "un colono è morto")
				await check_contract_end()
				return true
			return false
		"animal":
			var an: Dictionary = find_obj(animals, t["id"])
			if an.is_empty():
				return false
			an["wounds"] += n
			ev({"t": "dmg", "target": t, "n": n})
			if K.get("setup", {}).get("dominion", false) and is_beast(turn_ci) and ruins_of("B") >= 2:
				await dominion("red", 1, "un animale è ferito (2 Rovine)")
			if an["wounds"] >= int(D.ANIMALS[an["kind"]]["hp"]):
				animals.erase(an)
				deaths_today += 1
				dead_animals += 1
				if an["kind"] == "sheep":
					dead_sheep += 1
				var hunter_kill = src.get("kind", "") == "attack" and not is_beast(int(src.get("ci", 0)))
				if not hunter_kill:
					_count_kill(an["kind"], by_beast_attack or src.get("kind", "") == "summon" or src.get("kind", "") == "effect")
				ev({"t": "death", "target": t, "loc": an["loc"]})
				log_msg("Muore un%s %s in %s." % ["a" if an["kind"] in ["sheep", "sabertooth"] else "", D.ANIMALS[an["kind"]]["n"], loc_label(an["loc"])])
				if by_beast_attack:
					await gain_grudge(int(src["ci"]), int(D.ANIMALS[an["kind"]]["gr"]), "uccisione")
				elif hunter_kill and ch[int(src["ci"])].get("blood", -1) >= 0:
					var hb := int(src["ci"])
					ch[hb]["blood"] = mini(4, int(ch[hb]["blood"]) + int(D.ANIMALS[an["kind"]]["gr"]))
					log_msg("%s raccoglie sangue (%d)." % [cname(hb), ch[hb]["blood"]])
				if an["kind"] == "sheep":
					for b in beasts():
						if has_up(b, "natural_instinct") and turn_ci == b:
							if await yesno(b, "Istinto naturale: una Pecora è morta. Muovere di 1 passo?"):
								await beast_move(b, 1)
				return true
			return false
		"summon":
			var su: Dictionary = find_obj(summons, t["id"])
			if su.is_empty():
				return false
			su["wounds"] += n
			ev({"t": "dmg", "target": t, "n": n})
			if K.get("setup", {}).get("dominion", false):
				var adv2 := 1
				if ruins.get("yagi_cliffs", "") == "H" and not flags.get("yagi_bonus_day", false):
					flags["yagi_bonus_day"] = true
					adv2 += 1
				await dominion("blue", adv2, "un evocato è ferito")
			if su["wounds"] >= summon_hp(su["kind"]):
				await kill_summon(su)
				return true
			return false
	return false


func _count_kill(kind: String, yes: bool) -> void:
	if yes:
		kills[kind] = int(kills.get(kind, 0)) + 1


func kill_summon(su: Dictionary) -> void:
	summons.erase(su)
	ev({"t": "death", "target": {"t": "summon", "id": su["id"], "kind": su["kind"]}, "loc": su["loc"]})
	log_msg("%s muore." % D.SUMMONS[su["kind"]]["n"])
	var b: int = su["owner"]
	match str(su["kind"]):
		"polyp":
			if has_up(b, "cascade") and await yesno(b, "Cascata: un Polipo è morto. Muovere di 1 passo?"):
				await beast_move(b, 1)
		"changeling":
			if has_up(b, "endless_struggle") and await yesno(b, "Lotta senza fine: evocare?"):
				await do_summon(b)
		"yagi":
			if has_up(b, "eruption"):
				await eruption(b)


func kill_hunter(h: int, src: Dictionary) -> void:
	var c: Dictionary = ch[h]
	var by_beast = src.get("kind", "") == "attack" and is_beast(int(src.get("ci", -1)))
	deaths_today += 1
	kills["hunter_any"] = int(kills.get("hunter_any", 0)) + 1
	ev({"t": "death", "target": {"t": "hunter", "ci": h}, "loc": c["loc"]})
	log_msg("[b]%s è morto.[/b]" % cname(h))
	if by_beast:
		var b := int(src["ci"])
		await gain_grudge(b, 1, "cacciatore ucciso")
		var acts: Array = c["hand"].filter(func(x): return D.kind(x) == "action")
		if not acts.is_empty():
			var pick: String = acts[rng.randi_range(0, acts.size() - 1)]
			c["hand"].erase(pick)
			ch[b]["hand"].append(pick)
			log_msg("%s prende a caso una carta Azione di %s." % [cname(b), cname(h)])
		kills["hunter"] = int(kills.get("hunter", 0)) + 1
	for x in c["hand"]:
		_discard_card(h, x)
	c["hand"] = []
	c["grudges"] = 0
	ap_supply += int(c["ap"])
	c["ap"] = 0
	c["dead"] = true
	c["loc"] = ""
	if c.get("companion", false):
		companion = ""


func _discard_card(ci: int, cid: String) -> void:
	match D.kind(cid):
		"action":
			action_disc.append(cid)
		"item":
			item_disc.append(cid)
		"talent":
			talent_disc.append(cid)
		_:
			ch[ci]["abil_disc"].append(cid)


func gain_grudge(ci: int, n: int, why := "") -> void:
	if n <= 0 or ch[ci]["dead"]:
		return
	ch[ci]["grudges"] += n
	ev({"t": "grudge", "ci": ci, "n": n})
	log_msg("%s guadagna %d rancor%s%s." % [cname(ci), n, "e" if n == 1 else "i", (" (" + why + ")") if why != "" else ""])
	# Vacker: guadagnare rancori fa tornare altrettante anime attive
	if ch[ci].get("souls", -1) >= 0:
		var back := mini(n, int(ch[ci].get("drained", 0)))
		if back > 0:
			ch[ci]["drained"] -= back
			ch[ci]["souls"] += back
			await souls_returned(ci)


func _gain_ap(ci: int) -> bool:
	if ap_supply <= 0:
		return false
	ap_supply -= 1
	ch[ci]["ap"] += 1
	log_msg("%s prende un Potere antico." % cname(ci))
	return true


func heal(t: Dictionary, n: int) -> void:
	match str(t["t"]):
		"hunter":
			ch[t["ci"]]["wounds"] = maxi(0, int(ch[t["ci"]]["wounds"]) - n)
		"settler":
			var s := find_obj(settlers, t["id"])
			if not s.is_empty():
				s["wounds"] = maxi(0, int(s["wounds"]) - n)
		"beast":
			beast_wounds = maxi(0, beast_wounds - n)


func dominion(color: String, n: int, why: String) -> void:
	if not K.get("setup", {}).get("dominion", false) or game_over:
		return
	dom[color] = mini(int(K.get("dominion_goal", 12)), int(dom[color]) + n)
	ev({"t": "dom", "color": color, "v": dom[color]})
	log_msg("Dominio %s +%d (%s): %d." % ["rosso" if color == "red" else "blu", n, why, dom[color]])
	await check_contract_end()


# ================================================================== evocati

func summon_kind(b: int) -> String:
	return str(D.BEASTS[ch[b]["id"]]["summon"])


func summon_max(b: int) -> int:
	return int(D.BEASTS[ch[b]["id"]]["ns"])


## Luoghi dove la Bestia b può mettere un evocato: fino a 2 passi dal luogo vero, nel suo habitat.
func summon_spots(b: int) -> Array:
	var h := beast_hab(b)
	var dm := dist_map(ch[b]["loc"], 2, h)
	var out := []
	for l in dm:
		if has_hab(l, h):
			out.append(l)
	return out


## Simbolo Evoca: mettere un nuovo evocato oppure far agire tutti gli evocati sulla mappa.
func do_summon(b: int, force_place := false) -> void:
	if ch[b]["dead"]:
		return
	var mine := summons_of(b)
	var opts := []
	var spots := summon_spots(b)
	if not spots.is_empty():
		opts.append({"id": "place", "label": "Metti un %s sulla mappa" % D.SUMMONS[summon_kind(b)]["n"]})
	if not mine.is_empty() and not force_place:
		opts.append({"id": "act", "label": "Fai agire i tuoi evocati (%d)" % mine.size()})
	if opts.is_empty():
		return
	var r = await decide(b, {"type": "summon", "prompt": "Evoca", "opts": opts, "ask_single": true})
	if str(r) == "place":
		await place_summon(b, spots)
	else:
		await summons_act(b)


func place_summon(b: int, spots := [], at := "") -> void:
	var kind := summon_kind(b)
	if summons_of(b).size() >= summon_max(b):
		var opts := []
		for s in summons_of(b):
			opts.append({"id": str(s["id"]), "label": "Togli il %s in %s" % [D.SUMMONS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
		var r = await decide(b, {"type": "summon_remove", "prompt": "Tutti gli evocati sono sulla mappa: quale togliere?", "opts": opts})
		var su := find_obj(summons, int(str(r)))
		summons.erase(su)
		ev({"t": "unsummon", "id": su["id"]})
	var l := at
	if l == "":
		if spots.is_empty():
			spots = summon_spots(b)
		l = await pick_loc(b, "Dove mettere il %s?" % D.SUMMONS[kind]["n"], spots, false, "summon_loc")
	if l == "":
		return
	var su2 := {"id": new_id(), "owner": b, "kind": kind, "loc": l, "wounds": 0}
	summons.append(su2)
	ev({"t": "summon", "ci": b, "kind": kind, "loc": l, "id": su2["id"]})
	log_msg("%s evoca un %s in %s." % [cname(b), D.SUMMONS[kind]["n"], loc_label(l)])
	if kind == "banshee" and has_up(b, "pandemonium"):
		await summon_step(b, su2, "Pandemonio: la Banshee può muovere di 1 passo", true)


## Un evocato muove di 1 passo (may: può restare). Restituisce true se si è mosso.
func summon_step(b: int, su: Dictionary, prompt: String, may := true) -> bool:
	var st := step_targets(su["loc"], beast_hab(b))
	var opts := []
	for d in DIRS:
		if st.has(d):
			opts.append({"id": st[d], "label": "%s → %s" % [D.DIR_IT[d], loc_label(st[d])], "loc": st[d]})
	if opts.is_empty():
		return false
	if may:
		opts.append({"id": "stop", "label": "Resta"})
	var r = await decide(b, {"type": "step", "prompt": prompt, "opts": opts, "ask_single": true, "mover": "summon:%d" % su["id"]})
	if str(r) == "stop":
		return false
	await move_being_to({"t": "summon", "id": su["id"]}, str(r))
	return true


## Ogni evocato della Bestia compie un'azione: muovere, attaccare o usare la sua abilità.
func summons_act(b: int, only_kind := "", max_n := 99) -> void:
	var todo: Array = summons_of(b).filter(func(s): return only_kind == "" or s["kind"] == only_kind)
	var n := 0
	while not todo.is_empty() and n < max_n and not game_over:
		var opts := []
		for s in todo:
			opts.append({"id": str(s["id"]), "label": "%s in %s" % [D.SUMMONS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
		opts.append({"id": "end", "label": "Basta così"})
		var r = await decide(b, {"type": "summon_pick", "prompt": "Quale evocato agisce?", "opts": opts, "ask_single": true})
		if str(r) == "end":
			break
		var su := find_obj(summons, int(str(r)))
		todo = todo.filter(func(s): return s["id"] != int(str(r)))
		if su.is_empty():
			continue
		await summon_action(b, su)
		n += 1


func summon_action(b: int, su: Dictionary) -> void:
	var kind: String = su["kind"]
	var opts := [{"id": "move", "label": "Muovi di 1 passo"}]
	var tg := summon_targets(su["loc"])
	if not tg.is_empty():
		opts.append({"id": "attack", "label": "Attacca"})
	opts.append({"id": "ability", "label": D.SUMMONS[kind]["an"] + ": " + D.SUMMONS[kind]["at"]})
	var r = await decide(b, {"type": "summon_action", "prompt": "Azione del %s" % D.SUMMONS[kind]["n"], "opts": opts, "ask_single": true})
	match str(r):
		"move":
			await summon_step(b, su, "Muovi il %s" % D.SUMMONS[kind]["n"], false)
		"attack":
			await summon_attack(b, su)
		"ability":
			await summon_ability(b, su)


func summon_targets(l: String) -> Array:
	var out := []
	for h in hunters_at(l):
		out.append({"t": "hunter", "ci": h})
	for s in settlers_at(l):
		out.append({"t": "settler", "id": s["id"], "kind": s["kind"]})
	for a in animals_at(l):
		out.append({"t": "animal", "id": a["id"], "kind": a["kind"]})
	if towers_at(l) > 0:
		out.append({"t": "tower", "loc": l})
	if companion == l:
		out.append({"t": "companion"})
	return out


## Attacco di un evocato (1 danno; gli evocati non usano Poteri antichi né danno rancori).
func summon_attack(b: int, su: Dictionary, grudges := false) -> bool:
	var tg := summon_targets(su["loc"])
	if tg.is_empty():
		return false
	var opts := []
	for t in tg:
		opts.append({"id": being_key(t) if t["t"] != "tower" else "tower", "label": target_label(t), "ref": t, "loc": su["loc"]})
	var r = await decide(b, {"type": "target", "prompt": "Bersaglio del %s" % D.SUMMONS[su["kind"]]["n"], "opts": opts})
	var t: Dictionary = tg[0]
	for op in opts:
		if str(op["id"]) == str(r):
			t = op["ref"]
	var dmg := 1
	if su["kind"] == "banshee" and has_up(b, "deaths_lament"):
		dmg = 2
	ev({"t": "sattack", "id": su["id"], "loc": su["loc"], "target": t, "dmg": dmg})
	log_msg("%s attacca %s." % [D.SUMMONS[su["kind"]]["n"], target_label(t)])
	var src := {"kind": "attack", "ci": b} if grudges else {"kind": "summon", "sid": su["id"]}
	return await damage(t, dmg, src)


func summon_ability(b: int, su: Dictionary) -> void:
	match str(su["kind"]):
		"polyp":
			var steps := 2 if has_up(b, "lurking_dead") else 1
			for i in range(steps):
				if not await summon_step(b, su, "Esplosione: il Polipo muove", i > 0):
					break
			var l: String = su["loc"]
			await kill_summon(su)
			log_msg("Il Polipo esplode in %s." % loc_label(l))
			for t in summon_targets(l):
				if t["t"] != "companion":
					await damage(t, 1, {"kind": "summon", "sid": su["id"]})
			await transform(l, b, "swamp")
		"wolf":
			await wolf_charge(b, su)
		"banshee":
			await lure(b, su["loc"])
		"basilisk":
			var cand := []
			for l in nearby(su["loc"]):
				for h in hunters_at(l):
					cand.append(h)
			if cand.is_empty():
				return
			var opts := []
			for h in cand:
				opts.append({"id": str(h), "label": target_label({"t": "hunter", "ci": h}), "loc": ch[h]["loc"]})
			var r = await decide(b, {"type": "target", "prompt": "Pietrificare: quale cacciatore?", "opts": opts})
			var h2 := int(str(r))
			ch[h2]["skip"] = int(ch[h2].get("skip", 0)) + 1
			log_msg("%s è pietrificato: salterà il prossimo turno." % cname(h2))
			await damage({"t": "hunter", "ci": h2}, 2 if has_up(b, "fatal_gaze") else 1, {"kind": "summon", "sid": su["id"]})
		"warhog":
			await push(b, su)
		"changeling":
			var best := ""
			var bd := 99
			for h in alive_hunters():
				var d := dist(su["loc"], ch[h]["loc"])
				if d < bd:
					bd = d
					best = ch[h]["loc"]
			if best != "":
				await move_being_to({"t": "summon", "id": su["id"]}, best)
				await transform(best, b)
		"admirer":
			var killed := await summon_attack(b, su)
			if killed:
				var back := mini(2, int(ch[b].get("drained", 0)))
				ch[b]["drained"] -= back
				ch[b]["souls"] += back
				log_msg("Furto d'anime: %d anime tornano attive." % back)
				await souls_returned(b)
		"yagi":
			await ram(b, su)
		"abomination":
			var opts2 := []
			for l in nearby(su["loc"]):
				if l == su["loc"]:
					continue
				for t in beings_at(l, true):
					if t["t"] == "summon" and t["id"] == su["id"]:
						continue
					opts2.append({"id": being_key(t), "label": "%s da %s" % [being_name(t), loc_label(l)], "ref": t, "loc": l})
			if opts2.is_empty():
				return
			var r2 = await decide(b, {"type": "target", "prompt": "Risucchio abissale: chi trascinare?", "opts": opts2})
			for op in opts2:
				if str(op["id"]) == str(r2):
					await move_being_to(op["ref"], su["loc"])
			if has_up(b, "dark_spawn") and await yesno(b, "Progenie oscura: l'Abominio attacca?"):
				await summon_attack(b, su)
		"dreamer":
			var killed2 := await summon_attack(b, su)
			if killed2 and summons.has(su):
				await kill_summon(su)
				await gain_grudge(b, 1, "Devozione")


func wolf_charge(b: int, su: Dictionary) -> void:
	var r = await decide(b, {"type": "order", "prompt": "Carica del Lupo", "opts": [{"id": "am", "label": "Attacca, poi muovi"}, {"id": "ma", "label": "Muovi, poi attacca"}], "ask_single": true})
	if str(r) == "am":
		await summon_attack(b, su)
		if summons.has(su):
			await summon_step(b, su, "Il Lupo muove di 1 passo")
	else:
		await summon_step(b, su, "Il Lupo muove di 1 passo")
		await summon_attack(b, su)


func wolf_charge_after(b: int) -> void:
	var wolves: Array = summons_of(b).filter(func(s): return s["kind"] == "wolf")
	if wolves.is_empty():
		return
	var opts := [{"id": "no", "label": "Nessun Lupo"}]
	for w in wolves:
		opts.append({"id": str(w["id"]), "label": "Lupo in " + loc_label(w["loc"]), "loc": w["loc"]})
	var r = await decide(b, {"type": "summon_pick", "prompt": "Grande ululato: un Lupo può usare Carica", "opts": opts, "ask_single": true})
	if str(r) != "no":
		await wolf_charge(b, find_obj(summons, int(str(r))))


## Richiamo: ogni cacciatore, colono e animale vicino si sposta in l.
func lure(b: int, l: String) -> void:
	for nl in nearby(l):
		if nl == l:
			continue
		for t in beings_at(nl, false):
			if t["t"] in ["hunter", "settler", "animal"]:
				await move_being_to(t, l)
	log_msg("Richiamo: gli esseri vicini sono attirati in %s." % loc_label(l))


## Spinta del Cinghiale da guerra: 2 passi nella stessa direzione portando con sé chi incontra.
func push(b: int, su: Dictionary) -> void:
	var opts := []
	for d in DIRS:
		var line := line_from(su["loc"], d, 2, beast_hab(b))
		if line.size() == 2:
			opts.append({"id": d, "label": "%s → %s" % [D.DIR_IT[d], loc_label(line[1])], "loc": line[1]})
	if opts.is_empty():
		return
	var r = await decide(b, {"type": "dir", "prompt": "Spinta: direzione", "opts": opts, "ask_single": true})
	var line2 := line_from(su["loc"], str(r), 2, beast_hab(b))
	var carried := []
	for t in beings_at(su["loc"], false):
		if t["t"] in ["hunter", "settler", "animal"]:
			carried.append(t)
	for l in line2:
		for t in beings_at(l, false):
			if t["t"] in ["hunter", "settler", "animal"] and not carried.has(t):
				carried.append(t)
		await move_being_to({"t": "summon", "id": su["id"]}, l)
	for t in carried:
		await move_being_to(t, su["loc"])
	log_msg("Spinta del Cinghiale da guerra fino a %s." % loc_label(su["loc"]))


## Cozzata: muovi fino a 1 passo; sposta un cacciatore/animale/colono del luogo in un luogo vicino.
## su = evocato oppure {} per Thalduk stesso.
func ram(b: int, su: Dictionary) -> void:
	var is_me := su.is_empty()
	var r = await decide(b, {"type": "order", "prompt": "Cozzata", "opts": [{"id": "mp", "label": "Prima muovi, poi sposta un essere"}, {"id": "pm", "label": "Prima sposta un essere, poi muovi"}], "ask_single": true})
	for step in (["m", "p"] if str(r) == "mp" else ["p", "m"]):
		if step == "m":
			if is_me:
				await beast_move(b, 1, {"upto": true, "label": "Cozzata"})
			elif summons.has(su):
				await summon_step(b, su, "Cozzata: lo Yagi muove", true)
		else:
			var l: String = ch[b]["loc"] if is_me else su["loc"]
			var opts := []
			for t in beings_at(l, false):
				if t["t"] in ["hunter", "settler", "animal"]:
					opts.append({"id": being_key(t), "label": target_label(t), "ref": t, "loc": l})
			if opts.is_empty():
				continue
			opts.append({"id": "no", "label": "Nessuno"})
			var p = await decide(b, {"type": "target", "prompt": "Cozzata: chi spostare?", "opts": opts, "ask_single": true})
			if str(p) == "no":
				continue
			var tg: Dictionary = {}
			for op in opts:
				if str(op["id"]) == str(p):
					tg = op["ref"]
			var dests := nearby(l).filter(func(x): return x != l)
			var d2 := await pick_loc(b, "Dove spostarlo?", dests)
			if d2 != "":
				await move_being_to(tg, d2)
				if has_up(b, "behorned"):
					await damage(tg, 1, {"kind": "effect"})


func eruption(b: int) -> void:
	var opts := [{"id": "no", "label": "Nessuno"}, {"id": "me", "label": "Thalduk usa Cozzata"}]
	for s in summons_of(b):
		if s["kind"] == "yagi":
			opts.append({"id": str(s["id"]), "label": "Yagi in " + loc_label(s["loc"]), "loc": s["loc"]})
	var r = await decide(b, {"type": "summon_pick", "prompt": "Eruzione: chi usa Cozzata?", "opts": opts, "ask_single": true})
	if str(r) == "me":
		await ram(b, {})
	elif str(r) != "no":
		await ram(b, find_obj(summons, int(str(r))))


## Un evocato (di un tipo, se dato) può muovere fino a n passi.
func summon_free_move(b: int, kind: String, n: int, prompt: String) -> void:
	var mine: Array = summons_of(b).filter(func(s): return kind == "" or s["kind"] == kind)
	if mine.is_empty():
		return
	var opts := [{"id": "no", "label": "Nessuno"}]
	for s in mine:
		opts.append({"id": str(s["id"]), "label": "%s in %s" % [D.SUMMONS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
	var r = await decide(b, {"type": "summon_pick", "prompt": prompt, "opts": opts, "ask_single": true})
	if str(r) == "no":
		return
	var su := find_obj(summons, int(str(r)))
	for i in range(n):
		if not await summon_step(b, su, prompt, true):
			break


func souls_returned(b: int) -> void:
	if has_up(b, "reverance"):
		await summon_free_move(b, "admirer", 1, "Reverenza: un Ammiratore può muovere di 1 passo")


# ================================================================== trasformazioni, torri, trappole

## Trasforma il luogo l. by: Bestia (habitat preferito; Akkeron mette palude abissale) o cacciatore (insediamento).
func transform(l: String, by: int, force_hab := "") -> bool:
	if protected.has(l):
		return false
	var h := force_hab
	if h == "":
		if is_beast(by):
			h = "abyss" if ch[by].get("abyss", false) else beast_hab(by)
		else:
			h = "settlement"
	var cur := habs(l)
	if tokens.get(l, "") == h or (not tokens.has(l) and cur.size() == 1 and cur[0] == h):
		return false
	if h == "swamp" and is_abyss(l):
		return false
	tokens[l] = h
	ev({"t": "tf", "loc": l, "hab": h})
	log_msg("%s diventa %s." % [loc_label(l).get_slice(" (", 0) if LOCS[l].has("name") else "Un luogo", D.HAB_IT[h]])
	if h == "abyss" and is_beast(by) and has_up(by, "echo"):
		await summon_free_move(by, "abomination", 1, "Eco: un Abominio può muovere di 1 passo")
	return true


func place_tower(l: String) -> void:
	if towers.size() >= 6:
		towers.remove_at(0)
	towers.append(l)
	ev({"t": "tower", "loc": l})
	log_msg("Una torre di guardia sorge in %s." % loc_label(l))
	await refresh_trails()


## Mette una trappola: zona e habitat li sceglie il cacciatore (la Bestia non li vede).
func place_trap(h: int, cid: String, zone_only := "") -> bool:
	var zs := []
	for z in zone_ids():
		if zone_only != "" and z != zone_only:
			continue
		if traps.filter(func(t): return t["zone"] == z).size() < 3:
			zs.append(z)
	if zs.is_empty():
		return false
	var opts := []
	for z in zs:
		opts.append({"id": z, "label": "Zona " + str(M["zones"][z])})
	var z2 = await decide(h, {"type": "trap_zone", "prompt": "In quale zona mettere %s?" % D.cname(cid), "opts": opts, "ask_single": true, "secret": true})
	var hopts := []
	for hb in ["forest", "swamp", "cave", "settlement"]:
		hopts.append({"id": hb, "label": D.HAB_IT[hb].capitalize()})
	var hb2 = await decide(h, {"type": "trap_hab", "prompt": "Habitat sotto la trappola (si attiva se la Bestia si rivela lì)", "opts": hopts, "ask_single": true, "secret": true})
	traps.append({"zone": str(z2), "card": cid, "hab": str(hb2), "owner": h})
	ev({"t": "trap", "zone": str(z2)})
	log_msg("%s mette una trappola nella zona %s." % [cname(h), M["zones"][str(z2)]])
	return true


## Trappole che possono scattare: nella zona del luogo (il centro è in tutte) e con l'habitat giusto.
func trigger_traps(b: int) -> void:
	var l: String = ch[b]["loc"]
	for t in traps.duplicate():
		if not traps.has(t) or game_over:
			continue
		if not in_zone(l, t["zone"]) or not has_hab(l, t["hab"]):
			continue
		var h: int = t["owner"]
		if ch[h]["dead"]:
			h = alive_hunters()[0] if not alive_hunters().is_empty() else -1
		if h < 0:
			break
		if not await yesno(h, "La Bestia si è rivelata su %s: attivare %s?" % [D.HAB_IT[t["hab"]], D.cname(t["card"])], "Attiva", "Non ora", "trap_trigger"):
			continue
		traps.erase(t)
		ev({"t": "trap_fire", "zone": t["zone"], "card": t["card"], "hab": t["hab"]})
		log_msg("[b]Scatta %s![/b]" % D.cname(t["card"]))
		var cancelled := false
		if turn_ci == b:
			cancelled = await offer_cancel(b)
		if not cancelled:
			match str(D.ITEMS[D.base_id(t["card"])]["trap"]):
				"fire":
					await damage({"t": "beast", "ci": b}, 1, {"kind": "trap"})
				"hex":
					await beast_discard(b, 2)
				"shriek":
					for hh in alive_hunters():
						await hunter_move(hh, 2, {"upto": true, "label": "Trappola urlante: %s può muovere" % cname(hh)})
				"ritual":
					var opts := []
					for s in settlers:
						opts.append({"id": str(s["id"]), "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
					if not opts.is_empty():
						var r = await decide(h, {"type": "settler", "prompt": "Quale colono riceve l'Armatura?", "opts": opts})
						var s2 := find_obj(settlers, int(str(r)))
						s2["armor"] = int(s2.get("armor", 0)) + 1
		var gone := true
		for k in hunters():
			if has_up(k, "scavenger") and not ch[k]["dead"]:
				ch[k]["hand"].append(t["card"])
				log_msg("Recuperatore: %s riprende la trappola." % cname(k))
				gone = false
				break
		if gone:
			item_disc.append(t["card"])


## La Bestia scarta n carte a sua scelta.
func beast_discard(b: int, n: int) -> void:
	for i in range(n):
		var hand: Array = ch[b]["hand"]
		if hand.is_empty():
			return
		var opts := []
		for c in hand:
			opts.append({"id": c, "label": D.cname(c), "card": c})
		var r = await decide(b, {"type": "discard", "prompt": "Scarta una carta (%d di %d)" % [i + 1, n], "opts": opts, "secret": true})
		hand.erase(str(r))
		_discard_card(b, str(r))
		log_msg("%s scarta %s." % [cname(b), D.cname(str(r))])


# ================================================================== rovine

func claim_ruins_at_turn_start(ci: int) -> void:
	var team := side(ci)
	var places := []
	if is_beast(ci):
		places.append(ch[ci]["loc"])
		for s in summons_of(ci):
			places.append(s["loc"])
	else:
		places.append(ch[ci]["loc"])
		if ch[ci].get("companion", false) and companion != "":
			places.append(companion)
	for l in places:
		var r := ruin_at(l)
		if r == "" or ruins.get(r, "") == team or not K.has("ruins"):
			continue
		var name: String = M["ruins"][r]
		if await yesno(ci, "Sei sulla rovina %s: prenderne il controllo?" % name, "Prendi il controllo", "Lascia stare", "ruin"):
			await claim_ruin(ci, r)


func claim_ruin(ci: int, r: String) -> void:
	var team := side(ci)
	ruins[r] = team
	ev({"t": "ruin", "ruin": r, "team": team})
	log_msg("[b]%s prende il controllo di %s.[/b]" % ["La Bestia" if team == "B" else cname(ci), M["ruins"][r]])
	var rw: Dictionary = K["ruins"][r]
	await run_ops(ci, rw["b"] if team == "B" else rw["h"], {"card": "ruin:" + r})


# segnaposti implementati negli strati superiori
func run_ops(ci: int, ops: Array, ctx: Dictionary) -> void:
	pass


func offer_reaction(trigger: String, data: Dictionary) -> bool:
	return false


func offer_cancel(b: int) -> bool:
	return false


func check_contract_end() -> void:
	pass


func end_game(winner: String, why: String) -> void:
	pass
