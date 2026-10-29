"""Справочные данные для приложения из официального фида Dota 2 и OpenDota.

Пишет:
  data/heroinfo.json — описание героев, умения (названия RU/EN, перезарядка, ульт), таланты;
  data/patch.json    — изменения последних патчей по героям (RU/EN);
  data/pro_drafts.json — драфты свежих профессиональных матчей (для квиза «Кто победил?»);
  data/portraits.json — «отпечатки» картинок героев для распознавания драфта по скриншоту.

Запуск: python3 tools/fetch_info.py
"""
import base64
import io
import json
import os
import re
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_data import get as od_get  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(ROOT, "data")
FEED = "https://www.dota2.com/datafeed"
CDN = "https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/"


def fetch(url, tries=4, raw=False):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "dota-draft-app (github.com/Wateroflord/dota-draft)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                b = r.read()
                return b if raw else json.loads(b.decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            print("fetch error", url, e, flush=True)
            time.sleep(2 + 3 * i)
    return None


def load(name, default):
    try:
        with open(os.path.join(DATA, name), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save(name, obj):
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))


TAG = re.compile(r"<[^>]+>")


def clean(s, limit=260):
    """Убирает HTML и подстановки вида %value%, обрезает длинный текст."""
    if not s:
        return ""
    s = TAG.sub("", s.replace("<br>", " ").replace("<br/>", " "))
    s = re.sub(r"%[a-zA-Z_0-9]+%%?", "…", s)
    s = re.sub(r"\{s:[a-zA-Z_0-9]+\}", "…", s)
    s = re.sub(r"\s+", " ", s).strip()
    if len(s) > limit:
        cut = s[:limit]
        dot = max(cut.rfind(". "), cut.rfind("! "))
        s = cut[: dot + 1] if dot > limit * 0.5 else cut.rstrip() + "…"
    return s


def _fmt(v):
    try:
        f = float(v)
        return str(int(f)) if f == int(f) else f"{f:g}"
    except (TypeError, ValueError):
        return str(v)


def fill(s, vals):
    """Подставляет значения вместо {s:имя} в тексте таланта."""
    if not s:
        return s

    def rep(m):
        name = m.group(1)
        for key in (name, name[6:] if name.startswith("bonus_") else "bonus_" + name):
            if key in vals and vals[key] is not None:
                return _fmt(vals[key])
        if len(vals) == 1:
            return _fmt(next(iter(vals.values())))
        return m.group(0)

    return re.sub(r"\{s:([a-zA-Z_0-9]+)\}", rep, s)


def nums(v):
    out = []
    for x in v or []:
        try:
            f = float(x)
            out.append(int(f) if f == int(f) else round(f, 1))
        except (TypeError, ValueError):
            pass
    return out


def latest_patch():
    pl = fetch(f"{FEED}/patchnoteslist?language=english")
    if not pl or not pl.get("patches"):
        return None, []
    patches = pl["patches"]
    return patches[-1]["patch_number"], patches


# ---------- герои ----------

def hero_info(ids, patch, old):
    """Умения и таланты каждого героя на русском и английском."""
    if old.get("patch") == patch and old.get("v") == 2 and len(old.get("heroes", {})) >= len(ids) - 2:
        print("heroinfo up to date for", patch, flush=True)
        return old
    heroes = {}
    for hid in ids:
        per = {}
        for lang in ("russian", "english"):
            d = fetch(f"{FEED}/herodata?language={lang}&hero_id={hid}")
            time.sleep(0.25)
            try:
                per[lang] = d["result"]["data"]["heroes"][0]
            except (TypeError, KeyError, IndexError):
                per[lang] = None
        ru, en = per["russian"], per["english"]
        if not ru or not en:
            if str(hid) in old.get("heroes", {}):
                heroes[str(hid)] = old["heroes"][str(hid)]
            continue
        en_ab = {a.get("id"): a for a in en.get("abilities", [])}
        abilities = []
        for a in ru.get("abilities", []):
            name = a.get("name", "")
            if not name or name.startswith("special_bonus") or name == "generic_hidden":
                continue
            if a.get("ability_is_granted_by_scepter") or a.get("ability_is_granted_by_shard"):
                granted = "scepter" if a.get("ability_is_granted_by_scepter") else "shard"
            else:
                granted = ""
            e = en_ab.get(a.get("id"), {})
            abilities.append({
                "id": a.get("id"),
                "key": name,
                "ru": a.get("name_loc") or name,
                "en": e.get("name_loc") or name,
                "dru": clean(a.get("desc_loc")),
                "den": clean(e.get("desc_loc")),
                "cd": nums(a.get("cooldowns")),
                "mana": nums(a.get("mana_costs")),
                "ult": a.get("type") == 1,
                "lvl": a.get("max_level") or 0,
                "g": granted,
            })
        talents = []
        src_t = ru.get("talents") or []
        en_t = {t.get("id"): t for t in (en.get("talents") or [])}
        # Значения для подстановки в тексты талантов: свои special_values и бонусы к умениям.
        bonus = {}
        for a in ru.get("abilities", []):
            for sv in a.get("special_values") or []:
                for b in sv.get("bonuses") or []:
                    if b.get("name"):
                        bonus.setdefault(b["name"], {})[sv.get("name")] = b.get("value")
        for i, t in enumerate(src_t):
            e = en_t.get(t.get("id"), {})
            vals = dict(bonus.get(t.get("name"), {}))
            for sv in t.get("special_values") or []:
                vf = sv.get("values_float") or []
                if vf:
                    vals[sv.get("name")] = vf[0]
            talents.append({
                "id": t.get("id"),
                "tier": i // 2,  # 0 — 10 уровень, 1 — 15, 2 — 20, 3 — 25
                "ru": clean(fill(t.get("name_loc"), vals), 120),
                "en": clean(fill(e.get("name_loc"), vals), 120),
            })
        heroes[str(hid)] = {
            "hype_ru": clean(ru.get("hype_loc"), 400),
            "hype_en": clean(en.get("hype_loc"), 400),
            "npe_ru": clean(ru.get("npe_desc_loc"), 120),
            "npe_en": clean(en.get("npe_desc_loc"), 120),
            "range": ru.get("attack_range"),
            "ms": ru.get("movement_speed"),
            "armor": round(float(ru.get("armor") or 0), 1),
            "abilities": abilities,
            "talents": talents,
        }
    print("heroinfo heroes:", len(heroes), flush=True)
    return {"patch": patch, "v": 2, "heroes": heroes}


# ---------- патч ----------

def patch_notes(patches, info, old):
    """Изменения героев в двух последних патчах."""
    names = {}
    for hid, h in info.get("heroes", {}).items():
        for a in h.get("abilities", []):
            names[a["id"]] = (a["ru"], a["en"])
        for t in h.get("talents", []):
            names[t["id"]] = ("Талант", "Talent")
    out = []
    for p in patches[-2:][::-1]:
        ver = p["patch_number"]
        prev = next((x for x in old.get("patches", []) if x.get("version") == ver), None)
        notes = {"version": ver, "ts": p.get("patch_timestamp"), "heroes": {}}
        for lang, key in (("russian", "ru"), ("english", "en")):
            d = fetch(f"{FEED}/patchnotes?version={ver}&language={lang}")
            time.sleep(0.3)
            if not d:
                continue
            for h in d.get("heroes") or []:
                hid = str(h.get("hero_id"))
                lines = []
                for n in h.get("hero_notes") or []:
                    t = clean(n.get("note"), 300)
                    if t:
                        lines.append(t)
                for ab in h.get("abilities") or []:
                    nm = names.get(ab.get("ability_id"), ("", ""))[0 if key == "ru" else 1]
                    for n in ab.get("ability_notes") or []:
                        t = clean(n.get("note"), 300)
                        if t:
                            lines.append(f"{nm}: {t}" if nm else t)
                tl = "Таланты: " if key == "ru" else "Talents: "
                for n in h.get("talent_notes") or []:
                    sub = n.get("ability_notes") if isinstance(n.get("ability_notes"), list) else [n]
                    for x in sub:
                        t = clean(x.get("note"), 300) if isinstance(x, dict) else ""
                        if t:
                            lines.append(tl + t)
                if lines:
                    notes["heroes"].setdefault(hid, {})[key] = lines
        if not notes["heroes"] and prev:
            notes = prev
        out.append(notes)
    return {"patches": out}


# ---------- про-драфты ----------

def pro_drafts(old):
    have = {d["id"]: d for d in old.get("matches", [])}
    pm = od_get("/proMatches") or []
    picked = [m for m in pm if m.get("radiant_name") and m.get("dire_name") and m["match_id"] not in have]
    fresh = []
    for m in picked[:30]:
        d = od_get(f"/matches/{m['match_id']}", tries=2)
        time.sleep(1.1)
        if not isinstance(d, dict) or not isinstance(d.get("players"), list):
            continue
        r = [p["hero_id"] for p in d["players"] if p.get("isRadiant") and p.get("hero_id")]
        dr = [p["hero_id"] for p in d["players"] if not p.get("isRadiant") and p.get("hero_id")]
        if len(r) != 5 or len(dr) != 5:
            continue
        fresh.append({
            "id": m["match_id"], "t": m.get("start_time"), "league": m.get("league_name") or "",
            "rn": m.get("radiant_name"), "dn": m.get("dire_name"), "r": r, "d": dr,
            "w": bool(m.get("radiant_win")), "dur": m.get("duration") or 0,
        })
    allm = sorted(fresh + list(have.values()), key=lambda x: -(x.get("t") or 0))[:150]
    print("pro drafts:", len(allm), "new", len(fresh), flush=True)
    return {"matches": allm}


# ---------- отпечатки картинок ----------

W, H = 16, 9


def portraits(keys, old):
    try:
        from PIL import Image
    except ImportError:
        print("Pillow missing — skip portraits", flush=True)
        return old
    out = dict(old.get("heroes", {}))
    for hid, key in keys.items():
        if str(hid) in out:
            continue
        b = fetch(CDN + key + ".png", raw=True)
        if not b:
            continue
        img = Image.open(io.BytesIO(b)).convert("RGB")
        w, h = img.size
        crops = []
        # Полная картинка и центральные вырезы: в игре портрет может быть обрезан по краям.
        for f in (1.0, 0.85, 0.7):
            cw, ch = int(w * f), int(h * f)
            x0, y0 = (w - cw) // 2, int((h - ch) * 0.3)
            c = img.crop((x0, y0, x0 + cw, y0 + ch)).resize((W, H), Image.BILINEAR)
            crops.append(base64.b64encode(c.tobytes()).decode("ascii"))
        out[str(hid)] = crops
        time.sleep(0.1)
    print("portraits:", len(out), flush=True)
    return {"w": W, "h": H, "heroes": out}


def main():
    draft = load("draft.json", {})
    keys = {h["id"]: h["k"] for h in draft.get("heroes", [])}
    if not keys:
        print("no draft.json — run fetch_data first")
        return
    patch, patches = latest_patch()
    print("latest patch:", patch, flush=True)
    info = load("heroinfo.json", {})
    if patch:
        info = hero_info(sorted(keys), patch, info)
        save("heroinfo.json", info)
        save("patch.json", patch_notes(patches, info, load("patch.json", {})))
    save("pro_drafts.json", pro_drafts(load("pro_drafts.json", {})))
    save("portraits.json", portraits(keys, load("portraits.json", {})))


if __name__ == "__main__":
    main()
