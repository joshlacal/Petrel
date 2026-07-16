#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd -P)
SWIFT_EXECUTABLE=${RELEASE_SWIFT:-}
[[ $SWIFT_EXECUTABLE == /* && -x $SWIFT_EXECUTABLE ]] || {
  echo "RELEASE_SWIFT must name an absolute executable" >&2
  exit 64
}
DUMP_FILE=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/petrel-package-dump.XXXXXX")
trap '/bin/rm -f "$DUMP_FILE"' EXIT

cd "$ROOT"
"$SWIFT_EXECUTABLE" package dump-package > "$DUMP_FILE"

/usr/bin/python3 -I - "$DUMP_FILE" <<'PY'
import json
import sys
from pathlib import Path

dump = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = {
    "swiftcbor": ("0.5.0", "0.6.0"),
    "swift-async-dns-resolver": ("0.4.0", "0.5.0"),
}

dependencies = {}
for dependency in dump.get("dependencies", []):
    source_controls = dependency.get("sourceControl", [])
    if len(source_controls) != 1:
        continue

    source_control = source_controls[0]
    identity = source_control.get("identity")
    if identity in dependencies:
        raise SystemExit(f"duplicate source-control dependency identity: {identity}")
    dependencies[identity] = source_control

for identity, (expected_lower, expected_upper) in expected.items():
    dependency = dependencies.get(identity)
    if dependency is None:
        raise SystemExit(f"missing direct dependency: {identity}")

    requirement = dependency.get("requirement", {})
    ranges = requirement.get("range", [])
    if set(requirement) != {"range"} or len(ranges) != 1:
        raise SystemExit(
            f"{identity} must use one semantic version range; got {requirement!r}"
        )

    actual_lower = ranges[0].get("lowerBound")
    actual_upper = ranges[0].get("upperBound")
    if (actual_lower, actual_upper) != (expected_lower, expected_upper):
        raise SystemExit(
            f"{identity} requirement must be "
            f"{expected_lower}..<{expected_upper}; got "
            f"{actual_lower}..<{actual_upper}"
        )

print("Petrel dependency requirement contract passed")
PY
