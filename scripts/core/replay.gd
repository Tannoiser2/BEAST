class_name BSReplay
extends RefCounted
## Replay di fine partita: dal registro pubblico degli eventi e dalla rivelazione finale (registro
## segreto della Bestia) ricava la sequenza continua dei movimenti, con la Bestia sempre visibile.
## Non serve rigiocare il motore: bastano gli stessi dati che usa la verifica (verify.gd).
##
## Ogni passo è un dizionario:
##   {"k": "add",   "key", "piece", "loc"}            un pezzo entra sul tavolo
##   {"k": "move",  "key", "from", "to", "beast"}     un pezzo si sposta (beast = indice della Bestia o -1)
##   {"k": "jump",  "key", "to"}                      spostamento senza percorso (riposizionamento segreto)
##   {"k": "del",   "key", "loc"}                     un pezzo esce (morto)
##   {"k": "fx",    "loc", "text", "col"}             attacco, morte, ricerca, rivelazione
##   {"k": "day",   "text"}                           cambio di giorno o notte (solo un'etichetta)
## piece: {"id": sagoma o tipo, "kind": "beast"|"hunter"|"summon"|"companion"|"animal"|"settler"}

const D = preload("res://scripts/data/bs_data.gd")


static func build(events: Array, reveal: Dictionary, map_id: String, chars: Array) -> Array:
	var out := []
	var center: String = D.MAPS[map_id]["center"]
	var ids := {}
	var sides := {}
	for c in chars:
		ids[int(c["i"])] = str(c["id"])
		sides[int(c["i"])] = str(c["side"])
	var log_by_ev := {}
	for e in reveal.get("log", []):
		var k := int(e.get("ev", -1))
		if not log_by_ev.has(k):
			log_by_ev[k] = []
		log_by_ev[k].append(e)
	var pos := {}          # chiave -> luogo
	var add := func(key: String, piece: Dictionary, loc: String):
		if loc == "" or pos.has(key):
			return
		pos[key] = loc
		out.append({"k": "add", "key": key, "piece": piece, "loc": loc})
	var move := func(key: String, to: String, beast := -1):
		if to == "" or not pos.has(key) or pos[key] == to:
			return
		out.append({"k": "move", "key": key, "from": pos[key], "to": to, "beast": beast})
		pos[key] = to
	# le Bestie partono dal centro della mappa
	for i in ids:
		if sides[i] == "B":
			add.call("B%d" % i, {"id": ids[i], "kind": "beast"}, center)
	for i in range(events.size()):
		var e: Dictionary = events[i]
		for s in log_by_ev.get(i, []):
			var b := int(s["ci"])
			var bk := "B%d" % b
			if s.has("relocate"):
				if pos.get(bk, "") != str(s["relocate"]):
					out.append({"k": "jump", "key": bk, "to": str(s["relocate"])})
					pos[bk] = str(s["relocate"])
				continue
			for m in s.get("moves", []):
				if not bool(m.get("fake", false)) and str(m.get("dir", "")) != "X":
					move.call(bk, str(m["to"]), b)
		match str(e.get("t", "")):
			"board":
				for a in e.get("animals", []):
					add.call("A%d" % int(a["id"]), {"id": str(a["kind"]), "kind": "animal"}, str(a["loc"]))
				for x in e.get("settlers", []):
					add.call("T%d" % int(x["id"]), {"id": str(x["kind"]), "kind": "settler"}, str(x["loc"]))
			"amove":
				var ak := "A%d" % int(e["id"])
				if not pos.has(ak):
					add.call(ak, {"id": "sheep", "kind": "animal"}, str(e["from"]))
				move.call(ak, str(e["to"]))
			"smove":
				var tk := "T%d" % int(e["id"])
				if not pos.has(tk):
					add.call(tk, {"id": "farmer", "kind": "settler"}, str(e["from"]))
				move.call(tk, str(e["to"]))
			"skind":
				var tk2 := "T%d" % int(e["id"])
				if pos.has(tk2):
					var l2: String = pos[tk2]
					out.append({"k": "del", "key": tk2, "loc": l2})
					pos.erase(tk2)
					add.call(tk2, {"id": str(e["kind"]), "kind": "settler"}, l2)
			"hplace":
				var h := int(e["ci"])
				if pos.has("H%d" % h):
					move.call("H%d" % h, str(e["to"]))
				else:
					add.call("H%d" % h, {"id": ids.get(h, ""), "kind": "hunter"}, str(e["to"]))
			"hmove":
				move.call("H%d" % int(e["ci"]), str(e["to"]))
			"bvis":
				move.call("B%d" % int(e["ci"]), str(e["to"]), int(e["ci"]))
			"reveal":
				var bk2 := "B%d" % int(e["ci"])
				if pos.get(bk2, "") != str(e["loc"]):
					out.append({"k": "jump", "key": bk2, "to": str(e["loc"])})
					pos[bk2] = str(e["loc"])
				out.append({"k": "fx", "loc": str(e["loc"]), "text": "Rivelata", "col": "#ff5040"})
			"summon":
				var sk := "S%s" % str(e.get("id", "x%d" % i))
				add.call(sk, {"id": str(e["kind"]), "kind": "summon"}, str(e["loc"]))
			"summove":
				var sk2 := "S%d" % int(e["id"])
				if not pos.has(sk2):
					add.call(sk2, {"id": _summon_kind(events, i, int(e["id"])), "kind": "summon"}, str(e["from"]))
				move.call(sk2, str(e["to"]))
			"cmove":
				if pos.has("C"):
					move.call("C", str(e["to"]))
				else:
					add.call("C", {"id": "fylgja", "kind": "companion"}, str(e["to"]))
			"attack", "sattack":
				out.append({"k": "fx", "loc": str(e["loc"]), "text": "−%d" % int(e.get("dmg", 1)), "col": "#ff6a4a"})
			"search":
				out.append({"k": "fx", "loc": str(e["loc"]), "text": "Trovata!" if e["found"] else "Niente", "col": "#ffe9a0"})
			"death":
				var t: Dictionary = e.get("target", {})
				match str(t.get("t", "")):
					"summon":
						var dk := "S%d" % int(t.get("id", -1))
						if pos.has(dk):
							out.append({"k": "del", "key": dk, "loc": pos[dk]})
							pos.erase(dk)
					"hunter":
						var hk := "H%d" % int(t.get("ci", -1))
						if pos.has(hk):
							out.append({"k": "del", "key": hk, "loc": pos[hk]})
							pos.erase(hk)
						out.append({"k": "fx", "loc": str(e.get("loc", "")), "text": "✝", "col": "#ff5040"})
					"settler", "animal":
						var pk := ("T%d" if str(t["t"]) == "settler" else "A%d") % int(t.get("id", -1))
						if pos.has(pk):
							out.append({"k": "del", "key": pk, "loc": pos[pk]})
							pos.erase(pk)
						if str(t["t"]) == "settler":
							out.append({"k": "fx", "loc": str(e.get("loc", "")), "text": "✝ " + {"farmer": "Contadino", "noble": "Nobile"}.get(str(t.get("kind", "")), "Colono"), "col": "#ff5040"})
			"day":
				out.append({"k": "day", "text": "Giorno %d" % int(e.get("day", 0))})
			"night":
				out.append({"k": "day", "text": "Notte %d" % int(e.get("day", 0))})
			"end":
				for k2 in e.get("beast_locs", {}):
					var bk3 := "B%s" % str(k2)
					if pos.has(bk3) and pos[bk3] != str(e["beast_locs"][k2]):
						out.append({"k": "jump", "key": bk3, "to": str(e["beast_locs"][k2])})
						pos[bk3] = str(e["beast_locs"][k2])
				out.append({"k": "day", "text": "Fine: vince " + ("la Bestia" if str(e.get("winner", "")) == "B" else "la squadra dei cacciatori")})
	return out


static func _summon_kind(events: Array, upto: int, id: int) -> String:
	for j in range(upto, -1, -1):
		var e: Dictionary = events[j]
		if str(e.get("t", "")) == "summon" and int(e.get("id", -1)) == id:
			return str(e["kind"])
	return "wolf"
