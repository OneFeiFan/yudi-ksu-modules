#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p dist

for dir in modules/*; do
	id=$(basename "$dir")
	python3 - "$dir" "dist/$id.zip" <<'PY'
import os
import sys
import zipfile

src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for name in files:
            path = os.path.join(root, name)
            z.write(path, os.path.relpath(path, src))
print(out)
PY
done
