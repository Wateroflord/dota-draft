"""Средние показатели игроков на героях по группам рангов + популярные нейтральные предметы.

Берёт свежие публичные рейтинговые матчи (/publicMatches), равномерно по рангам скачивает их детали
(/matches/{id}) и копит суммы GPM, XPM, убийств, смертей, помощи, добиваний, урона по героям и вышкам.
Счётчики «стареют» (DECAY), так что учитываются примерно последние 2–3 недели.

Запуск: python3 tools/fetch_bench.py [--minutes N]
"""
import gzip
import json
import os
import random
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_data import get, team, KEY  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AGG = os.path.join(ROOT, "data", "bench_agg.json.gz")
OUT = os.path.join(ROOT, "data", "bench.json")
DECAY = 0.93
MIN_DURATION = 15 * 60

# Группа рангов матча по среднему rank_tier: 1 — Рекрут–Страж, 2 — Рыцарь–Легенда, 3 — Властелин–Титан.
def group_of(avg_rank_tier):
    if not avg_rank_tier:
        return None
    t = int(avg_rank_tier) // 10
    if t <= 2:
        return 1
    if t <= 5:
        return 2
    return 3


# Поля суммы: игры, победы, gpm, xpm, k, d, a, добивания за 10 минут, урон героям/мин, урон вышкам
FIELDS = ["n", "w", "gpm", "xpm", "k", "d", "a", "lh10", "hdm", "td"]


def load():
    try:
        with gzip.open(AGG, "rt", encoding="utf-8") as f:
            a = json.load(f)
        if a.get("version") == 1:
            return a
    except (OSError, ValueError):
        pass
    return {"version": 1, "seen": [], "stats": {}, "neutral": {}, "skills": {}, "talents": {}}


def decay(a):
    for key in ("stats", "neutral", "skills", "talents"):
        a.setdefault(key, {})
        for k in list(a[key].keys()):
            row = [round(v * DECAY, 3) for v in a[key][k]]
            if row[0] < 0.3:
                del a[key][k]
            else:
                a[key][k] = row


def add_stats(a, hero, grp, p, dur, won):
    mins = max(dur / 60, 1)
    vals = [
        1,
        1 if won else 0,
        p.get("gold_per_min") or 0,
        p.get("xp_per_min") or 0,
        p.get("kills") or 0,
        p.get("deaths") or 0,
        p.get("assists") or 0,
        (p.get("last_hits") or 0) / mins * 10,
        (p.get("hero_damage") or 0) / mins,
        p.get("tower_damage") or 0,
    ]
    for g in (0, grp):
        k = f"{hero}:{g}"
        row = a["stats"].get(k, [0.0] * len(FIELDS))
        a["stats"][k] = [x + v for x, v in zip(row, vals)]


def main():
    minutes = 28.0
    if "--minutes" in sys.argv:
        minutes = float(sys.argv[sys.argv.index("--minutes") + 1])
    deadline = time.time() + minutes * 60
    a = load()
    decay(a)
    seen = set(a.get("seen", []))

    # 1) Список кандидатов из свежих публичных матчей, по группам рангов.
    buckets = {1: [], 2: [], 3: []}
    less_than = None
    for _ in range(25):
        page = get("/publicMatches" + (f"?less_than_match_id={less_than}" if less_than else ""))
        if not page:
            break
        ids = []
        for m in page:
            mid = int(m.get("match_id", 0))
            ids.append(mid)
            if mid in seen or (m.get("duration") or 0) < MIN_DURATION:
                continue
            if m.get("lobby_type") not in (7, None):
                continue
            g = group_of(m.get("avg_rank_tier"))
            if g and len(team(m.get("radiant_team"))) == 5:
                buckets[g].append(mid)
        if not ids:
            break
        less_than = min(ids)
        time.sleep(1.1 if not KEY else 0.15)
    # Добираем каждую группу рангов отдельными запросами (низких рангов в общей ленте мало).
    for g, q in ((1, "max_rank=25"), (2, "min_rank=30&max_rank=55"), (3, "min_rank=60")):
        lt = None
        for _ in range(6):
            page = get(f"/publicMatches?{q}" + (f"&less_than_match_id={lt}" if lt else ""))
            if not page:
                break
            for m in page:
                mid = int(m.get("match_id", 0))
                if mid not in seen and (m.get("duration") or 0) >= MIN_DURATION and m.get("lobby_type") in (7, None):
                    buckets[g].append(mid)
            lt = min(int(m.get("match_id", 0)) for m in page)
            time.sleep(1.1 if not KEY else 0.15)
    for g in buckets:
        buckets[g] = list(dict.fromkeys(buckets[g]))
    for b in buckets.values():
        random.shuffle(b)
    print("candidates:", {k: len(v) for k, v in buckets.items()}, flush=True)

    # Названия умений по id (чтобы отличать таланты от обычных умений).
    ability_ids = get("/constants/ability_ids") or {}
    talent_ids = {int(k) for k, v in ability_ids.items() if str(v).startswith("special_bonus") and str(v) != "special_bonus_attributes"}
    skip_ids = {int(k) for k, v in ability_ids.items() if str(v).startswith("special_bonus")}

    # 2) Детали матчей по очереди из разных групп, пока есть время.
    done = 0
    order = [1, 2, 3]
    while time.time() < deadline and any(buckets.values()):
        for g in order:
            if not buckets[g] or time.time() >= deadline:
                continue
            mid = buckets[g].pop()
            m = get(f"/matches/{mid}", tries=2)
            time.sleep(1.1 if not KEY else 0.15)
            seen.add(mid)
            if not isinstance(m, dict) or not isinstance(m.get("players"), list):
                continue
            dur = m.get("duration") or 0
            if dur < MIN_DURATION:
                continue
            rw = bool(m.get("radiant_win"))
            for p in m["players"]:
                hid = p.get("hero_id")
                if not hid:
                    continue
                rad = p.get("isRadiant") if isinstance(p.get("isRadiant"), bool) else (p.get("player_slot", 0) < 128)
                won = rad == rw
                add_stats(a, hid, g, p, dur, won)
                ups = p.get("ability_upgrades_arr")
                if isinstance(ups, list) and ups:
                    lvl = 0
                    for aid in ups:
                        if not isinstance(aid, int):
                            continue
                        if aid in talent_ids:
                            k = f"{hid}:{aid}"
                            row = a["talents"].get(k, [0.0, 0.0])
                            a["talents"][k] = [row[0] + 1, row[1] + (1 if won else 0)]
                            continue
                        if aid in skip_ids or lvl >= 16:
                            continue
                        k = f"{hid}:{lvl}:{aid}"
                        row = a["skills"].get(k, [0.0, 0.0])
                        a["skills"][k] = [row[0] + 1, row[1] + (1 if won else 0)]
                        lvl += 1
                nid = p.get("item_neutral")
                if nid:
                    k = f"{hid}:{nid}"
                    row = a["neutral"].get(k, [0.0, 0.0])
                    a["neutral"][k] = [row[0] + 1, row[1] + (1 if won else 0)]
            done += 1
            if done % 50 == 0:
                print("matches:", done, flush=True)
    print("details fetched:", done, flush=True)
    a["seen"] = list(seen)[-20000:]

    # 3) Названия нейтральных предметов.
    consts = get("/constants/items") or {}
    items = {}
    for key, it in consts.items():
        if isinstance(it, dict) and it.get("id") is not None and it.get("tier"):
            items[int(it["id"])] = [key, it.get("dname") or key, int(it.get("tier") or 0)]

    heroes = {}
    for k, row in a["stats"].items():
        hid, g = k.split(":")
        n = row[0]
        if n < 1:
            continue
        avg = [round(row[0], 1), round(row[1] / n, 4)] + [round(v / n, 2) for v in row[2:]]
        heroes.setdefault(hid, {})[g] = avg
    neutral = {}
    for k, (n, w) in a["neutral"].items():
        hid, nid = k.split(":")
        if int(nid) not in items:
            continue
        neutral.setdefault(hid, []).append([int(nid), round(n, 1), round(w / n, 4) if n else 0])
    for hid in neutral:
        neutral[hid] = sorted(neutral[hid], key=lambda r: -r[1])[:6]
    used = {r[0] for rows in neutral.values() for r in rows}

    # Порядок прокачки: на каждом шаге — умение, которое чаще берут победители.
    by_step = {}
    for k, (n, w) in a["skills"].items():
        hid, step, aid = k.split(":")
        by_step.setdefault(hid, {}).setdefault(int(step), []).append((w, n, int(aid)))
    skills = {}
    for hid, steps in by_step.items():
        seq = []
        for step in range(16):
            opts = steps.get(step)
            if not opts:
                break
            tot_w = sum(o[0] for o in opts) or 1
            best = max(opts, key=lambda o: (o[0], o[1]))
            seq.append([best[2], round(best[0] / tot_w, 2)])
        if len(seq) >= 6:
            skills[hid] = seq
    talents = {}
    for k, (n, w) in a["talents"].items():
        hid, aid = k.split(":")
        talents.setdefault(hid, {})[aid] = [round(n, 1), round(w / n, 4) if n else 0]

    out = {
        "skills": skills,
        "talents": talents,
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "fields": FIELDS,
        "heroes": heroes,
        "neutral": neutral,
        "items": {str(i): items[i] for i in used},
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    with gzip.open(AGG, "wt", encoding="utf-8") as f:
        json.dump(a, f, separators=(",", ":"))
    print("written bench:", len(heroes), "heroes", flush=True)


if __name__ == "__main__":
    main()
