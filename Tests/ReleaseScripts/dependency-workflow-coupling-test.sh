#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
SWIFT_WORKFLOW=$ROOT/.github/workflows/swift.yml
RELEASE_WORKFLOW=$ROOT/.github/workflows/release.yml
GATE=Scripts/tests/validate-dependency-requirements-gate-test.sh
CONTRACT=Scripts/tests/validate-dependency-requirements-contract.sh

/usr/bin/ruby - "$SWIFT_WORKFLOW" "$RELEASE_WORKFLOW" "$GATE" "$CONTRACT" <<'RUBY'
require "psych"

swift_path, release_path, gate, contract = ARGV

def load_workflow(path)
  Psych.safe_load(
    File.binread(path),
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false
  )
end

def verify_coupling(workflow, label, gate, contract, expected_condition)
  jobs = workflow.fetch("jobs")
  macos_steps = jobs.fetch("macos").fetch("steps")
  activation_index = macos_steps.index do |step|
    step["name"] == "Select and verify stable Xcode"
  end
  abort "#{label} stable Xcode activation step is missing" unless activation_index
  dependency_step = macos_steps.fetch(activation_index + 1)
  abort "#{label} dependency gate must immediately follow Xcode activation" unless
    dependency_step["name"] == "Validate bounded dependency requirements"
  abort "#{label} dependency gate has the wrong event condition" unless
    dependency_step["if"] == expected_condition
  expected_run = <<~SH
    set -euo pipefail
    /bin/test -x /usr/bin/python3
    #{gate}
    #{contract}
  SH
  abort "#{label} dependency gate has the wrong fail-closed run body" unless
    dependency_step["shell"] == "bash" && dependency_step["run"] == expected_run

  gate_occurrences = jobs.transform_values do |job|
    job.fetch("steps").sum { |step| step.fetch("run", "").scan(gate).length }
  end
  contract_occurrences = jobs.transform_values do |job|
    job.fetch("steps").sum { |step| step.fetch("run", "").scan(contract).length }
  end
  abort "#{label} must invoke each dependency script exactly once in macOS" unless
    gate_occurrences.fetch("macos") == 1 && contract_occurrences.fetch("macos") == 1
  abort "#{label} dependency scripts leaked into another job" unless
    gate_occurrences.reject { |job, _| job == "macos" }.values.all?(&:zero?) &&
      contract_occurrences.reject { |job, _| job == "macos" }.values.all?(&:zero?)
end

verify_coupling(
  load_workflow(swift_path),
  "Swift compatibility",
  gate,
  contract,
  "${{ github.event_name == 'pull_request' }}"
)
verify_coupling(
  load_workflow(release_path),
  "release",
  gate,
  contract,
  "${{ startsWith(github.ref, 'refs/tags/') }}"
)
RUBY

for workflow in \
  docc.yml \
  generator.yml \
  kotlin.yml \
  lint.yml \
  sync-lexicons.yml; do
  if /usr/bin/grep -F "$GATE" "$ROOT/.github/workflows/$workflow" >/dev/null; then
    echo "dependency gate must not run from $workflow" >&2
    exit 1
  fi
  if /usr/bin/grep -F "$CONTRACT" "$ROOT/.github/workflows/$workflow" >/dev/null; then
    echo "dependency contract must not run from $workflow" >&2
    exit 1
  fi
done

echo "dependency workflow coupling contracts: PASS"
