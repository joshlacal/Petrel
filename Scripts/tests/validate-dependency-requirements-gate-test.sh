#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd -P)
VALIDATOR="$SCRIPT_DIR/validate-dependency-requirements-contract.sh"
TRUSTED_SWIFT=${RELEASE_SWIFT:-}

[[ $TRUSTED_SWIFT == /* && -x $TRUSTED_SWIFT ]] || {
  echo "test requires RELEASE_SWIFT to be an absolute executable" >&2
  exit 64
}

SCRATCH=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/petrel-dependency-gate-test.XXXXXX")
trap '/bin/rm -rf "$SCRATCH"' EXIT

SHIM_DIR="$SCRATCH/shims"
/bin/mkdir -p "$SHIM_DIR"
POISON_DIR="$SCRATCH/pythonpath"
/bin/mkdir -p "$POISON_DIR"

# shellcheck disable=SC2016 # Emit literal variable references into the shim.
printf '%s\n' \
  '#!/bin/bash' \
  ': "${SWIFT_SHIM_MARKER:?}"' \
  '/usr/bin/touch "$SWIFT_SHIM_MARKER"' \
  'exit 91' > "$SHIM_DIR/swift"
# shellcheck disable=SC2016 # Emit literal variable references into the shim.
printf '%s\n' \
  '#!/bin/bash' \
  ': "${PYTHON_SHIM_MARKER:?}"' \
  '/usr/bin/touch "$PYTHON_SHIM_MARKER"' \
  'exit 92' > "$SHIM_DIR/python3"
/bin/chmod +x "$SHIM_DIR/swift" "$SHIM_DIR/python3"
printf '%s\n' \
  'import os' \
  'with open(os.environ["PYTHONPATH_SHIM_MARKER"], "w", encoding="utf-8") as marker:' \
  '    marker.write("invoked")' \
  'raise RuntimeError("poisoned PYTHONPATH json module was imported")' \
  > "$POISON_DIR/json.py"

export PATH="$SHIM_DIR:/usr/bin:/bin"
export SWIFT_SHIM_MARKER="$SCRATCH/swift-shim-invoked"
export PYTHON_SHIM_MARKER="$SCRATCH/python-shim-invoked"
export PYTHONPATH_SHIM_MARKER="$SCRATCH/pythonpath-shim-invoked"

missing_output="$SCRATCH/missing-release-swift.txt"
if (unset RELEASE_SWIFT; "$VALIDATOR") > "$missing_output" 2>&1; then
  echo "validator accepted a missing RELEASE_SWIFT" >&2
  exit 1
fi
[[ ! -e $SWIFT_SHIM_MARKER && ! -e $PYTHON_SHIM_MARKER ]] || {
  echo "validator invoked an ambient executable when RELEASE_SWIFT was missing" >&2
  exit 1
}
/usr/bin/grep -Fq \
  "RELEASE_SWIFT must name an absolute executable" \
  "$missing_output"

relative_output="$SCRATCH/relative-release-swift.txt"
if RELEASE_SWIFT=swift "$VALIDATOR" > "$relative_output" 2>&1; then
  echo "validator accepted a relative RELEASE_SWIFT" >&2
  exit 1
fi
[[ ! -e $SWIFT_SHIM_MARKER && ! -e $PYTHON_SHIM_MARKER ]] || {
  echo "validator invoked a PATH shim for relative RELEASE_SWIFT" >&2
  exit 1
}
/usr/bin/grep -Fq \
  "RELEASE_SWIFT must name an absolute executable" \
  "$relative_output"

if ! RELEASE_SWIFT=$TRUSTED_SWIFT PYTHONPATH=$POISON_DIR \
  "$VALIDATOR" > "$SCRATCH/valid.txt" 2>&1; then
  if [[ -e $PYTHONPATH_SHIM_MARKER ]]; then
    echo "validator imported a module from poisoned PYTHONPATH" >&2
  else
    /bin/cat "$SCRATCH/valid.txt" >&2
  fi
  exit 1
fi
[[ ! -e $SWIFT_SHIM_MARKER && ! -e $PYTHON_SHIM_MARKER && \
  ! -e $PYTHONPATH_SHIM_MARKER ]] || {
  echo "validator invoked a PATH or PYTHONPATH shim" >&2
  exit 1
}
/usr/bin/grep -Fq \
  "Petrel dependency requirement contract passed" \
  "$SCRATCH/valid.txt"

echo "Petrel dependency requirement gate tests passed"
