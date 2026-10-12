#!/usr/bin/env python3
"""Genera le miniature 3D di Beast con Meshy (immagine → modello 3D).

Uso:
    export MESHY_API_KEY=la_tua_chiave
    python3 meshy/genera_miniature.py              # tutte quelle che mancano
    python3 meshy/genera_miniature.py bolgin wolf  # solo alcune
    python3 meshy/genera_miniature.py --rifai bolgin  # rigenera anche se esiste già

Prende le immagini di riferimento da meshy/riferimenti/<id>.png e salva il modello in
assets/miniatures/<id>.glb. Il gioco lo usa al posto della sagoma di cartone, senza modifiche al
codice (basta riaprire il progetto in Godot o rifare la build: la action di GitHub lo importa da sola).

Usa solo la libreria standard di Python. Ogni modello costa crediti Meshy: lo script salta quelli
già presenti, a meno di --rifai.
"""
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.error

API = "https://api.meshy.ai/openapi/v1/image-to-3d"
QUI = os.path.dirname(os.path.abspath(__file__))
RIF = os.path.join(QUI, "riferimenti")
OUT = os.path.join(QUI, "..", "assets", "miniatures")

# id → descrizione (aiuta a ricordare chi è; il nome del file è quello che conta)
MINIATURE = {
    # cacciatori
    "assar": "Assar, cacciatore", "grimgeir": "Grimgeir, cacciatore", "helga": "Helga, cacciatrice",
    "iona": "Iona, cacciatrice", "krim": "Krim, cacciatore", "varja": "Varja, cacciatrice",
    "eivind": "Eivind, cacciatore (con la Fylgja)", "valdi": "Valdi, cacciatore", "fara": "Fara, cacciatrice",
    "esmeria_h": "Esmeria cacciatrice (promo)",
    # Bestie
    "bolgin": "Bolgin", "fangrir": "Fangrir", "mara": "Mara", "raaga": "Raaga", "hogbad": "Hogbad",
    "esmeria": "Esmeria (Bestia)", "vacker": "Vacker", "thalduk": "Thal'Duk", "akkeron": "Akkeron",
    "fk": "Il Re Piumato",
    # evocazioni e compagni
    "abomination": "Abominio", "admirer": "Ammiratore", "banshee": "Banshee", "basilisk": "Basilisco",
    "changeling": "Mutaforma", "dreamer": "Sognatore", "polyp": "Polipo", "warhog": "Cinghiale da guerra",
    "wolf": "Lupo", "fylgja": "Fylgja (compagna di Eivind)",
}


def chiama(metodo, url, chiave, corpo=None):
    dati = json.dumps(corpo).encode() if corpo is not None else None
    rq = urllib.request.Request(url, data=dati, method=metodo)
    rq.add_header("Authorization", "Bearer " + chiave)
    if dati is not None:
        rq.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(rq, timeout=120) as r:
        return json.loads(r.read().decode())


def genera(mid, chiave):
    img = os.path.join(RIF, mid + ".png")
    if not os.path.exists(img):
        print(f"  manca l'immagine {img}: salto")
        return False
    with open(img, "rb") as f:
        uri = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    compito = chiama("POST", API, chiave, {
        "image_url": uri,
        "enable_pbr": False,
        "should_remesh": True,
        "target_polycount": 15000,   # leggero: deve girare anche nel browser
        "should_texture": True,
    })
    tid = compito.get("result")
    print(f"  compito {tid}")
    while True:
        time.sleep(10)
        st = chiama("GET", f"{API}/{tid}", chiave)
        stato = st.get("status")
        print(f"  {stato} {st.get('progress', 0)}%")
        if stato == "SUCCEEDED":
            url = st["model_urls"]["glb"]
            os.makedirs(OUT, exist_ok=True)
            dest = os.path.join(OUT, mid + ".glb")
            urllib.request.urlretrieve(url, dest)
            print(f"  salvato {os.path.relpath(dest)}")
            return True
        if stato in ("FAILED", "CANCELED", "EXPIRED"):
            print(f"  non riuscito: {st.get('task_error')}")
            return False


def main():
    chiave = os.environ.get("MESHY_API_KEY", "")
    if not chiave:
        sys.exit("Imposta prima la chiave: export MESHY_API_KEY=...")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rifai = "--rifai" in sys.argv
    ids = args or list(MINIATURE)
    for mid in ids:
        if mid not in MINIATURE:
            print(f"{mid}: id sconosciuto (vedi l'elenco in cima allo script)")
            continue
        if not rifai and os.path.exists(os.path.join(OUT, mid + ".glb")):
            print(f"{mid}: c'è già, salto")
            continue
        print(f"{mid}: {MINIATURE[mid]}")
        try:
            genera(mid, chiave)
        except urllib.error.HTTPError as e:
            print(f"  errore {e.code}: {e.read().decode()[:300]}")


if __name__ == "__main__":
    main()
