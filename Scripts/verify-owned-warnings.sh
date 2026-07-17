#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo 'usage: verify-owned-warnings.sh LABEL -- COMMAND [ARG...]' >&2
  exit 64
}

[[ $# -ge 3 && $2 == -- ]] || usage

LABEL=$1
case $LABEL in
  ''|*[!a-z0-9-]*) usage ;;
esac
shift 2

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
LOG=$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/petrel-$LABEL.XXXXXX")
trap 'rm -f "$LOG"' EXIT

set +e
"$@" 2>&1 | tee "$LOG"
PIPELINE_STATUS=("${PIPESTATUS[@]}")
set -e

COMMAND_STATUS=${PIPELINE_STATUS[0]}
TEE_STATUS=${PIPELINE_STATUS[1]}
if [[ $COMMAND_STATUS -ne 0 ]]; then
  exit "$COMMAND_STATUS"
fi
if [[ $TEE_STATUS -ne 0 ]]; then
  exit "$TEE_STATUS"
fi

OWNED_WARNING=0
while IFS= read -r LINE; do
  case $LINE in
    "warning: 'petrel': failed to retrieve search paths with pkg-config"*|\
    "warning: 'petrel': couldn't find pc file for libsecret-1"*|\
    "warning: failed to retrieve search paths with pkg-config"*|\
    "warning: couldn't find pc file for libsecret-1"*)
      continue
      ;;
    "warning: 'petrel':"*)
      printf '%s\n' "$LINE" >&2
      OWNED_WARNING=1
      continue
      ;;
  esac

  SOURCE_PATH=
  if [[ $LINE =~ ^(.+):[0-9]+:[0-9]+:[[:space:]]warning: ]]; then
    SOURCE_PATH=${BASH_REMATCH[1]}
  elif [[ $LINE =~ ^(.+):[0-9]+:[[:space:]]warning: ]]; then
    SOURCE_PATH=${BASH_REMATCH[1]}
  else
    continue
  fi

  case $SOURCE_PATH in
    ./*) SOURCE_PATH=${SOURCE_PATH#./} ;;
  esac
  case $SOURCE_PATH in
    "$ROOT"/Package.swift|\
    "$ROOT"/Package@swift-*.swift|\
    "$ROOT"/Plugins/*|\
    "$ROOT"/Sources/*|\
    "$ROOT"/Tests/*|\
    Package.swift|\
    Package@swift-*.swift|\
    Plugins/*|\
    Sources/*|\
    Tests/*)
      printf '%s\n' "$LINE" >&2
      OWNED_WARNING=1
      ;;
  esac
done <"$LOG"

if [[ $OWNED_WARNING -ne 0 ]]; then
  echo "package-owned warning detected in $LABEL" >&2
  exit 1
fi
