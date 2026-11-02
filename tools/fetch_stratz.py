"""Исходы линии из STRATZ: как герой стоит на линии против каждого героя и вместе с каждым.

Пишет data/stratz.json:
  {"updated": "...", "matches": N,
   "vs":   {"<hero>": {"<enemy>": [матчей, побед на линии, поражений на линии]}},
   "with": {"<hero>": {"<союзник>": [матчей, побед, поражений]}}}

Нужен бесплатный ключ STRATZ (stratz.com → API) в секрете репозитория STRATZ_TOKEN.
Без ключа или при ошибке скрипт ничего не меняет и завершается без ошибки,
чтобы не ломать остальные обновления данных.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(ROOT, "data")
URL = "https://api.stratz.com/graphql"
MIN_MATCHES = 40
BATCH = 8

FIELDS = "heroId1 heroId2 matchCount winCount drawCount lossCount"


def gql(token, query, tries=4):
    body = json.dumps({"query": query}).encode("utf-8")
    for i in range(tries):
        req = urllib.request.Request(
            URL,
            data=body,
            headers={
                "Authorization": "Bearer " + token,
                "Content-Type": "application/json",
                # STRATZ пропускает запросы только с таким User-Agent.
                "User-Agent": "STRATZ_API",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                j = json.loads(r.read().decode("utf-8"))
            if j.get("errors"):
                print("graphql errors:", json.dumps(j["errors"])[:1500], flush=True)
                if not j.get("data"):
                    return None
            return j.get("data")
        except urllib.error.HTTPError as e:
            txt = e.read().decode("utf-8", "replace")[:500]
            print("http", e.code, txt, flush=True)
            if e.code in (401, 403):
                return None
            time.sleep(5 + 10 * i)
        except Exception as e:  # noqa: BLE001
            print("error", e, flush=True)
            time.sleep(5 + 10 * i)
    return None


def hero_ids():
    with open(os.path.join(DATA, "draft.json"), encoding="utf-8") as f:
        return [h["id"] for h in json.load(f)["heroes"]]


def main():
    token = os.environ.get("STRATZ_TOKEN", "").strip()
    if not token:
        print("STRATZ_TOKEN is not set — skipping", flush=True)
        return 0
    ids = hero_ids()
    out = {"vs": {}, "with": {}}
    total = 0
    for start in range(0, len(ids), BATCH):
        part = ids[start:start + BATCH]
        q = ["{ heroStats {"]
        for h in part:
            q.append(f"  v{h}: laneOutcome(heroId: {h}, isWith: false) {{ {FIELDS} }}")
            q.append(f"  w{h}: laneOutcome(heroId: {h}, isWith: true) {{ {FIELDS} }}")
        q.append("} }")
        data = gql(token, "\n".join(q))
        if not data or not data.get("heroStats"):
            if start == 0:
                print("first request failed — nothing written", flush=True)
                return 0
            continue
        hs = data["heroStats"]
        for h in part:
            for kind, key in (("vs", f"v{h}"), ("with", f"w{h}")):
                rows = hs.get(key) or []
                m = {}
                for r in rows:
                    a, b = r.get("heroId1"), r.get("heroId2")
                    other = b if a == h else a
                    n = int(r.get("matchCount") or 0)
                    if other is None or other == h or n < MIN_MATCHES:
                        continue
                    m[str(other)] = [n, int(r.get("winCount") or 0), int(r.get("lossCount") or 0)]
                    if kind == "vs":
                        total += n
                if m:
                    out[kind][str(h)] = m
        print(f"heroes {start + 1}-{start + len(part)} done", flush=True)
        time.sleep(1.5)

    if len(out["vs"]) < len(ids) // 2:
        print(f"too little data ({len(out['vs'])} heroes) — nothing written", flush=True)
        return 0
    out = {"updated": time.strftime("%Y-%m-%d", time.gmtime()), "matches": total // 2, **out}
    path = os.path.join(DATA, "stratz.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    print("written", path, os.path.getsize(path), "bytes,", len(out["vs"]), "heroes", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
