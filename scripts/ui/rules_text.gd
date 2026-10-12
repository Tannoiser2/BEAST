class_name RulesText
extends RefCounted
## Regole in breve (in italiano), dal regolamento base 2.0 e da quello di Shattered Isles.

const D = preload("res://scripts/data/bs_data.gd")


static func text(contract := "") -> String:
	var s := ""
	if contract != "" and D.CONTRACTS.has(contract):
		var K: Dictionary = D.CONTRACTS[contract]
		s += "[b]CONTRATTO: %s[/b] (%s)\n[i]%s[/i]\n" % [K["n"], D.MAPS[K["map"]]["name"], K["intro"]]
		s += "• Preparazione: %s\n• Fine del contratto: %s\n" % [K["setup_t"], K["end_t"]]
		if K.get("legend_t", "") != "":
			s += "• Regole leggendarie: %s\n" % K["legend_t"]
		for i in range(K["nights"].size()):
			var N: Dictionary = K["nights"][i]
			s += "• Notte %d — Bestia: se «%s» → %s · Cacciatori: se «%s» → %s\n" % [i + 1, N["b_req_t"], N["b_rw_t"], N["h_req_t"], N["h_rw_t"]]
		s += "• Notte finale: vince%s.\n" % (" chi caccia" if K["final"] == "hunters" else "no le Bestie")
		if K.has("ruins"):
			s += "• Rovine (chi inizia il turno su una rovina non sua la prende e ottiene subito la ricompensa):\n"
			for r in K["ruins"]:
				s += "   – %s: cacciatori → %s; Bestia → %s\n" % [D.MAPS[K["map"]]["ruins"][r], K["ruins"][r]["h_t"], K["ruins"][r]["b_t"]]
		s += "\n"
	s += """[b]UNO CONTRO TUTTI[/b]
Una persona è la Bestia, le altre sono i cacciatori (in 2 giocatori una persona guida due cacciatori; in 5, con Shattered Isles, due Bestie alleate). Vince chi soddisfa per primo una condizione del contratto.

[b]IL ROUND[/b]: Alba (draft delle carte Azione), Giorno (turni), Notte (ricompense, riordino, cure, potenziamenti).
• [b]Draft[/b] (Shattered Isles): in 2 si danno 6 carte e il giocatore dei cacciatori ne tiene 2 per volta, poi si scartano 3 carte inutilizzate; in 3 si danno 5 carte e ognuno ne scarta 1; in 4 la Bestia mette da parte una carta, si danno 4 carte, poi ognuno ne scarta 1; in 5 si danno 4 carte e ognuno ne rimette 1 coperta fra le inutilizzate. Le carte passano in senso orario.
• [b]Turno[/b]: gioca fino a una carta rossa e una blu (in qualsiasi ordine; le carte divise si dichiarano rosse o blu, le sovraccariche valgono entrambe e danno anche l'effetto in basso), oppure [b]Fuggi[/b] (scarta una carta per muovere di 1 passo), oppure [b]Passa[/b] (solo se nessuno ha meno carte Azione di te). Quando tutti passano di fila finisce il Giorno. La Bestia gioca per prima.
• Le carte Azione hanno l'effetto dei cacciatori in alto e quello della Bestia in basso. Gli scarti sono informazione pubblica.

[b]IL MOVIMENTO NASCOSTO[/b] (lo gestisce il motore)
• La Bestia non sposta la sua sagoma: per ogni passo sceglie una carta Movimento coperta (Nord, Sud, Est, Ovest o «Nessun movimento», vietata se è con un cacciatore o un colono). La sagoma è l'ultima posizione nota e conta come Traccia.
• Quando un cacciatore, un colono (o Fylgja) si trova in un luogo dove porta una carta Movimento attiva, compare una [b]Traccia[/b]; le torri di guardia attive (con un cacciatore sopra) rivelano le Tracce di tutti i luoghi vicini. I cacciatori rivelano le Tracce a ogni passo, la Bestia le genera solo dopo aver piazzato tutte le carte.
• La Bestia si [b]rivela[/b] quando attacca o quando un cacciatore perlustra il suo luogo: mostra le carte Movimento, toglie le Tracce, la sagoma va nel luogo vero. Solo una Bestia rivelata si può attaccare.
• [b]Movimenti falsi[/b] (Shattered Isles): una carta falsa accanto a quella vera, dallo stesso luogo; genera Tracce come una vera.
• In questa versione la Bestia indica soltanto i luoghi: carte coperte, Tracce e controlli li fa il motore, e a fine partita ognuno può verificare con gli impegni salati che la Bestia non abbia barato.

[b]ATTACCHI E MORTE[/b]
• Ogni attacco infligge 1 danno a un bersaglio del luogo (2 con il potenziamento dei danni della Bestia); i Poteri antichi aggiungono 1 danno ciascuno. I cacciatori attaccano solo evocati e Bestie rivelate (Valdi anche gli animali).
• La Bestia guadagna rancori quando uccide con un attacco (vedi valori sulla mappa); un cacciatore ucciso dà 1 rancore e una sua carta Azione a caso. Gli evocati non danno rancori.
• Un cacciatore morto torna di notte in un insediamento a piena salute.

[b]EVOCATI, HABITAT, TRAPPOLE[/b]
• Il simbolo Evoca: metti un evocato a non più di 2 passi dal luogo vero, nell'habitat preferito, oppure fai compiere a ogni evocato un'azione (muovere, attaccare o la sua abilità).
• Trasformare: la Bestia mette il suo habitat preferito, i cacciatori l'insediamento. Il centro vale foresta, palude e caverna ed è in tutte le zone.
• Trappole: zona e habitat scelti in segreto; scattano quando la Bestia si rivela in quella zona su quell'habitat (al massimo 3 per zona).
• Sentieri nascosti: aperti se l'ingresso ha il tuo habitat preferito; il luogo dall'altra parte conta come vicino.
• Paludi abissali (Akkeron): contano come palude; passare da una all'altra vale un passo (la Bestia lascia subito una Traccia, i cacciatori subiscono 1 ferita).
• Armatura: previene 1 danno e si scarta.

[b]LA NOTTE[/b]: 1) ricompense del contratto (prima la Bestia, poi ogni cacciatore vivo); 2) si scartano le carte Azione e tornano in mano le Abilità, l'Arsenale si rinnova; 3) animali e coloni guariscono, i cacciatori morti rientrano; 4) potenziamenti (prima la Bestia): rossi permanenti, gialli immediati.

[b]COMANDI[/b]
• Tavolo: tasto destro per ruotare/inclinare, rotellina per lo zoom, trascina per spostare; Q/E ruota, R/F inclina, +/− zoom, frecce o WASD, Home per tornare alla vista iniziale. Pulsanti in basso a sinistra per il tocco.
• Le scelte compaiono a destra; i luoghi possibili si accendono sulla mappa (clic per sceglierli); le carte giocabili in mano sono bordate d'oro (passa il mouse per ingrandire). Clic su un personaggio per la sua plancia.
"""
	return s
