#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd -P)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd -P)
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

DUMP_SWIFT="$SCRATCH/dump-swift"
# shellcheck disable=SC2016 # Emit literal variable references into the shim.
printf '%s\n' \
  '#!/bin/bash' \
  'set -euo pipefail' \
  '[[ $# -eq 2 && $1 == package && $2 == dump-package ]] || exit 64' \
  ': "${FAKE_PACKAGE_DUMP:?}"' \
  'exec /bin/cat "$FAKE_PACKAGE_DUMP"' > "$DUMP_SWIFT"
/bin/chmod +x "$DUMP_SWIFT"

BASE_DUMP="$SCRATCH/base-dump.json"
(
  cd "$ROOT"
  "$TRUSTED_SWIFT" package dump-package > "$BASE_DUMP"
)

WRONG_URL_DUMP="$SCRATCH/wrong-url.json"
EXTRA_PRE_ONE_DUMP="$SCRATCH/extra-pre-one.json"
EXTRA_REGISTRY_PRE_ONE_DUMP="$SCRATCH/extra-registry-pre-one.json"
EXTRA_REGISTRY_QUALIFIED_DUMP="$SCRATCH/extra-registry-qualified.json"
DUPLICATE_KIND_DUMP="$SCRATCH/duplicate-kind.json"
MULTI_ENTRY_DUMP="$SCRATCH/multi-entry.json"
UNBOUNDED_REVIEWED_DUMP="$SCRATCH/unbounded-reviewed.json"
EXACT_POLICY_DIR="$SCRATCH/exact-policy"
/bin/mkdir -p "$EXACT_POLICY_DIR"
/usr/bin/python3 -I - \
  "$BASE_DUMP" \
  "$WRONG_URL_DUMP" \
  "$EXTRA_PRE_ONE_DUMP" \
  "$EXTRA_REGISTRY_PRE_ONE_DUMP" \
  "$EXTRA_REGISTRY_QUALIFIED_DUMP" \
  "$DUPLICATE_KIND_DUMP" \
  "$MULTI_ENTRY_DUMP" \
  "$UNBOUNDED_REVIEWED_DUMP" \
  "$EXACT_POLICY_DIR" <<'PY'
import copy
import json
import sys
from pathlib import Path

(
    base_path,
    wrong_url_path,
    extra_path,
    registry_path,
    qualified_registry_path,
    duplicate_kind_path,
    multi_entry_path,
    unbounded_path,
    exact_policy_dir,
) = map(Path, sys.argv[1:])
base = json.loads(base_path.read_text(encoding="utf-8"))


def source_control(document, identity):
    for dependency in document["dependencies"]:
        controls = dependency.get("sourceControl", [])
        if len(controls) == 1 and controls[0].get("identity") == identity:
            return controls[0]
    raise RuntimeError(f"missing source-control dependency {identity}")


wrong_url = copy.deepcopy(base)
source_control(wrong_url, "swiftcbor")["location"] = {
    "remote": [{"urlString": "https://example.invalid/SwiftCBOR.git"}]
}
wrong_url_path.write_text(json.dumps(wrong_url), encoding="utf-8")

extra = copy.deepcopy(base)
extra["dependencies"].append(
    {
        "sourceControl": [
            {
                "identity": "unreviewed-zero",
                "location": {
                    "remote": [
                        {"urlString": "https://example.invalid/unreviewed-zero.git"}
                    ]
                },
                "productFilter": None,
                "requirement": {
                    "range": [
                        {"lowerBound": "0.9.0", "upperBound": "0.10.0"}
                    ]
                },
                "traits": [{"name": "default"}],
            }
        ]
    }
)
extra_path.write_text(json.dumps(extra), encoding="utf-8")

registry = copy.deepcopy(base)
registry["dependencies"].append(
    {
        "registry": [
            {
                "identity": "example.unreviewed-zero",
                "productFilter": None,
                "requirement": {
                    "range": [
                        {"lowerBound": "0.9.0", "upperBound": "1.0.0"}
                    ]
                },
                "traits": [{"name": "default"}],
            }
        ]
    }
)
registry_path.write_text(json.dumps(registry), encoding="utf-8")

qualified_registry = copy.deepcopy(registry)
qualified_entry = qualified_registry["dependencies"][-1]["registry"][0]
qualified_entry["identity"] = "example.qualified-zero"
qualified_entry["requirement"]["range"][0]["lowerBound"] = (
    "0.9.0-alpha.1+build.7"
)
qualified_registry_path.write_text(
    json.dumps(qualified_registry),
    encoding="utf-8",
)

duplicate_kind = copy.deepcopy(base)
duplicate_kind["dependencies"].append(
    {
        "fileSystem": [
            {
                "identity": "swiftcbor",
                "path": "/tmp/unreviewed-swiftcbor",
                "productFilter": None,
                "traits": [{"name": "default"}],
            }
        ]
    }
)
duplicate_kind_path.write_text(json.dumps(duplicate_kind), encoding="utf-8")

multi_entry = copy.deepcopy(base)
bad_swiftcbor = copy.deepcopy(source_control(base, "swiftcbor"))
bad_swiftcbor["location"] = {
    "remote": [{"urlString": "https://example.invalid/SwiftCBOR.git"}]
}
bad_swiftcbor["requirement"] = {
    "range": [{"lowerBound": "0.5.0", "upperBound": "1.0.0"}]
}
bad_dns = copy.deepcopy(source_control(base, "swift-async-dns-resolver"))
bad_dns["location"] = {
    "remote": [{"urlString": "https://example.invalid/async-dns.git"}]
}
bad_dns["requirement"] = {
    "range": [{"lowerBound": "0.4.0", "upperBound": "1.0.0"}]
}
multi_entry["dependencies"].append(
    {"sourceControl": [bad_swiftcbor, bad_dns]}
)
multi_entry_path.write_text(json.dumps(multi_entry), encoding="utf-8")

unbounded = copy.deepcopy(base)
source_control(unbounded, "swiftcbor")["requirement"] = {
    "range": [{"lowerBound": "0.5.0", "upperBound": "1.0.0"}]
}
unbounded_path.write_text(json.dumps(unbounded), encoding="utf-8")

# The reviewed exact dependency must not inherit the bounded-range policy,
# accept another source/version, or bypass the generic pre-1.0 review gate.
exact_requirements = {
    "newer-version": {"exact": ["0.24.1"]},
    "prerelease": {"exact": ["0.24.0-alpha.1"]},
    "multiple-versions": {"exact": ["0.24.0", "0.24.1"]},
    "empty-versions": {"exact": []},
    "bounded-range": {
        "range": [{"lowerBound": "0.24.0", "upperBound": "0.25.0"}]
    },
    "branch": {"branch": ["main"]},
    "revision": {"revision": ["4c77c7384768acf1093d66ccaacf298d322b10b7"]},
    "mixed-requirements": {"exact": ["0.24.0"], "branch": ["main"]},
}
for label, requirement in exact_requirements.items():
    document = copy.deepcopy(base)
    source_control(document, "swift-secp256k1")["requirement"] = requirement
    (exact_policy_dir / f"{label}.json").write_text(
        json.dumps(document), encoding="utf-8"
    )

exact_wrong_url = copy.deepcopy(base)
source_control(exact_wrong_url, "swift-secp256k1")["location"] = {
    "remote": [{"urlString": "https://example.invalid/swift-secp256k1.git"}]
}
(exact_policy_dir / "wrong-url.json").write_text(
    json.dumps(exact_wrong_url), encoding="utf-8"
)

exact_registry = copy.deepcopy(base)
for wrapper in exact_registry["dependencies"]:
    entries = wrapper.get("sourceControl", [])
    if len(entries) == 1 and entries[0].get("identity") == "swift-secp256k1":
        entry = wrapper.pop("sourceControl")[0]
        entry.pop("location")
        wrapper["registry"] = [entry]
(exact_policy_dir / "registry-substitution.json").write_text(
    json.dumps(exact_registry), encoding="utf-8"
)

extra_exact = copy.deepcopy(base)
unknown_exact = copy.deepcopy(source_control(base, "swift-secp256k1"))
unknown_exact["identity"] = "unreviewed-exact-zero"
unknown_exact["location"] = {
    "remote": [{"urlString": "https://example.invalid/unreviewed-exact-zero.git"}]
}
extra_exact["dependencies"].append({"sourceControl": [unknown_exact]})
(exact_policy_dir / "unreviewed-exact.json").write_text(
    json.dumps(extra_exact), encoding="utf-8"
)
PY

expect_semantic_failure() {
  local label=$1
  local dump=$2
  local expected=$3
  local output="$SCRATCH/$label.txt"

  if FAKE_PACKAGE_DUMP=$dump RELEASE_SWIFT=$DUMP_SWIFT \
    "$VALIDATOR" > "$output" 2>&1; then
    echo "validator accepted invalid dependency dump: $label" >&2
    exit 1
  fi
  /usr/bin/grep -Fq "$expected" "$output" || {
    echo "validator failed $label for the wrong reason" >&2
    /bin/cat "$output" >&2
    exit 1
  }
}

expect_semantic_failure \
  wrong-url \
  "$WRONG_URL_DUMP" \
  "swiftcbor source URL must be https://github.com/valpackett/SwiftCBOR.git"
expect_semantic_failure \
  extra-pre-one \
  "$EXTRA_PRE_ONE_DUMP" \
  "unreviewed direct pre-1.0 dependency: unreviewed-zero"
expect_semantic_failure \
  extra-registry-pre-one \
  "$EXTRA_REGISTRY_PRE_ONE_DUMP" \
  "unreviewed direct pre-1.0 dependency: example.unreviewed-zero"
expect_semantic_failure \
  extra-registry-qualified \
  "$EXTRA_REGISTRY_QUALIFIED_DUMP" \
  "unreviewed direct pre-1.0 dependency: example.qualified-zero"
expect_semantic_failure \
  duplicate-kind \
  "$DUPLICATE_KIND_DUMP" \
  "duplicate direct dependency identity: swiftcbor"
expect_semantic_failure \
  multi-entry \
  "$MULTI_ENTRY_DUMP" \
  "sourceControl dependency wrapper must contain exactly one entry"
expect_semantic_failure \
  unbounded-reviewed \
  "$UNBOUNDED_REVIEWED_DUMP" \
  "swiftcbor requirement must be 0.6.0..<0.7.0"

for label in newer-version prerelease multiple-versions empty-versions \
  bounded-range branch revision mixed-requirements; do
  expect_semantic_failure \
    "exact-$label" \
    "$EXACT_POLICY_DIR/$label.json" \
    "swift-secp256k1 requirement must be exact 0.24.0"
done
expect_semantic_failure \
  exact-wrong-url \
  "$EXACT_POLICY_DIR/wrong-url.json" \
  "swift-secp256k1 source URL must be https://github.com/21-DOT-DEV/swift-secp256k1.git"
expect_semantic_failure \
  exact-registry-substitution \
  "$EXACT_POLICY_DIR/registry-substitution.json" \
  "missing direct dependency: swift-secp256k1"
expect_semantic_failure \
  unreviewed-exact \
  "$EXACT_POLICY_DIR/unreviewed-exact.json" \
  "unreviewed direct pre-1.0 dependency: unreviewed-exact-zero"

echo "Petrel dependency requirement gate tests passed"
