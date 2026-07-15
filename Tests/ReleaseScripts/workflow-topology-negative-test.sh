#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
GATE=$ROOT/Scripts/verify-release-workflow-topology.sh
TMP=$(mktemp -d "${TMPDIR:-/tmp}/petrel-workflow-topology-negative.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

make_fixture() {
  local fixture=$1

  mkdir -p "$fixture/Scripts" "$fixture/.github/workflows"
  cp "$GATE" "$fixture/Scripts/verify-release-workflow-topology.sh"
  chmod +x "$fixture/Scripts/verify-release-workflow-topology.sh"
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

echo "workflow topology negative contracts: PASS"
