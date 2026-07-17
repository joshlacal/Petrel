#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
WORKFLOW=$ROOT/.github/workflows/release.yml

/usr/bin/ruby - "$WORKFLOW" <<'RUBY'
require "psych"

path = ARGV.fetch(0)
source = File.binread(path)
workflow = Psych.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
steps = workflow.fetch("jobs").fetch("tagged-clean-consumer").fetch("steps")
guard = steps.find { |step| step["name"] == "Validate exact release tag" }
abort "release tag guard is missing" unless guard
run = guard.fetch("run")

required = [
  "/usr/bin/git show-ref --verify --quiet refs/remotes/origin/main",
  "/usr/bin/git merge-base --is-ancestor \"$CANDIDATE_COMMIT\" refs/remotes/origin/main",
]
required.each do |command|
  abort "release tag guard is missing #{command.inspect}" unless run.include?(command)
end
abort "release tag ancestry check must not be made advisory" if
  run.match?(/merge-base[^\n]*(?:\|\||\|)[^\n]*true/)
RUBY

echo "release tag ancestry gate contracts: PASS"
