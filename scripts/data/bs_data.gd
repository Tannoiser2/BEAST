## Dati di BEAST e SHATTERED ISLES (Studio Midhall): mappa, animali, coloni, Bestie, cacciatori,
## carte e contratti. Testi delle regole in italiano. Le immagini stanno nel manifesto delle carte
## (assets/cards/manifest.json): ogni carta ha una chiave «img» che il manifesto traduce in un file.
##
## Effetti delle carte: un elenco che comincia con il modo di risoluzione
##   "seq" = nell'ordine scritto («poi»), "any" = in qualsiasi ordine (ognuno facoltativo),
##   "one" = scegli un effetto;
## seguito dalle operazioni ["nome", argomenti…] che il motore (engine.gd) sa eseguire.
class_name BD
extends RefCounted

const HABITATS := ["forest", "swamp", "cave", "settlement", "abyss"]
const HAB_IT := {"forest": "foresta", "swamp": "palude", "cave": "caverna", "settlement": "insediamento", "abyss": "palude abissale"}
const DIR_IT := {"N": "Nord", "S": "Sud", "E": "Est", "W": "Ovest", "X": "Nessun movimento", "A": "Abisso"}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}

# ---------------------------------------------------------------------------------- mappe
## Coordinate (x, y) in frazioni dell'immagine della plancia. nb: vicini per direzione.
## hp: altro capo del Sentiero nascosto; hpdir: direzione dell'ingresso.
const MAPS := {
	"lsi": {
		"name": "Isole Frantumate inferiori",
		"en": "Lower Shattered Isles",
		"image": "res://assets/board/lower_shattered_isles.jpg",
		"aspect": 1.5009,
		"center": "b7",
		"zones": {"achur": "Achur", "elysur": "Elysur", "myrna": "Myrna"},
		"zone_label": {"achur": [0.62, 0.43], "elysur": [0.25, 0.46], "myrna": [0.72, 0.48]},
		"ruins": {"yagi_cliffs": "Rupi degli Yagi", "admirer_glade": "Radura dell'Ammiratore", "sunken_ruins": "Rovine sommerse"},
		"locs": {
			"a1": {"x": 0.1888, "y": 0.1032, "hab": ["forest"], "zone": "achur", "nb": {"E": "a2", "S": "a9"}},
			"a2": {"x": 0.2750, "y": 0.1313, "hab": ["forest", "swamp"], "zone": "achur", "nb": {"W": "a1", "E": "a3", "S": "a10"}, "animal": "boar"},
			"a3": {"x": 0.3750, "y": 0.1079, "hab": ["cave"], "zone": "achur", "nb": {"W": "a2", "E": "a4", "S": "a6"}, "animal": "sheep"},
			"a4": {"x": 0.4688, "y": 0.0985, "hab": ["swamp"], "zone": "achur", "nb": {"W": "a3", "E": "a5", "S": "a7"}, "animal": "sheep"},
			"a5": {"x": 0.5625, "y": 0.0891, "hab": ["forest"], "zone": "achur", "nb": {"W": "a4", "S": "a8", "E": "a11"}, "hp": "b3", "hpdir": "N"},
			"a6": {"x": 0.3719, "y": 0.2233, "hab": ["forest"], "zone": "achur", "nb": {"N": "a3", "E": "a7", "W": "a10", "S": "a14"}, "animal": "sheep"},
			"a7": {"x": 0.4688, "y": 0.2158, "hab": ["forest"], "zone": "achur", "nb": {"N": "a4", "W": "a6", "E": "a8"}, "animal": "sheep", "ruin": "admirer_glade"},
			"a8": {"x": 0.5594, "y": 0.2392, "hab": ["cave"], "zone": "achur", "nb": {"W": "a7", "N": "a5", "E": "a12", "S": "a17"}, "animal": "boar"},
			"a9": {"x": 0.1719, "y": 0.2298, "hab": ["settlement"], "zone": "achur", "nb": {"N": "a1", "E": "a10", "S": "a13"}, "settler": "farmer", "name": "the_lightseeker"},
			"a10": {"x": 0.2812, "y": 0.2627, "hab": ["cave"], "zone": "achur", "nb": {"N": "a2", "W": "a9", "E": "a6", "S": "a16"}, "animal": "sheep"},
			"a11": {"x": 0.7312, "y": 0.1079, "hab": ["settlement"], "zone": "achur", "nb": {"W": "a5", "S": "a12"}, "hp": "c18", "hpdir": "E", "settler": "noble", "name": "east_camp"},
			"a12": {"x": 0.6937, "y": 0.2345, "hab": ["swamp"], "zone": "achur", "nb": {"W": "a8", "N": "a11", "S": "a18"}, "hp": "b17", "hpdir": "E"},
			"a13": {"x": 0.2219, "y": 0.3424, "hab": ["swamp"], "zone": "achur", "nb": {"N": "a9", "E": "a16", "S": "b1"}},
			"a14": {"x": 0.3719, "y": 0.3330, "hab": ["swamp"], "zone": "achur", "nb": {"N": "a6", "E": "a15", "W": "a16", "S": "b6"}, "animal": "sheep"},
			"a15": {"x": 0.4688, "y": 0.3377, "hab": ["forest"], "zone": "achur", "nb": {"W": "a14", "E": "a17", "S": "b7"}},
			"a16": {"x": 0.2875, "y": 0.3705, "hab": ["forest"], "zone": "achur", "nb": {"N": "a10", "W": "a13", "E": "a14", "S": "b2"}, "animal": "sheep"},
			"a17": {"x": 0.5594, "y": 0.3490, "hab": ["cave"], "zone": "achur", "nb": {"N": "a8", "W": "a15", "S": "b8"}, "animal": "sheep"},
			"a18": {"x": 0.6781, "y": 0.3471, "hab": ["swamp"], "zone": "achur", "nb": {"N": "a12", "S": "b9"}, "animal": "sabertooth"},
			"b1": {"x": 0.2062, "y": 0.4221, "hab": ["forest"], "zone": "elysur", "nb": {"N": "a13", "E": "b2", "S": "b3"}, "animal": "sabertooth"},
			"b2": {"x": 0.2844, "y": 0.4597, "hab": ["swamp"], "zone": "elysur", "nb": {"N": "a16", "W": "b1", "S": "b4", "E": "b5"}},
			"b3": {"x": 0.1875, "y": 0.5066, "hab": ["forest"], "zone": "elysur", "nb": {"N": "b1", "E": "b4", "S": "b10"}, "hp": "a5", "hpdir": "W"},
			"b4": {"x": 0.2750, "y": 0.5253, "hab": ["cave"], "zone": "elysur", "nb": {"W": "b3", "N": "b2", "S": "b11", "E": "b5"}, "animal": "sheep"},
			"b5": {"x": 0.3469, "y": 0.4925, "hab": ["forest"], "zone": "elysur", "nb": {"N": "b2", "E": "b6", "W": "b4", "S": "b12"}, "animal": "sheep"},
			"b6": {"x": 0.4062, "y": 0.4690, "hab": ["cave"], "zone": "elysur", "nb": {"W": "b5", "E": "b7", "S": "b13", "N": "a14"}},
			"b7": {"x": 0.4594, "y": 0.4737, "hab": ["forest", "swamp", "cave"], "zone": "*", "nb": {"W": "b6", "N": "a15", "E": "b8", "S": "b14"}},
			"b8": {"x": 0.5594, "y": 0.4643, "hab": ["swamp"], "zone": "myrna", "nb": {"W": "b7", "N": "a17", "E": "b9", "S": "b15"}},
			"b9": {"x": 0.6562, "y": 0.4643, "hab": ["forest"], "zone": "myrna", "nb": {"W": "b8", "N": "a18", "S": "b16"}},
			"b10": {"x": 0.1562, "y": 0.6098, "hab": ["swamp"], "zone": "elysur", "nb": {"N": "b3", "E": "b11", "S": "c1"}, "animal": "boar"},
			"b11": {"x": 0.2625, "y": 0.6191, "hab": ["settlement"], "zone": "elysur", "nb": {"N": "b4", "W": "b10", "S": "c2"}, "settler": "noble", "name": "titan"},
			"b12": {"x": 0.3469, "y": 0.6079, "hab": ["cave"], "zone": "elysur", "nb": {"N": "b5", "E": "b13", "S": "c3"}, "animal": "sheep", "ruin": "yagi_cliffs"},
			"b13": {"x": 0.4062, "y": 0.6051, "hab": ["swamp"], "zone": "elysur", "nb": {"W": "b12", "S": "c6", "N": "b6", "E": "b14"}, "animal": "sheep"},
			"b14": {"x": 0.4844, "y": 0.5863, "hab": ["cave"], "zone": "myrna", "nb": {"N": "b7", "W": "b13", "E": "b15", "S": "c7"}},
			"b15": {"x": 0.5594, "y": 0.5722, "hab": ["cave"], "zone": "myrna", "nb": {"N": "b8", "W": "b14", "E": "b16", "S": "c11"}, "animal": "sheep"},
			"b16": {"x": 0.6781, "y": 0.5722, "hab": ["swamp"], "zone": "myrna", "nb": {"N": "b9", "W": "b15", "E": "b17", "S": "c14"}, "animal": "sheep"},
			"b17": {"x": 0.7844, "y": 0.5769, "hab": ["settlement"], "zone": "myrna", "nb": {"W": "b16", "S": "c15", "E": "c16"}, "hp": "a12", "hpdir": "N", "settler": "noble", "name": "elysara"},
			"c1": {"x": 0.1781, "y": 0.7223, "hab": ["cave"], "zone": "elysur", "nb": {"N": "b10", "E": "c2", "S": "c4"}, "hp": "c13", "hpdir": "W"},
			"c2": {"x": 0.2562, "y": 0.7223, "hab": ["forest"], "zone": "elysur", "nb": {"W": "c1", "E": "c3", "S": "c4", "N": "b11"}},
			"c3": {"x": 0.3469, "y": 0.7223, "hab": ["cave", "swamp"], "zone": "elysur", "nb": {"N": "b12", "W": "c2", "E": "c6", "S": "c5"}, "animal": "boar"},
			"c4": {"x": 0.2500, "y": 0.8349, "hab": ["cave"], "zone": "elysur", "nb": {"W": "c1", "N": "c2", "E": "c5"}},
			"c5": {"x": 0.3500, "y": 0.8443, "hab": ["swamp"], "zone": "elysur", "nb": {"W": "c4", "E": "c9", "N": "c3"}, "animal": "sheep"},
			"c6": {"x": 0.4062, "y": 0.7458, "hab": ["forest"], "zone": "elysur", "nb": {"N": "b13", "W": "c3", "S": "c9", "E": "c8"}, "animal": "sheep"},
			"c7": {"x": 0.4781, "y": 0.6754, "hab": ["forest"], "zone": "myrna", "nb": {"N": "b14", "S": "c8", "E": "c11"}, "animal": "sheep"},
			"c8": {"x": 0.4875, "y": 0.7552, "hab": ["swamp"], "zone": "elysur", "nb": {"W": "c6", "N": "c7", "E": "c12", "S": "c10"}},
			"c9": {"x": 0.4050, "y": 0.8349, "hab": ["forest"], "zone": "elysur", "nb": {"W": "c5", "N": "c6", "E": "c10"}, "animal": "sheep"},
			"c10": {"x": 0.4906, "y": 0.8490, "hab": ["settlement"], "zone": "elysur", "nb": {"N": "c8", "W": "c9", "E": "c13"}, "settler": "farmer", "name": "aurelia"},
			"c11": {"x": 0.5656, "y": 0.6801, "hab": ["swamp"], "zone": "myrna", "nb": {"N": "b15", "W": "c7", "S": "c12", "E": "c14"}, "animal": "sheep", "ruin": "sunken_ruins"},
			"c12": {"x": 0.5687, "y": 0.7505, "hab": ["forest"], "zone": "myrna", "nb": {"W": "c8", "N": "c11", "S": "c13", "E": "c17"}, "animal": "boar"},
			"c13": {"x": 0.5687, "y": 0.8490, "hab": ["cave"], "zone": "myrna", "nb": {"W": "c10", "N": "c12", "E": "c19"}, "hp": "c1", "hpdir": "S"},
			"c14": {"x": 0.6719, "y": 0.6876, "hab": ["forest"], "zone": "myrna", "nb": {"N": "b16", "W": "c11", "E": "c15", "S": "c17"}, "animal": "sheep"},
			"c15": {"x": 0.7844, "y": 0.6848, "hab": ["forest", "cave"], "zone": "myrna", "nb": {"N": "b17", "W": "c14", "E": "c16", "S": "c18"}, "animal": "boar"},
			"c16": {"x": 0.8656, "y": 0.6895, "hab": ["cave"], "zone": "myrna", "nb": {"N": "b17", "W": "c15", "S": "c18"}, "animal": "sheep"},
			"c17": {"x": 0.6781, "y": 0.7786, "hab": ["swamp"], "zone": "myrna", "nb": {"W": "c12", "N": "c14", "S": "c19", "E": "c18"}, "animal": "sheep"},
			"c18": {"x": 0.7844, "y": 0.7786, "hab": ["swamp"], "zone": "myrna", "nb": {"N": "c15", "W": "c17", "E": "c16"}, "hp": "a11", "hpdir": "S"},
			"c19": {"x": 0.6656, "y": 0.8771, "hab": ["cave"], "zone": "myrna", "nb": {"W": "c13", "N": "c17"}, "animal": "sabertooth"},		},
	},
}

# ---------------------------------------------------------------------------------- abitanti
const ANIMALS := {
	"sheep": {"n": "Pecora", "hp": 1, "gr": 1},
	"boar": {"n": "Cinghiale", "hp": 2, "gr": 2},
	"sabertooth": {"n": "Tigre dai denti a sciabola", "hp": 2, "gr": 3},
	"bear": {"n": "Orso", "hp": 3, "gr": 3},
}
const SETTLERS := {
	"farmer": {"n": "Contadino", "hp": 2, "gr": 1},
	"noble": {"n": "Nobile", "hp": 3, "gr": 1},
}
const SUMMONS := {
	"polyp": {"n": "Polipo", "ability": "burst", "an": "Esplosione", "at": "Muove di 1 passo, poi il Polipo si uccide e infligge 1 danno a ogni cacciatore, colono, torre di guardia e animale in quel luogo, che diventa una palude."},
	"wolf": {"n": "Lupo", "ability": "charge", "an": "Carica", "at": "In qualsiasi ordine: attacca; muove di 1 passo."},
	"banshee": {"n": "Banshee", "ability": "lure", "an": "Richiamo", "at": "Porta in questo luogo ogni cacciatore, colono e animale vicino."},
	"basilisk": {"n": "Basilisco", "ability": "petrify", "an": "Pietrificare", "at": "Attacca un cacciatore vicino per 1 danno: quel cacciatore salta il suo prossimo turno."},
	"warhog": {"n": "Cinghiale da guerra", "ability": "push", "an": "Spinta", "at": "Muove di esattamente 2 passi nella stessa direzione: cacciatori, coloni e animali su cui passa si muovono con lui."},
	"changeling": {"n": "Mutaforma", "ability": "haunt", "an": "Infestare", "at": "Si sposta nel luogo del cacciatore più vicino, poi trasforma quel luogo."},
	"admirer": {"n": "Ammiratore", "ability": "soul_steal", "an": "Furto d'anime", "at": "Attacca; se l'Ammiratore uccide la vittima, 2 anime tornano dalle Anime prosciugate alle Anime attive."},
	"yagi": {"n": "Yagi", "ability": "ram", "an": "Cozzata", "at": "In qualsiasi ordine: muove fino a 1 passo; sposta un cacciatore, animale o colono del suo luogo in un luogo vicino."},
	"abomination": {"n": "Abominio", "ability": "pull", "an": "Risucchio abissale", "at": "Porta un essere vicino nel luogo di questo Abominio."},
	"dreamer": {"n": "Sognatore", "ability": "devotion", "an": "Devozione", "at": "Attacca; se il Sognatore uccide la vittima, si uccide e tu guadagni 1 rancore."},
}

## Personaggi dell'espansione Isole Frantumate (Shattered Isles); tutti gli altri sono del gioco base.
const EXPANSION_IDS := ["vacker", "thalduk", "akkeron", "fk", "eivind", "valdi", "fara", "esmeria_h"]

static func is_expansion(id: String) -> bool:
	return EXPANSION_IDS.has(id)

# ---------------------------------------------------------------------------------- Bestie
## up: potenziamenti {id: [nome, costo, "p" passivo | "y" immediato, testo]}
const BEASTS := {
	"bolgin": {"n": "Bolgin", "sub": "Portatrice della palude nera", "hab": "swamp", "hp": 5, "summon": "polyp", "ns": 3,
		"cplx": "bassa", "board": "beast_bolgin", "abil": ["engorge", "leap", "beastly_tongue", "summon_polyp"],
		"lore": "Bolgin dà il meglio quando trascina le prede nelle sue paludi, spezzando la formazione dei cacciatori e sorprendendo i coloni rimasti soli. Polipi e potenziamenti trasformano il paesaggio e premiano ogni uccisione.",
		"up": {
			"infestation": ["Infestazione", 1, "p", "Dopo aver ucciso con Ingozzare, metti un Polipo in quel luogo."],
			"withering_maw": ["Fauci avvizzenti", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"unending_hunger": ["Fame senza fine", 2, "p", "Dopo aver usato Lingua bestiale, riprendi in mano Ingozzare."],
			"blight": ["Morbo", 1, "y", "Trasforma ogni luogo vicino, poi muovi di 1 passo."],
			"expand_marsh": ["Espandere la palude", 2, "p", "Quando giochi Balzo, trasforma ogni luogo vicino."],
			"lurking_dead": ["Morti in agguato", 3, "p", "Quando un Polipo usa Esplosione, può muovere di 1 passo in più."],
			"cascade": ["Cascata", 3, "p", "Dopo che un Polipo muore, puoi muovere di 1 passo."],
		}},
	"fangrir": {"n": "Fangrir", "sub": "Regina del branco", "hab": "forest", "hp": 4, "summon": "wolf", "ns": 3,
		"cplx": "bassa", "board": "beast_fangrir", "abil": ["prey_upon", "gather_pack", "lurk", "summon_wolf"],
		"lore": "Fangrir è veloce e aggressiva: setaccia le foreste in cerca di prede prima di puntare agli insediamenti, sempre in movimento e ferma solo il tempo di colpire. I suoi lupi la seguono o inseguono prede diverse.",
		"up": {
			"bloodlust": ["Sete di sangue", 3, "p", "Dopo aver ucciso con Avventarsi, riprendi in mano Avventarsi."],
			"enraged": ["Furibonda", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"great_howl": ["Grande ululato", 3, "p", "Dopo che attacchi, un Lupo può usare Carica."],
			"hunting_grounds": ["Terreno di caccia", 1, "y", "In qualsiasi ordine: muovi di 1 passo; trasforma ogni luogo vicino."],
			"kins_pursuit": ["Inseguimento del branco", 2, "p", "Dopo che muovi, un Lupo può muovere di 1 passo."],
			"natural_instinct": ["Istinto naturale", 2, "p", "Quando una Pecora muore nel tuo turno, puoi muovere di 1 passo."],
			"culling": ["Sfoltire", 0, "p", "Se sono morte 4 o più Pecore, In agguato muove di un passo in più."],
		}},
	"mara": {"n": "Mara", "sub": "Sovrana della notte eterna", "hab": "cave", "hp": 4, "summon": "banshee", "ns": 2,
		"cplx": "media", "board": "beast_mara", "abil": ["feed", "obscure_talent", "flicker", "shadow_step"],
		"lore": "Mara bracca le sue prede dalle caverne, aspettando il momento giusto. Sa ingannare i cacciatori su dove si trovi e percorrere grandi distanze in un solo turno; le Banshee attirano le vittime e la fanno sparire.",
		"up": {
			"deaths_lament": ["Lamento di morte", 3, "p", "Gli attacchi delle Banshee infliggono 2 danni."],
			"soul_harvest_m": ["Raccolta d'anime", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"pandemonium": ["Pandemonio", 2, "p", "Le Banshee possono muovere di 1 passo quando vengono messe sulla mappa."],
			"song_temptation": ["Canto della tentazione", 1, "y", "Mara usa Richiamo (come una Banshee)."],
			"vanish": ["Svanire", 1, "y", "Recupera 1 ferita e spostati al centro della mappa, poi rivelati."],
			"void_presence": ["Presenza del vuoto", 1, "p", "Dopo aver giocato Passo d'ombra, trasforma ogni luogo vicino."],
			"fear_night": ["Paura della notte", 1, "p", "I coloni non rivelano Tracce."],
		}},
	"raaga": {"n": "Raaga", "sub": "Oracolo dell'abisso", "hab": "swamp", "hp": 5, "summon": "basilisk", "ns": 2,
		"cplx": "media", "board": "beast_raaga", "abil": ["hydra", "slither", "flood", "summon_basilisk"],
		"lore": "Le tre teste di Raaga colpiscono più bersagli anche a distanza. Strisciando sulla mappa allaga le terre intorno a sé; i Basilischi tengono lontani i cacciatori con lo sguardo pietrificante.",
		"up": {
			"wrath_eirtir": ["Ira di Eirtir", 2, "p", "Quando attacchi con Idra, puoi attaccare un altro bersaglio vicino."],
			"leviathan": ["Leviatano", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"mendrs_fury": ["Furia di Mendr", 3, "p", "Quando attacchi con Idra, puoi attaccare un altro bersaglio vicino."],
			"drowner": ["Annegatrice", 0, "p", "Dopo l'Alba, puoi trasformare un luogo vicino."],
			"torrential": ["Torrenziale", 2, "p", "Dopo aver trasformato 1 o più luoghi, muovi di 1 passo."],
			"devourer": ["Divoratrice", 2, "p", "Dopo aver ucciso con Idra, riprendi in mano Strisciare."],
			"fatal_gaze": ["Sguardo fatale", 3, "p", "Pietrificare dei Basilischi infligge 2 danni."],
		}},
	"hogbad": {"n": "Hogbad", "sub": "Capo della grande carica", "hab": "forest", "hp": 5, "summon": "warhog", "ns": 3,
		"cplx": "media", "board": "beast_hogbad", "abil": ["stampede", "tusk", "ramble", "summon_warhog"],
		"lore": "Hogbad si apposta nelle sue foreste appena fuori portata, per poi caricare e uccidere o riposizionarsi, travolgendo chiunque trovi sulla sua strada. I Cinghiali da guerra lo aiutano a preparare grandi colpi.",
		"up": {
			"rampageous": ["Furia cieca", 1, "p", "Attacca dopo aver giocato Carica selvaggia."],
			"infernal_tusks": ["Zanne infernali", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"hordes_march": ["Marcia dell'orda", 2, "p", "Dopo aver ucciso con Zanna, riprendi in mano Carica selvaggia."],
			"wild_ode": ["Ode selvaggia", 1, "y", "Evoca (metti un evocato o fai agire i tuoi evocati)."],
			"chiefs_command": ["Comando del capo", 2, "y", "Muovi fino a 2 Cinghiali di fino a 2 passi ciascuno."],
			"primal_instincts": ["Istinti primordiali", 2, "p", "Quando giochi Carica selvaggia, i Cinghiali da guerra possono usare Spinta."],
			"amass": ["Radunare", 2, "p", "Quando vieni rivelato vicino a un Cinghiale, trasforma quel Cinghiale in un Cinghiale da guerra."],
		}},
	"esmeria": {"n": "Esmeria", "sub": "Cacciatrice caduta", "hab": "cave", "hp": 4, "summon": "changeling", "ns": 2,
		"cplx": "alta", "board": "beast_esmeria", "abil": ["murder", "deceive", "stalk", "summon_changeling"],
		"lore": "Esmeria conosce i cacciatori meglio di chiunque e sfrutta le loro posizioni e le loro carte. Origlia dalle sue caverne e fugge subito dopo aver ucciso; i Mutaforma infestano i cacciatori e trasformano il terreno.",
		"up": {
			"endless_struggle": ["Lotta senza fine", 3, "p", "Quando un Mutaforma viene ucciso, puoi Evocare."],
			"accursed_wrath": ["Ira maledetta", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"killing_spree": ["Strage", 3, "p", "Dopo aver ucciso con Assassinio, riprendi in mano Assassinio."],
			"sinister_act": ["Atto sinistro", 0, "y", "Togli una trappola nella tua zona."],
			"mesmerise": ["Ipnotizzare", 4, "y", "Dopo la prossima Alba scegli un cacciatore: nel suo prossimo turno decidi tu carte, azioni e mosse (può attaccare cacciatori e coloni). Poi quel cacciatore gioca un altro turno normale."],
			"true_instinct_b": ["Vero istinto", 1, "p", "Dopo che un cacciatore prende un Oggetto scoperto, puoi muovere di 1 passo."],
		}},
	"vacker": {"n": "Vacker", "sub": "Predatrice di anime rubate", "hab": "forest", "hp": 4, "summon": "admirer", "ns": 2, "souls": 8,
		"cplx": "alta", "board": "beast_vacker", "abil": ["allure", "elude", "behold", "summon_admirer"],
		"lore": "Vacker è vanitosa e volubile: si crogiola fra i suoi Ammiratori e fugge quando i cacciatori si avvicinano, sviandoli con false tracce. Gli Ammiratori rubano anime che lei consuma per potenziare le sue abilità, al prezzo di farsi trovare più facilmente.",
		"up": {
			"mirror_beast": ["Bestia specchio", 3, "p", "Dopo aver giocato Eludere, muovi di 1 passo falso, poi di 1 passo."],
			"golden_beak": ["Becco d'oro", 5, "p", "I tuoi attacchi infliggono 2 danni."],
			"soul_harvest_v": ["Mietitura d'anime", 0, "p", "Dopo ogni Alba, un'anima torna dalle Anime prosciugate alle Anime attive."],
			"swift_kill": ["Uccisione rapida", 2, "p", "Dopo aver ucciso con Attrattiva, riprendi in mano Eludere."],
			"entrancing": ["Incanto", 3, "p", "Con Ammirare puoi muovere gli esseri di 1 passo in più."],
			"reverance": ["Reverenza", 2, "p", "Dopo che riporti anime alle Anime attive, un Ammiratore può muovere di 1 passo."],
		}},
	"thalduk": {"n": "Thalduk", "sub": "Signore delle alte vette", "hab": "cave", "hp": 5, "summon": "yagi", "ns": 2,
		"cplx": "media", "board": "beast_thalduk", "abil": ["storm", "acclivity", "bleat", "summon_yagi"],
		"lore": "Thalduk, signore delle alte vette, attacca senza sosta. I suoi Yagi spingono i cacciatori dove vuole lui, e lì scatena le sue tempeste; con un belato assordante sa rispondere alle mosse dei cacciatori evocando i suoi servitori.",
		"up": {
			"cloudshift": ["Nubi mutevoli", 1, "p", "All'inizio di ogni Alba puoi rivelare l'ultima carta Movimento giocata per muovere di 1 passo."],
			"behorned": ["Cornuto", 5, "p", "Cozzata infligge 1 danno al bersaglio spostato."],
			"stormbringer": ["Portatempesta", 3, "p", "Dopo aver giocato Evoca Yagi, riprendi in mano Tempesta."],
			"eruption": ["Eruzione", 3, "p", "Dopo che uno Yagi muore, tu o uno Yagi potete usare Cozzata."],
			"sudden_shock": ["Shock improvviso", 2, "y", "Un cacciatore vicino salta il suo prossimo turno."],
			"discharge": ["Scarica", 2, "y", "Tu e ogni Yagi potete usare Cozzata."],
			"starfall": ["Caduta di stelle", 1, "p", "Quando giochi una reazione puoi muovere di 1 passo in più."],
		}},
	"akkeron": {"n": "Akkeron", "sub": "Abominio delle Isole Frantumate", "hab": "swamp", "hp": 4, "summon": "abomination", "ns": 2, "abyss": true,
		"cplx": "molto alta", "board": "beast_akkeron", "abil": ["consume", "void", "defile", "corrupt"],
		"lore": "Akkeron risale dagli abissi per corrompere la terra e trasformarla in un vuoto nero. Con le paludi abissali costruisce una rete per percorrere grandi distanze e trascinare a sé le vittime; gli Abomini risucchiano tutto nell'abisso.",
		"up": {
			"void_call": ["Richiamo del vuoto", 3, "y", "Ogni colono e cacciatore vicino a una palude abissale vi si sposta, poi subisce 1 ferita."],
			"abyssal_beast": ["Bestia abissale", 3, "y", "Puoi trasformare 2 paludi qualsiasi in paludi abissali."],
			"echo": ["Eco", 1, "p", "Dopo aver trasformato un luogo in palude abissale, un Abominio può muovere di 1 passo."],
			"eternity": ["Eternità", 2, "p", "Dopo aver giocato Profanare o Corrompere, puoi trasformare un'altra palude a non più di 2 passi in palude abissale."],
			"void_step": ["Passo del vuoto", 1, "p", "Quando inizi il turno su una palude abissale, puoi muovere di 1 passo."],
			"dark_spawn": ["Progenie oscura", 3, "p", "Dopo che un Abominio usa Risucchio abissale, può attaccare."],
		}},
	"fk": {"n": "Re Piumato", "sub": "Il Non Nato", "hab": "cave", "hp": 2, "hp_reborn": 4, "summon": "dreamer", "ns": 3,
		"cplx": "alta", "board": "beast_fk", "board2": "beast_fk_reborn", "abil": ["unwilling_sacrifice", "uprise", "unburden", "summon_dreamer"],
		"lore": "Qualcosa non va nel mondo: l'aria è gelida e tutti fanno lo stesso sogno. Il Re Piumato promette un rifugio nel suo palazzo dei sogni a chi si consacra alla sua causa. Da Non Nato è fragile; se abbastanza animali muoiono, rinasce.",
		"up": {
			"resurrection": ["Resurrezione", 2, "y", "Solo se sono morti 2 o più animali. Il Re Piumato rinasce: si rivela, poi trasforma ogni luogo vicino e infligge 1 danno a ogni cacciatore e colono vicino. Le ferite restano; la salute sale a 4 e si attivano i poteri del Rinato."],
		},
		"reborn": {
			"overlord": ["Signore supremo", 0, "p", "Quando giochi una carta con «Oscur…» nel nome puoi sacrificare un Sognatore per copiarne l'effetto."],
			"regal": ["Regale", 0, "p", "I tuoi attacchi infliggono 2 danni."],
			"prominence": ["Preminenza", 0, "p", "Finché hai un Sognatore sulla mappa, Insorgere muove di un passo in più."],
			"endless_dream": ["Sogno senza fine", 0, "p", "Dopo aver giocato Sacrificio involontario, puoi riprendere in mano Evoca Sognatore."],
			"worship": ["Adorazione", 0, "p", "Quando ti riveli vicino a un insediamento, evoca un Sognatore in quell'insediamento."],
			"martyr": ["Martire", 0, "p", "Se dovresti subire danni, puoi trasferirli a un Sognatore nel tuo luogo."],
			"soul_collector": ["Collezionista d'anime", 0, "p", "Alla fine della Notte aggiungi alla mano una carta Azione inutilizzata a caso."],
		}},
}

# ---------------------------------------------------------------------------------- cacciatori
const HUNTERS := {
	"assar": {"n": "Assar", "sub": "Esploratore", "hp": 4, "order": "qualsiasi", "board": "hunter_assar", "abil": ["assar_hunt", "assar_track", "scout"],
		"lore": "Assar è il cacciatore più veloce: tiene il passo della Bestia e a volte la supera. Il suo occhio per le tracce la rivela e la espone agli attacchi; impara in fretta e copia le abilità dei compagni.",
		"up": {
			"resonance": ["Risonanza", 3, "p", "Scegli un altro cacciatore e copia la prima carta rossa che gioca ogni Giorno."],
			"exceptional_tracker": ["Segugio eccezionale", 2, "p", "Dopo che la Bestia si rivela, riprendi in mano Seguire le tracce."],
			"seeker": ["Cercatore", 2, "p", "Puoi perlustrare dopo aver giocato Seguire le tracce."],
			"explore": ["Esplorare", 1, "y", "Muovi di 1 passo e prendi un Oggetto del cacciatore."],
		}},
	"grimgeir": {"n": "Grimgeir", "sub": "Sentinella", "hp": 4, "order": "presto - a metà", "board": "hunter_grimgeir", "abil": ["grimgeir_hunt", "grimgeir_track", "cleaver"],
		"lore": "Grimgeir alza in fretta torri di guardia e difese, limitando i movimenti della Bestia. Il suo occhio vigile prepara la squadra agli attacchi: è sempre la prima linea di difesa.",
		"up": {
			"watchtower_passage": ["Passaggio della torre", 1, "p", "Dopo aver giocato Mannaia, puoi spostarti su un'altra torre di guardia."],
			"refuge": ["Rifugio", 2, "p", "Quando un cacciatore inizia il turno su una torre di guardia, recupera 1 ferita."],
			"townswatch": ["Ronda", 3, "p", "Anche i coloni attivano le torri di guardia."],
			"defender": ["Difensore", 1, "y", "Il prossimo attacco della Bestia nel tuo luogo: previeni 1 danno."],
		}},
	"helga": {"n": "Helga", "sub": "Veggente", "hp": 3, "order": "presto", "board": "hunter_helga", "abil": ["helga_hunt", "helga_track", "seer"],
		"lore": "Helga vede con gli occhi della Bestia e ne ricostruisce i movimenti passati. La sua preveggenza permette alla squadra di stare al passo e di reagire prima dell'attacco.",
		"up": {
			"tormenting_visions": ["Visioni tormentose", 2, "p", "Dopo ogni Alba puoi subire 1 ferita, poi aggiungere alla mano una carta Azione inutilizzata a caso."],
			"soothsayer": ["Indovina", 3, "p", "Quando giochi Veggenza, rivela le ultime due carte Movimento giocate."],
			"clairvoyant": ["Chiaroveggente", 1, "p", "Muovi di 1 passo dopo aver giocato Veggenza."],
			"ancient_bond": ["Legame antico", 2, "p", "I cacciatori possono giocare Seguire le tracce come reazione a qualsiasi attacco della Bestia."],
		}},
	"iona": {"n": "Iona", "sub": "Cacciatrice dal grande arco", "hp": 4, "order": "a metà - tardi", "board": "hunter_iona", "abil": ["iona_hunt", "iona_track", "silver_arrow"],
		"lore": "Iona terrorizza le Bestie con il suo grande arco: la gittata le permette di abbattere gli evocati restando sulla pista della Bestia, pronta al colpo finale.",
		"up": {
			"joint_effort": ["Sforzo comune", 2, "p", "Muovi di 1 passo dopo che Seguire le tracce di un altro cacciatore termina nella tua zona."],
			"ballista": ["Balista", 3, "p", "Freccia d'argento può attaccare la Bestia."],
			"crepuscular": ["Crepuscolare", 1, "p", "Muovi di 1 passo dopo ogni Alba."],
			"ancient_calling": ["Richiamo antico", 2, "y", "Prendi un Potere antico."],
		}},
	"krim": {"n": "Krim", "sub": "Maestro delle trappole", "hp": 3, "order": "qualsiasi", "board": "hunter_krim", "abil": ["krim_hunt", "krim_track", "trapmaster"],
		"lore": "Krim porta anni di esperienza: meno forte dei compagni, con astuzia prepara trappole in tutta la regione. Con abbastanza Oggetti minaccia la Bestia ovunque attacchi.",
		"up": {
			"scavenger": ["Recuperatore", 3, "p", "Dopo che una trappola si attiva, riprendila in mano."],
			"trap_launcher": ["Lanciatrappole", 2, "p", "Quando metti una trappola con Maestro delle trappole puoi metterla in qualsiasi zona."],
			"portable_workshop": ["Officina portatile", 2, "p", "Dopo aver preso un Oggetto, puoi trasformare il tuo luogo in insediamento."],
			"resourcefulness": ["Ingegno", 1, "y", "Ogni cacciatore vicino prende un Oggetto del cacciatore."],
		}},
	"varja": {"n": "Varja", "sub": "Comandante", "hp": 3, "order": "presto - a metà", "board": "hunter_varja", "abil": ["varja_hunt", "varja_track", "command"],
		"lore": "Varja comanda i cacciatori e li sposta sulla mappa; cacciatori e coloni si riposizionano secondo il bisogno, dando flessibilità alla caccia.",
		"up": {
			"horn_valh": ["Corno di Valh", 3, "p", "Con Comando muovi un cacciatore e un colono in più."],
			"hunters_bane": ["Rovina della Bestia", 1, "p", "Dopo che un cacciatore infligge danni alla Bestia, quel cacciatore guadagna 1 rancore."],
			"heroic_speech": ["Discorso eroico", 3, "y", "Trasforma un Contadino in Nobile."],
			"tactical_manouver": ["Manovra tattica", 1, "y", "Muovi tutti i cacciatori e i coloni di 1 passo."],
		}},
	"eivind": {"n": "Eivind", "sub": "Cacciatore del cielo", "hp": 3, "order": "presto - a metà", "board": "hunter_eivind", "abil": ["grappling_hook", "eivind_hunt", "aviation"], "companion": true,
		"lore": "Eivind guida la spedizione nelle Isole Frantumate. La sua compagna Fylgja perlustra la regione in cerca di segni della Bestia e il rampino gli dà grande libertà di movimento.",
		"up": {
			"sky_master": ["Signore del cielo", 2, "p", "Quando Fylgja si sposta in un luogo con una Traccia, un cacciatore nella sua zona può muovere di 1 passo."],
			"rope_pull": ["Strattone", 1, "y", "Un essere a non più di 2 passi nella stessa direzione viene spostato nel tuo luogo, oppure tu nel suo."],
			"reach": ["Portata", 2, "p", "Quando giochi Rampino, puoi scegliere un essere a non più di 2 passi nella stessa direzione."],
		}},
	"valdi": {"n": "Valdi", "sub": "Cacciatore di sangue", "hp": 4, "order": "a metà - tardi", "board": "hunter_valdi", "abil": ["incision", "blood_track", "blood_hunt"], "blood": true,
		"lore": "Valdi trae forza dal sangue degli animali. Il suo armamentario alchemico gli permette di arricchire la squadra o di spingere le proprie abilità oltre i limiti umani. È l'unico cacciatore che può attaccare gli animali.",
		"up": {
			"infusion": ["Infusione", 0, "y", "Spendi 2 sangue, poi un cacciatore guadagna 2 rancori."],
			"blood_craft": ["Arte del sangue", 1, "p", "I tuoi attacchi agli animali infliggono 1 danno in più."],
			"dissection": ["Dissezione", 3, "p", "Quando uccidi un essere, un altro cacciatore nella tua zona può muovere di 1 passo."],
			"extract": ["Estrarre", 2, "p", "Muovi di 1 passo e guadagna 1 sangue dopo ogni Alba."],
		}},
	"fara": {"n": "Fara", "sub": "Cacciatrice dalla lama di fuoco", "hp": 3, "order": "a metà - tardi", "board": "hunter_fara", "abil": ["flame_rapier", "fara_hunt", "fara_track"],
		"lore": "Fara colpisce la Bestia anche da lontano, ma ha bisogno dei compagni per piazzarsi. Ancora incapace di dominare il fuoco che la guida, con lo Stocco di fiamma si muove solo in linea retta; più soffre in battaglia, più diventa forte.",
		"up": {
			"ignite": ["Accendere", 2, "p", "Dopo aver giocato Caccia o Seguire le tracce, un altro cacciatore nella tua zona può muovere di 1 passo."],
			"fling": ["Lancio", 2, "p", "Quando potenzi Stocco di fiamma, puoi portare con te un essere del tuo luogo."],
			"dark_flame": ["Fiamma oscura", 2, "p", "Dopo aver giocato una carta con «oscur…» nel nome, riprendi in mano Stocco di fiamma."],
			"rebirth_fire": ["Rinascita nel fuoco", 1, "y", "La prossima volta che hai 3 o più ferite, recuperane 1 e prendi un Potere antico."],
		}},
	"esmeria_h": {"n": "Esmeria", "sub": "Capitana della Grande Caccia", "hp": 4, "order": "qualsiasi", "board": "hunter_esmeria", "abil": ["unnatural_resolve", "delegate", "esmeria_hunt"], "promo": true,
		"lore": "Prima di cadere, Esmeria era la capitana della Grande Caccia: delega, anticipa e insegue la Bestia senza sosta.",
		"up": {
			"huntmaster": ["Maestra di caccia", 2, "p", "Delegare vale per ogni cacciatore nella tua zona."],
			"black_star": ["Stella nera", 1, "y", "All'inizio del prossimo Giorno puoi giocare 1 carta prima del turno della Bestia."],
			"predict": ["Prevedere", 3, "p", "Copia la prima carta Azione blu che la Bestia gioca ogni giorno."],
			"true_instinct_h": ["Vero istinto", 1, "p", "Quando la Bestia prende un Talento bestiale scoperto, puoi muovere di 1 passo."],
		}},
}

# ---------------------------------------------------------------------------------- carte
## c: R rossa, B blu, S divisa (rossa o blu a scelta), O sovraccarica (rossa, potenziabile con la blu),
## X reazione, T trappola. cost: rancori da pagare. lock: habitat richiesto (Bestia).
## Carte Azione: ht/hfx effetto del cacciatore (sopra), bt/bfx effetto della Bestia (sotto).
const ACTIONS := {
	"adapt": {"n": "Adattarsi", "en": "Adapt", "c": "B",
		"ht": "In qualsiasi ordine: spostati in un insediamento qualsiasi; prendi un Oggetto del cacciatore.", "hfx": ["any", ["relocate_set"], ["item", 1]],
		"bt": "Evoca, poi muovi di 1 passo per ogni evocato sulla mappa.", "bfx": ["seq", ["summon"], ["mv_per_summon"]]},
	"animate": {"n": "Animare", "en": "Animate", "c": "B",
		"ht": "Guarda le carte Azione inutilizzate, poi aggiungine 1 alla tua mano.", "hfx": ["seq", ["look_unused"]],
		"bt": "Evoca, poi guarda le carte Azione inutilizzate e aggiungine 1 alla tua mano.", "bfx": ["seq", ["summon"], ["look_unused"]]},
	"avarice": {"n": "Avidità", "en": "Avarice", "c": "R",
		"ht": "Ogni cacciatore vicino può muovere di 1 passo oppure attaccare.", "hfx": ["seq", ["near_hunters_mv_or_atk"]],
		"bt": "Attacca, poi guadagna 1 rancore in più se hai ucciso la vittima.", "bfx": ["seq", ["atk"], ["grudge_if_kill", 1]]},
	"bolster": {"n": "Rinforzi", "en": "Bolster", "c": "B",
		"ht": "Ogni cacciatore nel tuo luogo prende un Oggetto del cacciatore e 1 rancore.", "hfx": ["seq", ["here_hunters_item_grudge"]],
		"bt": "Evoca, poi muovi di 2 passi.", "bfx": ["seq", ["summon"], ["mv", 2]]},
	"charge": {"n": "Carica", "en": "Charge", "c": "R",
		"ht": "In qualsiasi ordine: attacca; muovi di 1 passo.", "hfx": ["any", ["atk"], ["mv", 1]],
		"bt": "In qualsiasi ordine: attacca; muovi di 1 passo.", "bfx": ["any", ["atk"], ["mv", 1]]},
	"dark_dealings": {"n": "Patti oscuri", "en": "Dark Dealings", "c": "R", "dark": true, "not_last": true,
		"ht": "Non si può giocare se è l'ultima carta Azione in mano. Subisci 1 ferita, poi prendi in mano 1 carta Azione scartata.", "hfx": ["seq", ["suffer", 1], ["take_discard"]],
		"bt": "Non si può giocare se è l'ultima carta Azione in mano. Prendi in mano 1 carta Azione scartata.", "bfx": ["seq", ["take_discard"]]},
	"dark_rituals": {"n": "Riti oscuri", "en": "Dark Rituals", "c": "B", "dark": true,
		"ht": "Subisci 1 ferita, poi ogni cacciatore vicino riprende in mano una sua carta Abilità scartata.", "hfx": ["seq", ["suffer", 1], ["near_hunters_ret_ability"]],
		"bt": "Riprendi in mano una carta Abilità scartata.", "bfx": ["seq", ["ret_ability"]]},
	"dash": {"n": "Scatto", "en": "Dash", "c": "R",
		"ht": "Muovi fino a 2 passi.", "hfx": ["seq", ["mvu", 2]],
		"bt": "Muovi di 1 passo, poi di 1 passo in più per ogni cacciatore nella tua zona.", "bfx": ["seq", ["mv_dash"]]},
	"ensnare": {"n": "Irretire", "en": "Ensnare", "c": "B",
		"ht": "La Bestia mostra la mano e tu scarti una sua carta Abilità a scelta.", "hfx": ["seq", ["ensnare_h"]],
		"bt": "Un cacciatore mostra la mano e tu scarti una sua carta a scelta.", "bfx": ["seq", ["ensnare_b"]]},
	"haste": {"n": "Fretta", "en": "Haste", "c": "R",
		"ht": "Muovi fino a 2 passi.", "hfx": ["seq", ["mvu", 2]],
		"bt": "In qualsiasi ordine: muovi di 2 passi; trasforma ogni luogo vicino.", "bfx": ["any", ["mv", 2], ["tf_near_all"]]},
	"hidden_passage": {"n": "Passaggio nascosto", "en": "Hidden Passage", "c": "R",
		"ht": "Sposta un cacciatore qualsiasi nel luogo di un altro cacciatore.", "hfx": ["seq", ["hunter_to_hunter"]],
		"bt": "Prendi 2 Talenti bestiali.", "bfx": ["seq", ["talent", 2]]},
	"incite": {"n": "Incitare", "en": "Incite", "c": "B",
		"ht": "In qualsiasi ordine: ogni cacciatore nella tua zona può muovere di 1 passo; guadagna 1 rancore.", "hfx": ["any", ["zone_hunters_mv1"], ["grudge", 1]],
		"bt": "Evoca, poi tu e ogni evocato potete muovere di 1 passo.", "bfx": ["seq", ["summon"], ["me_and_summons_mv1"]]},
	"prowl": {"n": "Aggirarsi", "en": "Prowl", "c": "R",
		"ht": "Muovi di 1 passo. Puoi ripetere questo movimento finché non sei in un luogo senza Traccia.", "hfx": ["seq", ["prowl"]],
		"bt": "In qualsiasi ordine: attacca; prendi un Talento bestiale.", "bfx": ["any", ["atk"], ["talent", 1]]},
	"pursuit": {"n": "Inseguimento", "en": "Pursuit", "c": "B",
		"ht": "Scegli un effetto: perlustra il tuo luogo e attacca; oppure prendi un Oggetto del cacciatore e attacca un evocato vicino.", "hfx": ["one", ["search_atk"], ["item_atk_summon"]],
		"bt": "In qualsiasi ordine: muovi di 1 passo; prendi un Talento bestiale.", "bfx": ["any", ["mv", 1], ["talent", 1]]},
	"rush": {"n": "Corsa", "en": "Rush", "c": "R",
		"ht": "Muovi fino a 2 passi.", "hfx": ["seq", ["mvu", 2]],
		"bt": "Muovi di 3 passi senza lasciare la tua zona.", "bfx": ["seq", ["mv_zone", 3]]},
	"unearth": {"n": "Dissotterrare", "en": "Unearth", "c": "R",
		"ht": "In qualsiasi ordine: rivela l'ultima carta Movimento giocata; guadagna 1 rancore.", "hfx": ["any", ["reveal_last", 1], ["grudge", 1]],
		"bt": "In qualsiasi ordine: prendi un Talento bestiale; prendi un Potere antico.", "bfx": ["any", ["talent", 1], ["ap"]]},
	"stride": {"n": "Falcata", "en": "Stride", "c": "S", "si": true,
		"ht": "Prendi un Oggetto del cacciatore, poi tu e un altro cacciatore a non più di 2 passi potete muovere di 1 passo ciascuno.", "hfx": ["seq", ["item", 1], ["stride_h"]],
		"bt": "Prendi un Talento bestiale, poi un evocato può muovere di 2 passi.", "bfx": ["seq", ["talent", 1], ["summon_mv", 2]]},
	"displace": {"n": "Dislocare", "en": "Displace", "c": "S", "si": true,
		"ht": "Trasforma un luogo a non più di 2 passi, poi ogni cacciatore vicino a quel luogo può muovere di 1 passo.", "hfx": ["seq", ["displace_h"]],
		"bt": "In qualsiasi ordine: trasforma fino a 2 luoghi vicini; muovi di 1 passo.", "bfx": ["any", ["tf_near_upto", 2], ["mv", 1]]},
	"glimpse": {"n": "Scorcio", "en": "Glimpse", "c": "R", "si": true,
		"ht": "Prendi un Oggetto del cacciatore, poi puoi giocare un Oggetto dalla mano ignorando ogni costo (non conta come azione rossa o blu).", "hfx": ["seq", ["item", 1], ["free_item"]],
		"bt": "Copia l'effetto di un Talento bestiale scoperto pagando 1 rancore in meno, poi scarta quel Talento.", "bfx": ["seq", ["glimpse_b"]]},
	"dark_offerings": {"n": "Offerte oscure", "en": "Dark Offerings", "c": "R", "si": true, "dark": true,
		"ht": "Subisci 1 ferita, poi spostati in un luogo a non più di 3 passi.", "hfx": ["seq", ["suffer", 1], ["relocate_range", 3]],
		"bt": "Attacca, poi, se hai ucciso la vittima, metti un evocato in un luogo vicino qualsiasi.", "bfx": ["seq", ["atk"], ["summon_if_kill"]]},
}

## Oggetti del cacciatore (n: copie nel mazzo)
const ITEMS := {
	"fire_trap": {"n": "Trappola di fuoco", "en": "Fire Trap", "c": "T", "cost": 1, "copies": 3, "t": "Trappola. Infligge 1 danno alla Bestia.", "trap": "fire"},
	"flare": {"n": "Razzo di segnalazione", "en": "Flare", "c": "X", "cost": 1, "copies": 2, "react": "trail_on_settler", "t": "Reazione: quando compare una Traccia nel luogo di un colono. Muovi un colono qualsiasi di 1 passo.", "fx": ["seq", ["move_settler", 1]]},
	"grapeshot": {"n": "Mitraglia", "en": "Grapeshot", "c": "R", "cost": 1, "copies": 1, "t": "Infliggi 1 danno a ogni evocato vicino.", "fx": ["seq", ["dmg_near_summons", 1]]},
	"hexing_trap": {"n": "Trappola del maleficio", "en": "Hexing Trap", "c": "T", "cost": 1, "copies": 3, "t": "Trappola. La Bestia scarta 2 carte.", "trap": "hex"},
	"hunters_rest": {"n": "Riposo del cacciatore", "en": "Hunter's Rest", "c": "B", "cost": 0, "copies": 2, "t": "Guadagna 1 rancore. Ogni cacciatore e colono vicino recupera 1 ferita.", "fx": ["seq", ["grudge", 1], ["heal_near", 1]]},
	"hunters_passage": {"n": "Passaggio del cacciatore", "en": "Hunter's Passage", "c": "B", "cost": 0, "copies": 2, "t": "Trasforma il tuo luogo in insediamento, poi spostati in un insediamento qualsiasi.", "fx": ["seq", ["tf_here"], ["relocate_set"]]},
	"hunters_bell": {"n": "Campana del cacciatore", "en": "Hunter's Bell", "c": "R", "cost": 0, "copies": 2, "t": "In qualsiasi ordine: muovi di 1 passo; un cacciatore vicino recupera 1 ferita.", "fx": ["any", ["mv", 1], ["heal_hunter_near", 1]]},
	"outpost": {"n": "Avamposto", "en": "Outpost", "c": "R", "cost": 0, "copies": 2, "t": "Metti una torre di guardia nel tuo luogo.", "fx": ["seq", ["watchtower"]]},
	"shrieker_trap": {"n": "Trappola urlante", "en": "Shrieker Trap", "c": "T", "cost": 1, "copies": 2, "t": "Trappola. Ogni cacciatore può muovere fino a 2 passi.", "trap": "shriek"},
	"blade_valh": {"n": "Lama di Valh", "en": "Blade of Valh", "c": "R", "cost": 0, "copies": 1, "t": "In qualsiasi ordine: guadagna 1 rancore; puoi comprare 1 potenziamento.", "fx": ["any", ["grudge", 1], ["buy_upgrade"]]},
	"smokebomb": {"n": "Fumogeno", "en": "Smokebomb", "c": "X", "cost": 1, "copies": 2, "react": "beast_attack_near", "t": "Reazione: quando la Bestia attacca un luogo vicino. Previeni 1 danno (non contro gli evocati).", "fx": ["seq", ["prevent", 1]]},
	"auroras_passage": {"n": "Passaggio di Aurora", "en": "Aurora's Passage", "c": "B", "cost": 1, "copies": 1, "t": "Muovi fino a 2 passi.", "fx": ["seq", ["mvu", 2]]},
	"wolfsbane": {"n": "Aconito", "en": "Wolfsbane", "c": "B", "cost": 1, "copies": 2, "t": "In qualsiasi ordine: perlustra il tuo luogo; attacca.", "fx": ["any", ["search"], ["atk"]]},
	"ritual_trap": {"n": "Trappola rituale", "en": "Ritual Trap", "c": "T", "cost": 1, "copies": 2, "si": true, "t": "Trappola. Un colono riceve un'Armatura.", "trap": "ritual"},
	"expedition_map": {"n": "Mappa della spedizione", "en": "Expedition Map", "c": "B", "cost": 0, "copies": 2, "si": true, "t": "Scegli un effetto: ogni cacciatore nella tua zona può muovere di 1 passo; oppure attiva una Rovina nella tua zona.", "fx": ["one", ["zone_hunters_mv1"], ["activate_ruin"]]},
	"spyglass": {"n": "Cannocchiale", "en": "Spyglass", "c": "S", "cost": 0, "copies": 1, "si": true, "t": "Perlustra un luogo a non più di 3 passi.", "fx": ["seq", ["search_range", 3]]},
	"sacred_riches": {"n": "Ricchezze sacre", "en": "Sacred Riches", "c": "S", "cost": 0, "copies": 2, "si": true, "t": "Guadagna 2 rancori.", "fx": ["seq", ["grudge", 2]]},
	"banshees_lure": {"n": "Richiamo della Banshee", "en": "Banshee's Lure", "c": "R", "cost": 0, "copies": 1, "si": true, "t": "Porta nel tuo luogo tutti gli esseri vicini.", "fx": ["seq", ["lure_all"]]},
	"warhogs_tusk": {"n": "Zanna del cinghiale da guerra", "en": "Warhog's Tusk", "c": "R", "cost": 1, "copies": 1, "si": true, "t": "Muovi di esattamente 2 passi nella stessa direzione. Fino a un essere su cui passi si muove con te.", "fx": ["seq", ["tusk_h"]]},
	"chain_grapnel": {"n": "Arpione a catena", "en": "Chain Grapnel", "c": "R", "cost": 0, "copies": 1, "si": true, "t": "Un essere a non più di 2 passi nella stessa direzione viene spostato nel tuo luogo, oppure tu nel suo; poi un cacciatore vicino può scartare una carta Azione per prendere in mano Arpione a catena.", "fx": ["seq", ["grapple", 2], ["grapnel_pass"]]},
	"esmerias_strand": {"n": "Ciocca di Esmeria", "en": "Esmeria's Strand", "c": "X", "cost": 1, "copies": 1, "si": true, "react": "beast_blue_action", "t": "Reazione: dopo che la Bestia gioca una carta Azione blu. Copia l'effetto del cacciatore di quella carta.", "fx": ["seq", ["copy_beast_action"]]},
	"dreamer_mask": {"n": "Maschera del sognatore", "en": "Dreamer Mask", "c": "X", "cost": 1, "copies": 2, "si": true, "react": "day_start", "t": "Reazione: all'inizio del Giorno. Puoi giocare 1 carta prima del turno della Bestia; poi l'ordine di turno prosegue normalmente.", "fx": ["seq", ["extra_turn"]]},
}

## Talenti bestiali
const TALENTS := {
	"abrupt_decay": {"n": "Decadimento improvviso", "en": "Abrupt Decay", "c": "B", "cost": 1, "copies": 1, "t": "Scegli una zona e un habitat, poi togli tutte le trappole di quella zona con quell'habitat.", "fx": ["seq", ["abrupt_decay"]]},
	"disappear": {"n": "Sparire", "en": "Disappear", "c": "R", "cost": 0, "copies": 1, "only_revealed": true, "t": "Giocabile solo se sei rivelata. Muovi di 2 passi.", "fx": ["seq", ["mv", 2]]},
	"brutality": {"n": "Brutalità", "en": "Brutality", "c": "R", "cost": 1, "copies": 2, "t": "In qualsiasi ordine: attacca; muovi di 1 passo.", "fx": ["any", ["atk"], ["mv", 1]]},
	"evolve": {"n": "Evolversi", "en": "Evolve", "c": "B", "cost": 0, "copies": 3, "t": "In qualsiasi ordine: muovi di 1 passo; compra fino a 1 potenziamento.", "fx": ["any", ["mv", 1], ["buy_upgrade"]]},
	"hatred": {"n": "Odio", "en": "Hatred", "c": "R", "cost": 1, "copies": 2, "t": "Prendi un Potere antico.", "fx": ["seq", ["ap"]]},
	"insidious_growth": {"n": "Crescita insidiosa", "en": "Insidious Growth", "c": "B", "cost": 0, "copies": 2, "t": "Trasforma ogni luogo vicino.", "fx": ["seq", ["tf_near_all"]]},
	"intuition": {"n": "Intuito", "en": "Intuition", "c": "X", "cost": 1, "copies": 2, "react": "hunt_played", "t": "Reazione: quando viene giocata l'abilità «Caccia». Muovi di 1 passo.", "fx": ["seq", ["mv", 1]]},
	"rage": {"n": "Rabbia", "en": "Rage", "c": "R", "cost": 0, "copies": 2, "t": "Attacca.", "fx": ["seq", ["atk"]]},
	"roam": {"n": "Vagare", "en": "Roam", "c": "R", "cost": 0, "copies": 2, "t": "In qualsiasi ordine: muovi di 1 passo; muovi i tuoi evocati di 1 passo.", "fx": ["any", ["mv", 1], ["summons_mv1"]]},
	"sprawl": {"n": "Dilagare", "en": "Sprawl", "c": "R", "cost": 0, "copies": 2, "t": "In qualsiasi ordine: trasforma il tuo luogo; muovi di 1 passo.", "fx": ["any", ["tf_here"], ["mv", 1]]},
	"disperse": {"n": "Disperdersi", "en": "Disperse", "c": "R", "cost": 1, "copies": 2, "t": "Muovi di 2 passi.", "fx": ["seq", ["mv", 2]]},
	"strange_summons": {"n": "Strane evocazioni", "en": "Strange Summons", "c": "B", "cost": 1, "copies": 2, "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	"unbending_will": {"n": "Volontà inflessibile", "en": "Unbending Will", "c": "B", "cost": 0, "copies": 2, "t": "Riprendi in mano una carta Abilità scartata.", "fx": ["seq", ["ret_ability"]]},
	"flourish": {"n": "Prosperare", "en": "Flourish", "c": "R", "cost": 1, "copies": 2, "si": true, "t": "Muovi di 1 passo, poi prendi una carta Azione inutilizzata a caso per ogni cinghiale, orso e tigre che hai ucciso in questa partita.", "fx": ["seq", ["mv", 1], ["flourish"]]},
	"fury": {"n": "Furore", "en": "Fury", "c": "O", "cost": 1, "copies": 1, "si": true, "lock": "*", "t": "Attacca.", "fx": ["seq", ["atk"]], "ot": "Furore infligge 1 danno in più. Trasforma ogni luogo vicino.", "ofx": ["seq", ["atk", 1], ["tf_near_all"]]},
	"feast": {"n": "Banchetto", "en": "Feast", "c": "R", "cost": 0, "copies": 2, "si": true, "lock": "*", "t": "Attacca. Questo attacco infligge 1 danno in più agli animali.", "fx": ["seq", ["atk", 0, 1]]},
	"swarm": {"n": "Sciame", "en": "Swarm", "c": "B", "cost": 0, "copies": 1, "si": true, "lock": "*", "t": "Tutti gli evocati possono attaccare. Guadagni i rancori delle vittime uccise in questo modo.", "fx": ["seq", ["swarm"]]},
	"shatter": {"n": "Frantumare", "en": "Shatter", "c": "O", "cost": 1, "copies": 1, "si": true, "lock": "*", "t": "Attacca.", "fx": ["seq", ["atk"]], "ot": "Poi attacca ogni altro animale vicino.", "ofx": ["seq", ["atk"], ["atk_other_animals_near"]]},
	"mirror_step": {"n": "Passo speculare", "en": "Mirror Step", "c": "B", "cost": 0, "copies": 2, "si": true, "lock": "*", "t": "Muovi di 1 passo, poi metti una carta Movimento falsa accanto a quella vera.", "fx": ["seq", ["mv_false", 1]]},
	"worldshift": {"n": "Mutamento del mondo", "en": "Worldshift", "c": "X", "cost": 0, "copies": 2, "si": true, "react": "hunter_turn_end", "t": "Reazione: dopo che un cacciatore termina il turno. Muovi di 1 passo e muovi di 1 passo un animale della tua zona.", "fx": ["seq", ["mv", 1], ["move_animal_zone"]]},
	"sudden_mist": {"n": "Nebbia improvvisa", "en": "Sudden Mist", "c": "X", "cost": 1, "copies": 1, "si": true, "react": "reaction_on_my_turn", "t": "Reazione: quando una reazione o una trappola si attiva nel tuo turno. Ignora l'effetto di quella reazione o trappola.", "fx": ["seq", ["cancel_reaction"]]},
}

## Carte Abilità dei personaggi. lock: habitat richiesto. ch/cht/chfx: Carica d'anime di Vacker.
## o: sovraccarica (ot/ofx). hunt/track: Caccia e Seguire le tracce (comuni a molti cacciatori).
const ABILITIES := {
	# --- Bolgin
	"engorge": {"n": "Ingozzare", "en": "Engorge", "c": "R", "lock": "swamp", "t": "Attacca.", "fx": ["seq", ["atk"]]},
	"leap": {"n": "Balzo", "en": "Leap", "c": "B", "lock": "swamp", "t": "Le carte «Nessun movimento» sono ammesse. Muovi di 2 passi nella stessa direzione.", "fx": ["seq", ["mv_same", 2, 1]]},
	"beastly_tongue": {"n": "Lingua bestiale", "en": "Beastly Tongue", "c": "B", "t": "Porta nel tuo luogo un cacciatore, colono o animale vicino.", "fx": ["seq", ["tongue"]]},
	"summon_polyp": {"n": "Evoca Polipo", "en": "Summon Polyp", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	# --- Fangrir
	"prey_upon": {"n": "Avventarsi", "en": "Prey Upon", "c": "R", "lock": "forest", "t": "In qualsiasi ordine: attacca; muovi di 1 passo.", "fx": ["any", ["atk"], ["mv", 1]]},
	"gather_pack": {"n": "Radunare il branco", "en": "Gather the Pack", "c": "B", "lock": "forest", "t": "Muovi di 1 passo, poi ogni Lupo nella tua zona muove fino a 1 passo.", "fx": ["seq", ["mv", 1], ["wolves_zone_mv1"]]},
	"lurk": {"n": "In agguato", "en": "Lurk", "c": "R", "t": "Muovi di 1 passo.", "fx": ["seq", ["mv_lurk"]]},
	"summon_wolf": {"n": "Evoca Lupo", "en": "Summon Wolf", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	# --- Mara
	"feed": {"n": "Nutrirsi", "en": "Feed", "c": "R", "lock": "cave", "t": "Attacca, poi metti una Banshee nel tuo luogo se hai ucciso la vittima.", "fx": ["seq", ["atk"], ["banshee_if_kill"]]},
	"obscure_talent": {"n": "Talento oscuro", "en": "Obscure Talent", "c": "B", "lock": "cave", "t": "In qualsiasi ordine: muovi di 1 passo; una Banshee può agire.", "fx": ["any", ["mv", 1], ["one_summon_act"]]},
	"flicker": {"n": "Guizzo", "en": "Flicker", "c": "R", "t": "Muovi di 1 passo per ogni cacciatore, colono e animale morto oggi.", "fx": ["seq", ["mv_flicker"]]},
	"shadow_step": {"n": "Passo d'ombra", "en": "Shadow Step", "c": "B", "t": "Scegli un effetto: muovi di 1 passo; oppure spostati su una Banshee, poi rivelati.", "fx": ["one", ["mv", 1], ["to_banshee"]]},
	# --- Raaga
	"hydra": {"n": "Idra", "en": "Hydra", "c": "R", "lock": "swamp", "t": "Attacca.", "fx": ["seq", ["atk_hydra"]]},
	"slither": {"n": "Strisciare", "en": "Slither", "c": "B", "lock": "swamp", "t": "Muovi di 1 passo, poi, se il nuovo luogo è una palude, muovi di 1 passo in più.", "fx": ["seq", ["mv_slither"]]},
	"flood": {"n": "Inondare", "en": "Flood", "c": "R", "t": "Trasforma fino a 2 luoghi vicini.", "fx": ["seq", ["tf_near_upto", 2]]},
	"summon_basilisk": {"n": "Evoca Basilisco", "en": "Summon Basilisk", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	# --- Hogbad
	"stampede": {"n": "Carica selvaggia", "en": "Stampede", "c": "R", "lock": "forest", "t": "Muovi di 2 passi nella stessa direzione, poi trasforma quei luoghi. Ogni cacciatore, colono e animale su cui passi si muove con te.", "fx": ["seq", ["stampede"]]},
	"ramble": {"n": "Vagabondare", "en": "Ramble", "c": "B", "t": "Muovi di 1 passo.", "fx": ["seq", ["mv", 1]]},
	"summon_warhog": {"n": "Evoca Cinghiale da guerra", "en": "Summon Warhog", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	"tusk": {"n": "Zanna", "en": "Tusk", "c": "R", "lock": "forest", "t": "Attacca.", "fx": ["seq", ["atk"]]},
	# --- Esmeria
	"deceive": {"n": "Ingannare", "en": "Deceive", "c": "B", "lock": "cave", "t": "Guarda la mano di un cacciatore e copia una sua carta Azione blu: giochi il tuo effetto di quella carta. La carta non viene scartata.", "fx": ["seq", ["deceive"]]},
	"stalk": {"n": "Pedinare", "en": "Stalk", "c": "R", "t": "Muovi di 1 passo, poi trasforma il tuo luogo, poi muovi di 1 passo in più.", "fx": ["seq", ["mv", 1], ["tf_here"], ["mv", 1]]},
	"summon_changeling": {"n": "Evoca Mutaforma", "en": "Summon Changeling", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	"murder": {"n": "Assassinio", "en": "Murder", "c": "R", "lock": "cave", "t": "Attacca, poi muovi di 1 passo.", "fx": ["seq", ["atk"], ["mv", 1]]},
	# --- Akkeron
	"corrupt": {"n": "Corrompere", "en": "Corrupt", "c": "B", "t": "In qualsiasi ordine: muovi di 1 passo; trasforma una palude vicina in palude abissale.", "fx": ["any", ["mv", 1], ["abyss_near"]]},
	"defile": {"n": "Profanare", "en": "Defile", "c": "B", "t": "In qualsiasi ordine: evoca; trasforma il tuo luogo in palude abissale.", "fx": ["any", ["summon"], ["abyss_here"]]},
	"consume": {"n": "Consumare", "en": "Consume", "c": "R", "lock": "swamp", "t": "In qualsiasi ordine: attacca; trasforma una palude vicina in palude abissale.", "fx": ["any", ["atk"], ["abyss_near"]]},
	"void": {"n": "Vuoto", "en": "Void", "c": "S", "lock": "swamp", "t": "Muovi di 1 passo, poi puoi muovere di 1 passo in più se il nuovo luogo è una palude abissale.", "fx": ["seq", ["mv_void"]]},
	# --- Thalduk
	"storm": {"n": "Tempesta", "en": "Storm", "c": "O", "lock": "cave", "t": "Attacca.", "fx": ["seq", ["atk"]], "ot": "Tempesta infligge 1 danno in più. Trasforma ogni luogo vicino.", "ofx": ["seq", ["atk", 1], ["tf_near_all"]]},
	"acclivity": {"n": "Erta", "en": "Acclivity", "c": "R", "lock": "cave", "t": "Muovi di 1 passo. Poi puoi rivelare l'ultima carta Movimento giocata per muovere di 1 passo in più.", "fx": ["seq", ["mv", 1], ["acclivity"]]},
	"summon_yagi": {"n": "Evoca Yagi", "en": "Summon Yagi", "c": "B", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	"bleat": {"n": "Belato", "en": "Bleat", "c": "X", "react": "hunter_red_action_zone", "t": "Reazione: quando un cacciatore nella tua zona gioca una carta Azione rossa. Evoca.", "fx": ["seq", ["summon"]]},
	# --- Vacker
	"allure": {"n": "Attrattiva", "en": "Allure", "c": "R", "lock": "forest", "t": "Attacca.", "fx": ["seq", ["atk"]], "ch": 4, "cht": "Poi metti un Ammiratore in una foresta vicina se hai ucciso la vittima.", "chfx": ["seq", ["atk"], ["admirer_if_kill"]]},
	"behold": {"n": "Ammirare", "en": "Behold", "c": "B", "t": "Rivelati, poi muovi di 1 passo 2 diversi coloni, animali o evocati della tua zona.", "fx": ["seq", ["reveal"], ["behold"]], "ch": 3, "cht": "Poi trasforma ogni luogo vicino.", "chfx": ["seq", ["reveal"], ["behold"], ["tf_near_all"]]},
	"summon_admirer": {"n": "Evoca Ammiratore", "en": "Summon Admirer", "c": "B", "t": "Evoca, poi muovi di 1 passo.", "fx": ["seq", ["summon"], ["mv", 1]], "ch": 2, "cht": "Poi muovi un Ammiratore fino a 1 passo.", "chfx": ["seq", ["summon"], ["mv", 1], ["summon_mvu", 1, "admirer"]]},
	"elude": {"n": "Eludere", "en": "Elude", "c": "R", "lock": "forest", "t": "Muovi di 1 passo, poi metti una carta Movimento falsa accanto a quella vera.", "fx": ["seq", ["mv_false", 1]], "ch": 3, "cht": "Poi copia l'effetto di Eludere.", "chfx": ["seq", ["mv_false", 1], ["mv_false", 1]]},
	# --- Re Piumato
	"unburden": {"n": "Alleggerire", "en": "Unburden", "c": "B", "t": "In qualsiasi ordine: muovi di 1 passo; prendi 1 rancore da un cacciatore vicino.", "fx": ["any", ["mv", 1], ["steal_grudge"]]},
	"unwilling_sacrifice": {"n": "Sacrificio involontario", "en": "Unwilling Sacrifice", "c": "R", "t": "In qualsiasi ordine: attacca; trasforma un luogo vicino.", "fx": ["any", ["atk"], ["tf_near_upto", 1]]},
	"uprise": {"n": "Insorgere", "en": "Uprise", "c": "S", "lock": "cave", "t": "Muovi di 1 passo.", "fx": ["seq", ["mv_uprise"]]},
	"summon_dreamer": {"n": "Evoca Sognatore", "en": "Summon Dreamer", "c": "S", "lock": "cave", "t": "In qualsiasi ordine: evoca; muovi di 1 passo.", "fx": ["any", ["summon"], ["mv", 1]]},
	# --- cacciatori: carte proprie
	"scout": {"n": "Ricognizione", "en": "Scout", "c": "R", "t": "Scegli un effetto: trasforma il tuo luogo in insediamento; oppure muovi fino a 2 passi se sei su un insediamento.", "fx": ["one", ["tf_here"], ["scout_move"]]},
	"cleaver": {"n": "Mannaia", "en": "Cleaver", "c": "R", "t": "Metti una torre di guardia nel tuo luogo, poi trasformalo.", "fx": ["seq", ["watchtower"], ["tf_here"]]},
	"seer": {"n": "Veggenza", "en": "Seer", "c": "R", "t": "Rivela l'ultima carta Movimento giocata.", "fx": ["seq", ["seer"]]},
	"silver_arrow": {"n": "Freccia d'argento", "en": "Silver Arrow", "c": "R", "t": "In qualsiasi ordine: attacca un evocato vicino; muovi di 1 passo.", "fx": ["any", ["atk_summon_near"], ["mv", 1]]},
	"trapmaster": {"n": "Maestro delle trappole", "en": "Trapmaster", "c": "R", "t": "In qualsiasi ordine: prendi un Oggetto del cacciatore; puoi mettere subito in gioco una trappola nella tua zona ignorando ogni costo.", "fx": ["any", ["item", 1], ["free_trap"]]},
	"command": {"n": "Comando", "en": "Command", "c": "R", "t": "In qualsiasi ordine: muovi fino a 1 passo un cacciatore della tua zona; muovi fino a 1 passo un colono della tua zona.", "fx": ["any", ["command_hunter"], ["command_settler"]]},
	"grappling_hook": {"n": "Rampino", "en": "Grappling Hook", "c": "R", "t": "Un essere vicino viene spostato nel tuo luogo, oppure tu nel suo.", "fx": ["seq", ["grapple", 1]]},
	"aviation": {"n": "Volo", "en": "Aviation", "c": "S", "t": "Scegli un effetto: tu e Fylgja potete muovere di 1 passo ciascuno; oppure riprendi in mano Rampino.", "fx": ["one", ["me_and_fylgja_mv1"], ["return_hook"]]},
	"incision": {"n": "Incisione", "en": "Incision", "c": "R", "t": "Muovi di 1 passo, poi attacca un animale. Se uccidi la vittima, guadagna 1 sangue in più.", "fx": ["seq", ["mv", 1], ["atk_animal"]]},
	"blood_track": {"n": "Pista di sangue", "en": "Blood Track", "c": "B", "track": true, "t": "Muovi di 1 passo. Se nel nuovo luogo c'è una Traccia, puoi spendere 1 sangue per muovere di 2 passi in più.", "fx": ["seq", ["blood_track"]]},
	"blood_hunt": {"n": "Caccia di sangue", "en": "Blood Hunt", "c": "B", "hunt": true, "t": "Perlustra un luogo vicino, poi puoi spendere 2 sangue per muovere di 1 passo e attaccare.", "fx": ["seq", ["search_near"], ["blood_hunt"]]},
	"flame_rapier": {"n": "Stocco di fiamma", "en": "Flame Rapier", "c": "O", "t": "Scegli una direzione e spostati fino a 3 passi in quella direzione.", "fx": ["seq", ["rapier"]], "ot": "Invece, muovi fino a 3 passi nella stessa direzione, poi attacca.", "ofx": ["seq", ["rapier_move"], ["atk"]]},
	"unnatural_resolve": {"n": "Risolutezza innaturale", "en": "Unnatural Resolve", "c": "R", "t": "Muovi di 1 passo, poi puoi ripetere questo movimento finché non sei in un luogo senza Traccia. L'effetto termina quando lasci la zona in cui sei.", "fx": ["seq", ["prowl_zone"]]},
	"delegate": {"n": "Delegare", "en": "Delegate", "c": "B", "t": "Ogni cacciatore vicino può muovere di 1 passo.", "fx": ["seq", ["delegate"]]},
}
const HUNT := {"n": "Caccia", "en": "Hunt", "c": "B", "hunt": true, "t": "In qualsiasi ordine: perlustra il tuo luogo; attacca.", "fx": ["any", ["search"], ["atk"]]}
const TRACK := {"n": "Seguire le tracce", "en": "Track", "c": "B", "track": true, "t": "Muovi di 1 passo. Se nel nuovo luogo c'è una Traccia, muovi fino a 1 passo in più.", "fx": ["seq", ["track"]]}

## Carta Movimento (nella versione digitale le sceglie il motore: la Bestia indica solo il luogo)
const MOVE_CARD_IT := "Carta Movimento"

# ---------------------------------------------------------------------------------- contratti
## req: alternative (basta una): ognuna è un dizionario di condizioni, tutte vere.
##   kill_<animale|farmer|noble|settler>: uccisi dalla Bestia; ruins: Rovine controllate;
##   beast_dmg: danni inflitti alla Bestia; dom_blue: passi del segnalino blu; tokens: habitat sul contratto.
## rw: ricompensa (operazioni eseguite da ogni Bestia o da ogni cacciatore vivo).
const CONTRACTS := {
	"regent": {"n": "Reggente delle rovine", "en": "Regent of Ruins", "players": [2, 3], "map": "lsi", "img": "contract_regent",
		"intro": "Espandendosi nelle Isole Frantumate, gli umani hanno scoperto rovine di un antico passato: luoghi che custodiscono segreti oscuri e poteri inimmaginabili. Entrambi gli schieramenti devono controllarle a ogni costo.",
		"setup_t": "La Bestia inizia con 1 rancore ed evoca; il segnalino rosso parte dallo 0 del contatore del Dominio. Ogni cacciatore inizia con 1 rancore; il segnalino blu parte dallo 0.",
		"end_t": "La Bestia vince quando il segnalino rosso arriva a 12. I cacciatori vincono quando il segnalino blu arriva a 12, quando la Bestia muore o quando arriva la Notte finale.",
		"legend_t": "Gli evocati hanno 1 salute in più. Quando muore un Contadino, il rosso avanza di 3; quando muore un Nobile, di 4. Se controlli 2 Rovine e un animale subisce danni nel tuo turno, il rosso avanza di 1. Quando la Bestia o un evocato subiscono danni, il blu avanza di 1.",
		"setup": {"beast_grudge": 1, "beast_summon": true, "hunter_grudge": 1, "dominion": true},
		"dominion_goal": 12,
		"nights": [
			{"b_req": [{"kill_sheep": 2}, {"kill_sabertooth": 1}], "b_req_t": "Uccise 2 pecore oppure una tigre", "b_rw": [["noble_to_farmer"], ["dom_per_ruin", "red"]], "b_rw_t": "Trasforma un Nobile in Contadino. Il rosso avanza di 1 per ogni Rovina che controlli.",
			 "h_req": [{"ruins": 1}], "h_req_t": "I cacciatori controllano una Rovina", "h_rw": [["grudge", 1], ["dom_per_ruin_once", "blue"]], "h_rw_t": "1 rancore. Il blu avanza di 1 per ogni Rovina che controllate."},
			{"b_req": [{"kill_settler": 1}, {"kill_sheep": 2, "kill_sabertooth": 1}], "b_req_t": "Ucciso un colono, oppure 2 pecore e una tigre", "b_rw": [["summon"], ["grudge", 1]], "b_rw_t": "Evoca. 1 rancore.",
			 "h_req": [{"dom_blue": 8}], "h_req_t": "Il blu è avanzato di almeno 8", "h_rw": [["item", 1], ["mv", 2]], "h_rw_t": "Prendi un Oggetto. Muovi di 2 passi."},
		],
		"final": "hunters",
		"ruins": {
			"yagi_cliffs": {"h_t": "Muovi di 2 passi. Finché controlli questa Rovina, il primo danno che infliggi ogni giorno a un evocato fa avanzare il blu di 1 in più.", "h": [["mv", 2]],
				"b_t": "Muovi fino a 2 passi, poi evoca.", "b": [["mvu", 2], ["summon"]]},
			"admirer_glade": {"h_t": "Muovi di 2 passi. Finché controlli questa Rovina, quando la Bestia subisce danni il blu avanza di 1 in più.", "h": [["mv", 2]],
				"b_t": "Evoca, poi un evocato può muovere fino a 2 passi.", "b": [["summon"], ["summon_mvu", 2, ""]]},
			"sunken_ruins": {"h_t": "Muovi di 1 passo. Puoi comprare un potenziamento con 1 rancore in meno.", "h": [["mv", 1], ["buy_upgrade_disc", 1]],
				"b_t": "Muovi fino a 2 passi. Guadagna 1 rancore.", "b": [["mvu", 2], ["grudge", 1]]},
		}},
	"brave": {"n": "Un patto dimenticato", "en": "Pact Long Forgotten", "players": [4], "map": "lsi", "img": "contract_brave",
		"intro": "Sono passate molte settimane da quando la Lightseeker e la Titan sono approdate su queste terre spezzate. Esplorando Elysara e Aurelia, la spedizione ha scoperto che un tempo l'uomo viveva sotto la protezione delle Bestie, finché l'ambizione non ruppe quella pace.",
		"setup_t": "La Bestia inizia con 1 rancore e il Talento bestiale Mutamento del mondo. Ogni cacciatore inizia con 1 rancore.",
		"end_t": "La Bestia vince quando sono morti 2 coloni. I cacciatori vincono quando la Bestia muore o quando arriva la Notte finale.",
		"legend_t": "",
		"setup": {"beast_grudge": 1, "beast_talent": "worldshift", "hunter_grudge": 1},
		"beast_wins_settlers": 2,
		"nights": [
			{"b_req": [{"kill_sheep": 2}, {"kill_sabertooth": 1}], "b_req_t": "Uccise 2 pecore oppure una tigre", "b_rw": [["grudge", 1], ["talent", 1]], "b_rw_t": "1 rancore. Prendi un Talento bestiale.",
			 "h_req": [{"beast_dmg": 1}, {"ruins": 2}], "h_req_t": "La Bestia ha subito 1 danno, oppure controllate 2 Rovine", "h_rw": [["grudge", 1], ["arsenal_plus"]], "h_rw_t": "1 rancore. Da ora l'Arsenale ha un Oggetto scoperto in più a ogni Notte."},
			{"b_req": [{"kill_settler": 1}], "b_req_t": "Ucciso un colono", "b_rw": [["grudge", 1], ["talent_per_ruin"]], "b_rw_t": "1 rancore. Un Talento bestiale per ogni Rovina che controlli.",
			 "h_req": [{"beast_dmg": 2}], "h_req_t": "La Bestia ha subito 2 danni", "h_rw": [["item", 1], ["tf_near_settlement"]], "h_rw_t": "Prendete un Oggetto. Ogni cacciatore può trasformare un luogo vicino in insediamento."},
		],
		"final": "hunters",
		"ruins": {
			"yagi_cliffs": {"h_t": "Fino a 2 cacciatori possono muovere di 1 passo.", "h": [["two_hunters_mv1"]],
				"b_t": "1 rancore. Prendi un Talento bestiale.", "b": [["grudge", 1], ["talent", 1]]},
			"admirer_glade": {"h_t": "1 rancore. Muovi fino a 1 passo.", "h": [["grudge", 1], ["mvu", 1]],
				"b_t": "Evoca, poi muovi di 1 passo.", "b": [["summon"], ["mv", 1]]},
			"sunken_ruins": {"h_t": "Prendi un Oggetto. Puoi mettere subito in gioco una trappola ignorando ogni costo.", "h": [["item", 1], ["free_trap"]],
				"b_t": "Puoi comprare un potenziamento con 1 rancore in meno.", "b": [["buy_upgrade_disc", 1]]},
		}},
	"titan": {"n": "L'arrivo della Titan", "en": "Arrival of the Titan", "players": [5], "beasts": 2, "map": "lsi", "img": "contract_titan",
		"intro": "Seguendo il segnale della Lightseeker, la Titan si avvicina alle Isole Frantumate con a bordo i rappresentanti delle casate del Nord. Ma le Bestie di questo luogo aspettano, pronte a colpire.",
		"setup_t": "Ogni Bestia inizia con 2 rancori. East Camp, Aurelia ed Elysara diventano un habitat preferito delle due Bestie. Ogni cacciatore inizia con 1 rancore. Tutti i coloni lasciano la mappa: sulla Titan restano solo un Nobile e un Contadino, e lì partono tutti i cacciatori.",
		"end_t": "Le Bestie vincono quando muoiono tutti i coloni o quando arriva la Notte finale. I cacciatori vincono quando sul contratto ci sono tre segnalini habitat, oppure quando le Bestie muoiono.",
		"legend_t": "Aurelia, Elysara ed East Camp non si possono trasformare. Quando un cacciatore gioca una carta Azione rossa, può muovere ogni colono di 1 passo. Quando un cacciatore inizia il turno con un colono su Aurelia, Elysara o East Camp, il segnalino habitat di quel luogo passa sul contratto.",
		"setup": {"beast_grudge": 2, "hunter_grudge": 1, "titan": true},
		"nights": [
			{"b_req": [{"kill_sheep": 3}], "b_req_t": "Le Bestie hanno ucciso 3 pecore", "b_rw": [["grudge", 1], ["talent", 1]], "b_rw_t": "1 rancore. Prendi un Talento bestiale.",
			 "h_req": [{"tokens": 1}], "h_req_t": "Un segnalino habitat è sul contratto", "h_rw": [["grudge", 1], ["mv", 1], ["settlers_mv1_once"]], "h_rw_t": "1 rancore. Ogni cacciatore e colono può muovere di 1 passo."},
			{"b_req": [{"kill_settler": 1}], "b_req_t": "Ucciso un colono", "b_rw": [["mvu", 1], ["talent", 1]], "b_rw_t": "Muovi fino a 1 passo. Prendi un Talento bestiale.",
			 "h_req": [{"tokens": 2}], "h_req_t": "Due segnalini habitat sul contratto", "h_rw": [["item", 1], ["tf_near_settlement"]], "h_rw_t": "Prendete un Oggetto, poi ogni cacciatore può trasformare un luogo vicino in insediamento."},
		],
		"final": "beasts",
		"ruins": {
			"yagi_cliffs": {"h_t": "Tutti i coloni e i cacciatori possono muovere di 1 passo.", "h": [["all_mv1"]],
				"b_t": "Ogni Bestia ed evocato può muovere di 2 passi.", "b": [["beasts_summons_mv2"]]},
			"admirer_glade": {"h_t": "Togli tutte le ferite a un colono.", "h": [["heal_settler_full"]],
				"b_t": "Entrambe le Bestie possono evocare.", "b": [["both_summon"]]},
			"sunken_ruins": {"h_t": "Un colono può trasformare il suo luogo in insediamento.", "h": [["settler_tf"]],
				"b_t": "1 rancore. Finché controlli questa Rovina, i coloni non possono usare i Sentieri nascosti.", "b": [["grudge", 1]]},
		}},
}
## Contratti del gioco base e delle Isole superiori: servono le mappe Northern Expanse, Drenched Lands e
## Great Divide, che non sono nel modulo TTS fornito (vedi README, «Cosa manca»).
const CONTRACTS_MISSING := {
	"great_cleansing": ["La Grande Purificazione", "Drenched Lands", "2-3"],
	"shipwreck": ["Naufragio", "Drenched Lands", "2-3"],
	"northern_settlements": ["Attacco agli insediamenti del Nord", "Northern Expanse", "4"],
	"northern_gods": ["Il risveglio degli dèi del Nord", "Northern Expanse", "4"],
	"ruins": ["Le rovine delle Isole Frantumate", "Great Divide", "2-3"],
	"release": ["Violare la Guglia abissale", "Great Divide", "4"],
	"alliance": ["Un'alleanza improbabile", "Great Divide", "5"],
}

## Mazzi: [id, copie]
static func item_deck() -> Array:
	var out := []
	for k in ITEMS:
		for i in range(int(ITEMS[k].get("copies", 1))):
			out.append("%s#%d" % [k, i + 1])
	return out

static func talent_deck() -> Array:
	var out := []
	for k in TALENTS:
		for i in range(int(TALENTS[k].get("copies", 1))):
			out.append("%s#%d" % [k, i + 1])
	return out

static func action_deck() -> Array:
	return ACTIONS.keys().map(func(k): return k + "#1")

## Dati di una carta da un identificativo d'istanza («fire_trap#2», «assar_hunt», «charge#1»).
static func base_id(cid: String) -> String:
	return cid.get_slice("#", 0)

static func card(cid: String) -> Dictionary:
	var b := base_id(cid)
	if ACTIONS.has(b):
		return ACTIONS[b]
	if ITEMS.has(b):
		return ITEMS[b]
	if TALENTS.has(b):
		return TALENTS[b]
	if ABILITIES.has(b):
		return ABILITIES[b]
	if b.ends_with("_hunt"):
		return HUNT
	if b.ends_with("_track"):
		return TRACK
	return {}

static func kind(cid: String) -> String:
	var b := base_id(cid)
	if ACTIONS.has(b):
		return "action"
	if ITEMS.has(b):
		return "item"
	if TALENTS.has(b):
		return "talent"
	return "ability"

## Chiave dell'immagine nel manifesto.
static func img_key(cid: String) -> String:
	var b := base_id(cid)
	var n := cid.get_slice("#", 1) if cid.contains("#") else ""
	match kind(cid):
		"action":
			return "action_" + b
		"item":
			return "item_%s_%s" % [b, n]
		"talent":
			return "talent_%s_%s" % [b, n]
	return "ability_" + b

static func cname(cid: String) -> String:
	return str(card(cid).get("n", cid))

static func is_hunt(cid: String) -> bool:
	return bool(card(cid).get("hunt", false))

static func is_track(cid: String) -> bool:
	return bool(card(cid).get("track", false))
