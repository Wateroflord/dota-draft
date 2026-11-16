#!/bin/bash
# Данные героев в assets (встроенная копия на случай, если нет интернета при первом запуске).
set -e
mkdir -p assets
if [ ! -f data/draft.json ]; then echo "::error title=data::нет data/draft.json — запусти workflow «data»"; exit 1; fi
cp data/draft.json assets/draft.json
for f in bench heroinfo patch pro_drafts portraits items; do
  if [ -f data/$f.json ]; then cp data/$f.json assets/$f.json; else echo "{}" > assets/$f.json; fi
done
ls -la assets
