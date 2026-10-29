"""Собирает статистику героев Dota 2 из открытого API OpenDota и пишет data/draft.json.

Что считается:
  * винрейт и популярность героя по группам рангов (из /heroStats);
  * «преимущество» героя против каждого другого (counter) и «синергия» пар в одной команде —
    по выборке свежих публичных рейтинговых матчей (/publicMatches).
Счётчики копятся между запусками в data/agg.json.gz и «стареют» (DECAY), так что учитываются
примерно последние 2–3 недели.

Запуск: python3 tools/fetch_data.py [--calls N]
"""
import gzip
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

API = "https://api.opendota.com/api"
KEY = os.environ.get("OPENDOTA_KEY", "")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AGG = os.path.join(ROOT, "data", "agg.json.gz")
OUT = os.path.join(ROOT, "data", "draft.json")

DECAY = 0.93  # каждый запуск (раз в день) старые матчи весят меньше
SHRINK = 80.0  # сколько игр нужно, чтобы доверять паре наполовину
MIN_DURATION = 15 * 60

# Группы рангов: 1 Рекрут, 2 Страж, 3 Рыцарь, 4 Герой, 5 Легенда, 6 Властелин, 7 Божество, 8 Титан.
# (OpenDota сейчас отдаёт Титанов вместе с Божеством, поэтому верхняя группа — 6–8.)
GROUPS = [list(range(1, 9)), [1, 2], [3, 4, 5], [6, 7, 8]]

# Типичные позиции (1 керри, 2 мид, 3 хард, 4 полусаппорт, 5 саппорт). Для новых героев — по ролям.
POSITIONS = {
    "antimage": [1], "axe": [3], "bane": [5, 4], "bloodseeker": [1, 3], "crystal_maiden": [5, 4],
    "drow_ranger": [1], "earthshaker": [4, 5, 3], "juggernaut": [1], "mirana": [4, 2], "morphling": [1, 2],
    "nevermore": [2, 1], "phantom_lancer": [1], "puck": [2], "pudge": [4, 3, 2], "razor": [3, 1, 2],
    "sand_king": [3, 4], "storm_spirit": [2], "sven": [1], "tiny": [2, 4, 1], "vengefulspirit": [5, 4],
    "windrunner": [2, 4, 3], "zuus": [2, 4, 5], "kunkka": [2, 3], "lina": [2, 1, 4], "lion": [5, 4],
    "shadow_shaman": [5, 4], "slardar": [3], "tidehunter": [3], "witch_doctor": [5], "lich": [5],
    "riki": [1, 4], "enigma": [3, 4], "tinker": [2], "sniper": [2, 1], "necrolyte": [3, 2], "warlock": [5],
    "beastmaster": [3], "queenofpain": [2], "venomancer": [4, 3, 5], "faceless_void": [1],
    "skeleton_king": [1], "death_prophet": [2, 3], "phantom_assassin": [1], "pugna": [2, 4, 5],
    "templar_assassin": [2, 1], "viper": [2, 3], "luna": [1], "dragon_knight": [2, 3, 1], "dazzle": [5, 4],
    "rattletrap": [4, 3], "leshrac": [2, 3], "furion": [4, 3, 1], "life_stealer": [1], "dark_seer": [3],
    "clinkz": [1, 4], "omniknight": [5, 3], "enchantress": [4, 5], "huskar": [2, 1], "night_stalker": [3],
    "broodmother": [2, 3], "bounty_hunter": [4], "weaver": [1, 4], "jakiro": [5, 4], "batrider": [3, 2, 4],
    "chen": [5], "spectre": [1], "ancient_apparition": [5], "doom_bringer": [3], "ursa": [1],
    "spirit_breaker": [4, 3], "gyrocopter": [1, 4], "alchemist": [1, 2], "invoker": [2], "silencer": [5, 4],
    "obsidian_destroyer": [2, 1], "lycan": [1, 3], "brewmaster": [3], "shadow_demon": [4, 5],
    "lone_druid": [1, 2], "chaos_knight": [1, 3], "meepo": [2, 1], "treant": [5, 4], "ogre_magi": [5, 4, 3],
    "undying": [5], "rubick": [4], "disruptor": [5], "nyx_assassin": [4], "naga_siren": [1, 5],
    "keeper_of_the_light": [4, 2, 5], "wisp": [5, 4], "visage": [2, 3], "slark": [1], "medusa": [1, 2],
    "troll_warlord": [1], "centaur": [3], "magnataur": [3, 2, 4], "shredder": [3, 2], "bristleback": [3, 1],
    "tusk": [4], "skywrath_mage": [4, 2], "abaddon": [3, 5, 1], "elder_titan": [4, 5],
    "legion_commander": [3], "techies": [4, 5], "ember_spirit": [2], "earth_spirit": [4],
    "abyssal_underlord": [3], "terrorblade": [1], "phoenix": [4], "oracle": [5], "winter_wyvern": [5, 4],
    "arc_warden": [2, 1], "monkey_king": [1, 2, 4], "dark_willow": [4, 5], "pangolier": [3, 2, 4],
    "grimstroke": [4, 5], "hoodwink": [4], "void_spirit": [2], "snapfire": [4, 5], "mars": [3],
    "dawnbreaker": [3, 5], "marci": [4, 1, 3], "primal_beast": [3, 2], "muerta": [1, 2], "kez": [1, 2],
    "ringmaster": [4, 5], "largo": [5, 4],
}


def positions_for(short, roles):
    if short in POSITIONS:
        return POSITIONS[short]
    p = []
    if "Carry" in roles:
        p.append(1)
    if "Nuker" in roles and "Carry" not in roles and "Support" not in roles:
        p.append(2)
    if "Initiator" in roles or "Durable" in roles:
        p.append(3)
    if "Support" in roles:
        p += [4, 5]
    return p or [3]


def get(path, tries=6):
    url = API + path
    if KEY:
        url += ("&" if "?" in url else "?") + "api_key=" + KEY
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "dota-draft-app/1.0 (+github.com/Wateroflord/dota-draft)"})
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            print("HTTP", e.code, path, flush=True)
            if e.code == 429:
                time.sleep(30 * (attempt + 1))
                continue
            if e.code >= 500:
                time.sleep(5 * (attempt + 1))
                continue
            return None
        except Exception as e:  # сеть, таймаут
            print("ERR", e, path, flush=True)
            time.sleep(5 * (attempt + 1))
    return None


def team(v):
    if isinstance(v, list):
        return [int(x) for x in v]
    if isinstance(v, str) and v:
        return [int(x) for x in v.split(",") if x.strip()]
    return []


def load_agg():
    try:
        with gzip.open(AGG, "rt", encoding="utf-8") as f:
            a = json.load(f)
        if a.get("version") == 1:
            return a
    except (OSError, ValueError):
        pass
    return {"version": 1, "last_id": 0, "matches": 0.0, "hero": {}, "ally": {}, "vs": {}}


def decay(a):
    a["matches"] *= DECAY
    for key in ("hero", "ally", "vs"):
        d = a[key]
        for k in list(d.keys()):
            g, w = d[k]
            g, w = g * DECAY, w * DECAY
            if g < 0.5:
                del d[k]
            else:
                d[k] = [round(g, 3), round(w, 3)]


def add(d, k, win):
    g, w = d.get(k, [0.0, 0.0])
    d[k] = [g + 1, w + (1 if win else 0)]


def crawl(a, max_calls, deadline):
    newest_seen = a["last_id"]
    stop_at = a["last_id"]
    less_than = None
    used = 0
    taken = 0
    while used < max_calls and time.time() < deadline:
        path = "/publicMatches" + (f"?less_than_match_id={less_than}" if less_than else "")
        page = get(path)
        used += 1
        if not page:
            break
        min_id = None
        reached_old = False
        for m in page:
            mid = int(m.get("match_id", 0))
            if mid <= 0:
                continue
            min_id = mid if min_id is None else min(min_id, mid)
            newest_seen = max(newest_seen, mid)
            if mid <= stop_at:
                reached_old = True
                continue
            if m.get("lobby_type") not in (7, None) or m.get("game_mode") not in (22, 2, 3, None):
                continue
            if (m.get("duration") or 0) < MIN_DURATION:
                continue
            r, d = team(m.get("radiant_team")), team(m.get("dire_team"))
            if len(r) != 5 or len(d) != 5:
                continue
            rw = bool(m.get("radiant_win"))
            taken += 1
            a["matches"] += 1
            for side, won in ((r, rw), (d, not rw)):
                for h in side:
                    add(a["hero"], str(h), won)
                for i in range(5):
                    for j in range(i + 1, 5):
                        x, y = sorted((side[i], side[j]))
                        add(a["ally"], f"{x}-{y}", won)
            for x in r:
                for y in d:
                    lo, hi = sorted((x, y))
                    # победа считается для меньшего id
                    lo_won = rw if lo == x else not rw
                    add(a["vs"], f"{lo}-{hi}", lo_won)
        if min_id is None or reached_old:
            break
        less_than = min_id
        time.sleep(1.1 if not KEY else 0.15)
        if used % 50 == 0:
            print(f"calls {used}, matches taken {taken}", flush=True)
    a["last_id"] = newest_seen
    print(f"crawl done: calls {used}, new matches {taken}, total weight {a['matches']:.0f}", flush=True)
    return taken


def matchups_fallback(a, heroes):
    """Если публичные матчи недоступны — берём противостояния из /heroes/{id}/matchups."""
    for h in heroes:
        rows = get(f"/heroes/{h['id']}/matchups") or []
        for r in rows:
            o = int(r.get("hero_id", 0))
            g, w = float(r.get("games_played", 0)), float(r.get("wins", 0))
            if o <= 0 or g <= 0:
                continue
            lo, hi = sorted((h["id"], o))
            if lo != h["id"]:
                continue  # каждую пару пишем один раз, со стороны меньшего id
            a["vs"][f"{lo}-{hi}"] = [g, w]
        time.sleep(1.1 if not KEY else 0.15)


def main():
    max_calls = 1000
    if "--calls" in sys.argv:
        max_calls = int(sys.argv[sys.argv.index("--calls") + 1])
    minutes = 30.0
    if "--minutes" in sys.argv:
        minutes = float(sys.argv[sys.argv.index("--minutes") + 1])
    deadline = time.time() + minutes * 60
    stats = get("/heroStats")
    if not stats:
        print("heroStats unavailable", flush=True)
        sys.exit(1 if not os.path.exists(OUT) else 0)
    stats.sort(key=lambda h: h["id"])

    a = load_agg()
    decay(a)
    taken = crawl(a, max_calls, deadline)
    if a["matches"] < 3000 and taken < 3000:
        print("few public matches — using matchups fallback", flush=True)
        matchups_fallback(a, stats)

    ids = [h["id"] for h in stats]
    index = {hid: i for i, hid in enumerate(ids)}

    # Базовый винрейт из выборки (для нормировки пар).
    base = {}
    for hid in ids:
        g, w = a["hero"].get(str(hid), [0, 0])
        if g >= 20:
            base[hid] = w / g
        else:
            p = sum(h.get(f"{b}_pick", 0) or 0 for b in range(1, 9) for h in stats if h["id"] == hid)
            wn = sum(h.get(f"{b}_win", 0) or 0 for b in range(1, 9) for h in stats if h["id"] == hid)
            base[hid] = wn / p if p else 0.5

    n = len(ids)
    adv = [[0] * n for _ in range(n)]
    syn = [[0] * n for _ in range(n)]
    for k, (g, w) in a["vs"].items():
        x, y = (int(v) for v in k.split("-"))
        if x not in index or y not in index or g <= 0:
            continue
        p = w / g
        exp = 0.5 + (base[x] - 0.5) - (base[y] - 0.5)
        v = (p - exp) * g / (g + SHRINK)
        adv[index[x]][index[y]] = round(v * 10000)
        adv[index[y]][index[x]] = -round(v * 10000)
    for k, (g, w) in a["ally"].items():
        x, y = (int(v) for v in k.split("-"))
        if x not in index or y not in index or g <= 0:
            continue
        p = w / g
        exp = 0.5 + (base[x] - 0.5) + (base[y] - 0.5)
        v = round((p - exp) * g / (g + SHRINK) * 10000)
        syn[index[x]][index[y]] = v
        syn[index[y]][index[x]] = v

    heroes = []
    for h in stats:
        short = h["name"].replace("npc_dota_hero_", "")
        wr, pr = [], []
        for grp in GROUPS:
            picks = sum((h.get(f"{b}_pick") or 0) for b in grp)
            wins = sum((h.get(f"{b}_win") or 0) for b in grp)
            total = sum(sum((x.get(f"{b}_pick") or 0) for b in grp) for x in stats) / 10 or 1
            if picks <= 0:  # нет данных по группе — берём общие
                picks = sum((h.get(f"{b}_pick") or 0) for b in range(1, 9))
                wins = sum((h.get(f"{b}_win") or 0) for b in range(1, 9))
                total = sum(sum((x.get(f"{b}_pick") or 0) for b in range(1, 9)) for x in stats) / 10 or 1
            wr.append(round(wins / picks, 4) if picks else 0.5)
            pr.append(round(picks / total, 4))
        heroes.append({
            "id": h["id"],
            "n": h.get("localized_name") or short,
            "k": short,
            "a": h.get("primary_attr", "all"),
            "r": h.get("roles", []),
            "p": positions_for(short, h.get("roles", [])),
            "wr": wr,
            "pr": pr,
        })

    out = {
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "matches": round(a["matches"]),
        "source": "OpenDota API",
        "heroes": heroes,
        "adv": adv,
        "syn": syn,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    with gzip.open(AGG, "wt", encoding="utf-8") as f:
        json.dump(a, f, separators=(",", ":"))
    print(f"written: {n} heroes, {round(a['matches'])} matches", flush=True)


if __name__ == "__main__":
    main()
