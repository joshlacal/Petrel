#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORKFLOW=$ROOT/.github/workflows/release.yml
SWIFT_WORKFLOW=$ROOT/.github/workflows/swift.yml
DOCC_WORKFLOW=$ROOT/.github/workflows/docc.yml
WORKFLOW_DIRECTORY=$ROOT/.github/workflows

required_release_executables=(
  Scripts/activate-release-toolchain.sh
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
  Scripts/tests/validate-documentation-contract.sh
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

/usr/bin/ruby - "$WORKFLOW" "$SWIFT_WORKFLOW" "$DOCC_WORKFLOW" "$WORKFLOW_DIRECTORY" <<'RUBY'
require "psych"

workflow_path = ARGV.fetch(0)
swift_workflow_path = ARGV.fetch(1)
docc_workflow_path = ARGV.fetch(2)
workflow_directory = ARGV.fetch(3)
source = File.binread(workflow_path)
swift_source = File.binread(swift_workflow_path)
docc_source = File.binread(docc_workflow_path)

def fail!(message)
  abort "release workflow topology: #{message}"
end

def reject_unsafe_yaml!(node)
  case node
  when Psych::Nodes::Alias
    fail!("YAML aliases are forbidden")
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key, value|
      fail!("mapping keys must be scalars") unless key.is_a?(Psych::Nodes::Scalar)
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

expected_action_pins = {
  "actions/checkout" => "34e114876b0b11c390a56381ad16ebd13914f8d5", # v4.3.1
  "actions/setup-python" => "a26af69be951a213d495a4c3e4e4022e16d87065", # v5.6.0
  "actions/setup-java" => "c1e323688fd81a25caa38c78aa6df2d33d3e20d9", # v4.8.0
  "gradle/actions/setup-gradle" => "748248ddd2a24f49513d8f472f81c3a07d4d50e1", # v4.4.4
  "peter-evans/create-pull-request" => "22a9089034f40e5a961c8808d113e2c98fb63676", # v7.0.11
}
loaded_workflows = {}
workflow_paths = Dir.glob([
  File.join(workflow_directory, "*.yml"),
  File.join(workflow_directory, "*.yaml"),
]).sort
expected_workflow_inventory = [
  "docc.yml",
  "generator.yml",
  "kotlin.yml",
  "lint.yml",
  "release.yml",
  "swift.yml",
  "sync-lexicons.yml",
]
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
[
  "Package.resolved",
  "EXPECTED_RELEASE_VERSION",
  "CANDIDATE_COMMIT",
  'state.fetch("version")',
  'state.fetch("revision")',
].each do |required|
  fail!("tagged consumer does not verify #{required.inspect}") unless tagged_run_source.include?(required)
end
RUBY
