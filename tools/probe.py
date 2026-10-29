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
try:
    ab = get(O + "/constants/abilities")
    show("ability chrono", ab.get("faceless_void_chronosphere"))
    show("ability bb", {k: ab.get(k) for k in ["special_bonus_unique_faceless_void_2"]})
    ha = get(O + "/constants/hero_abilities")
    show("hero_abilities void", ha.get("npc_dota_hero_faceless_void"))
    show("hero_abilities invoker", ha.get("npc_dota_hero_invoker"), 800)
    ids = get(O + "/constants/ability_ids")
    show("ability_ids", dict(list(ids.items())[:5]))
except Exception as e:
    print("ERR const", e)
try:
    pm = get(O + "/proMatches")
    show("proMatches", pm[:2])
    m = get(O + f"/matches/{pm[0]['match_id']}")
    show("pro match keys", sorted(m.keys()), 3000)
    p = m["players"][0]
    show("pro player keys", sorted(p.keys()), 4000)
    show("pro player sample", {k: p.get(k) for k in ["hero_id", "ability_upgrades_arr", "benchmarks", "lane_role", "rank_tier", "gold_t", "lh_t", "lane_efficiency_pct", "item_neutral", "item_neutral2", "leaver_status", "abandons", "net_worth", "hero_healing", "stuns", "obs_placed", "sen_placed", "camps_stacked", "teamfight_participation", "is_roaming", "lane", "deaths_log"]}, 4000)
    show("radiant_gold_adv", m.get("radiant_gold_adv"), 600)
except Exception as e:
    print("ERR pro", e)
try:
    pub = get(O + "/publicMatches")
    mid = pub[0]["match_id"]
    show("public sample", pub[0])
    m = get(O + f"/matches/{mid}")
    show("public match keys", sorted(m.keys()), 3000)
    p = m["players"][0]
    show("public player keys", sorted(p.keys()), 4000)
    show("public player sample", {k: p.get(k) for k in ["hero_id", "ability_upgrades_arr", "benchmarks", "lane_role", "rank_tier", "leaver_status", "net_worth", "hero_healing", "item_neutral", "personaname", "account_id"]}, 3000)
except Exception as e:
    print("ERR public", e)
D = "https://www.dota2.com/datafeed"
try:
    pl = get(D + "/patchnoteslist?language=russian")
    show("patchnoteslist", pl, 1200)
    last = pl["patches"][-1]["patch_number"] if "patches" in pl else None
    pn = get(D + f"/patchnotes?version={last}&language=russian")
    show("patchnotes keys", list(pn.keys()))
    show("patchnotes hero sample", (pn.get("heroes") or [None])[:2], 3000)
    show("patchnotes general", pn.get("general_notes"), 800)
    show("patchnotes items", (pn.get("items") or [None])[:1], 800)
except Exception as e:
    print("ERR patch", e)
try:
    hl = get(D + "/herolist?language=russian")
    show("herolist", hl, 800)
    hd = get(D + "/herodata?language=russian&hero_id=41")
    show("herodata void", hd, 4000)
except Exception as e:
    print("ERR herodata", e)
