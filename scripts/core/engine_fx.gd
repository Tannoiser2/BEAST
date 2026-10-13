class_name BSFx
extends BSRules
## Carte: giocabilità, risoluzione degli effetti (interprete delle operazioni), reazioni e potenziamenti
## che scattano dopo una carta.

const OP_IT := {
	"mv": "Muovi di %d passi", "mvu": "Muovi fino a %d passi", "atk": "Attacca", "search": "Perlustra il tuo luogo",
	"item": "Prendi un Oggetto del cacciatore", "talent": "Prendi un Talento bestiale", "grudge": "Guadagna %d rancore",
	"ap": "Prendi un Potere antico", "summon": "Evoca", "tf_here": "Trasforma il tuo luogo", "tf_near_all": "Trasforma ogni luogo vicino",
	"tf_near_upto": "Trasforma fino a %d luoghi vicini", "relocate_set": "Spostati in un insediamento",
	"zone_hunters_mv1": "Ogni cacciatore nella tua zona può muovere di 1 passo", "summons_mv1": "Muovi i tuoi evocati di 1 passo",
	"reveal_last": "Rivela l'ultima carta Movimento", "buy_upgrade": "Compra un potenziamento", "atk_summon_near": "Attacca un evocato vicino",
	"heal_hunter_near": "Un cacciatore vicino recupera 1 ferita", "search_atk": "Perlustra e attacca",
	"item_atk_summon": "Prendi un Oggetto e attacca un evocato vicino", "activate_ruin": "Attiva una Rovina nella tua zona",
	"to_banshee": "Spostati su una Banshee e rivelati", "one_summon_act": "Una Banshee può agire", "abyss_near": "Trasforma una palude vicina in palude abissale",
	"abyss_here": "Trasforma il tuo luogo in palude abissale", "steal_grudge": "Prendi 1 rancore da un cacciatore vicino",
	"scout_move": "Muovi fino a 2 passi (se sei su un insediamento)", "command_hunter": "Muovi un cacciatore della tua zona",
	"command_settler": "Muovi un colono della tua zona", "me_and_fylgja_mv1": "Tu e Fylgja muovete di 1 passo", "return_hook": "Riprendi in mano Rampino",
	"free_trap": "Metti in gioco una trappola gratis",
}


func op_label(op: Array) -> String:
	var k: String = op[0]
	var t: String = OP_IT.get(k, k)
	if t.contains("%d") and op.size() > 1:
		t = t % int(op[1])
		if k == "grudge" and int(op[1]) > 1:
			t = t.replace("rancore", "rancori")
	if k == "mv" and op.size() > 1 and int(op[1]) == 1:
		t = "Muovi di 1 passo"
	return t


# ================================================================== giocabilità

## Costo in rancori (Sunken Ruins e simili possono scontare i potenziamenti, non le carte).
func card_cost(cid: String) -> int:
	return int(D.card(cid).get("cost", 0))


func lock_ok(ci: int, cid: String) -> bool:
	var lk: String = D.card(cid).get("lock", "")
	if lk == "" or not is_beast(ci):
		return true
	if lk == "*":
		lk = beast_hab(ci)
	if K.get("abyss_pref", false) and lk == beast_hab(ci) and is_abyss(ch[ci]["loc"]):
		return true
	return has_hab(ch[ci]["loc"], lk)


## Modi in cui una carta si può giocare ora: "R", "B", "O" (sovraccarica), "C" (carica d'anime).
func card_modes(ci: int, cid: String, red_free: bool, blue_free: bool) -> Array:
	var c := D.card(cid)
	if c.is_empty():
		return []
	var col: String = c.get("c", "B")
	var k := D.kind(cid)
	if k == "action":
		pass
	elif k == "item" and is_beast(ci):
		return []
	elif k == "talent" and not is_beast(ci):
		return []
	if col == "X":
		return []
	if card_cost(cid) > int(ch[ci]["grudges"]):
		return []
	if not lock_ok(ci, cid):
		return []
	if c.get("not_last", false) and n_actions(ci) <= 1:
		return []
	if c.get("only_revealed", false) and not ch[ci]["revealed"]:
		return []
	var out := []
	match col:
		"R":
			if red_free:
				out.append("R")
		"B", "T":
			if blue_free:
				out.append("B")
		"S":
			if red_free:
				out.append("R")
			if blue_free:
				out.append("B")
		"O":
			if red_free:
				out.append("R")
			if red_free and blue_free:
				out.append("O")
	if c.has("ch") and ch[ci].get("souls", -1) >= int(c["ch"]):
		var base := out.duplicate()
		for m in base:
			if m in ["R", "B"]:
				out.append("C" + m)
	if col == "T" and traps.size() >= 3 * zone_ids().size():
		return []
	return out


func mode_label(cid: String, m: String) -> String:
	var n := D.cname(cid)
	var c := D.card(cid)
	match m:
		"O":
			return n + " (sovraccarica: rossa + blu)"
		"CR", "CB":
			return n + " (Carica d'anime: %d)" % int(c.get("ch", 0))
	if c.get("c", "") == "S":
		return n + (" (come rossa)" if m == "R" else " (come blu)")
	return n


# ================================================================== giocare una carta

## Gioca la carta cid nel modo m. Restituisce il contesto della risoluzione.
func play_card(ci: int, cid: String, m: String) -> Dictionary:
	var c := D.card(cid)
	var cost := card_cost(cid)
	ch[ci]["hand"].erase(cid)
	if cost > 0:
		ch[ci]["grudges"] -= cost
	var ctx := {"ci": ci, "card": cid, "mode": m, "killed": false, "transformed": false}
	var k := D.kind(cid)
	ev({"t": "play", "ci": ci, "card": cid, "mode": m})
	log_msg("%s gioca [b]%s[/b]." % [cname(ci), mode_label(cid, m)])
	var fx: Array
	if k == "action":
		fx = c["bfx"] if is_beast(ci) else c["hfx"]
	elif m == "O":
		fx = c["ofx"]
	elif m.begins_with("C"):
		fx = c["chfx"]
		var cost_s := int(c["ch"])
		ch[ci]["souls"] -= cost_s
		ch[ci]["drained"] = int(ch[ci].get("drained", 0)) + cost_s
		log_msg("Carica d'anime: %d anime prosciugate." % cost_s)
		if ch[ci]["souls"] == 0:
			await reveal(ci, "anime esaurite")
	else:
		fx = c.get("fx", ["seq"])
	# reazioni e potenziamenti che scattano «quando giochi»
	await before_effect(ci, cid, m, ctx)
	if c.get("c", "") == "T":
		var ok := await place_trap(ci, cid)
		if not ok:
			item_disc.append(cid)
		await after_effect(ci, cid, m, ctx)
		return ctx
	await run_fx(ci, fx, ctx)
	_discard_card(ci, cid)
	await after_effect(ci, cid, m, ctx)
	changed.emit()
	return ctx


## Risolve un effetto: ["seq"|"any"|"one", op, op, …].
func run_fx(ci: int, fx: Array, ctx: Dictionary) -> void:
	if fx.is_empty() or game_over:
		return
	var mode: String = fx[0]
	var ops: Array = fx.slice(1)
	match mode:
		"seq":
			for op in ops:
				if game_over or ch[ci]["dead"]:
					return
				await run_op(ci, op, ctx)
		"any":
			var left := ops.duplicate()
			while not left.is_empty() and not game_over and not ch[ci]["dead"]:
				if left.size() == 1 and not ctx.get("optional_last", true):
					await run_op(ci, left[0], ctx)
					break
				var opts := []
				for i in range(left.size()):
					opts.append({"id": str(i), "label": op_label(left[i])})
				opts.append({"id": "end", "label": "Basta così"})
				var r = await decide(ci, {"type": "fx_order", "prompt": "In qualsiasi ordine (ognuno facoltativo): cosa fai ora?", "opts": opts, "ask_single": true, "card": ctx.get("card", "")})
				if str(r) == "end":
					break
				var op: Array = left[int(str(r))]
				left.remove_at(int(str(r)))
				await run_op(ci, op, ctx)
		"one":
			var opts2 := []
			for i in range(ops.size()):
				opts2.append({"id": str(i), "label": op_label(ops[i])})
			var r2 = await decide(ci, {"type": "fx_one", "prompt": "Scegli un effetto", "opts": opts2, "ask_single": true, "card": ctx.get("card", "")})
			await run_op(ci, ops[int(str(r2))], ctx)


func run_ops(ci: int, ops: Array, ctx: Dictionary) -> void:
	for op in ops:
		if game_over:
			return
		await run_op(ci, op, ctx)


## Interprete delle operazioni elementari degli effetti.
func run_op(ci: int, op: Array, ctx: Dictionary) -> void:
	var k: String = op[0]
	var a1 = op[1] if op.size() > 1 else null
	var me: Dictionary = ch[ci]
	var beast := is_beast(ci)
	match k:
		# ---------------------------------------------------------- movimento
		"mv":
			if beast:
				await beast_move(ci, int(a1))
			else:
				await hunter_move(ci, int(a1))
		"mvu":
			if beast:
				await beast_move(ci, int(a1), {"upto": true})
			else:
				await hunter_move(ci, int(a1), {"upto": true})
		"mv_same":
			await beast_move(ci, int(a1), {"same": true, "nomove": int(op[2]) == 1 if op.size() > 2 else false})
		"mv_zone":
			if beast:
				await beast_move(ci, int(a1), {"zone": true})
			else:
				await hunter_move(ci, int(a1), {"zone": zone_of(me["loc"])})
		"mv_dash":
			var z := zone_of(me["loc"])
			var n := 1
			for h in alive_hunters():
				if in_zone(ch[h]["loc"], z):
					n += 1
			await beast_move(ci, n)
		"mv_lurk":
			var extra := 1 if has_up(ci, "culling") and dead_sheep >= 4 else 0
			await beast_move(ci, 1 + extra)
		"mv_flicker":
			if deaths_today > 0:
				await beast_move(ci, deaths_today)
		"mv_slither":
			await beast_move(ci, 1)
			if has_hab(me["loc"], "swamp"):
				await beast_move(ci, 1)
		"mv_void":
			await beast_move(ci, 1)
			if is_abyss(me["loc"]) and await yesno(ci, "Vuoto: sei su una palude abissale, muovere di 1 passo in più?"):
				await beast_move(ci, 1)
		"mv_uprise":
			var extra2 := 1 if me.get("reborn", false) and not summons_of(ci).is_empty() else 0
			await beast_move(ci, 1 + extra2)
		"mv_per_summon":
			var n2 := summons.size()
			if n2 > 0:
				await beast_move(ci, n2)
		"mv_false":
			await beast_move(ci, int(a1), {"fake": true})
		"prowl", "prowl_zone":
			var z0 := zone_of(me["loc"])
			var reps := 0
			while not me["dead"] and reps < 6:
				reps += 1
				if await hunter_move(ci, 1) == 0:
					break
				if k == "prowl_zone" and not in_zone(me["loc"], z0):
					break
				if not trail_at(me["loc"]):
					break
				if not await yesno(ci, "C'è una Traccia: ripetere il movimento?"):
					break
		"track":
			await hunter_move(ci, 1)
			if trail_at(me["loc"]):
				await hunter_move(ci, 1, {"upto": true, "label": "Traccia trovata: passo in più"})
			ctx["track_end"] = me["loc"]
		"blood_track":
			await hunter_move(ci, 1)
			if trail_at(me["loc"]) and int(me.get("blood", 0)) >= 1 and await yesno(ci, "Traccia trovata: spendere 1 sangue per muovere di 2 passi?"):
				me["blood"] -= 1
				await hunter_move(ci, 2, {"upto": true})
			ctx["track_end"] = me["loc"]
		"relocate_set":
			var t := await pick_loc(ci, "Spostati in un insediamento", settlements().filter(func(x): return x != me["loc"]))
			if t != "":
				await move_hunter_to(ci, t, false)
		"relocate_range":
			var dm := dist_map(me["loc"], int(a1), "settlement")
			var t2 := await pick_loc(ci, "Spostati in un luogo a non più di %d passi" % int(a1), dm.keys().filter(func(x): return x != me["loc"]))
			if t2 != "":
				await move_hunter_to(ci, t2, false)
		"hunter_to_hunter":
			var hs := alive_hunters()
			if hs.size() >= 2:
				var opts := []
				for h in hs:
					opts.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
				var who := int(str(await decide(ci, {"type": "hunter", "prompt": "Passaggio nascosto: quale cacciatore spostare?", "opts": opts})))
				var dests := []
				for h in hs:
					if h != who and not dests.has(ch[h]["loc"]):
						dests.append(ch[h]["loc"])
				var t3 := await pick_loc(ci, "Nel luogo di quale cacciatore?", dests)
				if t3 != "":
					await move_hunter_to(who, t3, false)
		"scout_move":
			if has_hab(me["loc"], "settlement"):
				await hunter_move(ci, 2, {"upto": true})
		"to_banshee":
			var bs: Array = summons_of(ci).filter(func(s): return s["kind"] == "banshee")
			if not bs.is_empty():
				var t4 := await pick_loc(ci, "Su quale Banshee spostarti?", bs.map(func(s): return s["loc"]))
				if t4 != "":
					secret_relocate(ci, t4)
					await reveal(ci, "Passo d'ombra")
		"rapier":
			var opts2 := []
			for d in DIRS:
				var line := line_from(me["loc"], d, 3, "settlement")
				for i in range(line.size()):
					opts2.append({"id": line[i], "label": "%s, %d pass%s → %s" % [D.DIR_IT[d], i + 1, "o" if i == 0 else "i", loc_label(line[i])], "loc": line[i]})
			if not opts2.is_empty():
				var t5 = await decide(ci, {"type": "loc", "prompt": "Stocco di fiamma: spostati fino a 3 passi in una direzione", "opts": opts2})
				await move_hunter_to(ci, str(t5), false)
		"rapier_move":
			var opts3 := []
			for d in DIRS:
				if not line_from(me["loc"], d, 1, "settlement").is_empty():
					opts3.append({"id": d, "label": D.DIR_IT[d]})
			if not opts3.is_empty():
				var d2 = await decide(ci, {"type": "dir", "prompt": "Stocco di fiamma potenziato: direzione", "opts": opts3, "ask_single": true})
				var carry := {}
				if has_up(ci, "fling"):
					var cands := beings_at(me["loc"], true).filter(func(t): return not (t["t"] == "hunter" and t["ci"] == ci))
					if not cands.is_empty():
						var o4 := [{"id": "no", "label": "Nessuno"}]
						for t in cands:
							o4.append({"id": being_key(t), "label": being_name(t), "ref": t})
						var r4 = await decide(ci, {"type": "target", "prompt": "Lancio: portare con te un essere?", "opts": o4, "ask_single": true})
						for o5 in o4:
							if str(o5["id"]) == str(r4) and o5.has("ref"):
								carry = o5["ref"]
				await hunter_move(ci, 3, {"upto": true, "same": true, "label": "Stocco di fiamma"})
				if not carry.is_empty():
					await move_being_to(carry, me["loc"])
		"me_and_fylgja_mv1":
			await hunter_move(ci, 1, {"upto": true})
			if companion != "":
				await fylgja_step(ci, 1)
		"return_hook":
			for a in me["abil_disc"].duplicate():
				if D.base_id(a) == "grappling_hook":
					me["abil_disc"].erase(a)
					me["hand"].append(a)
		# ---------------------------------------------------------- combattimento
		"atk":
			var r := await attack(ci, {"bonus": int(a1) if a1 != null else 0, "animal_bonus": int(op[2]) if op.size() > 2 else 0, "card": ctx.get("card", "")})
			if r["killed"]:
				ctx["killed"] = true
			ctx["attacked"] = true
		"atk_hydra":
			var targets := 1 + (1 if has_up(ci, "wrath_eirtir") else 0) + (1 if has_up(ci, "mendrs_fury") else 0)
			var r2 := await attack(ci, {"card": ctx.get("card", "")})
			if r2["killed"]:
				ctx["killed"] = true
			for i in range(targets - 1):
				if game_over or not await yesno(ci, "Idra: attaccare un altro bersaglio vicino?"):
					break
				var r3 := await attack(ci, {"near": true})
				if r3["killed"]:
					ctx["killed"] = true
		"atk_summon_near":
			var filt := "summon"
			if has_up(ci, "ballista"):
				filt = ""
			await attack(ci, {"filter": filt, "near": true})
		"atk_animal":
			var r5 := await attack(ci, {"filter": "animal"})
			if r5["killed"]:
				me["blood"] = mini(4, int(me.get("blood", 0)) + 1)
		"atk_other_animals_near":
			for l in nearby(me["loc"]):
				for an in animals_at(l):
					await damage({"t": "animal", "id": an["id"], "kind": an["kind"]}, beast_damage(ci), {"kind": "attack", "ci": ci})
		"search":
			await search(ci, me["loc"])
		"search_near":
			var t6 := await pick_loc(ci, "Perlustra un luogo vicino", nearby(me["loc"], "settlement"))
			if t6 != "":
				await search(ci, t6)
		"search_range":
			var t7 := await pick_loc(ci, "Perlustra un luogo a non più di %d passi" % int(a1), dist_map(me["loc"], int(a1), "settlement").keys())
			if t7 != "":
				await search(ci, t7)
		"search_atk":
			await search(ci, me["loc"])
			await attack(ci)
		"item_atk_summon":
			await gain_item(ci)
			await attack(ci, {"filter": "summon", "near": true})
		"blood_hunt":
			if int(me.get("blood", 0)) >= 2 and await yesno(ci, "Spendere 2 sangue per muovere di 1 passo e attaccare?"):
				me["blood"] -= 2
				await hunter_move(ci, 1)
				await attack(ci)
		"grudge_if_kill":
			if ctx.get("killed", false):
				await gain_grudge(ci, int(a1), "vittima uccisa")
		"summon_if_kill":
			if ctx.get("killed", false):
				await place_summon(ci, nearby(me["loc"]))
		"banshee_if_kill":
			if ctx.get("killed", false):
				await place_summon(ci, [], me["loc"])
		"admirer_if_kill":
			if ctx.get("killed", false):
				var fs := nearby(me["loc"]).filter(func(x): return has_hab(x, "forest"))
				if not fs.is_empty():
					await place_summon(ci, fs)
		"dmg_near_summons":
			for l in nearby(me["loc"], "settlement"):
				for su in summons_at(l):
					await damage({"t": "summon", "id": su["id"], "kind": su["kind"]}, int(a1), {"kind": "attack", "ci": ci})
		"swarm":
			for su in summons_of(ci).duplicate():
				if summons.has(su) and not summon_targets(su["loc"]).is_empty() and await yesno(ci, "Sciame: il %s in %s attacca?" % [D.SUMMONS[su["kind"]]["n"], loc_label(su["loc"])]):
					await summon_attack(ci, su, true)
		# ---------------------------------------------------------- risorse
		"item":
			for i in range(int(a1)):
				await gain_item(ci)
		"item_once":
			if not flags.get("item_once_" + str(ctx.get("night", 0)), false):
				flags["item_once_" + str(ctx.get("night", 0))] = true
				await gain_item(ci)
		"talent":
			for i in range(int(a1)):
				await gain_talent(ci)
		"grudge":
			await gain_grudge(ci, int(a1))
		"ap":
			_gain_ap(ci)
		"suffer":
			await damage({"t": "hunter", "ci": ci} if not beast else {"t": "beast", "ci": ci}, int(a1), {"kind": "effect"})
		"steal_grudge":
			var hs2 := []
			for l in nearby(me["loc"]):
				for h in hunters_at(l):
					if ch[h]["grudges"] > 0:
						hs2.append(h)
			if not hs2.is_empty():
				var o6 := []
				for h in hs2:
					o6.append({"id": str(h), "label": "%s (%d rancori)" % [cname(h), ch[h]["grudges"]], "loc": ch[h]["loc"]})
				var h3 := int(str(await decide(ci, {"type": "hunter", "prompt": "Da quale cacciatore prendere 1 rancore?", "opts": o6})))
				ch[h3]["grudges"] -= 1
				await gain_grudge(ci, 1, "preso a " + cname(h3))
		"heal_near":
			for l in nearby(me["loc"], "settlement"):
				for h in hunters_at(l):
					heal({"t": "hunter", "ci": h}, int(a1))
				for s in settlers_at(l):
					heal({"t": "settler", "id": s["id"]}, int(a1))
			log_msg("I cacciatori e i coloni vicini recuperano 1 ferita.")
		"heal_hunter_near":
			var o7 := []
			for l in nearby(me["loc"], "settlement"):
				for h in hunters_at(l):
					if ch[h]["wounds"] > 0:
						o7.append({"id": str(h), "label": cname(h), "loc": l})
			if not o7.is_empty():
				var h4 := int(str(await decide(ci, {"type": "hunter", "prompt": "Chi recupera 1 ferita?", "opts": o7})))
				heal({"t": "hunter", "ci": h4}, 1)
		"buy_upgrade":
			await buy_upgrades(ci, 1, 0)
		"buy_upgrade_disc":
			await buy_upgrades(ci, 1, int(a1))
		# ---------------------------------------------------------- carte
		"take_discard":
			var acts := action_disc.duplicate()
			if not acts.is_empty():
				var o8 := []
				for c in acts:
					o8.append({"id": c, "label": D.cname(c), "card": c})
				var c2 = await decide(ci, {"type": "card", "prompt": "Prendi in mano una carta Azione scartata", "opts": o8, "secret": true})
				action_disc.erase(str(c2))
				me["hand"].append(str(c2))
				log_msg("%s riprende %s dagli scarti." % [cname(ci), D.cname(str(c2))])
		"look_unused":
			if not unused.is_empty():
				var o9 := []
				for c in unused:
					o9.append({"id": c, "label": D.cname(c), "card": c})
				var c3 = await decide(ci, {"type": "card", "prompt": "Carte Azione inutilizzate: prendine una", "opts": o9, "secret": true})
				unused.erase(str(c3))
				me["hand"].append(str(c3))
				log_msg("%s prende una carta Azione inutilizzata." % cname(ci))
		"ret_ability":
			await return_ability(ci)
		"near_hunters_ret_ability":
			for l in nearby(me["loc"], "settlement"):
				for h in hunters_at(l):
					await return_ability(h)
		"ensnare_h":
			var b := await pick_beast(ci)
			var ab: Array = ch[b]["hand"].filter(func(x): return D.kind(x) == "ability")
			ev({"t": "showhand", "ci": b, "to": "H", "hand": ch[b]["hand"].duplicate()})
			log_msg("La Bestia mostra la mano: %s." % ", ".join(ch[b]["hand"].map(func(x): return D.cname(x))))
			if not ab.is_empty():
				var o10 := []
				for c in ab:
					o10.append({"id": c, "label": D.cname(c), "card": c})
				var c4 = await decide(ci, {"type": "card", "prompt": "Quale carta Abilità della Bestia scartare?", "opts": o10})
				ch[b]["hand"].erase(str(c4))
				ch[b]["abil_disc"].append(str(c4))
				log_msg("La Bestia scarta %s." % D.cname(str(c4)))
		"ensnare_b":
			var o11 := []
			for h in alive_hunters():
				o11.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
			if not o11.is_empty():
				var h5 := int(str(await decide(ci, {"type": "hunter", "prompt": "Quale cacciatore mostra la mano?", "opts": o11})))
				ev({"t": "showhand", "ci": h5, "to": "B", "hand": ch[h5]["hand"].duplicate()})
				log_msg("%s mostra la mano alla Bestia." % cname(h5))
				if not ch[h5]["hand"].is_empty():
					var o12 := []
					for c in ch[h5]["hand"]:
						o12.append({"id": c, "label": D.cname(c), "card": c})
					var c5 = await decide(ci, {"type": "card", "prompt": "Quale carta di %s scartare?" % cname(h5), "opts": o12})
					ch[h5]["hand"].erase(str(c5))
					_discard_card(h5, str(c5))
					log_msg("%s scarta %s." % [cname(h5), D.cname(str(c5))])
		"deceive":
			var o13 := []
			for h in alive_hunters():
				o13.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
			if not o13.is_empty():
				var h6 := int(str(await decide(ci, {"type": "hunter", "prompt": "Ingannare: di quale cacciatore guardi la mano?", "opts": o13})))
				ev({"t": "showhand", "ci": h6, "to": "B", "hand": ch[h6]["hand"].duplicate()})
				var blues: Array = ch[h6]["hand"].filter(func(x): return D.kind(x) == "action" and D.card(x).get("c", "") in ["B", "S"])
				if not blues.is_empty():
					var o14 := []
					for c in blues:
						o14.append({"id": c, "label": D.cname(c) + ": " + D.card(c)["bt"], "card": c})
					var c6 = await decide(ci, {"type": "card", "prompt": "Quale carta blu copiare (effetto della Bestia)?", "opts": o14})
					log_msg("%s copia %s." % [cname(ci), D.cname(str(c6))])
					await run_fx(ci, D.card(str(c6))["bfx"], ctx)
		"glimpse_b":
			var ups: Array = talent_up.filter(func(x): return maxi(0, card_cost(x) - 1) <= int(me["grudges"]) and D.card(x).get("c", "") != "X")
			if not ups.is_empty():
				var o15 := []
				for c in ups:
					o15.append({"id": c, "label": "%s: %s" % [D.cname(c), D.card(c)["t"]], "card": c})
				var c7 = await decide(ci, {"type": "card", "prompt": "Scorcio: quale Talento scoperto copiare?", "opts": o15})
				me["grudges"] -= maxi(0, card_cost(str(c7)) - 1)
				talent_up.erase(str(c7))
				talent_disc.append(str(c7))
				await run_fx(ci, D.card(str(c7))["fx"], ctx)
		"free_item":
			var its: Array = me["hand"].filter(func(x): return D.kind(x) == "item" and D.card(x).get("c", "") != "X")
			if not its.is_empty():
				var o16 := [{"id": "no", "label": "Nessuno"}]
				for c in its:
					o16.append({"id": c, "label": D.cname(c), "card": c})
				var c8 = await decide(ci, {"type": "card", "prompt": "Gioca un Oggetto gratis?", "opts": o16, "ask_single": true})
				if str(c8) != "no":
					me["grudges"] += card_cost(str(c8))
					await play_card(ci, str(c8), "B")
		"free_trap":
			var trs: Array = me["hand"].filter(func(x): return D.card(x).get("c", "") == "T")
			if not trs.is_empty():
				var o17 := [{"id": "no", "label": "Nessuna"}]
				for c in trs:
					o17.append({"id": c, "label": D.cname(c), "card": c})
				var c9 = await decide(ci, {"type": "card", "prompt": "Mettere in gioco una trappola gratis?", "opts": o17, "ask_single": true})
				if str(c9) != "no":
					me["hand"].erase(str(c9))
					var zone_only := "" if has_up(ci, "trap_launcher") or ctx.get("card", "").begins_with("ruin") else zone_of(me["loc"])
					if zone_only == "*":
						zone_only = ""
					if not await place_trap(ci, str(c9), zone_only):
						me["hand"].append(str(c9))
		"copy_beast_action":
			var cid: String = ctx.get("copy", "")
			if cid != "":
				await run_fx(ci, D.card(cid)["hfx"], ctx)
		"flourish":
			var n3 := int(kills.get("boar", 0)) + int(kills.get("bear", 0)) + int(kills.get("sabertooth", 0))
			for i in range(n3):
				if unused.is_empty():
					break
				var c10: String = unused.pop_at(rng.randi_range(0, unused.size() - 1))
				me["hand"].append(c10)
			if n3 > 0:
				log_msg("Prosperare: %s prende %d carte Azione inutilizzate." % [cname(ci), n3])
		"extra_turn":
			ctx["extra_turn"] = true
		"cancel_reaction":
			ctx["cancel"] = true
		# ---------------------------------------------------------- evocati
		"summon":
			await do_summon(ci)
		"summons_mv1":
			for su in summons_of(ci):
				await summon_step(ci, su, "Vagare: il %s muove" % D.SUMMONS[su["kind"]]["n"], true)
		"me_and_summons_mv1":
			await beast_move(ci, 1, {"upto": true})
			for su in summons_of(ci):
				await summon_step(ci, su, "Il %s può muovere" % D.SUMMONS[su["kind"]]["n"], true)
		"summon_mv":
			await summon_free_move(ci, "", int(a1), "Un evocato può muovere di %d passi" % int(a1))
		"summon_mvu":
			var kd: String = op[2] if op.size() > 2 else ""
			await summon_free_move(ci, kd, int(a1), "Un evocato può muovere fino a %d passi" % int(a1))
		"one_summon_act":
			var mine := summons_of(ci)
			if not mine.is_empty():
				var o18 := []
				for su in mine:
					o18.append({"id": str(su["id"]), "label": "%s in %s" % [D.SUMMONS[su["kind"]]["n"], loc_label(su["loc"])], "loc": su["loc"]})
				var s1 = await decide(ci, {"type": "summon_pick", "prompt": "Quale evocato agisce?", "opts": o18})
				await summon_action(ci, find_obj(summons, int(str(s1))))
		"wolves_zone_mv1":
			var z2 := zone_of(me["loc"])
			for su in summons_of(ci):
				if su["kind"] == "wolf" and same_zone(su["loc"], me["loc"]):
					await summon_step(ci, su, "Radunare il branco: il Lupo muove", true)
		# ---------------------------------------------------------- trasformazioni
		"tf_here":
			if await transform(me["loc"], ci):
				ctx["transformed"] = true
		"tf_near_all":
			for l in nearby(me["loc"]):
				if await transform(l, ci):
					ctx["transformed"] = true
		"tf_near_upto":
			var left := nearby(me["loc"])
			for i in range(int(a1)):
				var t8 := await pick_loc(ci, "Trasforma un luogo vicino (%d di %d)" % [i + 1, int(a1)], left, true)
				if t8 == "":
					break
				left.erase(t8)
				if await transform(t8, ci):
					ctx["transformed"] = true
		"abyss_near":
			var sw := nearby(me["loc"]).filter(func(x): return has_hab(x, "swamp") and not is_abyss(x))
			var t9 := await pick_loc(ci, "Quale palude vicina diventa abissale?", sw, true)
			if t9 != "" and await transform(t9, ci, "abyss"):
				ctx["transformed"] = true
		"abyss_here":
			if await transform(me["loc"], ci, "abyss"):
				ctx["transformed"] = true
		"displace_h":
			var dm2 := dist_map(me["loc"], 2, "settlement")
			var t10 := await pick_loc(ci, "Trasforma un luogo a non più di 2 passi", dm2.keys())
			if t10 != "":
				await transform(t10, ci)
				for l in nearby(t10, "settlement"):
					for h in hunters_at(l):
						await hunter_move(h, 1, {"may": true, "label": "Dislocare: %s può muovere" % cname(h)})
		"stampede":
			await stampede(ci)
		"watchtower":
			await place_tower(me["loc"])
			ctx["tower"] = true
		# ---------------------------------------------------------- spostamenti di gruppo
		"zone_hunters_mv1":
			var z3 := zone_of(me["loc"])
			for h in alive_hunters():
				if in_zone(ch[h]["loc"], z3):
					await hunter_move(h, 1, {"may": true, "label": "%s può muovere" % cname(h)})
		"near_hunters_mv_or_atk":
			for l in nearby(me["loc"], "settlement"):
				for h in hunters_at(l):
					var r6 = await decide(h, {"type": "choice", "prompt": "Avidità: %s muove di 1 passo o attacca?" % cname(h), "opts": [{"id": "m", "label": "Muovi di 1 passo"}, {"id": "a", "label": "Attacca"}, {"id": "n", "label": "Niente"}], "ask_single": true})
					if str(r6) == "m":
						await hunter_move(h, 1)
					elif str(r6) == "a":
						await attack(h)
		"here_hunters_item_grudge":
			for h in hunters_at(me["loc"]):
				await gain_item(h)
				await gain_grudge(h, 1)
		"stride_h":
			await hunter_move(ci, 1, {"may": true})
			var others := []
			for h in alive_hunters():
				if h != ci and dist(me["loc"], ch[h]["loc"], "settlement") <= 2:
					others.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
			if not others.is_empty():
				others.append({"id": "no", "label": "Nessuno"})
				var h7 = await decide(ci, {"type": "hunter", "prompt": "Falcata: quale altro cacciatore muove di 1 passo?", "opts": others, "ask_single": true})
				if str(h7) != "no":
					await hunter_move(int(str(h7)), 1, {"may": true})
		"delegate":
			var group := []
			if has_up(ci, "huntmaster"):
				for h in alive_hunters():
					if same_zone(ch[h]["loc"], me["loc"]):
						group.append(h)
			else:
				for l in nearby(me["loc"], "settlement"):
					group.append_array(hunters_at(l))
			for h in group:
				await hunter_move(h, 1, {"may": true, "label": "Delegare: %s può muovere" % cname(h)})
		"command_hunter", "command_settler":
			var times := 2 if has_up(ci, "horn_valh") else 1
			for i in range(times):
				if k == "command_hunter":
					var o19 := []
					for h in alive_hunters():
						if same_zone(ch[h]["loc"], me["loc"]):
							o19.append({"id": str(h), "label": cname(h), "loc": ch[h]["loc"]})
					if o19.is_empty():
						break
					o19.append({"id": "no", "label": "Nessuno"})
					var h8 = await decide(ci, {"type": "hunter", "prompt": "Comando: quale cacciatore muovi?", "opts": o19, "ask_single": true})
					if str(h8) != "no":
						await hunter_move(int(str(h8)), 1, {"may": true})
				else:
					var o20 := []
					for s in settlers:
						if same_zone(s["loc"], me["loc"]):
							o20.append({"id": str(s["id"]), "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
					if o20.is_empty():
						break
					o20.append({"id": "no", "label": "Nessuno"})
					var s2 = await decide(ci, {"type": "settler", "prompt": "Comando: quale colono muovi?", "opts": o20, "ask_single": true})
					if str(s2) != "no":
						await settler_step(ci, find_obj(settlers, int(str(s2))), "Muovi il colono")
		"move_settler":
			var o21 := []
			for s in settlers:
				o21.append({"id": str(s["id"]), "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
			if not o21.is_empty():
				var s3 = await decide(ci, {"type": "settler", "prompt": "Quale colono muovere?", "opts": o21})
				await settler_step(ci, find_obj(settlers, int(str(s3))), "Muovi il colono di 1 passo")
		"move_animal_zone":
			var o22 := [{"id": "no", "label": "Nessuno"}]
			for an in animals:
				if same_zone(an["loc"], me["loc"]):
					o22.append({"id": str(an["id"]), "label": "%s in %s" % [D.ANIMALS[an["kind"]]["n"], loc_label(an["loc"])], "loc": an["loc"]})
			var a2 = await decide(ci, {"type": "animal", "prompt": "Muovi un animale della tua zona", "opts": o22, "ask_single": true})
			if str(a2) != "no":
				await animal_step(ci, find_obj(animals, int(str(a2))), "Muovi l'animale")
		"tongue":
			var o23 := []
			for l in nearby(me["loc"]):
				if l == me["loc"]:
					continue
				for t in beings_at(l, false):
					if t["t"] in ["hunter", "settler", "animal"]:
						o23.append({"id": being_key(t), "label": "%s da %s" % [being_name(t), loc_label(l)], "ref": t, "loc": l})
			if not o23.is_empty():
				var r7 = await decide(ci, {"type": "target", "prompt": "Lingua bestiale: chi attirare?", "opts": o23})
				for o in o23:
					if str(o["id"]) == str(r7):
						await move_being_to(o["ref"], me["loc"])
			ctx["tongue"] = true
		"lure_all":
			for l in nearby(me["loc"], "settlement"):
				if l == me["loc"]:
					continue
				for t in beings_at(l, false):
					if t["t"] == "hunter" and t["ci"] == ci:
						continue
					await move_being_to(t, me["loc"])
		"tusk_h":
			var o24 := []
			for d in DIRS:
				var line2 := line_from(me["loc"], d, 2, "settlement")
				if line2.size() == 2:
					o24.append({"id": d, "label": "%s → %s" % [D.DIR_IT[d], loc_label(line2[1])], "loc": line2[1]})
			if not o24.is_empty():
				var d3 = await decide(ci, {"type": "dir", "prompt": "Zanna: direzione (2 passi)", "opts": o24, "ask_single": true})
				var line3 := line_from(me["loc"], str(d3), 2, "settlement")
				var over := []
				for l in line3:
					for t in beings_at(l, true):
						if not (t["t"] == "hunter" and t["ci"] == ci):
							over.append(t)
				var carry2 := {}
				if not over.is_empty():
					var o25 := [{"id": "no", "label": "Nessuno"}]
					for t in over:
						o25.append({"id": being_key(t), "label": being_name(t), "ref": t})
					var r8 = await decide(ci, {"type": "target", "prompt": "Chi si muove con te?", "opts": o25, "ask_single": true})
					for o in o25:
						if str(o["id"]) == str(r8) and o.has("ref"):
							carry2 = o["ref"]
				for l in line3:
					await move_hunter_to(ci, l, true)
				if not carry2.is_empty():
					await move_being_to(carry2, me["loc"])
		"grapple":
			await grapple(ci, int(a1))
		"grapnel_pass":
			var o26 := [{"id": "no", "label": "Nessuno"}]
			for l in nearby(me["loc"], "settlement"):
				for h in hunters_at(l):
					if h != ci and n_actions(h) > 0:
						o26.append({"id": str(h), "label": cname(h)})
			var h9 = await decide(ci, {"type": "hunter", "prompt": "Chi scarta una carta Azione per prendere l'Arpione?", "opts": o26, "ask_single": true})
			if str(h9) != "no":
				var hh := int(str(h9))
				var acts2: Array = ch[hh]["hand"].filter(func(x): return D.kind(x) == "action")
				var o27 := []
				for c in acts2:
					o27.append({"id": c, "label": D.cname(c), "card": c})
				var c11 = await decide(hh, {"type": "card", "prompt": "Quale carta Azione scartare?", "opts": o27})
				ch[hh]["hand"].erase(str(c11))
				action_disc.append(str(c11))
				ctx["grapnel_to"] = hh
		"behold":
			var steps := 2 if has_up(ci, "entrancing") else 1
			var moved := []
			for i in range(2):
				var o28 := [{"id": "no", "label": "Basta così"}]
				for s in settlers:
					if same_zone(s["loc"], me["loc"]) and not moved.has("settler:%d" % s["id"]):
						o28.append({"id": "settler:%d" % s["id"], "label": "%s in %s" % [D.SETTLERS[s["kind"]]["n"], loc_label(s["loc"])], "loc": s["loc"]})
				for an in animals:
					if same_zone(an["loc"], me["loc"]) and not moved.has("animal:%d" % an["id"]):
						o28.append({"id": "animal:%d" % an["id"], "label": "%s in %s" % [D.ANIMALS[an["kind"]]["n"], loc_label(an["loc"])], "loc": an["loc"]})
				for su in summons:
					if same_zone(su["loc"], me["loc"]) and not moved.has("summon:%d" % su["id"]):
						o28.append({"id": "summon:%d" % su["id"], "label": "%s in %s" % [D.SUMMONS[su["kind"]]["n"], loc_label(su["loc"])], "loc": su["loc"]})
				var r9 = await decide(ci, {"type": "target", "prompt": "Ammirare: quale essere muovi (%d di 2)?" % (i + 1), "opts": o28, "ask_single": true})
				if str(r9) == "no":
					break
				moved.append(str(r9))
				var kk: String = str(r9).get_slice(":", 0)
				var id := int(str(r9).get_slice(":", 1))
				for j in range(steps):
					var o29: Dictionary = find_obj(settlers if kk == "settler" else (animals if kk == "animal" else summons), id)
					if o29.is_empty():
						break
					var dests := nearby(o29["loc"]).filter(func(x): return x != o29["loc"])
					var t11 := await pick_loc(ci, "Dove?", dests, true)
					if t11 == "":
						break
					await move_being_to({"t": kk, "id": id}, t11)
		"reveal":
			await reveal(ci, D.cname(ctx.get("card", "")))
		"reveal_last":
			var b2 := await pick_beast(ci)
			await reveal_last_moves(b2, int(a1))
		"seer":
			var b3 := await pick_beast(ci)
			await reveal_last_moves(b3, 2 if has_up(ci, "soothsayer") else 1)
		"acclivity":
			if not me["moves"].is_empty() and await yesno(ci, "Erta: rivelare l'ultima carta Movimento per muovere di 1 passo in più?"):
				await reveal_last_moves(ci, 1)
				await beast_move(ci, 1)
		"activate_ruin":
			var rs := []
			for r in ruins:
				var rl := ruin_loc(r)
				if rl != "" and same_zone(rl, me["loc"]):
					rs.append({"id": r, "label": str(M["ruins"][r]), "loc": rl})
			if not rs.is_empty():
				var r10 = await decide(ci, {"type": "ruin", "prompt": "Quale Rovina attivare?", "opts": rs})
				await claim_ruin(ci, str(r10))
		"abrupt_decay":
			var o30 := []
			for z in zone_ids():
				for hb in ["forest", "swamp", "cave", "settlement"]:
					o30.append({"id": z + "|" + hb, "label": "%s, %s" % [M["zones"][z], D.HAB_IT[hb]]})
			var r11 = await decide(ci, {"type": "choice", "prompt": "Decadimento improvviso: zona e habitat", "opts": o30})
			var z4: String = str(r11).get_slice("|", 0)
			var hb2: String = str(r11).get_slice("|", 1)
			var gone := traps.filter(func(t): return t["zone"] == z4 and t["hab"] == hb2)
			for t in gone:
				traps.erase(t)
				item_disc.append(t["card"])
			ev({"t": "trap_gone", "zone": z4, "n": gone.size()})
			log_msg("Decadimento improvviso: %d trappol%s distrutt%s." % [gone.size(), "a" if gone.size() == 1 else "e", "a" if gone.size() == 1 else "e"])
		_:
			await run_special(ci, op, ctx)


func run_special(ci: int, op: Array, ctx: Dictionary) -> void:
	push_warning("Operazione sconosciuta: " + str(op))


## Carica selvaggia (Hogbad): 2 passi nella stessa direzione, trasforma, trascina chi incontra.
func stampede(b: int) -> void:
	var c: Dictionary = ch[b]
	var start: String = c["loc"]
	var opts := []
	for d in DIRS:
		var line := line_from(start, d, 2, beast_hab(b))
		if line.size() == 2:
			opts.append({"id": d, "label": "%s → %s" % [D.DIR_IT[d], loc_label(line[1])], "loc": line[1], "dir": d})
	if opts.is_empty():
		await beast_move(b, 2)
		return
	var r = await decide(b, {"type": "beast_step", "prompt": "Carica selvaggia: direzione (2 passi)", "opts": opts, "ask_single": true, "secret": true})
	var line2 := line_from(start, str(r), 2, beast_hab(b))
	var carried := []
	var batch := []
	for t in beings_at(start, false):
		if t["t"] in ["hunter", "settler", "animal"]:
			carried.append(t)
	for l in line2:
		for t in beings_at(l, false):
			if t["t"] in ["hunter", "settler", "animal"] and not carried.has(t):
				carried.append(t)
		var m := {"dir": str(r), "from": c["loc"], "to": l, "fake": false, "pair": 0, "found": false}
		c["moves"].append(m)
		c["revealed"] = false
		c["loc"] = l
		batch.append(m)
	ev({"t": "bmove", "ci": b, "n": 2, "pairs": c["moves"].map(func(m2): return int(m2.get("pair", 0))), "abyss": [], "h": commit_moves(b, batch)})
	for l in line2:
		await transform(l, b)
	for t in carried:
		await move_being_to(t, c["loc"])
	if not carried.is_empty():
		log_msg("Carica selvaggia: %d esseri travolti." % carried.size())
	await refresh_trails()


## Rampino / Arpione: un essere vicino (o a 2 passi in linea) viene da te, oppure tu vai da lui.
func grapple(h: int, rng_n: int) -> void:
	var me: Dictionary = ch[h]
	var cands := []
	if rng_n <= 1 and not has_up(h, "reach"):
		for l in nearby(me["loc"], "settlement"):
			if l != me["loc"]:
				for t in beings_at(l, true):
					cands.append({"t": t, "l": l})
	else:
		for d in DIRS:
			for l in line_from(me["loc"], d, 2, "settlement"):
				for t in beings_at(l, true):
					cands.append({"t": t, "l": l})
	if cands.is_empty():
		return
	var opts := []
	for i in range(cands.size()):
		var c: Dictionary = cands[i]
		opts.append({"id": str(i) + "a", "label": "Porta da te: %s (%s)" % [being_name(c["t"]), loc_label(c["l"])], "loc": c["l"]})
		opts.append({"id": str(i) + "b", "label": "Vai da: %s (%s)" % [being_name(c["t"]), loc_label(c["l"])], "loc": c["l"]})
	var r = await decide(h, {"type": "target", "prompt": "Rampino", "opts": opts})
	var i2 := int(str(r).left(-1))
	var cc: Dictionary = cands[i2]
	if str(r).ends_with("a"):
		await move_being_to(cc["t"], me["loc"])
	else:
		await move_hunter_to(h, cc["l"], false)


func fylgja_step(h: int, n: int) -> void:
	for i in range(n):
		var opts := walker_opts(companion, "settlement", "", "", false)
		opts.append({"id": "stop", "label": "Resta"})
		var r = await decide(h, {"type": "step", "prompt": "Fylgja muove", "opts": opts, "ask_single": true, "mover": "companion"})
		if str(r) == "stop":
			return
		companion = str(r)
		ev({"t": "cmove", "to": companion})
		await refresh_trails()
		if has_up(h, "sky_master") and trail_at(companion):
			var hs := alive_hunters().filter(func(x): return same_zone(ch[x]["loc"], companion))
			if not hs.is_empty():
				var o := [{"id": "no", "label": "Nessuno"}]
				for x in hs:
					o.append({"id": str(x), "label": cname(x)})
				var w = await decide(h, {"type": "hunter", "prompt": "Signore del cielo: un cacciatore muove di 1 passo", "opts": o, "ask_single": true})
				if str(w) != "no":
					await hunter_move(int(str(w)), 1, {"may": true})


func pick_beast(ci: int) -> int:
	var bs := beasts().filter(func(b): return not ch[b]["dead"])
	if bs.size() <= 1:
		return bs[0] if not bs.is_empty() else 0
	var opts := []
	for b in bs:
		opts.append({"id": str(b), "label": cname(b)})
	return int(str(await decide(ci, {"type": "beast", "prompt": "Quale Bestia?", "opts": opts})))


func return_ability(ci: int) -> void:
	var disc: Array = ch[ci]["abil_disc"]
	if disc.is_empty():
		return
	var opts := []
	for c in disc:
		opts.append({"id": c, "label": D.cname(c), "card": c})
	var r = await decide(ci, {"type": "card", "prompt": "%s: quale carta Abilità riprendere?" % cname(ci), "opts": opts})
	disc.erase(str(r))
	ch[ci]["hand"].append(str(r))
	log_msg("%s riprende %s." % [cname(ci), D.cname(str(r))])


# ================================================================== Arsenale

func gain_item(h: int) -> void:
	await _gain_arsenal(h, item_up, item_deck, item_disc, "Oggetto del cacciatore")


func gain_talent(b: int) -> void:
	await _gain_arsenal(b, talent_up, talent_deck, talent_disc, "Talento bestiale")


func _gain_arsenal(ci: int, up: Array, deck: Array, disc: Array, what: String) -> void:
	if ch[ci]["dead"]:
		return
	if deck.is_empty() and not disc.is_empty():
		deck.append_array(disc)
		disc.clear()
		shuffle(deck)
	var opts := []
	for c in up:
		opts.append({"id": c, "label": "%s: %s" % [D.cname(c), D.card(c)["t"]], "card": c})
	if not deck.is_empty():
		opts.append({"id": "top", "label": "La prima carta coperta del mazzo"})
	if opts.is_empty():
		return
	var r = await decide(ci, {"type": "arsenal", "prompt": "Prendi un %s" % what, "opts": opts, "ask_single": true})
	var c: String
	if str(r) == "top":
		c = deck.pop_back()
		ch[ci]["hand"].append(c)
		ev({"t": "gain", "ci": ci, "what": what, "hidden": true})
		log_msg("%s prende un %s coperto." % [cname(ci), what])
	else:
		c = str(r)
		up.erase(c)
		ch[ci]["hand"].append(c)
		ev({"t": "gain", "ci": ci, "what": what, "card": c})
		log_msg("%s prende %s." % [cname(ci), D.cname(c)])
		# Vero istinto: reazioni alle carte scoperte prese
		if is_beast(ci):
			for x in hunters():
				if has_up(x, "true_instinct_h") and not ch[x]["dead"] and await yesno(x, "Vero istinto: la Bestia ha preso un Talento scoperto. Muovere di 1 passo?"):
					await hunter_move(x, 1)
		else:
			for b in beasts():
				if has_up(b, "true_instinct_b") and await yesno(b, "Vero istinto: un cacciatore ha preso un Oggetto scoperto. Muovere di 1 passo?"):
					await beast_move(b, 1)
	if not is_beast(ci) and has_up(ci, "portable_workshop") and await yesno(ci, "Officina portatile: trasformare il tuo luogo in insediamento?"):
		await transform(ch[ci]["loc"], ci)


# ================================================================== potenziamenti

func upgrade_table(ci: int) -> Dictionary:
	if is_beast(ci):
		return D.BEASTS[ch[ci]["id"]]["up"]
	return D.HUNTERS[ch[ci]["id"]]["up"]


func upgrade_ok(ci: int, u: String, disc := 0) -> bool:
	var t: Array = upgrade_table(ci)[u]
	if ch[ci]["upg"].has(u):
		return false
	if u == "resurrection" and dead_animals < 2:
		return false
	if u == "infusion" and int(ch[ci].get("blood", 0)) < 2:
		return false
	return maxi(0, int(t[1]) - disc) <= int(ch[ci]["grudges"])


## Compra fino a n potenziamenti (n = 99 di notte) con lo sconto disc.
func buy_upgrades(ci: int, n: int, disc: int) -> void:
	var bought := 0
	while bought < n and not game_over and not ch[ci]["dead"]:
		var tab := upgrade_table(ci)
		var opts := []
		for u in tab:
			if upgrade_ok(ci, u, disc):
				var t: Array = tab[u]
				opts.append({"id": u, "label": "%s (%d): %s" % [t[0], maxi(0, int(t[1]) - disc), t[3]]})
		if opts.is_empty():
			return
		opts.append({"id": "end", "label": "Non comprare altro"})
		var r = await decide(ci, {"type": "upgrade", "prompt": "%s: compra un potenziamento (rancori: %d)" % [cname(ci), ch[ci]["grudges"]], "opts": opts, "ask_single": true})
		if str(r) == "end":
			return
		await buy_upgrade(ci, str(r), disc)
		bought += 1
		disc = 0 if n == 1 else disc


func buy_upgrade(ci: int, u: String, disc := 0) -> void:
	var t: Array = upgrade_table(ci)[u]
	ch[ci]["grudges"] -= maxi(0, int(t[1]) - disc)
	ch[ci]["upg"][u] = true
	ev({"t": "upgrade", "ci": ci, "u": u})
	log_msg("%s sblocca [b]%s[/b]." % [cname(ci), t[0]])
	if t[2] == "y":
		await yellow_upgrade(ci, u)


## Potenziamenti gialli: si risolvono subito.
func yellow_upgrade(ci: int, u: String) -> void:
	var ctx := {"ci": ci, "card": "up:" + u}
	match u:
		"blight":
			await run_fx(ci, ["seq", ["tf_near_all"], ["mv", 1]], ctx)
		"hunting_grounds":
			await run_fx(ci, ["any", ["mv", 1], ["tf_near_all"]], ctx)
		"song_temptation":
			await lure(ci, ch[ci]["loc"])
		"vanish":
			heal({"t": "beast", "ci": ci}, 1)
			secret_relocate(ci, center())
			await reveal(ci, "Svanire")
		"wild_ode":
			await do_summon(ci)
		"chiefs_command":
			for i in range(2):
				var bo: Array = animals.filter(func(a): return a["kind"] == "boar")
				if bo.is_empty():
					break
				var o := [{"id": "no", "label": "Basta"}]
				for a in bo:
					o.append({"id": str(a["id"]), "label": "Cinghiale in " + loc_label(a["loc"]), "loc": a["loc"]})
				var r = await decide(ci, {"type": "animal", "prompt": "Comando del capo: quale Cinghiale muovi?", "opts": o, "ask_single": true})
				if str(r) == "no":
					break
				var an := find_obj(animals, int(str(r)))
				for j in range(2):
					if not await animal_step(ci, an, "Muovi il Cinghiale"):
						break
		"sinister_act":
			var z := zone_of(ch[ci]["loc"])
			var mine := traps.filter(func(t): return in_zone(ch[ci]["loc"], t["zone"]))
			if not mine.is_empty():
				var t2: Dictionary = mine[rng.randi_range(0, mine.size() - 1)]
				traps.erase(t2)
				item_disc.append(t2["card"])
				ev({"t": "trap_gone", "zone": t2["zone"], "n": 1})
				log_msg("Atto sinistro: una trappola sparisce dalla zona %s." % M["zones"][t2["zone"]])
		"mesmerise":
			flags["mesmerise"] = ci
		"sudden_shock":
			var o2 := []
			for l in nearby(ch[ci]["loc"]):
				for h in hunters_at(l):
					o2.append({"id": str(h), "label": cname(h), "loc": l})
			if not o2.is_empty():
				var h2 := int(str(await decide(ci, {"type": "hunter", "prompt": "Shock improvviso: quale cacciatore salta il turno?", "opts": o2})))
				ch[h2]["skip"] = int(ch[h2].get("skip", 0)) + 1
				log_msg("%s salterà il prossimo turno." % cname(h2))
		"discharge":
			await ram(ci, {})
			for s in summons_of(ci):
				if s["kind"] == "yagi" and summons.has(s):
					await ram(ci, s)
		"void_call":
			for t in tokens.keys():
				if tokens[t] != "abyss":
					continue
				for l in nearby(t):
					for h in hunters_at(l):
						await move_hunter_to(h, t, false)
						await damage({"t": "hunter", "ci": h}, 1, {"kind": "effect"})
					for s in settlers_at(l):
						await move_settler_to(s, t)
						await damage({"t": "settler", "id": s["id"], "kind": s["kind"]}, 1, {"kind": "effect"})
		"abyssal_beast":
			for i in range(2):
				var sw := LOCS.keys().filter(func(x): return has_hab(x, "swamp") and not is_abyss(x) and not protected.has(x))
				var t3 := await pick_loc(ci, "Bestia abissale: palude da trasformare (%d di 2)" % (i + 1), sw, true)
				if t3 == "":
					break
				await transform(t3, ci, "abyss")
		"resurrection":
			ch[ci]["reborn"] = true
			beast_hp = int(D.BEASTS["fk"]["hp_reborn"]) + (beast_hp - int(D.BEASTS["fk"]["hp"]))
			for r in D.BEASTS["fk"]["reborn"]:
				ch[ci]["upg"][r] = true
			await reveal(ci, "Resurrezione")
			for l in nearby(ch[ci]["loc"]):
				await transform(l, ci)
				for h in hunters_at(l):
					await damage({"t": "hunter", "ci": h}, 1, {"kind": "effect"})
				for s in settlers_at(l):
					await damage({"t": "settler", "id": s["id"], "kind": s["kind"]}, 1, {"kind": "effect"})
			log_msg("[b]Il Re Piumato è rinato![/b]")
		"explore":
			await hunter_move(ci, 1)
			await gain_item(ci)
		"defender":
			ch[ci]["defender"] = true
		"resourcefulness":
			for l in nearby(ch[ci]["loc"], "settlement"):
				for h in hunters_at(l):
					await gain_item(h)
		"ancient_calling":
			_gain_ap(ci)
		"heroic_speech":
			var fa: Array = settlers.filter(func(s): return s["kind"] == "farmer")
			if not fa.is_empty():
				var o3 := []
				for s in fa:
					o3.append({"id": str(s["id"]), "label": "Contadino in " + loc_label(s["loc"]), "loc": s["loc"]})
				var s2 := find_obj(settlers, int(str(await decide(ci, {"type": "settler", "prompt": "Quale Contadino diventa Nobile?", "opts": o3}))))
				s2["kind"] = "noble"
				ev({"t": "skind", "id": s2["id"], "kind": "noble"})
		"tactical_manouver":
			for h in alive_hunters():
				await hunter_move(h, 1, {"may": true, "label": "Manovra tattica: %s" % cname(h)})
			for s in settlers.duplicate():
				await settler_step(ci, s, "Manovra tattica: muovi il colono")
		"rope_pull":
			await grapple(ci, 2)
		"infusion":
			ch[ci]["blood"] -= 2
			var o4 := []
			for h in alive_hunters():
				o4.append({"id": str(h), "label": cname(h)})
			var h3 := int(str(await decide(ci, {"type": "hunter", "prompt": "Infusione: chi guadagna 2 rancori?", "opts": o4})))
			await gain_grudge(h3, 2, "Infusione")
			ch[ci]["upg"].erase("infusion")
		"rebirth_fire":
			ch[ci]["rebirth_fire"] = true
		"black_star":
			ch[ci]["black_star"] = true


# ================================================================== prima e dopo l'effetto di una carta

func before_effect(ci: int, cid: String, m: String, ctx: Dictionary) -> void:
	var b := D.base_id(cid)
	var c := D.card(cid)
	# reazioni dei Belati (cacciatore nella zona di Thalduk gioca un'Azione rossa)
	if not is_beast(ci) and D.kind(cid) == "action" and (m == "R" or m == "O"):
		await offer_reaction("hunter_red_action_zone", {"ci": ci})
		if K.get("setup", {}).get("titan", false) or K.get("setup", {}).get("escort", false):
			for s in settlers.duplicate():
				if not await settler_step(ci, s, "Puoi muovere il colono di 1 passo"):
					continue
	if D.is_hunt(cid):
		await offer_reaction("hunt_played", {"ci": ci})
	if is_beast(ci):
		match b:
			"leap":
				if has_up(ci, "expand_marsh"):
					for l in nearby(ch[ci]["loc"]):
						await transform(l, ci)
			"stampede":
				if has_up(ci, "primal_instincts"):
					for s in summons_of(ci):
						if s["kind"] == "warhog" and summons.has(s) and await yesno(ci, "Istinti primordiali: il Cinghiale da guerra in %s spinge?" % loc_label(s["loc"])):
							await push(ci, s)


func after_effect(ci: int, cid: String, m: String, ctx: Dictionary) -> void:
	var b := D.base_id(cid)
	var c := D.card(cid)
	var me: Dictionary = ch[ci]
	if is_beast(ci):
		match b:
			"engorge":
				if ctx.get("killed", false) and has_up(ci, "infestation"):
					await place_summon(ci, [], me["loc"])
			"beastly_tongue":
				if has_up(ci, "unending_hunger"):
					_return_to_hand(ci, "engorge")
			"prey_upon":
				if ctx.get("killed", false) and has_up(ci, "bloodlust"):
					_return_to_hand(ci, "prey_upon")
			"tusk":
				if ctx.get("killed", false) and has_up(ci, "hordes_march"):
					_return_to_hand(ci, "stampede")
			"stampede":
				if has_up(ci, "rampageous"):
					var r := await attack(ci)
			"murder":
				if ctx.get("killed", false) and has_up(ci, "killing_spree"):
					_return_to_hand(ci, "murder")
			"hydra":
				if ctx.get("killed", false) and has_up(ci, "devourer"):
					_return_to_hand(ci, "slither")
			"shadow_step":
				if has_up(ci, "void_presence"):
					for l in nearby(me["loc"]):
						await transform(l, ci)
			"summon_yagi":
				if has_up(ci, "stormbringer"):
					_return_to_hand(ci, "storm")
			"allure":
				if ctx.get("killed", false) and has_up(ci, "swift_kill"):
					_return_to_hand(ci, "elude")
			"elude":
				if has_up(ci, "mirror_beast"):
					await beast_move(ci, 1, {"fake": true})
			"defile", "corrupt":
				if has_up(ci, "eternity"):
					var sw := dist_map(me["loc"], 2).keys().filter(func(x): return has_hab(x, "swamp") and not is_abyss(x))
					var t := await pick_loc(ci, "Eternità: un'altra palude diventa abissale?", sw, true)
					if t != "":
						await transform(t, ci, "abyss")
			"unwilling_sacrifice":
				if me.get("reborn", false):
					var dis: Array = me["abil_disc"].filter(func(x): return D.base_id(x) == "summon_dreamer")
					if not dis.is_empty() and await yesno(ci, "Sogno senza fine: riprendere Evoca Sognatore?"):
						_return_to_hand(ci, "summon_dreamer")
		if ctx.get("transformed", false) and has_up(ci, "torrential"):
			await beast_move(ci, 1, {"label": "Torrenziale"})
		if c.get("dark", false) and me.get("reborn", false):
			var dr: Array = summons_of(ci).filter(func(s): return s["kind"] == "dreamer")
			if not dr.is_empty() and await yesno(ci, "Signore supremo: sacrificare un Sognatore per copiare %s?" % D.cname(cid)):
				await kill_summon(dr[0])
				await run_fx(ci, c["bfx"] if D.kind(cid) == "action" else c["fx"], ctx)
		if D.kind(cid) == "action" and c.get("c", "") in ["B"] or (D.kind(cid) == "action" and c.get("c", "") == "S" and m == "B"):
			await offer_reaction("beast_blue_action", {"card": cid})
			for h in hunters():
				if has_up(h, "predict") and not ch[h]["dead"] and not ch[h].get("predicted", false):
					ch[h]["predicted"] = true
					log_msg("Prevedere: %s copia %s." % [cname(h), D.cname(cid)])
					await run_fx(h, c["hfx"], {"ci": h, "card": cid})
	else:
		if D.is_track(cid):
			if has_up(ci, "seeker") and await yesno(ci, "Cercatore: perlustrare il tuo luogo?"):
				await search(ci, me["loc"])
			for x in hunters():
				if x != ci and has_up(x, "joint_effort") and not ch[x]["dead"] and same_zone(ch[x]["loc"], me["loc"]):
					await hunter_move(x, 1, {"may": true, "label": "Sforzo comune: %s" % cname(x)})
		if (D.is_hunt(cid) or D.is_track(cid)) and has_up(ci, "ignite"):
			var hs := alive_hunters().filter(func(x): return x != ci and same_zone(ch[x]["loc"], me["loc"]))
			if not hs.is_empty():
				var o := [{"id": "no", "label": "Nessuno"}]
				for x in hs:
					o.append({"id": str(x), "label": cname(x)})
				var w = await decide(ci, {"type": "hunter", "prompt": "Accendere: un altro cacciatore muove di 1 passo", "opts": o, "ask_single": true})
				if str(w) != "no":
					await hunter_move(int(str(w)), 1, {"may": true})
		match b:
			"seer":
				if has_up(ci, "clairvoyant"):
					await hunter_move(ci, 1)
			"cleaver":
				if has_up(ci, "watchtower_passage"):
					var others: Array = towers.filter(func(t): return t != me["loc"])
					var t2 := await pick_loc(ci, "Passaggio della torre: spostarti su un'altra torre?", others, true)
					if t2 != "":
						await move_hunter_to(ci, t2, false)
			"chain_grapnel":
				if ctx.has("grapnel_to"):
					item_disc.erase(cid)
					ch[int(ctx["grapnel_to"])]["hand"].append(cid)
		if c.get("dark", false) and has_up(ci, "dark_flame"):
			_return_to_hand(ci, "flame_rapier")
		if D.kind(cid) == "action" and (m == "R") and c.get("c", "") != "B":
			for x in hunters():
				if x != ci and has_up(x, "resonance") and ch[x].get("resonance_target", -1) == ci and not ch[x].get("resonated", false) and not ch[x]["dead"]:
					ch[x]["resonated"] = true
					log_msg("Risonanza: %s copia %s." % [cname(x), D.cname(cid)])
					await run_fx(x, c["hfx"], {"ci": x, "card": cid})


func _return_to_hand(ci: int, base: String) -> void:
	for a in ch[ci]["abil_disc"].duplicate():
		if D.base_id(a) == base:
			ch[ci]["abil_disc"].erase(a)
			ch[ci]["hand"].append(a)
			log_msg("%s riprende in mano %s." % [cname(ci), D.cname(a)])
			return


# ================================================================== reazioni

## Offre le reazioni possibili per un evento. data dipende dal tipo.
func offer_reaction(trigger: String, data: Dictionary) -> bool:
	var played := false
	match trigger:
		"beast_attack_near":
			var l: String = data["loc"]
			for h in alive_hunters():
				if not nearby(ch[h]["loc"], "settlement").has(l):
					continue
				for c in ch[h]["hand"].duplicate():
					if D.base_id(c) == "smokebomb" and ch[h]["grudges"] >= 1:
						if await yesno(h, "La Bestia attacca in %s: giocare Fumogeno (previene 1 danno)?" % loc_label(l), "Gioca Fumogeno", "No", "reaction"):
							if await _react(h, c, data):
								data["prevent"]["n"] = int(data["prevent"]["n"]) + 1
							played = true
						break
			var bond := false
			for h in hunters():
				if has_up(h, "ancient_bond"):
					bond = true
			if bond:
				for h in alive_hunters():
					for c in ch[h]["hand"].duplicate():
						if D.is_track(c) and await yesno(h, "Legame antico: giocare %s come reazione all'attacco?" % D.cname(c), "Gioca", "No", "reaction"):
							ch[h]["hand"].erase(c)
							await run_fx(h, D.card(c)["fx"], {"ci": h, "card": c})
							ch[h]["abil_disc"].append(c)
							break
		"trail_on_settler":
			for h in alive_hunters():
				for c in ch[h]["hand"].duplicate():
					if D.base_id(c) == "flare" and ch[h]["grudges"] >= 1:
						if await yesno(h, "Compare una Traccia dove c'è un colono: giocare Razzo di segnalazione?", "Gioca", "No", "reaction"):
							await _react(h, c, data)
							played = true
						break
		"hunt_played":
			for b in beasts():
				for c in ch[b]["hand"].duplicate():
					if D.base_id(c) == "intuition" and ch[b]["grudges"] >= 1:
						if await yesno(b, "È stata giocata Caccia: giocare Intuito (muovi di 1 passo)?", "Gioca", "No", "reaction"):
							await _react(b, c, data)
							played = true
						break
		"hunter_turn_end":
			for b in beasts():
				for c in ch[b]["hand"].duplicate():
					if D.base_id(c) == "worldshift":
						if await yesno(b, "Un cacciatore ha finito il turno: giocare Mutamento del mondo?", "Gioca", "No", "reaction"):
							await _react(b, c, data)
							played = true
						break
		"beast_blue_action":
			for h in alive_hunters():
				for c in ch[h]["hand"].duplicate():
					if D.base_id(c) == "esmerias_strand" and ch[h]["grudges"] >= 1:
						if await yesno(h, "La Bestia ha giocato %s: giocare Ciocca di Esmeria e copiarne l'effetto?" % D.cname(data["card"]), "Gioca", "No", "reaction"):
							data["copy"] = data["card"]
							await _react(h, c, data)
							played = true
						break
		"hunter_red_action_zone":
			var hl: String = ch[data["ci"]]["loc"]
			for b in beasts():
				if not same_zone(ch[b]["loc"], hl):
					continue
				for c in ch[b]["hand"].duplicate():
					if D.base_id(c) == "bleat":
						if await yesno(b, "%s gioca una carta Azione rossa nella tua zona: Belato (evoca)?" % cname(data["ci"]), "Gioca", "No", "reaction"):
							await _react(b, c, data)
							played = true
						break
		"day_start":
			for h in alive_hunters():
				if ch[h].get("black_star", false):
					ch[h]["black_star"] = false
					data["extra"].append(h)
					continue
				for c in ch[h]["hand"].duplicate():
					if D.base_id(c) == "dreamer_mask" and ch[h]["grudges"] >= 1:
						if await yesno(h, "Inizia il Giorno: giocare Maschera del sognatore (gioca 1 carta prima della Bestia)?", "Gioca", "No", "reaction"):
							ch[h]["hand"].erase(c)
							ch[h]["grudges"] -= 1
							item_disc.append(c)
							data["extra"].append(h)
							played = true
						break
	return played


## Gioca una reazione: paga, scarta, risolve (salvo Nebbia improvvisa nel turno della Bestia).
func _react(ci: int, cid: String, data: Dictionary) -> bool:
	ch[ci]["hand"].erase(cid)
	ch[ci]["grudges"] -= card_cost(cid)
	ev({"t": "play", "ci": ci, "card": cid, "mode": "X"})
	log_msg("%s reagisce con [b]%s[/b]." % [cname(ci), D.cname(cid)])
	_discard_card(ci, cid)
	if not is_beast(ci) and is_beast(turn_ci) and await offer_cancel(turn_ci):
		return false
	var ctx := {"ci": ci, "card": cid}
	if data.has("copy"):
		ctx["copy"] = data["copy"]
	if D.base_id(cid) != "smokebomb":
		await run_fx(ci, D.card(cid).get("fx", ["seq"]), ctx)
	if is_beast(ci) and has_up(ci, "starfall"):
		if await yesno(ci, "Caduta di stelle: muovere di 1 passo in più?"):
			await beast_move(ci, 1)
	return true


## Nebbia improvvisa: la Bestia annulla una reazione o una trappola nel suo turno.
func offer_cancel(b: int) -> bool:
	for c in ch[b]["hand"].duplicate():
		if D.base_id(c) == "sudden_mist" and ch[b]["grudges"] >= 1:
			if await yesno(b, "Giocare Nebbia improvvisa e annullare l'effetto?", "Annulla", "No", "reaction"):
				ch[b]["hand"].erase(c)
				ch[b]["grudges"] -= 1
				talent_disc.append(c)
				log_msg("%s gioca Nebbia improvvisa: effetto annullato." % cname(b))
				if has_up(b, "starfall") and await yesno(b, "Caduta di stelle: muovere di 1 passo?"):
					await beast_move(b, 1)
				return true
			break
	return false
