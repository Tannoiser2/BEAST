class_name BSState
extends Node
## Stato della partita e funzioni di servizio comuni (mappa, esseri, registro, decisioni, viste).
## Il motore completo (BSEngine) estende questa classe a strati: movimenti e combattimento
## (engine_rules.gd), effetti delle carte (engine_fx.gd), fasi del round (engine.gd).
##
## INFORMAZIONE NASCOSTA. Il motore conosce tutto e gira su un solo dispositivo: quello della Bestia
## (o di chi crea la stanza se la Bestia è dell'IA, oppure il dispositivo unico in solitario e in hotseat).
## Le interfacce e le IA leggono solo `view_for(squadra)`: la vista dei cacciatori non contiene mai
## la posizione della Bestia né le sue carte; quella della Bestia non contiene mani e trappole dei cacciatori.

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(results: Dictionary)
signal event_added(ev: Dictionary)

const D = preload("res://scripts/data/bs_data.gd")
const DIRS := ["N", "E", "S", "W"]

var rng := RandomNumberGenerator.new()
var headless := false
var ai_delay := 0.0
var abort := false
var online = null            # sessione online del server (OnlineServer) oppure null
var ais := {}                # indice personaggio -> IA
var game_over := false
var results := {}
var seed_used := 0

# --- configurazione
var contract_id := "regent"
var base_only := false       # solo gioco base: niente carte dell'espansione Isole Frantumate
var K: Dictionary = {}       # dati del contratto
var M: Dictionary = {}       # dati della mappa
var LOCS: Dictionary = {}
var n_players := 2           # persone al tavolo (per il draft)

# --- personaggi: indici 0..nb-1 Bestie, poi cacciatori
var ch: Array = []
var nb := 1                  # numero di Bestie
var order: Array = []        # ordine di turno (indici)
var participants: Array = [] # partecipanti al draft: {"chars": [indici], "pick": n}

# --- tavolo
var tokens := {}             # luogo -> habitat del segnalino (forest, swamp, cave, settlement, abyss)
var animals: Array = []      # {id, kind, loc, wounds, armor}
var settlers: Array = []     # {id, kind, loc, wounds, armor, start}
var summons: Array = []      # {id, owner, kind, loc, wounds}
var towers: Array = []       # luoghi delle torri di guardia (max 6)
var trails := {}             # luogo -> {indice Bestia: numero}
var traps: Array = []        # {zone, card, hab, owner}  (segreto dei cacciatori)
var ruins := {}              # id rovina -> "" | "H" | "B"
var companion := ""          # luogo di Fylgja ("" fuori mappa)
var next_id := 1

# --- mazzi
var action_deck: Array = []
var unused: Array = []
var action_disc: Array = []
var item_deck: Array = []
var item_up: Array = []
var item_disc: Array = []
var talent_deck: Array = []
var talent_up: Array = []
var talent_disc: Array = []
var ap_supply := 3
var arsenal_extra := 0

# --- tempo
var day := 0
var phase := "setup"          # setup, dawn, day, night, end
var turn_ci := -1
var night_no := 0

# --- statistiche e contratto
var kills := {}               # tipo -> numero (uccisi dalla Bestia)
var dead_animals := 0
var dead_sheep := 0
var deaths_today := 0
var beast_dmg := 0
var beast_wounds := 0         # ferite della Bestia (in 5 giocatori: riserva comune)
var beast_hp := 5
var dom := {"red": 0, "blue": 0}
var contract_tokens := 0
var protected := []           # luoghi che non si possono trasformare (Titan)
var titan_hab := {}           # luogo -> habitat messo all'inizio (Titan)
var flags := {}

# --- registro
var log_lines: Array = []
var events: Array = []        # eventi pubblici (servono all'animazione e all'IA dei cacciatori)
var secret_log: Array = []    # mosse segrete della Bestia (per il commit-reveal a fine partita)
var current_req := {}
var salt := ""                 # sale segreto della Bestia per gli impegni (commit-reveal)


static func commit_hash(p_salt: String, n: int, ci: int, moves: Array) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(("%s|%d|%d|%s" % [p_salt, n, ci, JSON.stringify(moves, "", true)]).to_utf8_buffer())
	return hc.finish().hex_encode()


static func salt_commit(p_salt: String) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(("sale|" + p_salt).to_utf8_buffer())
	return hc.finish().hex_encode()


# ================================================================== servizi generali

func log_msg(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 800:
		log_lines.pop_front()
	log_added.emit(t)


## Evento pubblico: lo vedono tutti (anche online). Non deve contenere segreti.
func ev(e: Dictionary) -> void:
	# dopo l'evento di fine partita non si pubblica più nulla (un effetto a metà può ancora girare)
	if game_over and not events.is_empty() and str(events.back().get("t", "")) == "end":
		return
	e["n"] = events.size()
	e["day"] = day
	events.append(e)
	event_added.emit(e)


func new_id() -> int:
	next_id += 1
	return next_id


func shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func is_beast(ci: int) -> bool:
	return ci >= 0 and ci < nb


func side(ci: int) -> String:
	return "B" if is_beast(ci) else "H"


func cname(ci: int) -> String:
	if ci < 0 or ci >= ch.size():
		return "?"
	return str(ch[ci]["name"])


func hunters() -> Array:
	return range(nb, ch.size())


func alive_hunters() -> Array:
	return hunters().filter(func(i): return not ch[i]["dead"])


func beasts() -> Array:
	return range(nb)


func cdata(ci: int) -> Dictionary:
	return D.BEASTS[ch[ci]["id"]] if is_beast(ci) else D.HUNTERS[ch[ci]["id"]]


func has_up(ci: int, u: String) -> bool:
	return ch[ci]["upg"].has(u)


func beast_hab(ci: int) -> String:
	return str(D.BEASTS[ch[ci]["id"]]["hab"])


# ================================================================== mappa

func loc(id: String) -> Dictionary:
	return LOCS.get(id, {})


## Habitat effettivi di un luogo (il segnalino copre quelli stampati; la palude abissale vale palude).
func habs(l: String) -> Array:
	if tokens.has(l):
		var t: String = tokens[l]
		return ["swamp", "abyss"] if t == "abyss" else [t]
	return LOCS[l]["hab"]


func has_hab(l: String, h: String) -> bool:
	return habs(l).has(h)


func is_abyss(l: String) -> bool:
	return tokens.get(l, "") == "abyss"


func zone_of(l: String) -> String:
	if not LOCS.has(l):
		return ""
	return str(LOCS[l]["zone"])


func same_zone(a: String, b: String) -> bool:
	var za := zone_of(a)
	var zb := zone_of(b)
	return za == "*" or zb == "*" or za == zb


func in_zone(l: String, z: String) -> bool:
	var zl := zone_of(l)
	return zl == "*" or z == "*" or zl == z


func zone_ids() -> Array:
	return M["zones"].keys()


## Habitat preferito di chi si muove: "settlement" per cacciatori, coloni e Fylgja.
func mover_hab(who: String, ci := -1) -> String:
	if who == "beast" or who == "summon":
		return beast_hab(ci)
	if who == "animal":
		return ""
	return "settlement"


## Il Sentiero nascosto dal luogo l è aperto per chi ha l'habitat h?
func hidden_open(l: String, h: String) -> bool:
	if h == "" or not LOCS[l].has("hp"):
		return false
	if h == "settlement" and flags.get("no_settler_hp", false) and false:
		return false
	return has_hab(l, h)


## Vicini percorribili: {direzione: luogo}. Con hab != "" include il Sentiero nascosto se aperto.
func step_targets(l: String, hab := "") -> Dictionary:
	if not LOCS.has(l):
		return {}
	var out: Dictionary = LOCS[l]["nb"].duplicate()
	if hab != "" and hidden_open(l, hab):
		out[LOCS[l]["hpdir"]] = LOCS[l]["hp"]
	return out


## Luoghi «vicini»: il proprio e quelli collegati da un sentiero (anche i Sentieri nascosti aperti per hab).
func nearby(l: String, hab := "") -> Array:
	if not LOCS.has(l):
		return []
	var out := [l]
	var st := step_targets(l, hab)
	for d in st:
		var t: String = st[d]
		if not out.has(t):
			out.append(t)
	return out


func adjacent(a: String, b: String, hab := "") -> bool:
	return a != b and nearby(a, hab).has(b)


## Distanze in passi da l (BFS) fino a maxd.
func dist_map(l: String, maxd := 99, hab := "") -> Dictionary:
	if not LOCS.has(l):
		return {}
	var d := {l: 0}
	var q := [l]
	while not q.is_empty():
		var c: String = q.pop_front()
		if d[c] >= maxd:
			continue
		var st := step_targets(c, hab)
		for k in st:
			var t: String = st[k]
			if not d.has(t):
				d[t] = d[c] + 1
				q.append(t)
	return d


func dist(a: String, b: String, hab := "") -> int:
	return int(dist_map(a, 30, hab).get(b, 99))


## Luoghi nella stessa direzione: [primo passo, secondo passo, …] fino a n (si ferma al bordo).
func line_from(l: String, dir: String, n: int, hab := "") -> Array:
	var out := []
	var c := l
	for i in range(n):
		var st := step_targets(c, hab)
		if not st.has(dir):
			break
		c = st[dir]
		out.append(c)
	return out


func dir_between(a: String, b: String, hab := "") -> String:
	var st := step_targets(a, hab)
	for d in st:
		if st[d] == b:
			return d
	return ""


func settlements() -> Array:
	return LOCS.keys().filter(func(l): return has_hab(l, "settlement"))


func center() -> String:
	return str(M["center"])


func ruin_at(l: String) -> String:
	return str(LOCS[l].get("ruin", ""))


func ruin_loc(r: String) -> String:
	for l in LOCS:
		if LOCS[l].get("ruin", "") == r:
			return l
	return ""


func ruins_of(team: String) -> int:
	var n := 0
	for r in ruins:
		if ruins[r] == team:
			n += 1
	return n


# ================================================================== esseri

func hunters_at(l: String) -> Array:
	return alive_hunters().filter(func(i): return ch[i]["loc"] == l)


func settlers_at(l: String) -> Array:
	return settlers.filter(func(s): return s["loc"] == l)


func animals_at(l: String) -> Array:
	return animals.filter(func(a): return a["loc"] == l)


func summons_at(l: String, owner := -1) -> Array:
	return summons.filter(func(s): return s["loc"] == l and (owner < 0 or s["owner"] == owner))


func summons_of(ci: int) -> Array:
	return summons.filter(func(s): return s["owner"] == ci)


func beasts_at(l: String, revealed_only := false) -> Array:
	return beasts().filter(func(b): return not ch[b]["dead"] and ch[b]["loc"] == l and (not revealed_only or ch[b]["revealed"]))


func towers_at(l: String) -> int:
	return towers.count(l)


func summon_hp(kind: String) -> int:
	return 2 if K.get("setup", {}).get("dominion", false) else 1


func being_name(b: Dictionary) -> String:
	match str(b.get("t", "")):
		"hunter":
			return cname(int(b["ci"]))
		"beast":
			return cname(int(b["ci"]))
		"settler":
			return D.SETTLERS[b["kind"]]["n"]
		"animal":
			return D.ANIMALS[b["kind"]]["n"]
		"summon":
			return D.SUMMONS[b["kind"]]["n"]
		"tower":
			return "Torre di guardia"
		"companion":
			return "Fylgja"
	return "?"


## Esseri in un luogo come riferimenti {t, ci|id, kind}. Le Bestie solo se rivelate.
func beings_at(l: String, with_beasts := true) -> Array:
	var out := []
	for i in hunters_at(l):
		out.append({"t": "hunter", "ci": i})
	for s in settlers_at(l):
		out.append({"t": "settler", "id": s["id"], "kind": s["kind"]})
	for a in animals_at(l):
		out.append({"t": "animal", "id": a["id"], "kind": a["kind"]})
	for s in summons_at(l):
		out.append({"t": "summon", "id": s["id"], "kind": s["kind"]})
	if companion == l:
		out.append({"t": "companion"})
	if with_beasts:
		for b in beasts_at(l, true):
			out.append({"t": "beast", "ci": b})
	return out


func find_obj(arr: Array, id: int) -> Dictionary:
	for o in arr:
		if o["id"] == id:
			return o
	return {}


func being_loc(b: Dictionary) -> String:
	match str(b["t"]):
		"hunter", "beast":
			return str(ch[b["ci"]]["loc"])
		"settler":
			return str(find_obj(settlers, b["id"]).get("loc", ""))
		"animal":
			return str(find_obj(animals, b["id"]).get("loc", ""))
		"summon":
			return str(find_obj(summons, b["id"]).get("loc", ""))
		"companion":
			return companion
	return ""


func being_key(b: Dictionary) -> String:
	if b.has("ci"):
		return "%s:%d" % [b["t"], b["ci"]]
	if b.has("id"):
		return "%s:%d" % [b["t"], b["id"]]
	return str(b["t"])


# ================================================================== decisioni

## Chiede una decisione al personaggio ci. req = {type, prompt, opts: [{id, label, loc?, card?}], …}.
## Restituisce l'id dell'opzione scelta. Una sola opzione obbligata: si sceglie da sola.
func decide(ci: int, req: Dictionary):
	req["ci"] = ci
	req["side"] = side(ci)
	var opts: Array = req.get("opts", [])
	if opts.is_empty():
		return null
	if opts.size() == 1 and not req.get("ask_single", false):
		return opts[0]["id"]
	if abort or game_over:
		return opts[0]["id"]
	var who := controller(ci)
	current_req = req
	var r
	if online != null:
		r = await online.decide(self, ci, req)
	elif who.get("ai", true):
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		r = ais[ci].decide(self, ci, req)
	else:
		changed.emit()
		decision_requested.emit(req)
		r = await decision_provided
	current_req = {}
	# validazione: una risposta fuori elenco vale come la prima opzione
	for o in opts:
		if str(o["id"]) == str(r):
			return o["id"]
	return opts[0]["id"]


func provide_decision(r) -> void:
	decision_provided.emit(r)


## Chi controlla il personaggio: {"ai": bool, "level": int, "who": nome}. Esmeria (Ipnotizzare) può
## prendere il controllo di un cacciatore per un turno.
func controller(ci: int) -> Dictionary:
	var c: Dictionary = ch[ci]
	if c.get("mesmerised_by", -1) >= 0:
		return ch[c["mesmerised_by"]]["ctrl"]
	return c["ctrl"]


func yesno(ci: int, prompt: String, yes := "Sì", no := "No", t := "yesno") -> bool:
	var r = await decide(ci, {"type": t, "prompt": prompt, "opts": [{"id": "y", "label": yes}, {"id": "n", "label": no}], "ask_single": true})
	return str(r) == "y"


## Scelta di un luogo fra quelli dati.
func pick_loc(ci: int, prompt: String, locs: Array, allow_none := false, t := "loc") -> String:
	var opts := []
	for l in locs:
		opts.append({"id": l, "label": loc_label(l), "loc": l})
	if allow_none:
		opts.append({"id": "-", "label": "Nessuno"})
	if opts.is_empty():
		return ""
	var r = await decide(ci, {"type": t, "prompt": prompt, "opts": opts, "ask_single": allow_none})
	return "" if str(r) == "-" else str(r)


func loc_label(l: String) -> String:
	var L: Dictionary = LOCS[l]
	var s := ""
	if L.has("name"):
		s = str(L.get("label", str(L["name"]).replace("_", " ").capitalize()))
	elif l == center():
		s = "Centro"
	else:
		var hs := []
		for h in habs(l):
			if h != "abyss" or true:
				hs.append(D.HAB_IT.get(h, h))
		s = "/".join(hs).capitalize()
	var z := zone_of(l)
	if z != "*":
		s += " (" + str(M["zones"][z]) + ")"
	if L.has("ruin"):
		s += " · " + str(M["ruins"][L["ruin"]])
	return s


# ================================================================== viste (informazione nascosta)

## Vista della partita per una squadra: "B" (Bestie), "H" (cacciatori) o "P" (pubblico).
## È un dizionario serializzabile in JSON: lo usano interfaccia, IA e rete.
func view_for(team: String) -> Dictionary:
	var v := {
		"contract": contract_id, "map": M.get("id", "lsi"), "day": day, "phase": phase, "night": night_no,
		"turn": turn_ci, "team": team, "nb": nb, "over": game_over, "results": results,
		"tokens": tokens.duplicate(), "towers": towers.duplicate(), "companion": companion,
		"ruins": ruins.duplicate(), "dom": dom.duplicate(), "ctokens": contract_tokens,
		"animals": animals.duplicate(true), "settlers": settlers.duplicate(true), "summons": summons.duplicate(true),
		"action_disc": action_disc.duplicate(), "item_up": item_up.duplicate(), "talent_up": talent_up.duplicate(),
		"item_disc": item_disc.duplicate(), "talent_disc": talent_disc.duplicate(),
		"decks": {"action": action_deck.size(), "unused": unused.size(), "item": item_deck.size(), "talent": talent_deck.size()},
		"ap_supply": ap_supply, "beast_wounds": beast_wounds, "beast_hp": beast_hp, "kills": kills.duplicate(),
		"log": log_lines.slice(max(0, log_lines.size() - 120)), "ev_n": events.size(), "order": order.duplicate(),
		"protected": protected.duplicate(),
	}
	# tracce: numero per luogo (pubblico); per Bestia solo alle Bestie
	var tr := {}
	for l in trails:
		var n := 0
		for b in trails[l]:
			n += int(trails[l][b])
		if n > 0:
			tr[l] = n
	v["trails"] = tr
	if team == "B":
		v["trails_by"] = trails.duplicate(true)
	# trappole: quante per zona; i dettagli solo ai cacciatori
	var tz := {}
	for t in traps:
		tz[t["zone"]] = int(tz.get(t["zone"], 0)) + 1
	v["traps_n"] = tz
	if team == "H":
		v["traps"] = traps.duplicate(true)
	var cs := []
	for i in range(ch.size()):
		var c: Dictionary = ch[i]
		var pub := {
			"i": i, "id": c["id"], "name": c["name"], "side": side(i), "grudges": c["grudges"], "ap": c["ap"],
			"upg": c["upg"].keys(), "abil_disc": c["abil_disc"].duplicate(), "dead": c["dead"], "wounds": c.get("wounds", 0),
			"armor": c.get("armor", 0), "skip": c.get("skip", 0), "hand_n": c["hand"].size(),
			"actions_n": n_actions(i), "ai": controller(i).get("ai", true), "player": controller(i).get("who", ""),
		}
		if is_beast(i):
			pub["standee"] = c["standee"]
			pub["revealed"] = c["revealed"]
			pub["moves_n"] = c["moves"].size()
			pub["pairs"] = c["moves"].map(func(m): return int(m.get("pair", 0)))
			pub["souls"] = c.get("souls", -1)
			pub["drained"] = c.get("drained", 0)
			pub["reborn"] = c.get("reborn", false)
			if c["revealed"]:
				pub["loc"] = c["loc"]
			if team == "B":
				pub["loc"] = c["loc"]
				pub["moves"] = c["moves"].duplicate(true)
				pub["hand"] = c["hand"].duplicate()
		else:
			pub["loc"] = c["loc"]
			pub["blood"] = c.get("blood", 0)
			if team == "H":
				pub["hand"] = c["hand"].duplicate()
		cs.append(pub)
	v["chars"] = cs
	return v


## Numero di carte Azione in mano (conta per il Passo).
func n_actions(ci: int) -> int:
	var n := 0
	for c in ch[ci]["hand"]:
		if D.kind(c) == "action":
			n += 1
	return n


## Copia profonda dello stato completo (per salvataggio locale del server e per il commit-reveal).
func snapshot() -> Dictionary:
	return {
		"contract": contract_id, "ch": ch.duplicate(true), "tokens": tokens.duplicate(), "animals": animals.duplicate(true),
		"settlers": settlers.duplicate(true), "summons": summons.duplicate(true), "towers": towers.duplicate(),
		"trails": trails.duplicate(true), "traps": traps.duplicate(true), "ruins": ruins.duplicate(), "day": day,
		"phase": phase, "beast_wounds": beast_wounds, "dom": dom.duplicate(), "kills": kills.duplicate(),
	}


## Impronta della parte pubblica della partita (per confrontare i dispositivi nelle prove).
func fingerprint() -> String:
	var v := view_for("P")
	v.erase("log")
	return str(hash(JSON.stringify(v)))
