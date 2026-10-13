# Beast – adattamento digitale (Godot 4)

Versione digitale per uso personale di **Beast** e dell'espansione **Shattered Isles** di Studio Midhall
(Aron e Elon Midhall, Assar Pettersson). Mappa, carte, sagome e regole © dei rispettivi autori: le immagini
vengono dal modulo Tabletop Simulator «[Official] Beast + Shattered Isles» e non vanno distribuite
pubblicamente.

**Gioca nel browser:** https://tannoiser2.github.io/BEAST/

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Una Bestia contro i cacciatori**, da 2 a 5 giocatori, con le regole delle Isole Frantumate: in 2 un
  giocatore guida la Bestia e l'altro due cacciatori; in 3 e 4 una Bestia contro 2 o 3 cacciatori;
  in 5 (contratto *L'arrivo della Titan*) **due Bestie** contro tre cacciatori. Ogni posto è Umano o IA.
- **Tutte le Bestie** (Bolgin, Fangrir, Mara, Raaga, Hogbad, Esmeria, Vacker con le anime, Thal'Duk,
  Akkeron con l'abisso, il Re Piumato con la rinascita) e **tutti i cacciatori** (Assar, Grimgeir, Helga,
  Iona, Krim, Varja, Eivind con la Fylgja, Valdi con il sangue, Fara, Esmeria cacciatrice promo), con
  abilità, potenziamenti rossi/blu e gialli, Talenti bestiali, Oggetti del cacciatore, trappole, torri di
  guardia, carte Azione con il draft dell'alba, carte Caccia e Tracciamento, evocazioni (Polipo, Lupo,
  Banshee, Basilisco, Mutaforma, Sognatore, Abominio, Ammiratore, Cinghiale da guerra) e le Rovine.
- **Tutte e quattro le mappe e tutti i 10 contratti**, scelti nel menu per mappa:
  - *Isole Frantumate inferiori*: *Reggente delle rovine* (2–3, contatore del Dominio), *Un patto
    dimenticato* (4), *L'arrivo della Titan* (5, due Bestie, coloni da scortare).
  - *Isole Frantumate superiori*: *Segreti di un'era perduta* (2–3), *Liberare l'Abisso* (4, palude
    abissale come habitat preferito, Guglia abissale che protegge i cacciatori), *Un'alleanza improbabile*
    (5, due Bestie, coloni con l'Armatura).
  - *Terre sommerse*: *La Grande Purificazione* (2–3), *Naufragio* (2–3, due Contadini da scortare dal
    relitto a Tiveden).
  - *Distese del Nord*: *Attacco agli insediamenti del Nord* (4) e *Il risveglio degli dèi del Nord* (4),
    con tre Notti.
  Notti con richieste e ricompense del contratto, Notte finale, condizioni di vittoria.
- **Movimento nascosto gestito dal motore**: la Bestia sceglie le carte Movimento (anche false) e le
  direzioni; il gioco mette le tracce, risponde a Ricerca/Perlustrazione/Seguire le tracce, rivela quando
  serve e alla fine mostra il percorso completo della Bestia sulla mappa.
- **Tavolo 3D**: il vero tavolo del modulo TTS (*The Kraken Table*, estratto dagli asset bundle) con la
  plancia appoggiata sopra, luci calde, telecamera libera. Animali e coloni sono i modelli 3D del modulo;
  cacciatori, Bestie ed evocati sono sagome di cartone su basetta (sostituibili da miniature 3D, vedi
  sotto); tracce, ferite, segnalini, torri e trappole sono pedine 3D. Le carte Movimento attive della
  Bestia sono posate sulla colonna stampata della plancia (coperte, per i cacciatori).
- **Carte con lo zoom**: passa il mouse su una carta (della mano o di una scelta) per vederla in grande
  con il testo italiano; il pulsante ARSENALE mostra tutto ciò che è stato giocato e scartato.
- **IA** su tre livelli (Facile / Normale / Difficile), vedi sotto.
- **Schede dei personaggi** (a sinistra): sotto ogni personaggio le sue abilità, con il bordo colorato
  se sono pronte, spente con «usata» se sono già state giocate oggi (tornano in mano di notte), con
  «bloccata» se la Bestia non è nel luogo giusto per usarle (lo vede solo chi sa dov'è); i potenziamenti
  sbloccati sono le voci ★ su fondo oro. Passa il mouse su una voce per il testo, clic per la plancia.
- **Regole in breve** (REGOLE), **diario** (DIARIO), fine partita con il vincitore, il percorso della
  Bestia e la verifica che la Bestia non abbia barato.
- **Replay** (RIVEDI LA PARTITA, a fine partita): tutta la partita di seguito, senza fermarsi ai turni,
  con la Bestia sempre visibile e il suo percorso che si disegna sulla mappa mentre si muove (rosso per la
  prima Bestia, viola per la seconda), i cacciatori, gli evocati, animali e coloni, attacchi, morti e ricerche. Pausa, velocità
  da ½ a ×4, ricomincia; la telecamera resta libera. Funziona anche online: usa gli eventi pubblici e la
  rivelazione finale della Bestia, la stessa usata per la verifica.

## Comandi
- **Telecamera**: tasto destro trascinato = ruota e inclina; rotella o pizzico = zoom; sinistro
  trascinato = sposta; tastiera Q/E ruota, R/F inclina, WASD/frecce sposta, +/− zoom, Home riporta la
  vista iniziale. Ci sono anche i pulsanti della telecamera sul lato dello schermo (per il telefono).
- **Scelte**: i luoghi validi si illuminano sul tavolo (clic sul luogo) e compaiono anche come pulsanti
  nel pannello delle decisioni. Le carte giocabili sono in basso: clic per giocarle.
- **Hotseat** (più persone sullo stesso dispositivo): quando cambia la squadra di turno compare la
  schermata **PASSA IL DISPOSITIVO**. Chi gioca la Bestia non vede mai le mani dei cacciatori e i
  cacciatori non vedono né la posizione della Bestia né le sue carte. Con GUARDA IL TAVOLO si può vedere
  la plancia pubblica senza svelare nulla.

## Gioco online
Dal menu, **GIOCA ONLINE** (anche dalla versione web). Usa lo stesso progetto Firebase degli altri giochi
(`flammerouge-f8669`, Realtime Database, piano gratuito), con le stanze sotto `beast/rooms`.

- **Chi crea la stanza** sceglie prima nel menu contratto, Bestie, cacciatori e livello dell'IA: i
  personaggi su UMANO diventano i posti per gli amici (il primo è il suo). Scrive il nome, preme
  *Crea una stanza* e comunica il codice di 4 lettere. Quando ci sono tutti preme *Inizia online*.
- **Gli amici** scrivono il nome e il codice e premono *Entra*.
- **Le informazioni nascoste restano davvero nascoste.** Non si usa il lockstep con lo stesso seme (con cui
  ogni dispositivo conoscerebbe la posizione della Bestia): il motore e lo stato segreto esistono solo sul
  dispositivo della Bestia (l'*arbitro*). Nel database l'arbitro scrive soltanto gli eventi pubblici
  (`ev/…`, scrivibili una volta sola) e, per ogni persona, una casella privata (`box/<uid>`, leggibile solo
  da lei) con la vista della sua squadra e la decisione che le spetta; le risposte tornano in
  `cmd/<uid>/<n>`, leggibili solo dall'arbitro. La posizione e le carte della Bestia non lasciano mai il
  suo dispositivo.
- **Verifica a fine partita (commit–reveal)**: all'inizio l'arbitro pubblica l'hash di un *sale* segreto
  e, a ogni movimento nascosto, l'hash SHA-256 di «sale | numero dell'evento | Bestia | carte giocate».
  A fine partita pubblica il sale e il registro segreto (`reveal`); ogni dispositivo dei cacciatori
  ricalcola gli hash e controlla che i movimenti fossero legali e coerenti con tutte le tracce, le
  ricerche e le rivelazioni avvenute. L'esito compare nella schermata finale.
- **Se la Bestia la gioca l'IA**, l'arbitro è il dispositivo di chi ha creato la stanza (deve restare
  aperto per tutta la partita).
- **Se cade la linea** si rientra con lo stesso codice e *Entra*. Chi tace per un minuto viene sostituito
  dall'IA finché non rientra. Se esce l'arbitro, al rientro il motore rigioca le decisioni salvate sul
  suo dispositivo (con lo stesso sale) e la partita riprende da dove era.

**Configurazione Firebase.** Le regole sono in `firebase/database.rules.json` e comprendono anche quelle
degli altri giochi (Ultimo chilometro, Snow Tails, STATUS, World Order, Kingsburg, Churchill) più la nuova
sezione `beast`: vanno pubblicate nella console di Firebase (Realtime Database → Regole) al posto delle
precedenti. Senza questo passaggio la creazione della stanza risponde "Permission denied".

**Prove senza Firebase.** `tests/firebase_mock.py` è un finto Firebase locale che applica le stesse
regole (stampa `NEGATO` per ogni lettura o scrittura rifiutata). Con `BS_DB_URL`, `BS_AUTH_URL` e
`BS_REFRESH_URL` che puntano lì, `tests/online_play.gd` fa giocare una partita intera a due istanze
(`BS_ROLE=host` con la Bestia, `guest` con i cacciatori; con `BS_PHASE=drop` e poi `back` l'ospite esce a
metà e rientra). L'ospite controlla a ogni aggiornamento che non arrivino mai la posizione o le carte
della Bestia nascosta e a fine partita esegue la verifica commit–reveal. Ultimo esito: 0 fughe di
segreti, 0 accessi negati, verifica superata, anche con uscita e rientro a metà partita.

## Intelligenza artificiale
- **Cacciatori**: non conoscono mai la posizione della Bestia. Tengono l'insieme delle **posizioni
  possibili** (`scripts/core/belief.gd`), ricavato solo dagli eventi pubblici: carte Movimento giocate,
  tracce, ricerche fallite, rivelazioni, carte svelate. Al livello Difficile si spartiscono le ipotesi
  migliori (ognuno ne copre una diversa), presidiano i coloni minacciati e, nella Titan, scortano i coloni
  verso i luoghi protetti giocando carte Azione rosse.
- **Bestia**: pianifica il turno (attacco qui, movimento e attacco, fuga se rivelata e in pericolo,
  evocazioni e talenti senza rivelarsi). Al livello Difficile **bluffa**: valuta ogni passo con la stessa
  credenza dei cacciatori e preferisce i percorsi che lasciano aperte più ipotesi, usa le carte Movimento
  false per lasciare tracce lontane dalla vera posizione, finisce i coloni già feriti prima che guariscano
  di notte.
- **Taratura** con partite IA contro IA senza grafica (`tests/sim.gd`, 80 partite per casella, Bestie e
  cacciatori a caso). Percentuale di vittorie della Bestia:

| Contratto | Normale vs Normale | Bestia Difficile | Cacciatori Difficili | Difficile vs Difficile |
|---|---|---|---|---|
| Reggente delle rovine (2–3) | 7% | 18% | 7% | 16% |
| Un patto dimenticato (4) | 26% | 32% | 27% | 25% |
| L'arrivo della Titan (5) | 72% | 77% | 31% | 36% |

  La Bestia Difficile vince più della Normale in tutti e tre i contratti (Reggente 7% → 18%, Patto 26% → 32%,
  Titan 72% → 77%). I cacciatori Difficili battono nettamente i Normali nella Titan (72% → 31% di vittorie della
  Bestia) e contro la Bestia Difficile nel Patto (32% → 25%); nel Reggente i cacciatori vincono già quasi
  sempre e la differenza non si vede. Le 960 partite di prova hanno superato tutte la verifica commit–reveal.
  I pesi del livello Difficile sono in `TUNE_BASE` (`scripts/core/ai.gd`) e si possono provare con `BS_TUNE`.

## Carte sostituibili e testi
- Tutte le immagini di carte, schede e contratti passano da `assets/cards/manifest.json` (id carta →
  immagine). Le immagini inglesi del modulo sono in `assets/cards/en/`.
- **Per usare carte in italiano** basta mettere un file con lo stesso nome in `assets/cards/it/`
  (`.webp`, `.png` o `.jpg`): ha la precedenza su quello inglese, senza toccare il codice.
- I testi delle regole delle carte (Azioni, abilità, potenziamenti, Oggetti, Talenti, contratti,
  evocazioni) sono tradotti in italiano in `scripts/data/bs_data.gd` e sono quelli mostrati nel gioco.

### Gioco base e espansione
- **Gioco base** — Bestie: Bolgin (evoca Polipo), Fangrir (Lupo), Mara (Banshee), Raaga (Basilisco), Hogbad (Cinghiale da guerra), Esmeria (Mutaforma). Cacciatori: Assar, Grimgeir, Helga, Iona, Krim, Varja.
- **Isole Frantumate (Shattered Isles)** — Bestie: Vacker (Ammiratore), Thalduk (Yagi), Akkeron (Abominio), Re Piumato (Sognatore). Cacciatori: Eivind, Valdi, Fara, Esmeria capitana.
- Nel menu ogni personaggio ha l'etichetta «GIOCO BASE» o «ISOLE FRANTUMATE»; se esiste la miniatura 3D, al posto dell'immagine compare il modello che ruota.

## Miniature 3D (Meshy)
Animali e coloni hanno già i loro modelli 3D. Cacciatori, Bestie ed evocati nel gioco da tavolo sono sagome
di cartone: per ora nel gioco sono sagome su basetta, ma **ognuna si sostituisce con una miniatura 3D
mettendo `assets/miniatures/<id>.glb`** (il gioco la scala e la appoggia da solo, nessuna modifica al
codice).

Per generarle con Meshy (immagine → 3D):
```
export MESHY_API_KEY=la_tua_chiave
python3 meshy/genera_miniature.py            # tutte quelle che mancano
python3 meshy/genera_miniature.py bolgin wolf # solo alcune
```
Le immagini di riferimento sono in `meshy/riferimenti/` (le sagome del modulo, con lo sfondo trasparente).
Dopo, riapri il progetto in Godot (o fai il push: la action di GitHub importa i modelli da sola).

**Miniature già fatte (31)**, generate con Meshy dalle illustrazioni del modulo:
- Cacciatori: assar, grimgeir, helga, iona, krim, varja (gioco base); eivind, valdi, fara, esmeria_h (Isole Frantumate)
- Bestie: bolgin, fangrir, mara, raaga, hogbad, esmeria (gioco base); vacker, thalduk, akkeron, fk (Isole Frantumate)
- Evocati e compagni: banshee, basilisk, polyp, warhog, wolf, changeling (gioco base); abomination, admirer, dreamer, fylgja (Isole Frantumate)
- Torre di guardia: watchtower

Nel menu di scelta i personaggi con la miniatura compaiono in 3D al posto dell'illustrazione.

**Miniature da fare (1):** lo Yagi, l'evocato di Thalduk (nel modulo non c'è la sua sagoma: si può fare dall'illustrazione della carta).

## Cosa manca
- La miniatura 3D dello Yagi (vedi sopra).
- Le carte in italiano (si aggiungono in `assets/cards/it/`).

## Struttura
```
scripts/data/bs_data.gd      mappa (54 luoghi con coordinate, habitat, sentieri nascosti), Bestie, cacciatori,
                             carte, oggetti, talenti, evocazioni, contratti (testi in italiano)
scripts/core/engine*.gd      motore delle regole a strati: stato → regole → effetti delle carte → partita
                             (nessuna dipendenza dalla UI; view_for(squadra) dà la vista senza i segreti)
scripts/core/belief.gd       posizioni possibili della Bestia ricavate dagli eventi pubblici
scripts/core/ai.gd           IA
scripts/core/verify.gd       verifica commit–reveal di fine partita
scripts/net/                 Firebase (REST), arbitro (online_server.gd) e dispositivo senza motore (online_client.gd)
scripts/ui/                  menu, tavolo 3D, vista di gioco, regole in breve
tests/sim.gd                 godot --headless -s res://tests/sim.gd -- 40 brave 2 1   (partite, contratto, liv. Bestia, liv. cacciatori)
tests/shot.gd                xvfb-run godot -s res://tests/shot.gd -- game regent      (screenshot, partita intera dall'interfaccia)
tests/online_play.gd         prova online con tests/firebase_mock.py
tests/web_test.js            prova della versione web con Playwright (nessun errore in console)
meshy/                       script e immagini di riferimento per le miniature
assets/                      plancia, carte, sagome, segnalini, modelli 3D e tavolo (dal modulo TTS), font OFL
```
Versione web: renderer Compatibility (WebGL2), texture compresse (Basis Universal per il 3D, WebP con
perdita per le carte), pacchetto di circa 45 MB.

## Scelte da verificare
- **Movimento nascosto**: invece della scheda segreta su carta, la Bestia sceglie carte e direzioni e il
  motore tiene la posizione. Le carte Movimento false lasciano tracce come quelle vere; il controllo delle
  tracce («check») avviene dopo ogni movimento e dopo ogni movimento dei cacciatori.
- **Online, la mano dei cacciatori è nota all'arbitro**: il motore gira sul dispositivo della Bestia, che
  quindi conosce anche le carte in mano ai cacciatori (l'interfaccia non le mostra, ma un giocatore
  smaliziato potrebbe leggerle). Le informazioni della Bestia invece non escono mai dal suo dispositivo.
  Nascondere entrambe le parti richiederebbe un server di terze parti.
- **Contratti**: ricompense e richieste delle Notti trascritte dalle carte contratto del modulo; dove la
  carta è ambigua: «controllare 2 Rovine» si valuta nel momento del danno; i segnalini della Titan passano
  sul contratto all'inizio del turno di qualsiasi cacciatore; la Notte finale arriva dopo l'ultima Notte del contratto (la seconda, o la terza
  nelle Distese del Nord).
- **Nuove mappe**: luoghi, habitat, sentieri con le direzioni, animali e coloni ricavati dalle immagini delle
  mappe. Icone delle carte contratto: la spada è un Potere antico, la mano artigliata è Evoca, la maschera
  grigia è l'Armatura dei coloni. Le ricompense dei cacciatori che valgono per la squadra (torri, Contadino
  che diventa Nobile) si applicano una volta sola per Notte. In *Liberare l'Abisso* la palude abissale vale
  come habitat preferito solo per le carte che si giocano sull'habitat preferito.
- **Naufragio**: nel contratto i coloni da scortare sono Contadini e l'obiettivo è Tiveden; «un colono di
  Vildmark» e simili si riferiscono a dove si trova il colono quando muore.
- **Reggente delle rovine**: con le carte del modulo la Bestia vince di rado contro i cacciatori dell'IA
  (il Dominio rosso arriva in media a 6 su 12 in tre giorni). Le regole sono state controllate più volte:
  se nel gioco vero la Bestia ha più spazio, il punto da guardare è il contatore del Dominio.
- **Draft dell'alba**: ogni partecipante riceve 6/5/4/4 carte Azione con 2/3/4/5 giocatori; in 4 una
  carta viene messa da parte prima di distribuire.
- **Evocati**: 1 salute in più nel Reggente; al massimo gli evocati indicati sulla scheda della Bestia.
- **Re Piumato**: alla prima morte rinasce con 4 salute (sagoma «rinato»); Vacker visibile mentre raccoglie
  anime.
- **Nebbia improvvisa** e le altre reazioni si offrono solo quando si possono pagare, per non
  interrompere il gioco a vuoto.
- **IA**: le schede d'aiuto per l'IA del gioco (se esistono) non sono nel modulo; l'IA usa valutazioni proprie.
- **Tavolo**: le misure del tavolo TTS sono state scalate a occhio sotto la plancia.
