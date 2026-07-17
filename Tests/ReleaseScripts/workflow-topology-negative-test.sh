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

fixture=$TMP/minimum-test-runner-isolation
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '"$RELEASE_SWIFT" test --no-parallel --enable-xctest --disable-swift-testing'
unsafe = '"$RELEASE_SWIFT" test --parallel --enable-xctest --enable-swift-testing'
abort "minimum test runner fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, unsafe))
RUBY
expect_failure "$fixture" 'release macOS must preserve the exact minimum/newest-stable test branch'

for workflow in release.yml swift.yml; do
  case $workflow in
    release.yml) label='release' ;;
    swift.yml) label='Swift compatibility' ;;
  esac

  fixture=$TMP/minimum-platform-proof-uses-xcodebuild-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '            "$RELEASE_SWIFT" build ' + 92.chr + "\n"
abort "minimum SwiftPM platform proof fixture did not match" unless source.include?(reviewed)
replacement = '            "$RELEASE_XCODEBUILD" ' + 92.chr + "\n"
File.binwrite(path, source.sub(reviewed, replacement))
RUBY
  expect_failure "$fixture" "$label platform proof paths, triple, SDK, scratch, and simulator destination must occur exactly once"

  fixture=$TMP/newest-platform-proof-uses-swiftpm-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '            Scripts/verify-owned-warnings.sh ios-simulator -- "$RELEASE_XCODEBUILD" ' + 92.chr + "\n"
abort "newest simulator platform proof fixture did not match" unless source.include?(reviewed)
cross = '            "$RELEASE_SWIFT" build ' + 92.chr + "\n" \
  + "              --scratch-path .build/xcode163-iphoneos-cross " + 92.chr + "\n" \
  + "              --triple arm64-apple-ios18.0 " + 92.chr + "\n" \
  + '              --sdk "$SDK_PATH"' + "\n"
File.binwrite(path, source.sub(reviewed, cross + reviewed))
RUBY
  expect_failure "$fixture" "$label platform proof paths, triple, SDK, scratch, and simulator destination must occur exactly once"

  fixture=$TMP/extra-xcodebuild-outside-platform-proof-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = "              build\n          fi\n"
abort "platform proof tail fixture did not match" unless source.include?(reviewed)
extra = '          "$RELEASE_XCODEBUILD" -scheme Petrel -destination ' \
  + "'generic/platform=iOS' build\n"
File.binwrite(path, source.sub(reviewed, reviewed + extra))
RUBY
  expect_failure "$fixture" "$label platform proof commands must not occur outside reviewed lane conditional"

  fixture=$TMP/extra-swiftpm-outside-platform-proof-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = "              build\n          fi\n"
abort "platform proof tail fixture did not match" unless source.include?(reviewed)
extra = '          "$RELEASE_SWIFT" build --scratch-path .build/wrong ' \
  + '--triple x86_64-apple-ios17.0 --sdk /tmp/wrong-sdk' + "\n"
File.binwrite(path, source.sub(reviewed, reviewed + extra))
RUBY
  expect_failure "$fixture" "$label platform proof commands must not occur outside reviewed lane conditional"

  while IFS='|' read -r slug command; do
    fixture=$TMP/alternate-swift-outside-platform-proof-${workflow%.yml}-$slug
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$command" <<'RUBY'
path = ARGV.fetch(0)
command = ARGV.fetch(1)
source = File.binread(path)
reviewed = "              build\n          fi\n"
abort "platform proof tail fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, reviewed + "          #{command}\n"))
RUBY
    expect_failure "$fixture" "$label platform proof commands must not occur outside reviewed lane conditional"
  done <<'CASES'
ambient|swift build
absolute|/usr/bin/swift build
braced|"${RELEASE_SWIFT}" build
substitution|$(command -v swift) build
CASES

  fixture=$TMP/ambient-swift-before-platform-proof-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = "          if [[ $RELEASE_TOOLCHAIN_LANE == minimum ]]; then\n"
abort "platform proof opening fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, "          swift build\n" + reviewed))
RUBY
  expect_failure "$fixture" "$label platform proof commands must not occur outside reviewed lane conditional"

  fixture=$TMP/ambient-swift-inside-platform-proof-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '            SDK_PATH=$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-path)' + "\n"
abort "platform proof SDK fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, reviewed + "            swift build\n"))
RUBY
  expect_failure "$fixture" "$label platform proof must keep minimum SwiftPM-cross and newest simulator xcodebuild isolated"

  for extra_name in duplicate alternate; do
    fixture=$TMP/extra-macos-build-step-${workflow%.yml}-$extra_name
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$extra_name" <<'RUBY'
path = ARGV.fetch(0)
extra_name = ARGV.fetch(1)
source = File.binread(path)
anchor = "\n  linux:\n"
abort "macOS job tail fixture did not match" unless source.include?(anchor)
name = if extra_name == "duplicate"
  "Build, test, and reject package-owned warnings"
else
  "Unreviewed platform build"
end
extra = <<~YAML.lines.map { |line| "      #{line}" }.join
  - name: #{name}
    shell: bash
    run: /usr/bin/xcodebuild -scheme Attacker -destination 'generic/platform=iOS' build
YAML
File.binwrite(path, source.sub(anchor, "\n" + extra + "  linux:\n"))
RUBY
    if [[ $extra_name == duplicate ]]; then
      expect_failure "$fixture" "$label macOS must contain exactly one reviewed build step"
    else
      expect_failure "$fixture" "$label macOS other run steps must not contain build or platform proof primitives"
    fi
  done

  for indirect_build in variable wrapper; do
    fixture=$TMP/indirect-extra-macos-build-step-${workflow%.yml}-$indirect_build
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$indirect_build" <<'RUBY'
path = ARGV.fetch(0)
indirect_build = ARGV.fetch(1)
source = File.binread(path)
anchor = "\n  linux:\n"
abort "macOS job tail fixture did not match" unless source.include?(anchor)
body = if indirect_build == "variable"
  <<~'BASH'
    TOOL="$RELEASE_SWIFT"
    "$TOOL" build
  BASH
else
  <<~'BASH'
    invoke() { "$@" build; }
    invoke "$RELEASE_SWIFT"
  BASH
end
indented_body = body.lines.map { |line| "          #{line}" }.join
extra = "      - name: Adversarial assembled build\n" \
  "        shell: bash\n" \
  "        run: |\n#{indented_body}"
File.binwrite(path, source.sub(anchor, "\n" + extra + "  linux:\n"))
RUBY
    expect_failure "$fixture" "$label macOS other run steps must not contain build or platform proof primitives"
  done

  for metadata_mutation in shell if env continue-on-error; do
    fixture=$TMP/reviewed-build-step-metadata-${workflow%.yml}-$metadata_mutation
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$metadata_mutation" <<'RUBY'
path = ARGV.fetch(0)
metadata_mutation = ARGV.fetch(1)
source = File.binread(path)
anchor = <<~'YAML'.lines.map { |line| "      #{line}" }.join
  - name: Build, test, and reject package-owned warnings
    shell: bash
    run: |
YAML
abort "reviewed build-step metadata fixture did not match" unless source.include?(anchor)
replacement = case metadata_mutation
when "shell"
  anchor.sub("shell: bash", "shell: bash -c 'exit 0' {0}")
when "if"
  anchor.sub("        run: |\n", "        if: ${{ false }}\n        run: |\n")
when "env"
  anchor.sub("        run: |\n", "        env:\n          RELEASE_SWIFT: /usr/bin/true\n        run: |\n")
when "continue-on-error"
  anchor.sub("        run: |\n", "        continue-on-error: true\n        run: |\n")
else
  abort "unknown metadata mutation"
end
File.binwrite(path, source.sub(anchor, replacement))
RUBY
    expect_failure "$fixture" "$label macOS reviewed build step metadata must be exact"
  done

  for job_control in if continue-on-error timeout env defaults-shell defaults-working-directory; do
    fixture=$TMP/macos-job-control-${workflow%.yml}-$job_control
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$job_control" <<'RUBY'
path = ARGV.fetch(0)
job_control = ARGV.fetch(1)
source = File.binread(path)
anchor = "  macos:\n"
abort "macOS job fixture did not match" unless source.include?(anchor)
control = case job_control
when "if"
  "    if: ${{ false }}\n"
when "continue-on-error"
  "    continue-on-error: true\n"
when "timeout"
  "    timeout-minutes: 1\n"
when "env"
  "    env:\n      RELEASE_SWIFT: /usr/bin/true\n"
when "defaults-shell"
  "    defaults:\n      run:\n        shell: /usr/bin/true {0}\n"
when "defaults-working-directory"
  "    defaults:\n      run:\n        working-directory: /tmp\n"
else
  abort "unknown job control"
end
File.binwrite(path, source.sub(anchor, anchor + control))
RUBY
    expect_failure "$fixture" "$label macOS job metadata must be exact"
  done

  for workflow_control in defaults-shell defaults-working-directory; do
    fixture=$TMP/workflow-control-${workflow%.yml}-$workflow_control
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$workflow_control" <<'RUBY'
path = ARGV.fetch(0)
workflow_control = ARGV.fetch(1)
source = File.binread(path)
anchor = "\njobs:\n"
abort "workflow jobs fixture did not match" unless source.include?(anchor)
setting = if workflow_control == "defaults-shell"
  "    shell: /usr/bin/true {0}\n"
else
  "    working-directory: /tmp\n"
end
defaults = "\ndefaults:\n  run:\n#{setting}jobs:\n"
File.binwrite(path, source.sub(anchor, defaults))
RUBY
    expect_failure "$fixture" "$label workflow control metadata must be exact"
  done

  for yaml_decoration in anchor explicit-tag; do
    fixture=$TMP/yaml-decoration-${workflow%.yml}-$yaml_decoration
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$yaml_decoration" <<'RUBY'
path = ARGV.fetch(0)
yaml_decoration = ARGV.fetch(1)
source = File.binread(path)
marker = yaml_decoration == "anchor" ? "&unused " : "!!str "
abort "workflow name fixture did not match" unless source.match?(/^name: /)
File.binwrite(path, source.sub(/^name: /, "name: #{marker}"))
RUBY
    if [[ $yaml_decoration == anchor ]]; then
      expect_failure "$fixture" 'YAML anchors are forbidden'
    else
      expect_failure "$fixture" 'YAML explicit tags are forbidden'
    fi
  done

  fixture=$TMP/newest-stable-runner-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = "          runner: macos-26\n"
abort "newest-stable runner fixture did not match" unless source.scan(reviewed).length == 1
File.binwrite(path, source.sub(reviewed, "          runner: self-hosted\n"))
RUBY
  expect_failure "$fixture" "$label newest-stable Apple toolchain tuple must be exact"

  for key_decoration in anchor explicit-tag; do
    fixture=$TMP/yaml-key-decoration-${workflow%.yml}-$key_decoration
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$key_decoration" <<'RUBY'
path = ARGV.fetch(0)
key_decoration = ARGV.fetch(1)
source = File.binread(path)
marker = key_decoration == "anchor" ? "&unused " : "!!str "
abort "workflow permissions key fixture did not match" unless source.match?(/^permissions:/)
File.binwrite(path, source.sub(/^permissions:/, "#{marker}permissions:"))
RUBY
    if [[ $key_decoration == anchor ]]; then
      expect_failure "$fixture" 'YAML anchors are forbidden'
    else
      expect_failure "$fixture" 'YAML explicit tags are forbidden'
    fi
  done

  fixture=$TMP/overridden-platform-sdk-path-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '            test -d "$SDK_PATH"' + "\n"
abort "SDK path validation fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, "            SDK_PATH=/tmp/attacker-sdk\n" + reviewed))
RUBY
  expect_failure "$fixture" "$label platform proof paths, triple, SDK, scratch, and simulator destination must occur exactly once"

  while IFS='|' read -r slug marker; do
    fixture=$TMP/duplicate-platform-proof-${workflow%.yml}-$slug
    make_fixture "$fixture"
    /usr/bin/ruby - "$fixture/.github/workflows/$workflow" "$marker" <<'RUBY'
path = ARGV.fetch(0)
marker = ARGV.fetch(1)
source = File.binread(path)
line = source.lines.find { |candidate| candidate.include?(marker) }
abort "platform proof cardinality fixture did not match #{marker.inspect}" unless line
File.binwrite(path, source.sub(line, line + line))
RUBY
    expect_failure "$fixture" "$label platform proof paths, triple, SDK, scratch, and simulator destination must occur exactly once"
  done <<'CASES'
sdk-path|SDK_PATH=$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-path)
directory|test -d "$SDK_PATH"
runtime|--show-sdk-version)" = '18.4'
scratch|--scratch-path .build/xcode163-iphoneos-cross
triple|--triple arm64-apple-ios18.0
sdk-argument|--sdk "$SDK_PATH"
simulator-destination|-destination 'generic/platform=iOS Simulator'
CASES
done

for api_mutation in minimum false delete-if shell continue-on-error env delete duplicate; do
  fixture=$TMP/release-api-compatibility-$api_mutation
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/release.yml" "$api_mutation" <<'RUBY'
path = ARGV.fetch(0)
api_mutation = ARGV.fetch(1)
source = File.binread(path)
anchor = <<~'YAML'.lines.map { |line| "      #{line}" }.join
  - name: Diagnose API compatibility against exact 0.1.0
    if: ${{ matrix.lane == 'newest-stable' }}
    shell: bash
    run: Scripts/run-api-compatibility.sh --current-git-checkout --breakage-allowlist-path api-breakage-allowlist.txt
YAML
abort "API compatibility step fixture did not match" unless source.scan(anchor).length == 1
replacement = case api_mutation
when "minimum"
  anchor.sub("matrix.lane == 'newest-stable'", "matrix.lane == 'minimum'")
when "false"
  anchor.sub("${{ matrix.lane == 'newest-stable' }}", "${{ false }}")
when "delete-if"
  anchor.sub("        if: ${{ matrix.lane == 'newest-stable' }}\n", "")
when "shell"
  anchor.sub("shell: bash", "shell: bash -c 'exit 0' {0}")
when "continue-on-error"
  anchor.sub("        run:", "        continue-on-error: true\n        run:")
when "env"
  anchor.sub("        run:", "        env:\n          RELEASE_SWIFT: /usr/bin/true\n        run:")
when "delete"
  ""
when "duplicate"
  anchor + anchor
else
  abort "unknown API compatibility mutation"
end
File.binwrite(path, source.sub(anchor, replacement))
RUBY
  expect_failure "$fixture" 'release API compatibility must run exactly once in newest-stable only'
done

fixture=$TMP/swift-extra-self-hosted-build-job
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/swift.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
anchor = "\n  linux:\n"
abort "Swift linux job fixture did not match" unless source.include?(anchor)
extra = <<~'YAML'.lines.map { |line| "  #{line}" }.join
  unreviewed-build:
    runs-on: self-hosted
    steps:
      - run: /usr/bin/xcodebuild -scheme Attacker build
YAML
File.binwrite(path, source.sub(anchor, "\n" + extra + "  linux:\n"))
RUBY
expect_failure "$fixture" 'Swift compatibility complete parsed workflow semantics must be exact'

fixture=$TMP/docc-validation-step-toolchain-override
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/docc.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
anchor = <<~'YAML'.lines.map { |line| "      #{line}" }.join
  - name: Validate documentation with warnings as errors
    shell: bash
    run: Scripts/validate-documentation.sh
YAML
abort "DocC validation step fixture did not match" unless source.include?(anchor)
replacement = anchor.sub(
  "        run:",
  "        env:\n          RELEASE_DEVELOPER_DIR: /Applications/Xcode_16.0.app/Contents/Developer\n        run:"
)
File.binwrite(path, source.sub(anchor, replacement))
RUBY
expect_failure "$fixture" 'DocC complete parsed workflow semantics must be exact'

fixture=$TMP/tagged-consumer-swift-override
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
anchor = <<~'YAML'.lines.map { |line| "      #{line}" }.join
  - name: Resolve and build exact public coordinate
    shell: bash
    run: |
YAML
abort "tagged consumer build step fixture did not match" unless source.include?(anchor)
replacement = anchor.sub(
  "        run: |",
  "        env:\n          RELEASE_SWIFT: /usr/bin/true\n        run: |"
)
File.binwrite(path, source.sub(anchor, replacement))
RUBY
expect_failure "$fixture" 'release complete parsed workflow semantics must be exact'

fixture=$TMP/minimum-apple-toolchain-build-drift
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = "            xcode-build: '16E140'\n"
abort "minimum Apple toolchain fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, "            xcode-build: '16E141'\n"))
RUBY
expect_failure "$fixture" 'release minimum Apple toolchain tuple must be exact Xcode 16.3'

for workflow in release.yml swift.yml; do
  case $workflow in
    release.yml) label='release matrix' ;;
    swift.yml) label='Swift compatibility matrix' ;;
  esac
  fixture=$TMP/unquoted-xcode-build-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
quoted = "            xcode-build: '16E140'\n"
abort "quoted Xcode build fixture did not match" unless source.include?(quoted)
File.binwrite(path, source.sub(quoted, "            xcode-build: 16E140\n"))
RUBY
  expect_failure "$fixture" "$label must source-quote Xcode build identity '16E140'"
done

for workflow in release.yml docc.yml; do
  case $workflow in
    release.yml) label='release tagged consumer' ;;
    docc.yml) label='DocC' ;;
  esac
  fixture=$TMP/unquoted-xcode-export-${workflow%.yml}
  make_fixture "$fixture"
  /usr/bin/ruby - "$fixture/.github/workflows/$workflow" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
quoted = "          export RELEASE_XCODE_BUILD='16E140'\n"
abort "quoted Xcode build export fixture did not match" unless source.include?(quoted)
File.binwrite(path, source.sub(quoted, "          export RELEASE_XCODE_BUILD=16E140\n"))
RUBY
  expect_failure "$fixture" "$label must source-quote Xcode build identity '16E140'"
done

fixture=$TMP/minimum-apple-toolchain-activation-drift
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/Scripts/activate-release-toolchain.sh" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = '$RELEASE_XCODE_BUILD != 16E140'
abort "minimum Apple activation fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, '$RELEASE_XCODE_BUILD != 16E141'))
RUBY
expect_failure "$fixture" 'activation minimum Apple toolchain tuple must be exact Xcode 16.3'

fixture=$TMP/release-newest-stable-test-runner-deleted
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/release.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = [
  '          else',
  '            Scripts/verify-owned-warnings.sh tests -- "$RELEASE_SWIFT" test',
  "            Scripts/verify-owned-warnings.sh dag-cbor-bridge -- \\",
  '              "$RELEASE_SWIFT" test --filter DAGCBORJSONBridgeTests',
  '          fi',
].join("\n") + "\n"
abort "release newest-stable runner fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, "          fi\n"))
RUBY
expect_failure "$fixture" 'release macOS must preserve the exact minimum/newest-stable test branch'

fixture=$TMP/swift-newest-stable-test-runner-weakened
make_fixture "$fixture"
/usr/bin/ruby - "$fixture/.github/workflows/swift.yml" <<'RUBY'
path = ARGV.fetch(0)
source = File.binread(path)
reviewed = 'Scripts/verify-owned-warnings.sh tests -- "$RELEASE_SWIFT" test'
weakened = reviewed + ' --disable-swift-testing'
abort "Swift newest-stable runner fixture did not match" unless source.include?(reviewed)
File.binwrite(path, source.sub(reviewed, weakened))
RUBY
expect_failure "$fixture" 'Swift compatibility macOS must preserve the exact minimum/newest-stable test branch'

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
