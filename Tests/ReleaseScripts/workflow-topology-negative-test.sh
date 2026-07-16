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
    Scripts/extract-documentation-examples.sh \
    Scripts/install-generated-documentation.sh \
    Scripts/regenerate-generated.sh \
    Scripts/run-api-compatibility.sh \
    Scripts/tests/validate-dependency-requirements-contract.sh \
    Scripts/tests/validate-dependency-requirements-gate-test.sh \
    Scripts/validate-documentation.sh \
    Scripts/verify-generator-environment.sh \
    Scripts/verify-owned-warnings.sh \
    Scripts/verify-release-workflow-topology.sh \
    Scripts/tests/validate-documentation-contract.sh \
    Tests/ReleaseScripts/dependency-workflow-coupling-test.sh \
    Tests/ReleaseScripts/install-generated-documentation-test.sh \
    Tests/ReleaseScripts/owned-warning-gate-test.sh \
    Tests/ReleaseScripts/release-documentation-gate-test.sh \
    Tests/ReleaseScripts/release-tag-ancestry-gate-test.sh \
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

fixture=$TMP/tag-main-ancestry
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
old = '          /usr/bin/git merge-base --is-ancestor "$CANDIDATE_COMMIT" refs/remotes/origin/main' + "\n"
abort "tag ancestry fixture did not match" unless source.include?(old)
File.binwrite(path, source.sub(old, ""))
RUBY
expect_failure "$fixture" 'tag guard is missing "/usr/bin/git merge-base --is-ancestor'

fixture=$TMP/dependency-gate-order
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/swift.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
dependency = <<'YAML'
      - name: Validate bounded dependency requirements
        if: "${{ github.event_name == 'pull_request' }}"
        shell: bash
        run: |
          set -euo pipefail
          /bin/test -x /usr/bin/python3
          Scripts/tests/validate-dependency-requirements-gate-test.sh
          Scripts/tests/validate-dependency-requirements-contract.sh
YAML
activation = "      - name: Select and verify stable Xcode\n"
abort "dependency ordering fixture did not match" unless source.include?(dependency)
abort "activation ordering fixture did not match" unless source.include?(activation)
without_dependency = source.sub(dependency, "")
File.binwrite(path, without_dependency.sub(activation, dependency + activation))
RUBY
expect_failure "$fixture" 'Swift compatibility dependency gate must immediately follow Xcode activation'

fixture=$TMP/dependency-python-probe
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
probe = "          /bin/test -x /usr/bin/python3\n"
abort "dependency Python probe fixture did not match" unless source.include?(probe)
File.binwrite(path, source.sub(probe, ""))
RUBY
expect_failure "$fixture" 'release dependency gate has the wrong fail-closed run body'

fixture=$TMP/dependency-release-condition
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
condition = %Q(        if: "${{ startsWith(github.ref, 'refs/tags/') }}"\n)
abort "dependency release condition fixture did not match" unless source.include?(condition)
File.binwrite(path, source.sub(condition, ""))
RUBY
expect_failure "$fixture" 'release dependency gate has the wrong event condition'

for relative in \
  Scripts/tests/validate-dependency-requirements-contract.sh \
  Scripts/tests/validate-dependency-requirements-gate-test.sh; do
  fixture=$TMP/missing-$(basename "$relative")
  make_fixture "$fixture"
  rm "$fixture/$relative"
  expect_failure "$fixture" "required release executable is missing: $relative"

  fixture=$TMP/nonexecutable-$(basename "$relative")
  make_fixture "$fixture"
  chmod -x "$fixture/$relative"
  expect_failure "$fixture" "required release executable is not executable: $relative"
done

echo "workflow topology negative contracts: PASS"
