#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VENV="$ROOT/.build/release-generator-venv"
LOCK="$ROOT/generator/requirements-release.lock"

[[ -n ${RELEASE_PYTHON312:-} ]] || {
  echo "RELEASE_PYTHON312 must name an explicit Python 3.12 executable" >&2
  exit 1
}
[[ -x $RELEASE_PYTHON312 ]] || {
  echo "RELEASE_PYTHON312 is not executable: $RELEASE_PYTHON312" >&2
  exit 1
}
python_version=$("$RELEASE_PYTHON312" -c \
  'import sys; print(".".join(map(str, sys.version_info[:3])))')
[[ $python_version == 3.12.* ]] || {
  echo "release generator requires Python 3.12.x, got $python_version" >&2
  exit 1
}
[[ -f $LOCK ]] || {
  echo "release generator lock is missing: $LOCK" >&2
  exit 1
}

if [[ -e $VENV ]]; then
  previous="${TMPDIR:-/tmp}/petrel-release-generator-venv.previous.$$.${RANDOM}"
  mv "$VENV" "$previous"
fi
mkdir -p "$(dirname "$VENV")"
"$RELEASE_PYTHON312" -m venv "$VENV"
PIP_NO_CACHE_DIR=1 "$VENV/bin/python" -m pip install --require-hashes -r "$LOCK"
"$ROOT/Scripts/verify-generator-environment.sh"
PETREL_PYTHON="$VENV/bin/python"
export PETREL_PYTHON
