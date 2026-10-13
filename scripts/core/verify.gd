class_name BSVerify
extends RefCounted
## Verifica a fine partita (commit-reveal). Usa SOLO il registro pubblico degli eventi, la mappa e la
## rivelazione finale della Bestia (sale + registro segreto delle mosse). Controlla che:
##  1. il sale sia quello impegnato all'inizio (evento «setup»);
##  2. ogni gruppo di carte Movimento coperte corrisponda all'hash pubblicato nell'evento «bmove»;
##  3. le mosse siano legali (passi fra luoghi collegati, carte false accanto a quelle vere);
##  4. tutto ciò che si è visto in partita torni: tracce trovate e mancate, perlustrazioni a vuoto,
##     rivelazioni, Veggente, posizione finale.
## Restituisce {"ok": bool, "errors": [testi], "checked": numero di controlli}.

const D = preload("res://scripts/data/bs_data.gd")


static func run(events: Array, reveal: Dictionary, map_id: String) -> Dictionary:
	var errors := []
	var checked := 0
	var locs: Dictionary = D.MAPS[map_id]["locs"]
	var center: String = D.MAPS[map_id]["center"]
	var salt := str(reveal.get("salt", ""))
	var log_by_ev := {}
	for e in reveal.get("log", []):
		var k := int(e.get("ev", -1))
		if not log_by_ev.has(k):
			log_by_ev[k] = []
		log_by_ev[k].append(e)
	var pos := {}        # Bestia -> luogo vero
	var active := {}     # Bestia -> [{to, dir, fake, found}]
	var abyss := {}      # luoghi abissali noti (per i passi attraverso l'abisso)
	for i in range(events.size()):
		var e: Dictionary = events[i]
		# mosse segrete registrate al momento di questo evento
		for s in log_by_ev.get(i, []):
			var b := int(s["ci"])
			if not pos.has(b):
				pos[b] = center
				active[b] = []
			if s.has("relocate"):
				pos[b] = str(s["relocate"])
				continue
			var mv: Array = s.get("moves", [])
			if str(e.get("t", "")) != "bmove" or int(e.get("ci", -1)) != b:
				errors.append("Mosse segrete senza l'evento pubblico corrispondente (evento %d)." % i)
				continue
			checked += 1
			if BSState.commit_hash(salt, i, b, mv) != str(e.get("h", "")):
				errors.append("Le mosse rivelate non corrispondono all'impegno del giorno %d (evento %d)." % [int(e.get("day", 0)), i])
			var last_from := str(pos[b])
			for m in mv:
				checked += 1
				var fr := str(m["from"])
				var to := str(m["to"])
				var dir := str(m["dir"])
				if bool(m["fake"]):
					if fr != last_from:
						errors.append("Carta falsa che non parte dal luogo della carta vera (evento %d)." % i)
				else:
					if fr != str(pos[b]):
						errors.append("Mossa che non parte dalla posizione della Bestia (%s invece di %s, evento %d)." % [fr, pos[b], i])
					last_from = fr
				if not _legal(locs, fr, to, dir):
					errors.append("Passo non consentito da %s a %s (evento %d)." % [fr, to, i])
				if not bool(m["fake"]):
					pos[b] = to
				active[b].append({"to": to, "dir": dir, "fake": bool(m["fake"]), "found": dir == "A"})
		match str(e.get("t", "")):
			"setup":
				checked += 1
				if BSState.salt_commit(salt) != str(e.get("commit", "")):
					errors.append("Il sale rivelato non è quello impegnato a inizio partita.")
			"bmove":
				if not log_by_ev.has(i):
					errors.append("Manca la rivelazione delle carte Movimento giocate nell'evento %d." % i)
			"tf":
				if str(e.get("hab", "")) == "abyss":
					abyss[str(e["loc"])] = true
			"reveal":
				var b2 := int(e["ci"])
				checked += 1
				if pos.has(b2) and str(pos[b2]) != str(e["loc"]):
					errors.append("La Bestia si è rivelata in %s ma secondo le sue mosse era in %s (evento %d)." % [e["loc"], pos[b2], i])
				pos[b2] = str(e["loc"])
				active[b2] = []
			"bvis":
				pos[int(e["ci"])] = str(e["to"])
				active[int(e["ci"])] = []
			"check":
				var b3 := int(e["ci"])
				if not active.has(b3):
					continue
				var found: Dictionary = e.get("found", {})
				var cnt := {}
				for a in active[b3]:
					if not a["found"] and a["dir"] != "X" and (e["locs"] as Array).has(a["to"]):
						cnt[a["to"]] = int(cnt.get(a["to"], 0)) + 1
				for l in e["locs"]:
					checked += 1
					if int(cnt.get(l, 0)) != int(found.get(l, 0)):
						errors.append("Tracce non dichiarate correttamente in %s (evento %d): dovevano essere %d, erano %d." % [l, i, int(cnt.get(l, 0)), int(found.get(l, 0))])
				for a in active[b3]:
					if not a["found"] and a["dir"] != "X" and (e["locs"] as Array).has(a["to"]):
						a["found"] = true
			"search":
				checked += 1
				var here := false
				for b4 in pos:
					if str(pos[b4]) == str(e["loc"]):
						here = true
				if not bool(e["found"]) and here:
					errors.append("Perlustrazione in %s dichiarata a vuoto, ma la Bestia era lì (evento %d)." % [e["loc"], i])
			"seer":
				var b5 := int(e["ci"])
				for m2 in e.get("moves", []):
					checked += 1
					var idx := int(m2.get("idx", -1))
					if not active.has(b5) or idx < 0 or idx >= active[b5].size() or str(active[b5][idx]["to"]) != str(m2["to"]):
						errors.append("Carta Movimento rivelata da Veggente non coerente (evento %d)." % i)
			"end":
				for k2 in e.get("beast_locs", {}):
					checked += 1
					if pos.has(int(k2)) and str(pos[int(k2)]) != str(e["beast_locs"][k2]):
						errors.append("Posizione finale dichiarata diversa da quella delle mosse.")
	return {"ok": errors.is_empty(), "errors": errors, "checked": checked}


static func _legal(locs: Dictionary, fr: String, to: String, dir: String) -> bool:
	if not locs.has(fr) or not locs.has(to):
		return false
	if dir == "X":
		return fr == to
	if dir == "A":
		return true
	var L: Dictionary = locs[fr]
	if L["nb"].get(dir, "") == to:
		return true
	return L.get("hp", "") == to and L.get("hpdir", "") == dir
