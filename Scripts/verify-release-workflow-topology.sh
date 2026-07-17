#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORKFLOW=$ROOT/.github/workflows/release.yml
SWIFT_WORKFLOW=$ROOT/.github/workflows/swift.yml
DOCC_WORKFLOW=$ROOT/.github/workflows/docc.yml
ACTIVATE_RELEASE_TOOLCHAIN=$ROOT/Scripts/activate-release-toolchain.sh
WORKFLOW_DIRECTORY=$ROOT/.github/workflows

required_release_executables=(
  Scripts/activate-release-toolchain.sh
  Scripts/release-tool-identity.sh
  Scripts/bootstrap-generator-environment.sh
  Scripts/bootstrap-release-tools.sh
  Scripts/extract-documentation-examples.sh
  Scripts/install-generated-documentation.sh
  Scripts/regenerate-generated.sh
  Scripts/run-api-compatibility.sh
  Scripts/validate-documentation.sh
  Scripts/verify-generator-environment.sh
  Scripts/verify-owned-warnings.sh
  Scripts/verify-release-workflow-topology.sh
  Scripts/tests/validate-dependency-requirements-contract.sh
  Scripts/tests/validate-dependency-requirements-gate-test.sh
  Scripts/tests/validate-documentation-contract.sh
  Scripts/tests/release-tool-identity-contract.sh
  Tests/ReleaseScripts/dependency-workflow-coupling-test.sh
  Tests/ReleaseScripts/install-generated-documentation-test.sh
  Tests/ReleaseScripts/owned-warning-gate-test.sh
  Tests/ReleaseScripts/release-documentation-gate-test.sh
  Tests/ReleaseScripts/release-tag-ancestry-gate-test.sh
  Tests/ReleaseScripts/workflow-topology-negative-test.sh
)

for relative in "${required_release_executables[@]}"; do
  path=$ROOT/$relative
  [[ -f $path ]] || {
    echo "required release executable is missing: $relative" >&2
    exit 1
  }
  [[ -x $path ]] || {
    echo "required release executable is not executable: $relative" >&2
    exit 1
  }
done

"$ROOT/Scripts/tests/release-tool-identity-contract.sh"

[[ -f $WORKFLOW ]] || {
  echo "release workflow is missing: $WORKFLOW" >&2
  exit 1
}
[[ -f $SWIFT_WORKFLOW ]] || {
  echo "Swift compatibility workflow is missing: $SWIFT_WORKFLOW" >&2
  exit 1
}
[[ -f $DOCC_WORKFLOW ]] || {
  echo "DocC workflow is missing: $DOCC_WORKFLOW" >&2
  exit 1
}
[[ -x /usr/bin/ruby ]] || {
  echo "/usr/bin/ruby is required to validate release workflow YAML" >&2
  exit 1
}

/usr/bin/ruby - "$WORKFLOW" "$SWIFT_WORKFLOW" "$DOCC_WORKFLOW" \
  "$WORKFLOW_DIRECTORY" "$ACTIVATE_RELEASE_TOOLCHAIN" <<'RUBY'
require "psych"
require "digest"
require "json"

canonicalize = nil
canonicalize = lambda do |value|
  case value
  when Hash
    value.keys.sort.to_h { |key| [key, canonicalize.call(value.fetch(key))] }
  when Array
    value.map { |entry| canonicalize.call(entry) }
  else
    value
  end
end
semantic_fingerprint = lambda do |value|
  Digest::SHA256.hexdigest(JSON.generate(canonicalize.call(value)))
end

workflow_path = ARGV.fetch(0)
swift_workflow_path = ARGV.fetch(1)
docc_workflow_path = ARGV.fetch(2)
workflow_directory = ARGV.fetch(3)
activation_path = ARGV.fetch(4)
source = File.binread(workflow_path)
swift_source = File.binread(swift_workflow_path)
docc_source = File.binread(docc_workflow_path)
activation_source = File.binread(activation_path)

def fail!(message)
  abort "release workflow topology: #{message}"
end

def reject_unsafe_yaml!(node)
  fail!("YAML anchors are forbidden") if node.respond_to?(:anchor) && node.anchor
  fail!("YAML explicit tags are forbidden") if node.respond_to?(:tag) && node.tag
  case node
  when Psych::Nodes::Alias
    fail!("YAML aliases are forbidden")
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key, value|
      fail!("mapping keys must be scalars") unless key.is_a?(Psych::Nodes::Scalar)
      reject_unsafe_yaml!(key)
      fail!("duplicate YAML key #{key.value.inspect}") if seen.key?(key.value)
      seen[key.value] = true
      reject_unsafe_yaml!(value)
    end
  when Psych::Nodes::Sequence
    node.children.each { |child| reject_unsafe_yaml!(child) }
  end
end

stream = Psych.parse_stream(source)
fail!("expected one YAML document") unless stream.children.length == 1
document = stream.children.fetch(0)
fail!("workflow document is empty") unless document.root
reject_unsafe_yaml!(document.root)

swift_stream = Psych.parse_stream(swift_source)
fail!("expected one Swift workflow YAML document") unless swift_stream.children.length == 1
swift_document = swift_stream.children.fetch(0)
fail!("Swift workflow document is empty") unless swift_document.root
reject_unsafe_yaml!(swift_document.root)

docc_stream = Psych.parse_stream(docc_source)
fail!("expected one DocC workflow YAML document") unless docc_stream.children.length == 1
docc_document = docc_stream.children.fetch(0)
fail!("DocC workflow document is empty") unless docc_document.root
reject_unsafe_yaml!(docc_document.root)

workflow = Psych.safe_load(
  source,
  permitted_classes: [],
  permitted_symbols: [],
  aliases: false
)
swift_workflow = Psych.safe_load(
  swift_source,
  permitted_classes: [],
  permitted_symbols: [],
  aliases: false
)
docc_workflow = Psych.safe_load(
  docc_source,
  permitted_classes: [],
  permitted_symbols: [],
  aliases: false
)
fail!("workflow root must be a mapping") unless workflow.is_a?(Hash)
fail!("Swift workflow root must be a mapping") unless swift_workflow.is_a?(Hash)
fail!("DocC workflow root must be a mapping") unless docc_workflow.is_a?(Hash)

workflow_control_fingerprints = {
  "release" => "5f179e79039184718e2190e141e43e018f33997d8af60b7ebd371cd21e769927",
  "Swift compatibility" => "5e922b17616b7bab0ae33cb90d7f4ffce6632e91eff63cf225b40d16bf1e215f",
}
[
  ["release", workflow],
  ["Swift compatibility", swift_workflow],
].each do |label, parsed_workflow|
  control_metadata = parsed_workflow.reject { |key, _| key == "jobs" }
  fail!("#{label} workflow control metadata must be exact") unless
    semantic_fingerprint.call(control_metadata) == workflow_control_fingerprints.fetch(label)
end

expected_action_pins = {
  "actions/checkout" => "34e114876b0b11c390a56381ad16ebd13914f8d5", # v4.3.1
  "actions/setup-python" => "a26af69be951a213d495a4c3e4e4022e16d87065", # v5.6.0
  "actions/setup-java" => "c1e323688fd81a25caa38c78aa6df2d33d3e20d9", # v4.8.0
  "gradle/actions/setup-gradle" => "748248ddd2a24f49513d8f472f81c3a07d4d50e1", # v4.4.4
  "peter-evans/create-pull-request" => "22a9089034f40e5a961c8808d113e2c98fb63676", # v7.0.11
  "anthropics/claude-code-action" => "1298632ce7736903d02a1435002705aa2a594a6c", # v1.0.175
}
loaded_workflows = {}
workflow_paths = Dir.glob([
  File.join(workflow_directory, "*.yml"),
  File.join(workflow_directory, "*.yaml"),
]).sort
expected_workflow_inventory = [
  "claude-code-review.yml",
  "claude.yml",
  "docc.yml",
  "generator.yml",
  "kotlin.yml",
  "lint.yml",
  "release.yml",
  "swift.yml",
  "sync-lexicons.yml",
]
claude_workflow_inventory = ["claude-code-review.yml", "claude.yml"]
actual_workflow_inventory = workflow_paths.map { |path| File.basename(path) }
fail!("workflow inventory differs from #{expected_workflow_inventory.inspect}") unless
  actual_workflow_inventory == expected_workflow_inventory

workflow_paths.each do |path|
  label = File.basename(path)
  body = File.binread(path)
  parsed = Psych.parse_stream(body)
  fail!("#{label} must contain exactly one YAML document") unless parsed.children.length == 1
  root = parsed.children.fetch(0).root
  fail!("#{label} workflow document is empty") unless root
  reject_unsafe_yaml!(root)
  loaded = Psych.safe_load(body, permitted_classes: [], permitted_symbols: [], aliases: false)
  fail!("#{label} workflow root must be a mapping") unless loaded.is_a?(Hash)
  loaded_workflows[label] = loaded

  jobs_for_security = loaded["jobs"]
  fail!("#{label} jobs must be a mapping") unless jobs_for_security.is_a?(Hash)
  jobs_for_security.each do |job_name, job|
    fail!("#{label} #{job_name} must not declare job-level permissions") if
      job.key?("permissions") && !claude_workflow_inventory.include?(label)
    steps = job["steps"]
    fail!("#{label} #{job_name} steps must be an array") unless steps.is_a?(Array)
    steps.each do |step|
      next unless step.is_a?(Hash) && step["uses"].is_a?(String)

      action, revision = step["uses"].split("@", 2)
      expected_revision = expected_action_pins[action]
      fail!("#{label} uses an unreviewed action #{action.inspect}") unless expected_revision
      fail!("#{label} action #{action} is not pinned to the reviewed commit") unless
        revision == expected_revision
      if action == "actions/checkout"
        checkout_with = step["with"]
        fail!("#{label} #{job_name} checkout must define with") unless checkout_with.is_a?(Hash)
        fail!("#{label} #{job_name} checkout must disable persisted credentials") unless
          checkout_with["persist-credentials"] == false
      end
    end
  end
end

read_only_permissions = {"contents" => "read"}
["docc.yml", "generator.yml", "kotlin.yml", "lint.yml", "release.yml", "swift.yml"].each do |label|
  fail!("#{label} must use read-only default permissions") unless
    loaded_workflows.fetch(label)["permissions"] == read_only_permissions
end
expected_claude_permissions = {
  "contents" => "read",
  "pull-requests" => "read",
  "issues" => "read",
  "id-token" => "write",
}
claude_review_workflow = loaded_workflows.fetch("claude-code-review.yml")
fail!("claude-code-review.yml top-level topology must be exact") unless
  claude_review_workflow.keys == ["name", "on", "permissions", "jobs"] &&
    claude_review_workflow["name"] == "Claude Code Review"
expected_claude_review_triggers = {
  "pull_request" => {
    "types" => ["opened", "synchronize", "ready_for_review", "reopened"],
  },
}
fail!("claude-code-review.yml triggers must be exact") unless
  claude_review_workflow["on"] == expected_claude_review_triggers
fail!("claude-code-review.yml must deny permissions by default") unless
  claude_review_workflow["permissions"] == {}
fail!("claude-code-review.yml must define exactly the reviewed job") unless
  claude_review_workflow.fetch("jobs").keys == ["claude-review"]
claude_review_job = claude_review_workflow.fetch("jobs").fetch("claude-review")
fail!("claude-code-review.yml job topology must be exact") unless
  claude_review_job.keys == ["runs-on", "permissions", "steps"]
fail!("claude-code-review.yml runner must be exact") unless
  claude_review_job["runs-on"] == "ubuntu-24.04"
fail!("claude-code-review.yml must use the exact reviewed job permissions") unless
  claude_review_job["permissions"] == expected_claude_permissions
expected_checkout_step = {
  "name" => "Checkout repository",
  "uses" => "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
  "with" => {"fetch-depth" => 1, "persist-credentials" => false},
}
claude_review_steps = claude_review_job.fetch("steps")
fail!("claude-code-review.yml step inventory must be exact") unless
  claude_review_steps.length == 2 &&
    claude_review_steps.fetch(0) == expected_checkout_step &&
    claude_review_steps.fetch(1).keys == ["name", "id", "uses", "with"] &&
    claude_review_steps.fetch(1).slice("name", "id", "uses") == {
      "name" => "Run Claude Code Review",
      "id" => "claude-review",
      "uses" => "anthropics/claude-code-action@1298632ce7736903d02a1435002705aa2a594a6c",
    }
expected_claude_review_inputs = {
  "claude_code_oauth_token" => "${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}",
  "prompt" => "Review this pull request for correctness and security. Report actionable findings with severity and file/line evidence.",
}
fail!("claude-code-review.yml action inputs must be the exact reviewed allowlist") unless
  claude_review_steps.fetch(1)["with"] == expected_claude_review_inputs
expected_interactive_claude_permissions = expected_claude_permissions.merge("actions" => "read")
interactive_claude_workflow = loaded_workflows.fetch("claude.yml")
fail!("claude.yml top-level topology must be exact") unless
  interactive_claude_workflow.keys == ["name", "on", "permissions", "jobs"] &&
    interactive_claude_workflow["name"] == "Claude Code"
expected_interactive_claude_triggers = {
  "issue_comment" => {"types" => ["created"]},
  "pull_request_review_comment" => {"types" => ["created"]},
  "issues" => {"types" => ["opened", "assigned"]},
  "pull_request_review" => {"types" => ["submitted"]},
}
fail!("claude.yml triggers must be exact") unless
  interactive_claude_workflow["on"] == expected_interactive_claude_triggers
fail!("claude.yml must deny permissions by default") unless
  interactive_claude_workflow["permissions"] == {}
fail!("claude.yml must define exactly the reviewed job") unless
  interactive_claude_workflow.fetch("jobs").keys == ["claude"]
interactive_claude_job = interactive_claude_workflow.fetch("jobs").fetch("claude")
fail!("claude.yml job topology must be exact") unless
  interactive_claude_job.keys == ["if", "runs-on", "permissions", "steps"]
expected_interactive_condition = [
  "(github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||",
  "(github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||",
  "(github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||",
  "(github.event_name == 'issues' && (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')))",
].join("\n") + "\n"
fail!("claude.yml job condition must be exact") unless
  interactive_claude_job["if"] == expected_interactive_condition
fail!("claude.yml runner must be exact") unless
  interactive_claude_job["runs-on"] == "ubuntu-24.04"
fail!("claude.yml must use the exact reviewed job permissions") unless
  interactive_claude_job["permissions"] == expected_interactive_claude_permissions
interactive_claude_steps = interactive_claude_job.fetch("steps")
fail!("claude.yml step inventory must be exact") unless
  interactive_claude_steps.length == 2 &&
    interactive_claude_steps.fetch(0) == expected_checkout_step &&
    interactive_claude_steps.fetch(1).keys == ["name", "id", "uses", "with"] &&
    interactive_claude_steps.fetch(1).slice("name", "id", "uses") == {
      "name" => "Run Claude Code",
      "id" => "claude",
      "uses" => "anthropics/claude-code-action@1298632ce7736903d02a1435002705aa2a594a6c",
    }
expected_interactive_claude_inputs = {
  "claude_code_oauth_token" => "${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}",
  "additional_permissions" => "actions: read\n",
}
fail!("claude.yml action inputs must be the exact reviewed allowlist") unless
  interactive_claude_steps.fetch(1)["with"] == expected_interactive_claude_inputs
expected_sync_permissions = {"contents" => "write", "pull-requests" => "write"}
sync_workflow = loaded_workflows.fetch("sync-lexicons.yml")
fail!("sync-lexicons.yml permissions must be the exact PR-writing set") unless
  sync_workflow["permissions"] == expected_sync_permissions
sync_events = sync_workflow["on"]
expected_sync_events = ["schedule", "workflow_dispatch"]
fail!("sync workflow events must be exactly schedule and workflow_dispatch") unless
  sync_events.is_a?(Hash) && sync_events.keys == expected_sync_events
fail!("sync workflow schedule must remain the reviewed weekly cron") unless
  sync_events["schedule"] == [{"cron" => "17 6 * * 1"}]
sync_steps = sync_workflow.fetch("jobs").fetch("sync").fetch("steps")
create_pr_steps = sync_steps.select do |step|
  step.is_a?(Hash) && step["uses"].to_s.start_with?("peter-evans/create-pull-request@")
end
fail!("sync workflow must have exactly one create-pull-request action") unless create_pr_steps.length == 1
create_pr_step = create_pr_steps.fetch(0)
fail!("create-pull-request token must be scoped to its final action") unless
  create_pr_step.fetch("with", {})["token"] == "${{ github.token }}"
sync_steps.each do |step|
  next if step.equal?(create_pr_step)
  fail!("sync token must not be exposed before create-pull-request") if
    step.to_s.include?("${{ github.token }}")
end

fail!("Kotlin workflow runner must be ubuntu-24.04") unless
  loaded_workflows.fetch("kotlin.yml").dig("jobs", "build", "runs-on") == "ubuntu-24.04"
fail!("lint hygiene runner must be ubuntu-24.04") unless
  loaded_workflows.fetch("lint.yml").dig("jobs", "hygiene", "runs-on") == "ubuntu-24.04"

expected_permissions = {"contents" => "read"}
fail!("workflow permissions must be contents: read") unless workflow["permissions"] == expected_permissions
fail!("Swift workflow permissions must be contents: read") unless swift_workflow["permissions"] == expected_permissions
fail!("DocC default permissions must be contents: read") unless docc_workflow["permissions"] == expected_permissions
fail!("expected release version must be exactly 0.2.0") unless workflow.dig("env", "EXPECTED_RELEASE_VERSION") == "0.2.0"
jobs = workflow["jobs"]
fail!("jobs must be a mapping") unless jobs.is_a?(Hash)

expected_jobs = ["macos", "linux", "tagged-clean-consumer"]
fail!("job IDs or order differ from #{expected_jobs.inspect}") unless jobs.keys == expected_jobs

macos = jobs.fetch("macos")
linux = jobs.fetch("linux")
tagged = jobs.fetch("tagged-clean-consumer")
fail!("macos must not declare needs") if macos.key?("needs")
fail!("linux must not declare needs") if linux.key?("needs")
fail!("tagged-clean-consumer needs must be [macos, linux]") unless tagged["needs"] == ["macos", "linux"]
expected_if = "${{ startsWith(github.ref, 'refs/tags/') }}"
fail!("tagged-clean-consumer has the wrong condition") unless tagged["if"] == expected_if

tagged_steps = tagged.fetch("steps")
tag_guard = tagged_steps.fetch(1)
fail!("tag guard must be the first step after checkout") unless tag_guard["name"] == "Validate exact release tag"
tag_guard_run = tag_guard["run"]
fail!("tag guard run body is missing") unless tag_guard_run.is_a?(String)
[
  "GITHUB_REF_NAME",
  "EXPECTED_RELEASE_VERSION",
  "CANDIDATE_COMMIT",
  "rev-parse HEAD",
  "rev-parse \"$GITHUB_REF_NAME^{commit}\"",
  "/usr/bin/git show-ref --verify --quiet refs/remotes/origin/main",
  "/usr/bin/git merge-base --is-ancestor \"$CANDIDATE_COMMIT\" refs/remotes/origin/main",
].each do |required|
  fail!("tag guard is missing #{required.inspect}") unless tag_guard_run.include?(required)
end

expected_checkout = "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
expected_setup_python = "actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065"

jobs.each do |job_name, job|
  steps = job["steps"]
  fail!("#{job_name} steps must be an array") unless steps.is_a?(Array)
  checkouts = steps.select do |step|
    step.is_a?(Hash) && step["uses"].is_a?(String) && step["uses"].start_with?("actions/checkout@")
  end
  fail!("#{job_name} must have exactly one checkout action") unless checkouts.length == 1
  fail!("#{job_name} checkout is not pinned to reviewed checkout v4.3.1") unless checkouts.fetch(0)["uses"] == expected_checkout
  checkout_with = checkouts.fetch(0)["with"]
  fail!("#{job_name} checkout must define with.fetch-depth") unless checkout_with.is_a?(Hash)
  fail!("#{job_name} checkout fetch-depth must stringify to 0") unless checkout_with["fetch-depth"].to_s == "0"
  fail!("#{job_name} checkout must disable persisted credentials") unless checkout_with["persist-credentials"] == false
end

setup_python = macos.fetch("steps").select do |step|
  step.is_a?(Hash) && step["uses"].is_a?(String) && step["uses"].start_with?("actions/setup-python@")
end
fail!("macos must have exactly one setup-python action") unless setup_python.length == 1
fail!("setup-python is not pinned to reviewed v5.6.0") unless setup_python.fetch(0)["uses"] == expected_setup_python

macos_run_source = macos.fetch("steps").map do |step|
  step.is_a?(Hash) ? step.fetch("run", "") : ""
end.join("\n")
[
  "Scripts/verify-release-workflow-topology.sh",
  "Tests/ReleaseScripts/workflow-topology-negative-test.sh",
  "Tests/ReleaseScripts/owned-warning-gate-test.sh",
  "Tests/ReleaseScripts/install-generated-documentation-test.sh",
  "Tests/ReleaseScripts/dependency-workflow-coupling-test.sh",
  "Scripts/tests/validate-dependency-requirements-gate-test.sh",
  "Scripts/tests/validate-dependency-requirements-contract.sh",
  "Scripts/tests/validate-documentation-contract.sh",
  "Tests/ReleaseScripts/release-documentation-gate-test.sh",
  "Tests/ReleaseScripts/release-tag-ancestry-gate-test.sh",
  "Scripts/validate-documentation.sh",
].each do |required|
  fail!("macos release gate does not execute #{required.inspect}") unless macos_run_source.include?(required)
end

swift_jobs = swift_workflow["jobs"]
fail!("Swift workflow jobs must be a mapping") unless swift_jobs.is_a?(Hash)
swift_checkouts = swift_jobs.flat_map do |job_name, job|
  steps = job["steps"]
  fail!("Swift #{job_name} steps must be an array") unless steps.is_a?(Array)
  steps.select do |step|
    step.is_a?(Hash) && step["uses"].is_a?(String) && step["uses"].start_with?("actions/checkout@")
  end
end
fail!("Swift workflow must have exactly two checkout actions") unless swift_checkouts.length == 2
swift_checkouts.each do |checkout|
  fail!("Swift checkout is not pinned to reviewed checkout v4.3.1") unless checkout["uses"] == expected_checkout
  checkout_with = checkout["with"]
  fail!("Swift checkout must define with") unless checkout_with.is_a?(Hash)
  fail!("Swift checkout fetch-depth must stringify to 0") unless checkout_with["fetch-depth"].to_s == "0"
  fail!("Swift checkout must disable persisted credentials") unless checkout_with["persist-credentials"] == false
end

dependency_gate = "Scripts/tests/validate-dependency-requirements-gate-test.sh"
dependency_contract = "Scripts/tests/validate-dependency-requirements-contract.sh"
[
  ["release", jobs, "${{ startsWith(github.ref, 'refs/tags/') }}"],
  ["Swift compatibility", swift_jobs, "${{ github.event_name == 'pull_request' }}"],
].each do |label, workflow_jobs, expected_condition|
  workflow_macos_steps = workflow_jobs.fetch("macos").fetch("steps")
  activation_index = workflow_macos_steps.index do |step|
    step["name"] == "Select and verify stable Xcode"
  end
  fail!("#{label} stable Xcode activation step is missing") unless activation_index
  dependency_step = workflow_macos_steps.fetch(activation_index + 1)
  fail!("#{label} dependency gate must immediately follow Xcode activation") unless
    dependency_step["name"] == "Validate bounded dependency requirements"
  fail!("#{label} dependency gate has the wrong event condition") unless
    dependency_step["if"] == expected_condition
  expected_dependency_run = [
    "set -euo pipefail",
    "/bin/test -x /usr/bin/python3",
    dependency_gate,
    dependency_contract,
  ].join("\n") + "\n"
  fail!("#{label} dependency gate has the wrong fail-closed run body") unless
    dependency_step["shell"] == "bash" && dependency_step["run"] == expected_dependency_run

  gate_occurrences = workflow_jobs.transform_values do |job|
    job.fetch("steps").sum do |step|
      step.is_a?(Hash) ? step.fetch("run", "").scan(dependency_gate).length : 0
    end
  end
  contract_occurrences = workflow_jobs.transform_values do |job|
    job.fetch("steps").sum do |step|
      step.is_a?(Hash) ? step.fetch("run", "").scan(dependency_contract).length : 0
    end
  end
  fail!("#{label} must invoke each dependency script exactly once in macOS") unless
    gate_occurrences.fetch("macos") == 1 && contract_occurrences.fetch("macos") == 1
  fail!("#{label} dependency scripts must not run in another job") unless
    gate_occurrences.reject { |job, _| job == "macos" }.values.all?(&:zero?) &&
      contract_occurrences.reject { |job, _| job == "macos" }.values.all?(&:zero?)
end

["docc.yml", "generator.yml", "kotlin.yml", "lint.yml", "sync-lexicons.yml"].each do |label|
  body = File.binread(File.join(workflow_directory, label))
  fail!("dependency gate must not run from #{label}") if body.include?(dependency_gate)
  fail!("dependency contract must not run from #{label}") if body.include?(dependency_contract)
end

docc_events = docc_workflow["on"]
fail!("DocC events must be a mapping") unless docc_events.is_a?(Hash)
expected_docc_events = ["push", "pull_request", "workflow_dispatch"]
fail!("DocC events or order differ from #{expected_docc_events.inspect}") unless docc_events.keys == expected_docc_events
docc_jobs = docc_workflow["jobs"]
fail!("DocC jobs must be a mapping") unless docc_jobs.is_a?(Hash)
expected_docc_jobs = ["validate-docs"]
fail!("DocC jobs or order differ from #{expected_docc_jobs.inspect}") unless docc_jobs.keys == expected_docc_jobs
validate_docs = docc_jobs.fetch("validate-docs")
fail!("DocC validation must run on macos-15") unless validate_docs["runs-on"] == "macos-15"
fail!("DocC validation must inherit read-only permissions") if validate_docs.key?("permissions")
fail!("DocC validation must run for every configured event") if validate_docs.key?("if")

docc_jobs.each do |job_name, job|
  steps = job["steps"]
  fail!("DocC #{job_name} steps must be an array") unless steps.is_a?(Array)
  checkouts = steps.select do |step|
    step.is_a?(Hash) && step["uses"].is_a?(String) && step["uses"].start_with?("actions/checkout@")
  end
  fail!("DocC #{job_name} must have exactly one checkout") unless checkouts.length == 1
  checkout = checkouts.fetch(0)
  fail!("DocC #{job_name} checkout is not pinned") unless checkout["uses"] == expected_checkout
  checkout_with = checkout["with"]
  fail!("DocC #{job_name} checkout must define with") unless checkout_with.is_a?(Hash)
  fail!("DocC #{job_name} checkout must disable persisted credentials") unless checkout_with["persist-credentials"] == false
end

validate_run_source = validate_docs.fetch("steps").map do |step|
  step.is_a?(Hash) ? step.fetch("run", "") : ""
end.join("\n")
fail!("DocC validation must use the strict validator") unless validate_run_source.include?("Scripts/validate-documentation.sh")
[
  "contents: write",
  "github.token",
  "GITHUB_TOKEN",
  "git push",
  "push origin",
  "commit -m",
].each do |forbidden|
  fail!("DocC workflow contains forbidden mutation primitive #{forbidden.inspect}") if
    docc_source.include?(forbidden)
end

matrix = macos.dig("strategy", "matrix")
fail!("macos matrix must contain only include") unless matrix.is_a?(Hash) && matrix.keys == ["include"]
rows = matrix.fetch("include")
fail!("macos matrix include must be an array") unless rows.is_a?(Array)
lanes = rows.map { |row| row.is_a?(Hash) ? row["lane"] : nil }
fail!("macos lanes must be [minimum, newest-stable]") unless lanes == ["minimum", "newest-stable"]

swift_rows = swift_jobs.fetch("macos").dig("strategy", "matrix", "include")
expected_macos_test_branch = <<~'BASH'.chomp
  if [[ $RELEASE_TOOLCHAIN_LANE == minimum ]]; then
    Scripts/verify-owned-warnings.sh xctest -- \
      "$RELEASE_SWIFT" test --no-parallel --enable-xctest --disable-swift-testing
    Scripts/verify-owned-warnings.sh swift-testing -- \
      "$RELEASE_SWIFT" test --no-parallel --disable-xctest --enable-swift-testing
    Scripts/verify-owned-warnings.sh dag-cbor-bridge -- \
      "$RELEASE_SWIFT" test --no-parallel --disable-xctest --enable-swift-testing \
        --filter DAGCBORJSONBridgeTests
  else
    Scripts/verify-owned-warnings.sh tests -- "$RELEASE_SWIFT" test
    Scripts/verify-owned-warnings.sh dag-cbor-bridge -- \
      "$RELEASE_SWIFT" test --filter DAGCBORJSONBridgeTests
  fi
BASH
# Pin the complete parsed semantics and order of every non-build macOS step.
# This closes shell-indirection and custom-action bypasses that command-pattern
# matching cannot enumerate; the reviewed build step is validated in full below.
expected_other_step_fingerprints = {
  "release" => [
    [nil, "c65f56c49a3c60ab4b32db846bbbe9c6adbe219ad18ad3ed536607646e09b893"],
    ["Verify release workflow topology", "c6a141e807793165b1fc9aebb21638b4e1fa353d80e5665eb2cd942207841d23"],
    [nil, "8ab62dfbc944c92aa4e154d38a5d08610976cddfad2947379f289a780e4e5206"],
    ["Select and verify stable Xcode", "15a5f87efdd4340fbd074edd46e061f0a64aed62295a3649cd9da95dec0f6794"],
    ["Validate bounded dependency requirements", "bf334e37ae97804ac15ad186b867d758f1bacb6c5063c1edec589bb5c9d4bc4c"],
    ["Bootstrap locked generator and release tools", "c5795d8ed5ead5b43ae4f3b71e9ff4702e1462bf7925f159d9363eeb28402e0c"],
    ["Run generator tests and verify deterministic projection", "afaacdedf8ac411eccbfeb43b313eccfde75a3519dbb7336519ab57c00874eb2"],
    ["Validate documentation and compile public examples", "87d9ad80d8e7932d6281a6f94765d84cd38fc054da2c7b29284f6302c20975da"],
    ["Diagnose API compatibility against exact 0.1.0", "e1a5d999d2c19b7cf931236e6fc421aa224af5379355257f254cd786fc08ebce"],
  ],
  "Swift compatibility" => [
    [nil, "c65f56c49a3c60ab4b32db846bbbe9c6adbe219ad18ad3ed536607646e09b893"],
    ["Select and verify stable Xcode", "8803b99e5bf8a298edfc72ee540b0df979535657b20f60be8bc609368c0a11be"],
    ["Validate bounded dependency requirements", "7e0b66384a3edb57d48fb803d5cb694c870457950bbd10388befe913d8c781ca"],
  ],
}
expected_macos_job_names = {
  "release" => "macOS release gate (${{ matrix.lane }})",
  "Swift compatibility" => "macOS (${{ matrix.lane }})",
}
[
  ["release", macos],
  ["Swift compatibility", swift_jobs.fetch("macos")],
].each do |label, job|
  strategy = job["strategy"]
  fail!("#{label} macOS job metadata must be exact") unless
    job.keys.sort == ["name", "runs-on", "steps", "strategy"] &&
      job["name"] == expected_macos_job_names.fetch(label) &&
      job["runs-on"] == "${{ matrix.runner }}" &&
      strategy.is_a?(Hash) &&
      strategy.keys.sort == ["fail-fast", "matrix"] &&
      strategy["fail-fast"] == false
  macos_steps = job.fetch("steps")
  build_steps = macos_steps.select do |step|
    step["name"] == "Build, test, and reject package-owned warnings"
  end
  fail!("#{label} macOS must contain exactly one reviewed build step") unless
    build_steps.length == 1
  build_step = build_steps.fetch(0)
  build_step_metadata = build_step.reject { |key, _| key == "run" }
  expected_build_step_metadata = {
    "name" => "Build, test, and reject package-owned warnings",
    "shell" => "bash",
  }
  fail!("#{label} macOS reviewed build step metadata must be exact") unless
    build_step_metadata == expected_build_step_metadata
  build_run = build_step.fetch("run")
  if label == "release"
    api_compatibility_steps = macos_steps.select do |step|
      step.is_a?(Hash) && step["name"] == "Diagnose API compatibility against exact 0.1.0"
    end
    expected_api_compatibility_step = {
      "name" => "Diagnose API compatibility against exact 0.1.0",
      "if" => "${{ matrix.lane == 'newest-stable' }}",
      "shell" => "bash",
      "run" => "Scripts/run-api-compatibility.sh --current-git-checkout --breakage-allowlist-path api-breakage-allowlist.txt",
    }
    fail!("release API compatibility must run exactly once in newest-stable only") unless
      api_compatibility_steps == [expected_api_compatibility_step]
  end
  other_step_fingerprints = macos_steps.reject { |step| step.equal?(build_step) }.map do |step|
    canonical_step = JSON.generate(canonicalize.call(step))
    [step["name"], Digest::SHA256.hexdigest(canonical_step)]
  end
  fail!("#{label} macOS other run steps must not contain build or platform proof primitives") unless
    other_step_fingerprints == expected_other_step_fingerprints.fetch(label)
  fail!("#{label} macOS must preserve the exact minimum/newest-stable test branch") unless
    build_run.scan(expected_macos_test_branch).length == 1
  expected_platform_proof = <<~'BASH'.chomp
    if [[ $RELEASE_TOOLCHAIN_LANE == minimum ]]; then
      SDK_PATH=$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-path)
      test -d "$SDK_PATH"
      test "$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-version)" = '18.4'
      "$RELEASE_SWIFT" build \
        --scratch-path .build/xcode163-iphoneos-cross \
        --triple arm64-apple-ios18.0 \
        --sdk "$SDK_PATH"
    else
      Scripts/verify-owned-warnings.sh ios-simulator -- "$RELEASE_XCODEBUILD" \
        -scheme Petrel \
        -destination 'generic/platform=iOS Simulator' \
        build
    fi
  BASH
  cardinality_fragments = [
    'SDK_PATH=$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-path)',
    'test -d "$SDK_PATH"',
    'test "$("$RELEASE_XCRUN" --sdk iphoneos --show-sdk-version)" = \'18.4\'',
    "  \"$RELEASE_SWIFT\" build \\\n",
    '--scratch-path .build/xcode163-iphoneos-cross',
    '--triple arm64-apple-ios18.0',
    '--sdk "$SDK_PATH"',
    'Scripts/verify-owned-warnings.sh ios-simulator -- "$RELEASE_XCODEBUILD"',
    "-destination 'generic/platform=iOS Simulator'",
  ]
  fail!("#{label} platform proof paths, triple, SDK, scratch, and simulator destination must occur exactly once") unless
    cardinality_fragments.all? { |fragment| build_run.scan(fragment).length == 1 } &&
      build_run.scan("SDK_PATH=").length == 1
  fail!("#{label} platform proof must keep minimum SwiftPM-cross and newest simulator xcodebuild isolated") unless
    build_run.scan(expected_platform_proof).length == 1
  outside_platform_proof = build_run.sub(expected_platform_proof, "")
  forbidden_outside = [
    'SDK_PATH',
    'iphoneos',
    '--scratch-path',
    '--triple',
    '--sdk',
    '-destination',
    'RELEASE_XCODEBUILD',
    'xcodebuild',
  ]
  expected_common_swift_builds = [
    'Scripts/verify-owned-warnings.sh debug-build -- "$RELEASE_SWIFT" build',
    'Scripts/verify-owned-warnings.sh release-build -- "$RELEASE_SWIFT" build -c release',
  ]
  common_builds_exact = expected_common_swift_builds.all? do |command|
    outside_platform_proof.scan(command).length == 1
  end
  unreviewed_builds = expected_common_swift_builds.reduce(outside_platform_proof) do |body, command|
    body.sub(command, "")
  end
  alternate_swift_build =
    unreviewed_builds.match?(/(?<![[:alnum:]_])swift["'}]*[[:space:]]+build\b/i) ||
    unreviewed_builds.match?(/RELEASE_SWIFT["'}]*[[:space:]]+build\b/)
  fail!("#{label} platform proof commands must not occur outside reviewed lane conditional") if
    forbidden_outside.any? { |fragment| outside_platform_proof.include?(fragment) } ||
      !common_builds_exact || alternate_swift_build
  expected_build_run = [
    "set -euo pipefail",
    'Scripts/verify-owned-warnings.sh debug-build -- "$RELEASE_SWIFT" build',
    expected_macos_test_branch,
    'Scripts/verify-owned-warnings.sh release-build -- "$RELEASE_SWIFT" build -c release',
    expected_platform_proof,
  ].join("\n") + "\n"
  fail!("#{label} platform proof commands must not occur outside reviewed lane conditional") unless
    build_run == expected_build_run
end

expected_minimum_apple_tuple = {
  "lane" => "minimum",
  "runner" => "macos-15",
  "selection" => "pinned-minimum",
  "evidence-class" => "stable-release",
  "developer-dir" => "/Applications/Xcode_16.3.app/Contents/Developer",
  "xcode-version" => "16.3",
  "xcode-build" => "16E140",
  "deployment-target" => "18.0",
  "ios-runtime" => "18.4",
  "watchos-runtime" => "11.4",
  "tvos-runtime" => "18.4",
  "visionos-runtime" => "2.4",
}
expected_newest_stable_apple_tuple = {
  "lane" => "newest-stable",
  "runner" => "macos-26",
  "selection" => "official-runner-inventory",
  "evidence-class" => "stable-release",
  "developer-dir" => "/Applications/Xcode_26.6.app/Contents/Developer",
  "xcode-version" => "26.6",
  "xcode-build" => "17F113",
  "deployment-target" => "18.0",
  "ios-runtime" => "26.5",
  "watchos-runtime" => "26.5",
  "tvos-runtime" => "26.5",
  "visionos-runtime" => "26.5",
}
[
  ["release", rows.fetch(0)],
  ["Swift compatibility", swift_rows.fetch(0)],
].each do |label, minimum_row|
  fail!("#{label} minimum Apple toolchain tuple must be exact Xcode 16.3") unless
    minimum_row == expected_minimum_apple_tuple
end
[
  ["release", rows.fetch(1)],
  ["Swift compatibility", swift_rows.fetch(1)],
].each do |label, newest_row|
  fail!("#{label} newest-stable Apple toolchain tuple must be exact") unless
    newest_row == expected_newest_stable_apple_tuple
end

[
  ["release matrix", source, "xcode-build: '16E140'", 1],
  ["Swift compatibility matrix", swift_source, "xcode-build: '16E140'", 1],
  ["release tagged consumer", source, "export RELEASE_XCODE_BUILD='16E140'", 1],
  ["DocC", docc_source, "export RELEASE_XCODE_BUILD='16E140'", 1],
].each do |label, workflow_source, required, count|
  fail!("#{label} must source-quote Xcode build identity '16E140'") unless
    workflow_source.scan(required).length == count
end

expected_minimum_exports = [
  "export RELEASE_DEVELOPER_DIR=/Applications/Xcode_16.3.app/Contents/Developer",
  "export RELEASE_XCODE_VERSION=16.3",
  "export RELEASE_XCODE_BUILD='16E140'",
  "export RELEASE_IOS_RUNTIME=18.4",
  "export RELEASE_WATCHOS_RUNTIME=11.4",
  "export RELEASE_TVOS_RUNTIME=18.4",
  "export RELEASE_VISIONOS_RUNTIME=2.4",
]
[["DocC", validate_run_source]].each do |label, run_source|
  expected_minimum_exports.each do |required|
    fail!("#{label} minimum Apple toolchain tuple must be exact Xcode 16.3") unless
      run_source.scan(required).length == 1
  end
end

expected_activation_tuple = [
  '$RELEASE_DEVELOPER_DIR != /Applications/Xcode_16.3.app/Contents/Developer',
  '$RELEASE_XCODE_VERSION != 16.3',
  '$RELEASE_XCODE_BUILD != 16E140',
  '${RELEASE_IOS_RUNTIME:-} != 18.4',
  '${RELEASE_WATCHOS_RUNTIME:-} != 11.4',
  '${RELEASE_TVOS_RUNTIME:-} != 18.4',
  '${RELEASE_VISIONOS_RUNTIME:-} != 2.4',
]
expected_activation_tuple.each do |required|
  fail!("activation minimum Apple toolchain tuple must be exact Xcode 16.3") unless
    activation_source.scan(required).length == 1
end

minimum_test_commands = [
  '"$RELEASE_SWIFT" test --no-parallel --enable-xctest --disable-swift-testing',
  '"$RELEASE_SWIFT" test --no-parallel --disable-xctest --enable-swift-testing',
]
[
  ["release macOS", macos],
  ["Swift compatibility macOS", swift_jobs.fetch("macos")],
].each do |label, job|
  run_source = job.fetch("steps").map do |step|
    step.is_a?(Hash) ? step.fetch("run", "") : ""
  end.join("\n")
  fail!("#{label} must preserve the exact minimum/newest-stable test branch") unless
    run_source.scan(expected_macos_test_branch).length == 1
end

[
  ["release Linux", linux],
  ["Swift compatibility Linux", swift_jobs.fetch("linux")],
].each do |label, job|
  run_source = job.fetch("steps").map do |step|
    step.is_a?(Hash) ? step.fetch("run", "") : ""
  end.join("\n")
  minimum_test_commands.each do |command|
    fail!("#{label} is missing serialized minimum test command #{command.inspect}") unless
      run_source.include?(command)
  end
end

expected_container = "swift:6.0.3-jammy@sha256:f0bfe313779a0bb99db87f97c88ea6ada014aa6b3359f9c5583bf70b0b721217"
fail!("linux container is not the pinned Swift image") unless linux["container"] == expected_container

consumer = "Tests/ReleaseConsumers/PetrelURLConsumer"
run_occurrences = {}
jobs.each do |job_name, job|
  run_occurrences[job_name] = job.fetch("steps").sum do |step|
    step.is_a?(Hash) ? step.fetch("run", "").scan(consumer).length : 0
  end
end
fail!("consumer path appears in a pre-tag job") unless run_occurrences["macos"] == 0 && run_occurrences["linux"] == 0
fail!("consumer path is absent from tagged-clean-consumer run steps") unless run_occurrences["tagged-clean-consumer"] > 0
fail!("consumer path occurs outside tagged-clean-consumer run steps") unless source.scan(consumer).length == run_occurrences["tagged-clean-consumer"]

tagged_run_source = tagged_steps.map do |step|
  step.is_a?(Hash) ? step.fetch("run", "") : ""
end.join("\n")
expected_minimum_exports.each do |required|
  fail!("tagged clean consumer minimum Apple toolchain tuple must be exact Xcode 16.3") unless
    tagged_run_source.scan(required).length == 1
end
[
  "Package.resolved",
  "EXPECTED_RELEASE_VERSION",
  "CANDIDATE_COMMIT",
  'state.fetch("version")',
  'state.fetch("revision")',
].each do |required|
  fail!("tagged consumer does not verify #{required.inspect}") unless tagged_run_source.include?(required)
end

# Final fail-closed inventory gate: detailed checks above retain actionable
# messages, while these canonical fingerprints cover every remaining parsed
# workflow, job, and step control surface without depending on shell spellings.
complete_workflow_fingerprints = {
  "release" => "3a28ae18f4f4215b009566f51d445b8aee5dbe5101b1de7f36da06f09015d5e3",
  "Swift compatibility" => "53000fea50e642c60a40f24cb06a0c077c5c1ee50a21e093f27ac8779740a3bd",
  "DocC" => "c30190bbe4dbf04d1797b218953fd2a118e5ba6a847c774e296fcdd2c6b8b128",
}
[
  ["release", workflow],
  ["Swift compatibility", swift_workflow],
  ["DocC", docc_workflow],
].each do |label, parsed_workflow|
  fail!("#{label} complete parsed workflow semantics must be exact") unless
    semantic_fingerprint.call(parsed_workflow) == complete_workflow_fingerprints.fetch(label)
end
RUBY
