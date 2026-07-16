#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/petrel-workflow-topology-negative.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

make_fixture() {
  local fixture=$1
  local relative

  mkdir -p \
    "$fixture/Scripts/tests" \
    "$fixture/Tests/ReleaseScripts" \
    "$fixture/.github/workflows"
  for relative in \
    Scripts/activate-release-toolchain.sh \
    Scripts/bootstrap-generator-environment.sh \
    Scripts/bootstrap-release-tools.sh \
    Scripts/install-generated-documentation.sh \
    Scripts/regenerate-generated.sh \
    Scripts/run-api-compatibility.sh \
    Scripts/validate-documentation.sh \
    Scripts/verify-generator-environment.sh \
    Scripts/verify-owned-warnings.sh \
    Scripts/verify-release-workflow-topology.sh \
    Scripts/tests/validate-documentation-contract.sh \
    Tests/ReleaseScripts/install-generated-documentation-test.sh \
    Tests/ReleaseScripts/owned-warning-gate-test.sh \
    Tests/ReleaseScripts/release-documentation-gate-test.sh \
    Tests/ReleaseScripts/workflow-topology-negative-test.sh; do
    cp "$ROOT/$relative" "$fixture/$relative"
    chmod +x "$fixture/$relative"
  done
  cp "$ROOT"/.github/workflows/*.yml "$fixture/.github/workflows/"
  "$fixture/Scripts/verify-release-workflow-topology.sh"
}

expect_failure() {
  local fixture=$1
  local expected=$2
  local output status

  set +e
  output=$("$fixture/Scripts/verify-release-workflow-topology.sh" 2>&1)
  status=$?
  set -e
  if [[ $status -eq 0 || $output != *"$expected"* ]]; then
    printf 'expected topology failure containing %q; status=%s output=%s\n' \
      "$expected" "$status" "$output" >&2
    exit 1
  fi
}

fixture=$TMP/yaml-inventory
make_fixture "$fixture"
printf '%s\n' \
  'name: Unreviewed workflow' \
  "'on':" \
  '  pull_request:' \
  'permissions:' \
  '  contents: write' \
  'jobs:' \
  '  unsafe:' \
  '    runs-on: ubuntu-24.04' \
  '    steps:' \
  '      - uses: actions/checkout@v4' \
  > "$fixture/.github/workflows/unreviewed.yaml"
expect_failure "$fixture" 'workflow inventory differs'

fixture=$TMP/sync-trigger
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/sync-lexicons.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
old = "'on':\n  schedule:\n    - cron: '17 6 * * 1'   # weekly, Monday 06:17 UTC\n  workflow_dispatch:\n"
abort "sync trigger fixture did not match" unless source.include?(old)
File.binwrite(path, source.sub(old, "'on':\n  pull_request:\n"))
RUBY
expect_failure "$fixture" 'sync workflow events must be exactly schedule and workflow_dispatch'

fixture=$TMP/missing-documentation-validator
make_fixture "$fixture"
rm "$fixture/Scripts/validate-documentation.sh"
expect_failure "$fixture" 'required release executable is missing: Scripts/validate-documentation.sh'

fixture=$TMP/nonexecutable-documentation-validator
make_fixture "$fixture"
chmod -x "$fixture/Scripts/validate-documentation.sh"
expect_failure "$fixture" 'required release executable is not executable: Scripts/validate-documentation.sh'

echo "workflow topology negative contracts: PASS"
