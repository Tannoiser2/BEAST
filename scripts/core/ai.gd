class_name BSAI
extends RefCounted
## IA su tre livelli (0 Facile, 1 Normale, 2 Difficile) per la Bestia e per i cacciatori.
##
## Regola d'oro: l'IA di una squadra non sbircia mai i segreti dell'altra.
## - I cacciatori ragionano su BSBelief (posizioni possibili della Bestia ricavate dagli eventi pubblici)
##   e cooperano: al livello Difficile si spartiscono le zone più probabili e coprono i coloni.
## - La Bestia conosce la propria posizione ma valuta le mosse con la stessa BSBelief dei cacciatori:
##   al livello Difficile sceglie i passi che lasciano più ipotesi aperte (bluff con le tracce)
##   e usa le carte Movimento false per mandare i cacciatori fuori strada.

const D = preload("res://scripts/data/bs_data.gd")

var level := 1
var rng := RandomNumberGenerator.new()
var plan := {}               # intenzioni del turno in corso (obiettivo, ordine attacco/movimento…)
var goal := ""               # luogo verso cui muoversi

## Pesi del livello Difficile (tarati con le simulazioni di tests/sim.gd).
## Per provarne altri senza toccare il codice: BS_TUNE="set=1.4,dg=0.4" godot ... tests/sim.gd
const TUNE_BASE := {"set": 1.0, "an": 1.0, "dg": 0.6, "dmv": 0.35, "dst": 0.9, "bluff": 0.8, "ruin": 1.0, "fin": 1.5, "guard": 4.0, "escort": 0.25, "red": 1.0}
static var _tune := {}


func tv(k: String) -> float:
	if level < 2:
		return {"dg": 0.6, "dmv": 0.5, "dst": 0.9}.get(k, 1.0) if not k in ["bluff", "fin"] else 0.0
	if _tune.is_empty():
		_tune = TUNE_BASE.duplicate()
		for kv in OS.get_environment("BS_TUNE").split(",", false):
			var p := kv.split("=")
			if p.size() == 2:
				_tune[p[0]] = float(p[1])
	return float(_tune.get(k, 1.0))


# ------------------------------------------------------------------ credenze condivise

## Una credenza per Bestia, condivisa da tutte le IA (è calcolata solo da eventi pubblici).
static func belief(eng, b: int) -> BSBelief:
	if not eng.has_meta("beliefs"):
		eng.set_meta("beliefs", {})
	var bs: Dictionary = eng.get_meta("beliefs")
	if not bs.has(b):
		bs[b] = BSBelief.new(eng, b)
	var bl: BSBelief = bs[b]
	bl.update()
	return bl


## Probabilità combinate di tutte le Bestie nascoste (le rivelate sono certe).
func beast_probs(eng) -> Dictionary:
	var out := {}
	for b in eng.beasts():
		if eng.ch[b]["dead"]:
			continue
		if eng.ch[b]["revealed"]:
			out[eng.ch[b]["standee"]] = float(out.get(eng.ch[b]["standee"], 0.0)) + 1.0
			continue
		var pr := belief(eng, b).probs()
		if level == 0:
			# Facile: solo l'ultima posizione nota e le tracce visibili
			pr = {eng.ch[b]["standee"]: 0.5}
			for l in eng.trails:
				pr[l] = float(pr.get(l, 0.0)) + 0.5
		for l in pr:
			out[l] = float(out.get(l, 0.0)) + float(pr[l])
	return out


# ------------------------------------------------------------------ smistamento

func decide(eng, ci: int, req: Dictionary):
	var opts: Array = req.get("opts", [])
	if opts.is_empty():
		return null
	var t: String = req.get("type", "")
	var beast: bool = eng.is_beast(ci)
	var r = null
	match t:
		"turn":
			r = beast_turn(eng, ci, req) if beast else hunter_turn(eng, ci, req)
		"beast_step":
			r = beast_step(eng, ci, req)
		"beast_false":
			r = beast_false(eng, ci, req)
		"step", "loc", "summon_loc", "start":
			r = pick_loc_opt(eng, ci, req)
		"target":
			r = pick_target(eng, ci, req)
		"ap":
			r = opts[opts.size() - 1]["id"] if (level >= 1 and _finisher(eng, ci)) else opts[0]["id"]
		"fx_order":
			r = fx_order(eng, ci, req)
		"fx_one":
			r = fx_one(eng, ci, req)
		"draft", "card", "arsenal":
			r = pick_card(eng, ci, req)
		"draft_discard", "discard":
			r = worst_card(eng, ci, req)
		"upgrade":
			r = pick_upgrade(eng, ci, req)
		"summon":
			r = summon_choice(eng, ci, req)
		"summon_pick", "summon_remove":
			r = opts[rng.randi_range(0, opts.size() - 1)]["id"] if level == 0 else _first_not(opts, ["no", "end"])
			if str(r).is_valid_int():
				plan["summon"] = eng.find_obj(eng.summons, int(str(r)))
		"summon_action":
			r = summon_action(eng, ci, req)
		"trap_zone":
			r = trap_zone(eng, ci, req)
		"trap_hab":
			r = trap_hab(eng, ci, req)
		"yesno", "trap_trigger", "reaction", "ruin":
			r = yesno(eng, ci, req)
		"order":
			r = opts[0]["id"]
		"assign":
			r = opts[rng.randi_range(0, opts.size() - 1)]["id"]
		_:
			r = _first_not(opts, ["no", "end", "stop", "-"])
	if r == null:
		r = opts[0]["id"]
	return r


func _first_not(opts: Array, bad: Array):
	for o in opts:
		if not bad.has(str(o["id"])):
			return o["id"]
	return opts[0]["id"]


# ================================================================== cacciatori

## Obiettivo del cacciatore: il luogo più promettente (probabilità della Bestia / distanza),
## al Difficile coordinato con i compagni (ognuno su un'ipotesi diversa) e attento ai coloni.
func hunter_goal(eng, h: int) -> String:
	var pr := beast_probs(eng)
	var me: String = eng.ch[h]["loc"]
	if pr.is_empty():
		return me
	var taken := {}
	if level >= 2:
		# assegnazione: i cacciatori prima di me nell'ordine prendono i luoghi migliori per loro
		for o in eng.alive_hunters():
			if o == h:
				break
			var best := ""
			var bv := -1.0
			for l in pr:
				var v: float = pr[l] / (1.0 + eng.dist(eng.ch[o]["loc"], l, "settlement"))
				if v > bv and not taken.has(l):
					bv = v
					best = l
			if best != "":
				taken[best] = true
	var best2 := me
	var bv2 := -1.0
	for l in pr:
		var d: int = eng.dist(me, l, "settlement")
		var v2: float = float(pr[l]) / (1.0 + d * (0.6 if level >= 2 else 1.0))
		if taken.has(l):
			v2 *= 0.35
		# vicino a un colono la Bestia fa più danni: vale la pena presidiare
		if level >= 1:
			for s in eng.settlers:
				if eng.dist(s["loc"], l) <= 1:
					v2 *= 1.15 if level == 1 else tv("guard")
		if v2 > bv2:
			bv2 = v2
			best2 = l
	if level >= 2 and eng.contract_id == "titan" and not eng.settlers.is_empty() and not taken.is_empty():
		# Titan, Difficile: chi non è assegnato a un'ipotesi buona scorta il colono più lontano dalla meta
		var far := ""
		var fd := -1
		for s in eng.settlers:
			var dd := _titan_dist(eng, s["loc"])
			if dd < 99 and dd > fd:
				fd = dd
				far = s["loc"]
		if far != "" and bv2 < tv("escort"):
			best2 = far
	if level == 0 and rng.randf() < 0.3:
		var ks := pr.keys()
		best2 = ks[rng.randi_range(0, ks.size() - 1)]
	return best2


func p_here(eng, l: String) -> float:
	return float(beast_probs(eng).get(l, 0.0))


func revealed_beast_at(eng, l: String) -> bool:
	for b in eng.beasts():
		if not eng.ch[b]["dead"] and eng.ch[b]["revealed"] and eng.ch[b]["standee"] == l:
			return true
	return false


func hunter_turn(eng, h: int, req: Dictionary):
	var opts: Array = req["opts"]
	var me: String = eng.ch[h]["loc"]
	goal = hunter_goal(eng, h)
	plan = {"goal": goal}
	var ph := p_here(eng, me)
	var best = null
	var bv := -999.0
	for o in opts:
		var v := _hunter_value(eng, h, o, me, ph)
		v += rng.randf() * (0.6 if level == 0 else 0.15)
		if v > bv:
			bv = v
			best = o
	if best == null:
		return opts[0]["id"]
	if best.has("card"):
		var c := D.card(best["card"])
		plan["card"] = best["card"]
		plan["search_first"] = true
	return best["id"]


func _hunter_value(eng, h: int, o: Dictionary, me: String, ph: float) -> float:
	var id := str(o["id"])
	if id == "pass":
		return 0.4 if eng.n_actions(h) > 0 else 1.5
	if id == "end":
		return 0.5
	if id == "flee":
		return -1.0
	var cid: String = o["card"]
	var b := D.base_id(cid)
	var c := D.card(cid)
	var k := D.kind(cid)
	var dgoal: int = eng.dist(me, goal, "settlement")
	var beast_here := revealed_beast_at(eng, me)
	var v := 0.0
	var txt: String = c.get("hfx", c.get("fx", [])).duplicate().reduce(func(a, x): return a + " " + str(x), "")
	if txt.contains("search") or txt.contains("atk"):
		if beast_here:
			v += 6.0
		else:
			v += ph * 10.0
	if txt.contains("\"atk\"") and beast_here:
		v += 4.0
	if txt.contains("mv") or txt.contains("track") or txt.contains("prowl") or txt.contains("relocate") or txt.contains("rapier"):
		if dgoal > 0 and not beast_here:
			v += 1.5 + mini(dgoal, 3) * 0.6
		else:
			v -= 0.5
	if txt.contains("item"):
		v += 1.0
	if txt.contains("grudge"):
		v += 0.8
	if txt.contains("watchtower"):
		v += 1.3 if eng.towers.size() < 4 and not eng.towers.has(me) else -1.0
	if txt.contains("seer") or txt.contains("reveal_last"):
		v += 2.0 if _hidden_moves(eng) >= 2 else -1.0
	if c.get("c", "") == "T":
		v += 1.2 if eng.ch[h]["grudges"] >= 1 else -2
	if txt.contains("atk_summon"):
		v += 2.0 if _summon_near(eng, me) else -1.0
	if b in ["hunters_rest"]:
		v += 1.0 if eng.ch[h]["wounds"] > 0 else 0.0
	if txt.contains("suffer"):
		v -= 1.5
	if k == "action":
		v -= 0.3
	if k == "ability" and D.is_hunt(cid) and ph < 0.15 and not beast_here:
		v -= 2.0
	if str(o.get("mode", "")) == "O":
		v += 0.5
	if level >= 2 and eng.contract_id == "titan" and k == "action" and str(o.get("mode", "")) in ["R", "O"]:
		v += tv("red")
	return v


func _hidden_moves(eng) -> int:
	var n := 0
	for b in eng.beasts():
		n += eng.ch[b]["moves"].size()
	return n


func _summon_near(eng, l: String) -> bool:
	for nl in eng.nearby(l, "settlement"):
		if not eng.summons_at(nl).is_empty():
			return true
	return false


# ================================================================== Bestia

## Valore di una preda per il contratto in corso.
func prey_value(eng, b: int, kind: String) -> float:
	var k: String = eng.contract_id
	if kind in ["farmer", "noble"]:
		return _prey_raw(k, kind, eng) * tv("set")
	if kind in ["sheep", "boar", "sabertooth"]:
		return _prey_raw(k, kind, eng) * tv("an")
	return _prey_raw(k, kind, eng)


func _prey_raw(k: String, kind: String, eng) -> float:
	match kind:
		"farmer":
			return 6.0 if k != "regent" else 7.0
		"noble":
			return 6.5 if k != "regent" else 8.0
		"sheep":
			if eng.contract_id == "regent" and eng.ruins_of("B") >= 2:
				return 3.0
			return 2.0 if eng.night_no < 1 else 1.2
		"boar":
			return 2.2
		"sabertooth":
			return 3.0
		"hunter":
			return 2.5
	return 1.0


## Bersaglio della Bestia: il luogo con la preda migliore, pesato per la distanza e il pericolo.
func beast_goal(eng, b: int) -> String:
	var me: String = eng.ch[b]["loc"]
	var hab: String = eng.beast_hab(b)
	var best := me
	var bv := -999.0
	var dm: Dictionary = eng.dist_map(me, 8, hab)
	for l in dm:
		var v := 0.0
		for s in eng.settlers_at(l):
			v += prey_value(eng, b, s["kind"]) / (1.0 + float(s["wounds"] == 0) * 0.3) + float(s["wounds"]) * (tv("fin") if level >= 2 else 0.0)
		for a in eng.animals_at(l):
			v += prey_value(eng, b, a["kind"]) * 0.6
		for h in eng.hunters_at(l):
			var hp: int = D.HUNTERS[eng.ch[h]["id"]]["hp"]
			if hp - eng.ch[h]["wounds"] <= eng.beast_damage(b):
				v += 3.0
		if eng.ruin_at(l) != "" and eng.ruins.get(eng.ruin_at(l), "") != "B":
			v += (4.0 if eng.contract_id == "regent" else 2.0) * tv("ruin")
		if v <= 0:
			continue
		v -= float(dm[l]) * 0.9
		v -= _danger(eng, l) * (tv("dg") if level >= 1 else 0.1)
		if v > bv:
			bv = v
			best = l
	return best


## Pericolo di un luogo: cacciatori vicini.
func _danger(eng, l: String) -> float:
	var d := 0.0
	for h in eng.alive_hunters():
		var x: int = eng.dist(l, eng.ch[h]["loc"], "settlement")
		if x == 0:
			d += 3.0
		elif x == 1:
			d += 2.0
		elif x == 2:
			d += 0.8
	return d


func beast_turn(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	var me: String = eng.ch[b]["loc"]
	goal = beast_goal(eng, b)
	plan = {"goal": goal}
	if level == 0:
		return _beast_turn_simple(eng, b, req)
	var hab: String = eng.beast_hab(b)
	var prey_here := _prey_at(eng, b, me)
	var dang := _danger(eng, me)
	var revealed: bool = eng.ch[b]["revealed"]
	var cards := []
	for o in opts:
		if o.has("card"):
			var pf := card_profile(eng, b, str(o["card"]), str(o.get("mode", "")))
			pf["o"] = o
			cards.append(pf)
	var red_free: bool = req.get("red_free", true)
	var blue_free: bool = req.get("blue_free", true)
	# 1. preda qui: attacca (meglio se la carta permette anche di scappare)
	if prey_here >= 1.0:
		var best = null
		var bv := -99.0
		for pf in cards:
			if not pf["atk"]:
				continue
			var v: float = 5.0 + float(pf["mv"]) * 0.8 + float(pf["bonus"]) * 2.0
			# resta una carta di movimento dell'altro colore per la fuga?
			if _escape_left(cards, pf):
				v += 1.5
			if v > bv:
				bv = v
				best = pf
		if best != null:
			plan["attack"] = true
			return best["o"]["id"]
	# 2. preda raggiungibile in questo turno con un movimento, poi un attacco
	var best_mv = null
	var bmv := -99.0
	for pf in cards:
		if pf["mv"] <= 0:
			continue
		var can_attack_after: bool = pf["atk"] or _attack_left(cards, pf)
		var reach: Dictionary = eng.dist_map(me, int(pf["mv"]), hab)
		for l in reach:
			var pv := _prey_at(eng, b, l)
			var v2 := 0.0
			if pv > 0 and can_attack_after:
				v2 = pv * 1.2 - _danger(eng, l) * tv("dmv") - float(reach[l]) * 0.2
			elif pv > 0:
				v2 = pv * 0.35 - _danger(eng, l) * 0.6
			else:
				continue
			if v2 > bmv:
				bmv = v2
				best_mv = pf
				plan["goal"] = l
	if best_mv != null and bmv > 0.8:
		goal = plan["goal"]
		return best_mv["o"]["id"]
	# 3. rivelata e in pericolo: scappa
	if revealed and dang >= 1.5:
		var esc = null
		var ev := -99.0
		for pf in cards:
			if pf["mv"] > ev:
				ev = pf["mv"]
				esc = pf
		if esc != null:
			plan["escape"] = true
			goal = _escape_goal(eng, b, int(esc["mv"]))
			return esc["o"]["id"]
	# 4. carte che non rivelano: evocare, talenti, trasformare
	var util = null
	var uv := 0.6
	for pf in cards:
		var v3: float = pf["util"]
		if pf["atk"]:
			v3 -= 3.0
		if v3 > uv:
			uv = v3
			util = pf
	if util != null:
		return util["o"]["id"]
	# 5. avvicinarsi alle prede senza farsi vedere, oppure tenere le carte
	for o in opts:
		if str(o["id"]) == "pass" and (level >= 2 or rng.randf() < 0.6):
			return "pass"
	for o in opts:
		if str(o["id"]) == "end":
			return "end"
	var mvc = null
	var mvv := -99.0
	for pf in cards:
		if pf["mv"] > 0 and not pf["atk"] and pf["mv"] > mvv:
			mvv = pf["mv"]
			mvc = pf
	if mvc != null and eng.dist(me, goal, hab) > 1:
		return mvc["o"]["id"]
	return _beast_turn_simple(eng, b, req)


func _beast_turn_simple(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	var me: String = eng.ch[b]["loc"]
	var prey_here := _prey_at(eng, b, me)
	var dang := _danger(eng, me)
	var best = null
	var bv := -999.0
	for o in opts:
		var v := _beast_value(eng, b, o, me, prey_here, dang)
		v += rng.randf() * (0.8 if level == 0 else 0.2)
		if v > bv:
			bv = v
			best = o
	return best["id"] if best != null else opts[0]["id"]


## Profilo di una carta per la Bestia: attacca? quanti passi? utilità?
func card_profile(eng, b: int, cid: String, mode: String) -> Dictionary:
	var c := D.card(cid)
	var fx: Array = c.get("bfx", c.get("fx", ["seq"]))
	if mode == "O":
		fx = c.get("ofx", fx)
	elif mode.begins_with("C"):
		fx = c.get("chfx", fx)
	var out := {"cid": cid, "atk": false, "mv": 0, "bonus": 0, "util": 0.0, "col": mode.substr(mode.length() - 1)}
	if mode == "O":
		out["col"] = "O"
	for op in fx.slice(1):
		var k: String = op[0]
		match k:
			"atk", "atk_hydra":
				out["atk"] = true
				if op.size() > 1:
					out["bonus"] = int(op[1])
			"mv", "mvu", "mv_same", "mv_zone", "mv_false":
				out["mv"] += int(op[1])
			"mv_dash":
				out["mv"] += 1 + eng.alive_hunters().size() / 2
			"mv_lurk", "mv_uprise", "mv_void":
				out["mv"] += 1
			"mv_slither":
				out["mv"] += 2 if eng.has_hab(eng.ch[b]["loc"], "swamp") else 1
			"mv_flicker":
				out["mv"] += eng.deaths_today
			"mv_per_summon":
				out["mv"] += eng.summons.size()
			"stampede":
				out["mv"] += 2
			"summon":
				out["util"] += 1.2 if eng.summons_of(b).size() < eng.summon_max(b) else 0.8
			"talent":
				out["util"] += 1.0 * (int(op[1]) if op.size() > 1 else 1)
			"tf_here", "tf_near_all", "tf_near_upto", "abyss_near", "abyss_here":
				out["util"] += 0.5
			"ap":
				out["util"] += 0.8
			"buy_upgrade":
				out["util"] += 0.9
			"ret_ability", "take_discard", "look_unused":
				out["util"] += 0.7
			"reveal":
				out["util"] -= 2.0
			"suffer":
				out["util"] -= 2.0
	return out


func _escape_left(cards: Array, used: Dictionary) -> bool:
	for pf in cards:
		if pf == used or pf["mv"] <= 0:
			continue
		if pf["col"] != used["col"] and used["col"] != "O" and pf["col"] != "O":
			return true
	return used["mv"] > 0


func _attack_left(cards: Array, used: Dictionary) -> bool:
	for pf in cards:
		if pf == used or not pf["atk"]:
			continue
		if pf["col"] != used["col"] and used["col"] != "O" and pf["col"] != "O":
			return true
	return false


## Luogo di fuga: lontano dai cacciatori, entro n passi.
func _escape_goal(eng, b: int, n: int) -> String:
	var me: String = eng.ch[b]["loc"]
	var dm: Dictionary = eng.dist_map(me, max(1, n), eng.beast_hab(b))
	var best := me
	var bv := -99.0
	for l in dm:
		var v := -_danger(eng, l) + _prey_at(eng, b, l) * 0.2
		if v > bv:
			bv = v
			best = l
	return best


func _settler_wounds(eng, t: Dictionary) -> float:
	if level < 2:
		return 0.0
	for s in eng.settlers:
		if s["id"] == t.get("id", -1):
			return float(s["wounds"])
	return 0.0


func _prey_at(eng, b: int, l: String) -> float:
	var v := 0.0
	for t in eng.attack_targets(b, l):
		match str(t["t"]):
			"settler":
				# Difficile: finire il colono già ferito (di notte guarisce)
				v = max(v, prey_value(eng, b, t["kind"]) + _settler_wounds(eng, t) * tv("fin"))
			"animal":
				v = max(v, prey_value(eng, b, t["kind"]))
			"hunter":
				var hp: int = D.HUNTERS[eng.ch[t["ci"]]["id"]]["hp"]
				if hp - eng.ch[t["ci"]]["wounds"] <= eng.beast_damage(b) + 1:
					v = max(v, 3.0)
				else:
					v = max(v, 0.8)
	return v


func _beast_value(eng, b: int, o: Dictionary, me: String, prey: float, dang: float) -> float:
	var id := str(o["id"])
	if id == "pass":
		return 0.3 if eng.n_actions(b) > 0 else 1.2
	if id == "end":
		return 0.4 + (dang * 0.4 if eng.ch[b]["revealed"] else 0.0)
	if id == "flee":
		return -1.0 + (2.0 if eng.ch[b]["revealed"] and dang >= 2 else 0.0)
	var cid: String = o["card"]
	var c := D.card(cid)
	var fx: Array = c.get("bfx", c.get("fx", []))
	if str(o.get("mode", "")) == "O":
		fx = c.get("ofx", fx)
	var txt: String = fx.reduce(func(a, x): return a + " " + str(x), "")
	var v := 0.0
	var dgoal: int = eng.dist(me, goal, eng.beast_hab(b))
	if txt.contains("atk"):
		if prey > 0:
			v += 2.0 + prey
			# colpisci e scappa: meglio se dopo resta una carta blu di movimento
			if dang >= 2 and level >= 1 and not txt.contains("mv"):
				v -= 1.0
		else:
			v -= 3.0
	if txt.contains("mv") or txt.contains("stampede"):
		if prey > 0 and not txt.contains("atk"):
			v -= 1.0
		elif dgoal > 0:
			v += 1.2 + mini(dgoal, 3) * 0.5
		if eng.ch[b]["revealed"] and dang > 0:
			v += 1.5 + dang * 0.5
	if txt.contains("summon"):
		v += 1.4 if eng.summons_of(b).size() < eng.summon_max(b) else 0.6
	if txt.contains("talent"):
		v += 1.0
	if txt.contains("tf_"):
		v += 0.6
	if txt.contains("mv_false"):
		v += 1.0 if level >= 2 else 0.3
	if txt.contains("ap"):
		v += 0.6
	if txt.contains("reveal\"") and not eng.ch[b]["revealed"]:
		v -= 1.5
	if D.kind(cid) == "action":
		v -= 0.2
	if txt.contains("suffer"):
		v -= 2.0
	return v


func beast_step(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	if goal == "":
		goal = beast_goal(eng, b)
	var hab: String = eng.beast_hab(b)
	var me: String = eng.ch[b]["loc"]
	if plan.get("attack", false) and eng.ch[b]["revealed"] and level >= 1 and _prey_at(eng, b, me) < 1.0:
		goal = _escape_goal(eng, b, 2)
	var bel: BSBelief = belief(eng, b) if level >= 2 else null
	var observed: Array = eng.observed_locs(b) if level >= 2 else []
	var best = null
	var bv := -999.0
	for o in opts:
		var id := str(o["id"])
		if id == "stop":
			var vs := 0.2 if _prey_at(eng, b, me) > 0 else -0.5
			if vs > bv:
				bv = vs
				best = o
			continue
		var t: String = o.get("loc", me)
		var v := -float(eng.dist(t, goal, hab)) * 1.0
		v -= _danger(eng, t) * (tv("dst") if level >= 1 else 0.2)
		v += _prey_at(eng, b, t) * 0.4
		if level >= 1 and observed.has(t) == false and level >= 2:
			v += 0.4
		if level >= 2 and bel != null:
			# bluff: tenere aperte più ipotesi possibili per i cacciatori
			v += log(1.0 + bel.support_after(t, observed)) * tv("bluff")
			if observed.has(t):
				v -= 1.2
		if id == "X":
			v -= 0.6
		v += rng.randf() * (1.5 if level == 0 else 0.3)
		if v > bv:
			bv = v
			best = o
	return best["id"] if best != null else opts[0]["id"]


## Carta falsa: verso i cacciatori o lontano dalla Bestia, per sviarli.
func beast_false(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	var best = opts[0]
	var bv := -999.0
	for o in opts:
		var t: String = o.get("loc", "")
		var v := float(eng.dist(t, eng.ch[b]["loc"]))
		if level >= 2:
			# una falsa che genera una traccia lontana dalla vera confonde di più
			for h in eng.alive_hunters():
				if eng.ch[h]["loc"] == t:
					v += 2.0
		v += rng.randf()
		if v > bv:
			bv = v
			best = o
	return best["id"]


# ================================================================== scelte comuni

func pick_loc_opt(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var beast: bool = eng.is_beast(ci)
	var t: String = req.get("type", "")
	var mover: String = req.get("mover", "")
	if t == "start":
		# i cacciatori si distribuiscono; un cacciatore che torna in gioco va vicino alla Bestia
		var pr := beast_probs(eng)
		var best = opts[0]
		var bv := -999.0
		for o in opts:
			var l: String = o.get("loc", "")
			var v := 0.0
			for pl in pr:
				v += float(pr[pl]) / (1.0 + eng.dist(l, pl, "settlement"))
			for h in eng.alive_hunters():
				if h != ci and eng.ch[h]["loc"] == l:
					v -= 0.5
			v += rng.randf() * (1.0 if level == 0 else 0.2)
			if v > bv:
				bv = v
				best = o
		return best["id"]
	if t == "summon_loc":
		var best2 = opts[0]
		var bv2 := -999.0
		for o in opts:
			var l2: String = o.get("loc", "")
			var v2 := _prey_at(eng, ci, l2) - _danger(eng, l2) * 0.2
			if eng.ruin_at(l2) != "" and eng.ruins.get(eng.ruin_at(l2), "") != "B":
				v2 += 4.0
			# al Difficile l'evocato si mette lontano dalla Bestia per non tradirla
			if level >= 2:
				v2 += float(eng.dist(l2, eng.ch[ci]["loc"])) * 0.5
			v2 += rng.randf() * 0.3
			if v2 > bv2:
				bv2 = v2
				best2 = o
		return best2["id"]
	# passo di un cacciatore (o di un essere mosso da un cacciatore)
	if not beast and (mover == "" or mover.begins_with("hunter")):
		var g := goal if goal != "" else hunter_goal(eng, ci)
		var best3 = opts[0]
		var bv3 := -999.0
		for o in opts:
			if str(o["id"]) == "stop":
				var vs := 0.0
				if eng.ch[ci]["loc"] == g:
					vs = 5.0
				if revealed_beast_at(eng, eng.ch[ci]["loc"]):
					vs = 6.0
				if vs > bv3:
					bv3 = vs
					best3 = o
				continue
			var l3: String = o.get("loc", "")
			var v3 := -float(eng.dist(l3, g, "settlement"))
			v3 += p_here(eng, l3) * 3.0
			if eng.trails.has(l3):
				v3 += 0.3
			if o.get("dir", "") == "A":
				v3 -= 1.5
			v3 += rng.randf() * (1.0 if level == 0 else 0.1)
			if v3 > bv3:
				bv3 = v3
				best3 = o
		return best3["id"]
	if mover.begins_with("summon") and beast:
		var best6 = opts[0]
		var bv6 := -999.0
		var sid := int(mover.get_slice(":", 1))
		var su2: Dictionary = eng.find_obj(eng.summons, sid)
		for o in opts:
			var l6: String = o.get("loc", su2.get("loc", ""))
			if str(o["id"]) == "stop":
				l6 = su2.get("loc", "")
			if l6 == "":
				continue
			var v6 := 0.0
			for t6 in eng.summon_targets(l6):
				if t6["t"] in ["settler", "animal"]:
					v6 += 2.0
			if eng.ruin_at(l6) != "" and eng.ruins.get(eng.ruin_at(l6), "") != "B":
				v6 += 3.0
			# verso le prede più vicine
			var dm6: Dictionary = eng.dist_map(l6, 3)
			for s6 in eng.settlers:
				if dm6.has(s6["loc"]):
					v6 += 1.0 / (1.0 + dm6[s6["loc"]])
			v6 += rng.randf() * 0.2
			if v6 > bv6:
				bv6 = v6
				best6 = o
		return best6["id"]
	if mover.begins_with("settler"):
		# i coloni scappano dalla Bestia (per quanto se ne sa)
		var pr2 := beast_probs(eng)
		var best4 = opts[0]
		var bv4 := -999.0
		for o in opts:
			var l4: String = o.get("loc", "")
			var v4 := 0.0
			if str(o["id"]) == "stop":
				l4 = ""
			for pl in pr2:
				if l4 != "":
					v4 -= float(pr2[pl]) / (1.0 + eng.dist(l4, pl))
			if l4 != "" and not eng.hunters_at(l4).is_empty():
				v4 += 0.5
			if eng.contract_id == "titan":
				var cur: String = l4 if l4 != "" else _settler_loc(eng, mover)
				if eng.titan_hab.has(cur):
					v4 += 5.0
				elif level >= 1:
					# verso il luogo protetto più vicino ancora da raggiungere
					v4 -= float(_titan_dist(eng, cur)) * (1.4 if level >= 2 else 0.7)
			if v4 > bv4:
				bv4 = v4
				best4 = o
		return best4["id"]
	# esseri mossi dalla Bestia: verso di lei / lontano dai cacciatori
	var best5 = opts[0]
	var bv5 := -999.0
	for o in opts:
		var l5: String = o.get("loc", "")
		var v5 := 0.0
		if l5 != "":
			v5 = -float(eng.dist(l5, eng.ch[ci]["loc"] if beast else l5)) + _prey_at(eng, ci, l5) if beast else 0.0
		if str(o["id"]) == "stop":
			v5 = -0.5
		v5 += rng.randf() * 0.3
		if v5 > bv5:
			bv5 = v5
			best5 = o
	return best5["id"]


func _settler_loc(eng, mover: String) -> String:
	var id := int(mover.get_slice(":", 1))
	for s in eng.settlers:
		if s["id"] == id:
			return s["loc"]
	return ""


func _titan_dist(eng, l: String) -> int:
	var d := 99
	for t in eng.titan_hab:
		d = mini(d, eng.dist(l, t, "settlement"))
	return d


func pick_target(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var best = opts[0]
	var bv := -999.0
	for o in opts:
		if not o.has("ref"):
			if str(o["id"]) in ["no", "-"]:
				if bv < -5:
					best = o
				continue
			continue
		var t: Dictionary = o["ref"]
		var v := 0.0
		match str(t["t"]):
			"beast":
				v = 20.0
			"summon":
				v = 5.0
			"settler":
				v = prey_value(eng, ci, t["kind"]) + 1.0
			"animal":
				v = prey_value(eng, ci, t["kind"])
			"hunter":
				if eng.is_beast(ci):
					var hp: int = D.HUNTERS[eng.ch[t["ci"]]["id"]]["hp"]
					v = 4.0 if hp - eng.ch[t["ci"]]["wounds"] <= eng.beast_damage(ci) else 1.5
				else:
					v = 0.5
			"tower":
				v = 0.7
			"companion":
				v = 0.3
		v += rng.randf() * 0.2
		if v > bv:
			bv = v
			best = o
	return best["id"]


func _finisher(eng, ci: int) -> bool:
	# usare i Poteri antichi quando chiudono un'uccisione importante o colpiscono la Bestia
	return not eng.is_beast(ci) or eng.ch[ci]["ap"] > 0


func fx_order(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var labels := opts.map(func(o): return str(o["label"]))
	var beast: bool = eng.is_beast(ci)
	var me: String = eng.ch[ci]["loc"]
	# cacciatori: prima perlustra, poi attacca; Bestia: prima attacca (se c'è preda), poi muovi
	for o in opts:
		var lb := str(o["label"])
		if not beast and lb.begins_with("Perlustra"):
			if p_here(eng, me) > 0.02 or revealed_beast_at(eng, me):
				return o["id"]
		if lb == "Attacca":
			if beast and _prey_at(eng, ci, me) > 0:
				return o["id"]
			if not beast and revealed_beast_at(eng, me):
				return o["id"]
	for o in opts:
		var lb2 := str(o["label"])
		if lb2.begins_with("Muovi") or lb2.begins_with("Spostati"):
			if beast and (_prey_at(eng, ci, me) > 0 and not eng.ch[ci]["revealed"]):
				continue
			return o["id"]
		if lb2.begins_with("Prendi") or lb2.begins_with("Guadagna") or lb2.begins_with("Evoca") or lb2.begins_with("Trasforma") or lb2.begins_with("Rivela"):
			if lb2.begins_with("Rivela") and beast:
				continue
			return o["id"]
	for o in opts:
		if str(o["label"]) == "Attacca" and beast and _prey_at(eng, ci, me) > 0:
			return o["id"]
	return opts[opts.size() - 1]["id"]


func fx_one(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var me: String = eng.ch[ci]["loc"]
	for o in opts:
		var lb := str(o["label"])
		if lb.begins_with("Perlustra") and (p_here(eng, me) > 0.1 or revealed_beast_at(eng, me)):
			return o["id"]
		if lb.contains("Banshee") and eng.is_beast(ci) and _danger(eng, me) >= 2:
			return o["id"]
	for o in opts:
		var lb2 := str(o["label"])
		if lb2.begins_with("Muovi") or lb2.begins_with("Ogni cacciatore"):
			return o["id"]
	return opts[0]["id"]


## Valore di una carta per chi la prende (draft, arsenale, scelte di carte).
func card_value(eng, ci: int, cid: String) -> float:
	if cid == "top":
		return 1.5
	var c := D.card(cid)
	var beast: bool = eng.is_beast(ci)
	var fx: Array = c.get("bfx" if beast else "hfx", c.get("fx", []))
	var txt: String = fx.reduce(func(a, x): return a + " " + str(x), "")
	var v := 1.0
	if txt.contains("atk"):
		v += 2.0 if beast else 1.5
	if txt.contains("search"):
		v += 1.8
	if txt.contains("mv") or txt.contains("relocate") or txt.contains("hunter_to_hunter"):
		v += 1.6
	if txt.contains("summon"):
		v += 1.0
	if txt.contains("talent") or txt.contains("item"):
		v += 1.0
	if txt.contains("grudge"):
		v += 0.8
	if txt.contains("suffer"):
		v -= 1.0
	if c.get("c", "") == "T":
		v += 1.0
	if c.get("c", "") == "X":
		v += 0.8
	v -= float(c.get("cost", 0)) * 0.3
	return v + rng.randf() * (1.0 if level == 0 else 0.2)


func pick_card(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var best = opts[0]
	var bv := -999.0
	for o in opts:
		var v := card_value(eng, ci, str(o.get("card", o["id"])))
		if v > bv:
			bv = v
			best = o
	return best["id"]


func worst_card(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	var best = opts[0]
	var bv := 999.0
	for o in opts:
		var cid := str(o.get("card", o["id"]))
		var v := card_value(eng, ci, cid)
		if D.kind(cid) == "ability":
			v += 2.0
		if v < bv:
			bv = v
			best = o
	return best["id"]


## Potenziamenti: i danni doppi della Bestia sono la priorità; poi i più economici.
func pick_upgrade(eng, ci: int, req: Dictionary):
	var opts: Array = req["opts"]
	if level == 0 and rng.randf() < 0.4:
		return "end"
	var best = null
	var bv := -999.0
	for o in opts:
		var id := str(o["id"])
		if id == "end":
			continue
		var lb := str(o["label"])
		var v := 0.0
		if lb.contains("2 danni"):
			v += 6.0
		v -= float(lb.get_slice("(", 1).get_slice(")", 0).to_int()) * 0.4
		v += rng.randf()
		if v > bv:
			bv = v
			best = o
	if best == null:
		return "end"
	# al Difficile la Bestia risparmia per i danni doppi
	if level >= 2 and eng.is_beast(ci) and not str(best["label"]).contains("2 danni"):
		for u in eng.upgrade_table(ci):
			var t: Array = eng.upgrade_table(ci)[u]
			if str(t[3]).contains("2 danni") and not eng.ch[ci]["upg"].has(u) and eng.ch[ci]["grudges"] + 2 >= int(t[1]) and eng.ch[ci]["grudges"] < int(t[1]):
				return "end"
	return best["id"]


func summon_choice(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	var mine: Array = eng.summons_of(b)
	for o in opts:
		if str(o["id"]) == "act":
			for s in mine:
				if _prey_at(eng, b, s["loc"]) > 0:
					return "act"
	for o in opts:
		if str(o["id"]) == "place" and mine.size() < eng.summon_max(b):
			return "place"
	return opts[0]["id"]


func summon_action(eng, b: int, req: Dictionary):
	var opts: Array = req["opts"]
	for o in opts:
		if str(o["id"]) == "attack":
			return "attack"
	var su: Dictionary = plan.get("summon", {})
	if not su.is_empty() and eng.ruin_at(su["loc"]) != "" and eng.ruins.get(eng.ruin_at(su["loc"]), "") != "B":
		return "ability"
	if level >= 1 and rng.randf() < 0.5:
		for o in opts:
			if str(o["id"]) == "ability":
				return "ability"
	return "move"


func trap_zone(eng, h: int, req: Dictionary):
	var pr := beast_probs(eng)
	var best = req["opts"][0]
	var bv := -1.0
	for o in req["opts"]:
		var v := 0.0
		for l in pr:
			if eng.in_zone(l, str(o["id"])):
				v += float(pr[l])
		if v > bv:
			bv = v
			best = o
	return best["id"]


func trap_hab(eng, h: int, req: Dictionary):
	# l'habitat preferito della Bestia è quello dove si rivela più spesso
	for b in eng.beasts():
		return eng.beast_hab(b)
	return req["opts"][0]["id"]


func yesno(eng, ci: int, req: Dictionary):
	var t: String = req.get("type", "")
	var pr: String = req.get("prompt", "")
	if t == "trap_trigger" or t == "ruin":
		return "y"
	if t == "reaction":
		return "y" if level >= 1 or rng.randf() < 0.5 else "n"
	if pr.begins_with("C'è una Traccia"):
		return "y"
	if pr.contains("subire 1 ferita"):
		return "y" if eng.ch[ci]["wounds"] == 0 else "n"
	if pr.contains("Rivelare") or pr.contains("rivelare"):
		return "n" if eng.is_beast(ci) and level >= 1 else "y"
	return "y" if rng.randf() < 0.8 else "n"
