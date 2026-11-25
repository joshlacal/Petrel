#!/usr/bin/env bash
set -euo pipefail

# x86_64-unknown-linux-gnu, on both the Ubuntu runner and the Swift container.
rustup_version=1.29.2
rustup_sha256=5be191e8c70a5007074254cb74d78dbfdd25cd5a61c27de7b8e5410122ec24f4
install_dir=$(mktemp -d "${RUNNER_TEMP}/petrel-rustup.XXXXXX")
installer="${install_dir}/rustup-init"
curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location --retry 3 \
  --output "$installer" \
  "https://static.rust-lang.org/rustup/archive/${rustup_version}/x86_64-unknown-linux-gnu/rustup-init"
printf '%s  %s\n' "$rustup_sha256" "$installer" | sha256sum --check
chmod +x "$installer"

# Isolate this install from any Rust preinstalled on the runner. Rustup will
# load rust-toolchain.toml when the first Cargo command runs from rust/.
export CARGO_HOME="${install_dir}/cargo"
export RUSTUP_HOME="${install_dir}/toolchains"
RUSTUP_INIT_SKIP_PATH_CHECK=yes "$installer" -y --no-modify-path \
  --profile minimal --default-toolchain none
{
  printf 'CARGO_HOME=%s\n' "$CARGO_HOME"
  printf 'RUSTUP_HOME=%s\n' "$RUSTUP_HOME"
} >> "$GITHUB_ENV"
printf '%s\n' "${CARGO_HOME}/bin" >> "$GITHUB_PATH"
