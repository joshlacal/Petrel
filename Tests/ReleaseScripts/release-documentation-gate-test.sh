#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
RELEASE_WORKFLOW=$ROOT/.github/workflows/release.yml
DOCC_WORKFLOW=$ROOT/.github/workflows/docc.yml

[[ -x $ROOT/Scripts/validate-documentation.sh ]]
[[ -x $ROOT/Scripts/tests/validate-documentation-contract.sh ]]

/usr/bin/ruby - "$RELEASE_WORKFLOW" "$DOCC_WORKFLOW" <<'RUBY'
require "psych"

release_path, docc_path = ARGV
release_source = File.binread(release_path)
docc_source = File.binread(docc_path)
release = Psych.safe_load(release_source, permitted_classes: [], permitted_symbols: [], aliases: false)
docc = Psych.safe_load(docc_source, permitted_classes: [], permitted_symbols: [], aliases: false)

abort "DocC workflow must remain read-only" unless docc.fetch("permissions") == {"contents" => "read"}
abort "DocC workflow must contain only its validation job" unless
  docc.fetch("jobs").keys == ["validate-docs"]
validate_job = docc.fetch("jobs").fetch("validate-docs")
abort "DocC validation job must not elevate permissions" if validate_job.key?("permissions")
docc_runs = validate_job.fetch("steps").map { |step| step["run"] }.compact.join("\n")
abort "DocC workflow must run the strict validator" unless
  docc_runs.include?("Scripts/validate-documentation.sh")

[
  "contents: write",
  "github.token",
  "GITHUB_TOKEN",
  "git push",
  "push origin",
  "commit -m",
].each do |forbidden|
  abort "DocC workflow contains forbidden mutation primitive #{forbidden.inspect}" if
    docc_source.include?(forbidden)
end

macos_runs = release.fetch("jobs").fetch("macos").fetch("steps").map do |step|
  step["run"]
end.compact.join("\n")
abort "macOS tag-capable release gate must run the strict DocC validator" unless
  macos_runs.include?("Scripts/validate-documentation.sh")
abort "release topology step must run the documentation validator contract" unless
  macos_runs.include?("Scripts/tests/validate-documentation-contract.sh")
abort "release topology step must run the read-only documentation gate contract" unless
  macos_runs.include?("Tests/ReleaseScripts/release-documentation-gate-test.sh")
RUBY

echo "release documentation gate contracts: PASS"
