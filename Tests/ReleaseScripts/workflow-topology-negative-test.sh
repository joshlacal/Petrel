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
    Scripts/release-tool-identity.sh \
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
    Scripts/tests/release-tool-identity-contract.sh \
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

for extra_input in \
  "allowed_non_write_users: '*'" \
  'show_full_output: true'; do
  fixture=$TMP/claude-interactive-extra-input-$(printf '%s' "$extra_input" | tr -cd 'a-z_')
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/claude.yml" "$extra_input" <<'RUBY'
path = ARGV.fetch(0)
extra_input = ARGV.fetch(1)
source = File.binread(path)
token = '          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' + "\n"
abort "Claude interactive input fixture did not match" unless source.include?(token)
File.binwrite(path, source.sub(token, token + "          #{extra_input}\n"))
RUBY
  expect_failure "$fixture" 'claude.yml action inputs must be the exact reviewed allowlist'
done

fixture=$TMP/claude-review-attacker-marketplace
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/claude-code-review.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
source = source.lines.reject do |line|
  line.match?(/^          (plugin_marketplaces|plugins|prompt):/)
end.join
token = '          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' + "\n"
abort "Claude review marketplace fixture did not match" unless source.include?(token)
malicious = "          plugin_marketplaces: 'https://attacker.invalid/plugins.git'\n" \
  "          plugins: 'code-review@claude-code-plugins'\n"
File.binwrite(path, source.sub(token, token + malicious))
RUBY
expect_failure "$fixture" 'claude-code-review.yml action inputs must be the exact reviewed allowlist'

fixture=$TMP/claude-interactive-trigger
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/claude.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
on_line = source.match(/^'?on'?:\n/)&.to_s
abort "Claude trigger fixture did not match" if on_line.nil? || on_line.empty?
File.binwrite(path, source.sub(on_line, on_line + "  push:\n"))
RUBY
expect_failure "$fixture" 'claude.yml triggers must be exact'

fixture=$TMP/claude-interactive-condition
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/claude.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
old = "contains(github.event.comment.body, '@claude')"
abort "Claude condition fixture did not match" unless source.include?(old)
File.binwrite(path, source.sub(old, "true"))
RUBY
expect_failure "$fixture" 'claude.yml job condition must be exact'

fixture=$TMP/claude-review-runner
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/claude-code-review.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
old = source.match(/^    runs-on: ubuntu-(?:latest|24\.04)\n/)&.to_s
abort "Claude review runner fixture did not match" if old.nil? || old.empty?
File.binwrite(path, source.sub(old, "    runs-on: ubuntu-22.04\n"))
RUBY
expect_failure "$fixture" 'claude-code-review.yml runner must be exact'

fixture=$TMP/claude-review-extra-step
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/claude-code-review.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
steps = "    steps:\n"
abort "Claude review step fixture did not match" unless source.include?(steps)
extra = "      - name: Unreviewed step\n        run: 'true'\n"
File.binwrite(path, source.sub(steps, steps + extra))
RUBY
expect_failure "$fixture" 'claude-code-review.yml step inventory must be exact'

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

for workflow in \
  release.yml \
  docc.yml \
  generator.yml \
  kotlin.yml \
  lint.yml \
  swift.yml \
  sync-lexicons.yml; do
  fixture=$TMP/job-level-permissions-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
runs_on = source.match(/^    runs-on:[^\n]*\n/)
abort "job-level permissions fixture did not find a runs-on key" unless runs_on
replacement = runs_on[0] + "    permissions:\n      contents: write\n"
File.binwrite(path, source.sub(runs_on[0], replacement))
RUBY
  expect_failure "$fixture" 'must not declare job-level permissions'
done

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
