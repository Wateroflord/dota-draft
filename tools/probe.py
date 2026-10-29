"""Разовая проверка форматов внешних API (для разработки)."""
import json
import urllib.request

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "dota-draft-probe"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

def show(title, obj, n=1500):
    s = json.dumps(obj, ensure_ascii=False)
    print(f"===== {title} ({len(s)} chars)\n{s[:n]}\n", flush=True)

O = "https://api.opendota.com/api"
D = "https://www.dota2.com/datafeed"
for title, url, n in [
    ("itemTimings", O + "/scenarios/itemTimings?hero_id=11&item=black_king_bar", 1500),
    ("itemTimings no item", O + "/scenarios/itemTimings?hero_id=11", 800),
    ("player heroes", O + "/players/105248644/heroes", 800),
    ("player wl", O + "/players/105248644/wl?date=7", 300),
    ("itemlist ru", D + "/itemlist?language=russian", 1500),
    ("itemdata bkb ru", D + "/itemdata?language=russian&item_id=116", 4000),
    ("const items bkb", None, 0),
]:
    try:
        if url is None:
            it = get(O + "/constants/items")
            show(title, it.get("black_king_bar"), 2500)
            show("const items neutral sample", it.get("trusty_shovel"), 1500)
            continue
        show(title, get(url), n)
    except Exception as e:
        print("ERR", title, e)
try:
    pm = get(O + "/proMatches")
    m = get(O + f"/matches/{pm[0]['match_id']}")
    p = m["players"][0]
    show("purchase_log", p.get("purchase_log"), 1200)
    show("first_purchase_time", p.get("first_purchase_time"), 800)
    show("purchase_time", p.get("purchase_time"), 600)
    show("lh_t", p.get("lh_t"), 300)
    show("parsed keys", sorted(k for k in p.keys()), 4000)
except Exception as e:
    print("ERR match", e)
try:
    r = get(O + "/players/105248644/matches?limit=3&project=hero_id&project=purchase_time&project=first_purchase_time&project=item_0")
    show("player matches project purchase", r, 1500)
except Exception as e:
    print("ERR pm", e)
