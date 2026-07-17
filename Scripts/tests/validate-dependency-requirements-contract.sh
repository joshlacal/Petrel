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
import re
import sys
from pathlib import Path

dump = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = {
    "swiftcbor": (
        "https://github.com/valpackett/SwiftCBOR.git",
        "0.6.0",
        "0.7.0",
    ),
    "swift-async-dns-resolver": (
        "https://github.com/apple/swift-async-dns-resolver",
        "0.7.0",
        "0.8.0",
    ),
}

direct_dependencies = dump.get("dependencies", [])
if not isinstance(direct_dependencies, list):
    raise SystemExit("direct dependencies must be an array")

dependencies = {}
dependency_identities = {}
direct_entries = []
for dependency in direct_dependencies:
    if not isinstance(dependency, dict) or len(dependency) != 1:
        raise SystemExit("dependency wrapper must contain exactly one kind")
    dependency_kind, entries = next(iter(dependency.items()))
    if not isinstance(entries, list) or len(entries) != 1:
        raise SystemExit(
            f"{dependency_kind} dependency wrapper must contain exactly one entry"
        )

    entry = entries[0]
    if not isinstance(entry, dict):
        raise SystemExit(f"{dependency_kind} dependency entry must be an object")
    identity = entry.get("identity")
    if not isinstance(identity, str) or not identity:
        raise SystemExit(f"{dependency_kind} dependency identity is missing")
    if identity in dependency_identities:
        raise SystemExit(f"duplicate direct dependency identity: {identity}")

    dependency_identities[identity] = dependency_kind
    direct_entries.append((dependency_kind, entry))
    if dependency_kind == "sourceControl":
        dependencies[identity] = entry


def contains_pre_one_version(value):
    if isinstance(value, dict):
        return any(contains_pre_one_version(item) for item in value.values())
    if isinstance(value, list):
        return any(contains_pre_one_version(item) for item in value)
    if not isinstance(value, str):
        return False

    version = re.match(
        r"^(0|[1-9][0-9]*)\.[0-9]+\.[0-9]+(?:$|[-+])",
        value,
    )
    return version is not None and version.group(1) == "0"


for identity, (expected_url, expected_lower, expected_upper) in expected.items():
    dependency = dependencies.get(identity)
    if dependency is None:
        raise SystemExit(f"missing direct dependency: {identity}")

    expected_location = {"remote": [{"urlString": expected_url}]}
    actual_location = dependency.get("location")
    if actual_location != expected_location:
        raise SystemExit(
            f"{identity} source URL must be {expected_url}; got {actual_location!r}"
        )

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

for dependency_kind, entry in direct_entries:
    if not contains_pre_one_version(entry.get("requirement", {})):
        continue
    identity = entry["identity"]
    if dependency_kind != "sourceControl" or identity not in expected:
        raise SystemExit(f"unreviewed direct pre-1.0 dependency: {identity}")

print("Petrel dependency requirement contract passed")
PY
