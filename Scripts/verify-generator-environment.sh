#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PETREL_PYTHON="$ROOT/.build/release-generator-venv/bin/python"
LOCK="$ROOT/generator/requirements-release.lock"
[[ -x $PETREL_PYTHON ]] || {
  echo "locked release-generator Python is missing: $PETREL_PYTHON" >&2
  exit 1
}
[[ -f $LOCK ]] || {
  echo "release generator lock is missing: $LOCK" >&2
  exit 1
}

"$PETREL_PYTHON" - "$LOCK" <<'PY'
from __future__ import annotations

import importlib
from importlib import metadata
from pathlib import Path
import re
import sys

if sys.version_info[:2] != (3, 12):
    raise SystemExit(f"release generator requires Python 3.12.x, got {sys.version.split()[0]}")

for module in ("jinja2", "aiofiles", "orjson", "markupsafe"):
    importlib.import_module(module)

expected = {
    "jinja2": "3.1.6",
    "aiofiles": "25.1.0",
    "orjson": "3.11.7",
    "markupsafe": "3.0.3",
}
allowed_bootstrap = {"pip", "setuptools", "wheel"}

def canonical(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()

lock_path = Path(sys.argv[1])
lock_entries: dict[str, str] = {}
current: str | None = None
hash_counts: dict[str, int] = {}
for line_number, raw_line in enumerate(lock_path.read_text(encoding="utf-8").splitlines(), 1):
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    requirement = re.fullmatch(r"([A-Za-z0-9_.-]+)==([^ ]+) \\", line)
    if requirement:
        current = canonical(requirement.group(1))
        if current in lock_entries:
            raise SystemExit(f"duplicate lock entry for {current}")
        lock_entries[current] = requirement.group(2)
        hash_counts[current] = 0
        continue
    if re.fullmatch(r"--hash=sha256:[0-9a-f]{64}( \\)?", line):
        if current is None:
            raise SystemExit(f"orphan hash on lock line {line_number}")
        hash_counts[current] += 1
        continue
    raise SystemExit(f"unrecognized release-lock line {line_number}: {raw_line}")

if lock_entries != expected:
    raise SystemExit(f"release lock differs from exact dependency set: {lock_entries!r}")
if any(count == 0 for count in hash_counts.values()):
    raise SystemExit("every locked dependency must have at least one SHA-256")

installed: dict[str, str] = {}
for distribution in metadata.distributions():
    name = distribution.metadata.get("Name")
    if not name:
        raise SystemExit("installed distribution is missing its Name metadata")
    normalized = canonical(name)
    if normalized in installed:
        raise SystemExit(f"duplicate installed distribution: {normalized}")
    installed[normalized] = distribution.version

unexpected = set(installed) - set(expected) - allowed_bootstrap
missing = set(expected) - set(installed)
mismatched = {
    name: (expected[name], installed.get(name))
    for name in expected
    if installed.get(name) != expected[name]
}
if unexpected:
    raise SystemExit(f"unexpected third-party distributions: {sorted(unexpected)}")
if missing:
    raise SystemExit(f"missing generator distributions: {sorted(missing)}")
if mismatched:
    raise SystemExit(f"mismatched generator distributions: {mismatched}")
PY

export PETREL_PYTHON
