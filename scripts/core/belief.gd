class_name BSBelief
extends RefCounted
## Insieme delle posizioni possibili di una Bestia, ricavato SOLO dagli eventi pubblici
## (mosse coperte, tracce trovate o mancate, perlustrazioni, evocazioni, rivelazioni, Veggenza).
## Lo usano l'IA dei cacciatori (per cercarla) e l'IA della Bestia (per sapere quanto è nascosta
## e scegliere le mosse che confondono di più).
##
## Ogni «particella» è un'ipotesi completa: posizione attuale e destinazioni delle carte Movimento attive.

const MAXP := 1600

var eng                     # motore (si leggono solo mappa, segnalini e eventi pubblici)
var b := 0                  # indice della Bestia seguita
var parts: Array = []       # {pos, o (origine dell'ultimo passo), c: [[dest, fake]], f: [bool trovata]}
var seen := 0               # eventi già letti
var hab := "swamp"
var abyss := false


func _init(p_eng, p_b: int) -> void:
	eng = p_eng
	b = p_b
	hab = eng.beast_hab(b)
	abyss = eng.ch[b].get("abyss", false)
	parts = [{"pos": eng.center(), "o": eng.center(), "c": [], "f": []}]


## Legge gli eventi pubblici nuovi.
func update() -> void:
	var evs: Array = eng.events
	while seen < evs.size():
		var e: Dictionary = evs[seen]
		seen += 1
		_apply(e)


func _apply(e: Dictionary) -> void:
	match str(e.get("t", "")):
		"bmove":
			if int(e["ci"]) != b:
				return
			var pairs: Array = e.get("pairs", [])
			var old: int = parts[0]["c"].size() if not parts.is_empty() else 0
			_extend(pairs.slice(old), e.get("abyss", []))
		"check":
			if int(e["ci"]) == b:
				_check(e["locs"], e["found"])
		"search":
			if not e["found"]:
				parts = parts.filter(func(p): return p["pos"] != e["loc"])
				_guard()
		"reveal":
			if int(e["ci"]) == b:
				parts = [{"pos": e["loc"], "o": e["loc"], "c": [], "f": []}]
		"bvis":
			if int(e["ci"]) == b:
				parts = [{"pos": e["to"], "o": e["to"], "c": [], "f": []}]
		"summon":
			if int(e.get("ci", -1)) == b and eng.phase != "setup":
				var l: String = e["loc"]
				var keep := parts.filter(func(p): return eng.dist(p["pos"], l, hab) <= 2)
				if not keep.is_empty():
					parts = keep
		"seer":
			if int(e["ci"]) != b:
				return
			for m in e["moves"]:
				var i := int(m.get("idx", -1))
				if i < 0:
					continue
				parts = parts.filter(func(p): return i < p["c"].size() and p["c"][i][0] == m["to"] and bool(p["c"][i][1]) == bool(m["fake"]))
			_guard()
		"setup":
			parts = [{"pos": eng.center(), "o": eng.center(), "c": [], "f": []}]


## Aggiunge le nuove carte Movimento coperte (con le coppie vera/falsa).
func _extend(new_pairs: Array, abyss_dest: Array) -> void:
	var prev_pair := 0
	for j in range(new_pairs.size()):
		var pr := int(new_pairs[j])
		var out := []
		var partner := pr != 0 and pr == prev_pair
		for p in parts:
			if partner:
				# questa carta è la compagna della precedente: una delle due è falsa
				var o: String = p["o"]
				var prev: Array = p["c"].back()
				# ipotesi 1: la precedente è vera, questa falsa
				for t in _moves(o):
					var q := _copy(p)
					q["c"].append([t, true, t == o])
					q["f"].append(false)
					out.append(q)
				# ipotesi 2: la precedente era falsa, questa è vera
				for t in _moves(o):
					var q2 := _copy(p)
					q2["c"][q2["c"].size() - 1] = [prev[0], true, prev[2]]
					q2["c"].append([t, false, t == o])
					q2["f"].append(false)
					q2["pos"] = t
					out.append(q2)
			else:
				for t in _moves(p["pos"]):
					var q3 := _copy(p)
					q3["o"] = p["pos"]
					q3["pos"] = t
					q3["c"].append([t, false, t == p["pos"]])
					q3["f"].append(false)
					out.append(q3)
		prev_pair = pr
		parts = out
		_cap()
	# attraverso l'abisso: la Traccia sull'arrivo è già pubblica
	for t2 in abyss_dest:
		var keep := parts.filter(func(p): return p["pos"] == t2 or p["c"].any(func(c): return c[0] == t2))
		if not keep.is_empty():
			parts = keep
	_guard()


func _moves(l: String) -> Array:
	var out := [l]
	var st: Dictionary = eng.step_targets(l, hab)
	for d in st:
		if not out.has(st[d]):
			out.append(st[d])
	if abyss and eng.is_abyss(l):
		for t in eng.tokens:
			if eng.tokens[t] == "abyss" and not out.has(t):
				out.append(t)
	return out


func _copy(p: Dictionary) -> Dictionary:
	return {"pos": p["pos"], "o": p["o"], "c": p["c"].duplicate(true), "f": p["f"].duplicate()}


## Filtro sulle Tracce: in ogni luogo osservato il numero di carte non ancora trovate che vi portano
## deve essere uguale al numero di Tracce appena comparse.
func _check(locs: Array, found: Dictionary) -> void:
	var out := []
	for p in parts:
		var ok := true
		var cnt := {}
		for i in range(p["c"].size()):
			if p["f"][i] or p["c"][i][2]:
				continue
			var d: String = p["c"][i][0]
			if locs.has(d):
				cnt[d] = int(cnt.get(d, 0)) + 1
		for l in locs:
			if int(cnt.get(l, 0)) != int(found.get(l, 0)):
				ok = false
				break
		if ok:
			for i in range(p["c"].size()):
				if not p["f"][i] and not p["c"][i][2] and locs.has(p["c"][i][0]):
					p["f"][i] = true
			out.append(p)
	parts = out
	_guard()


## Se le ipotesi si esauriscono (mossa speciale non prevista), si riparte da tutte le posizioni
## raggiungibili dall'ultima posizione nota.
func _guard() -> void:
	if not parts.is_empty():
		return
	var start: String = eng.ch[b]["standee"]
	var n: int = eng.ch[b]["moves"].size()
	var dm: Dictionary = eng.dist_map(start, max(1, n), hab)
	for l in dm:
		parts.append({"pos": l, "o": l, "c": [], "f": []})


func _cap() -> void:
	if parts.size() <= MAXP:
		return
	# campionamento casuale (con il generatore del motore: è deterministico)
	var keep := []
	var step := float(parts.size()) / MAXP
	var x := 0.0
	while int(x) < parts.size() and keep.size() < MAXP:
		keep.append(parts[int(x)])
		x += step
	parts = keep


## Probabilità di ogni luogo come posizione attuale.
func probs() -> Dictionary:
	var out := {}
	if parts.is_empty():
		return out
	var w := 1.0 / parts.size()
	for p in parts:
		out[p["pos"]] = float(out.get(p["pos"], 0.0)) + w
	return out


func support() -> int:
	return probs().size()


func best() -> String:
	var pr := probs()
	var bl := ""
	var bv := -1.0
	for l in pr:
		if pr[l] > bv:
			bv = pr[l]
			bl = l
	return bl


## Quante posizioni resterebbero possibili se la Bestia, da qui, facesse un passo in t (stima
## per l'IA della Bestia): simula estensione e controllo delle Tracce sui luoghi osservati.
func support_after(t: String, observed: Array) -> int:
	var poss := {}
	for p in parts:
		for m in _moves(p["pos"]):
			var hit := observed.has(m)
			# se il passo vero porta in un luogo osservato compare una Traccia: restano solo le ipotesi
			# che arrivano lì; altrimenti restano quelle che non toccano luoghi osservati
			if observed.has(t):
				if m == t:
					poss[m] = true
			elif not hit:
				poss[m] = true
	return poss.size()
