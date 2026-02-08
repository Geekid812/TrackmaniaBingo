#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p ../../db

if command -v uv >/dev/null 2>&1; then
  uv run python3 main.py -o ../../db/mapcache.db
elif command -v python3 >/dev/null 2>&1; then
  python3 main.py -o ../../db/mapcache.db
else
  echo "error: neither 'uv' nor 'python3' was found in PATH" >&2
  exit 1
fi
