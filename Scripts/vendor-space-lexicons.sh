#!/usr/bin/env bash
# Update generator/provenance/spaces.json only after reviewing a new release.
# Checkpoint owned work with jj before invoking this script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${PETREL_PYTHON:-python3}" "$ROOT/Scripts/space_lexicon_provenance.py" vendor "$@"
