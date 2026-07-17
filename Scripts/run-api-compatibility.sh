#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "usage: $0 (--local-jj-candidate|--current-git-checkout) [--breakage-allowlist-path api-breakage-allowlist.txt]" >&2
  exit 64
}

[[ $# == 1 || $# == 3 ]] || usage

MODE=$1
case $MODE in
  --local-jj-candidate|--current-git-checkout) ;;
  *) usage ;;
esac

USE_ALLOWLIST=0
if [[ $# == 3 ]]; then
  [[ $2 == --breakage-allowlist-path && $3 == api-breakage-allowlist.txt ]] || usage
  USE_ALLOWLIST=1
fi

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CANONICAL=/Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
EXPECTED_TAG_COMMIT=02de350792158ffc9f2ad9902ac61f101ea84bca

[[ -n ${RELEASE_SWIFT:-} && $RELEASE_SWIFT == /* && -x $RELEASE_SWIFT ]] || {
  echo "RELEASE_SWIFT must name the activated absolute Swift executable" >&2
  exit 1
}
[[ -x /usr/bin/git ]] || {
  echo "/usr/bin/git is required" >&2
  exit 1
}
if [[ $USE_ALLOWLIST == 1 ]]; then
  [[ -f $ROOT/api-breakage-allowlist.txt ]] || {
    echo "api-breakage-allowlist.txt is missing" >&2
    exit 1
  }
fi

require_full_commit() {
  local value=$1
  case $value in
    *[!0-9a-f]*|'') return 1 ;;
  esac
  [[ ${#value} == 40 ]]
}

verify_tag_and_ancestry() {
  local checkout=$1
  local candidate=$2
  local tag_commit

  [[ $(/usr/bin/git -C "$checkout" rev-parse --is-shallow-repository) == false ]] || {
    echo "API compatibility requires complete Git history" >&2
    return 1
  }
  tag_commit=$(/usr/bin/git -C "$checkout" rev-parse '0.1.0^{commit}')
  [[ $tag_commit == "$EXPECTED_TAG_COMMIT" ]] || {
    echo "0.1.0 does not resolve to the reviewed commit" >&2
    return 1
  }
  /usr/bin/git -C "$checkout" merge-base --is-ancestor "$EXPECTED_TAG_COMMIT" "$candidate" || {
    echo "0.1.0 is not an ancestor of the candidate" >&2
    return 1
  }
}

run_diagnosis() {
  local checkout=$1
  local capture_dir command_status stderr_file stdout_file
  if [[ $USE_ALLOWLIST == 1 ]]; then
    [[ -f $checkout/api-breakage-allowlist.txt ]] || {
      echo "diagnosed candidate does not contain api-breakage-allowlist.txt" >&2
      return 1
    }
  fi

  capture_dir=$(mktemp -d /tmp/petrel-api-diagnosis-output.XXXXXX)
  stdout_file=$capture_dir/stdout.log
  stderr_file=$capture_dir/stderr.log
  (
    trap 'rm -rf "$capture_dir"' EXIT
    # SwiftPM builds in parallel. Capture its streams independently so compiler
    # stderr cannot splice bytes into the stdout API summary when callers use 2>&1.
    if [[ $USE_ALLOWLIST == 1 ]]; then
      if (
        cd "$checkout"
        "$RELEASE_SWIFT" package diagnose-api-breaking-changes 0.1.0 \
          --breakage-allowlist-path api-breakage-allowlist.txt
      ) >"$stdout_file" 2>"$stderr_file"; then
        command_status=0
      else
        command_status=$?
      fi
    else
      if (
        cd "$checkout"
        "$RELEASE_SWIFT" package diagnose-api-breaking-changes 0.1.0
      ) >"$stdout_file" 2>"$stderr_file"; then
        command_status=0
      else
        command_status=$?
      fi
    fi

    /bin/cat "$stdout_file"
    /bin/cat "$stderr_file" >&2
    exit "$command_status"
  )
}

case $MODE in
  --local-jj-candidate)
    RC_ROOT=${RC_ROOT:-/tmp/petrel-compatible-release-0.2.0}
    CANDIDATE_ROOT=$RC_ROOT/Petrel
    [[ -d $CANDIDATE_ROOT ]] || {
      echo "local Petrel candidate is missing: $CANDIDATE_ROOT" >&2
      exit 1
    }
    [[ -d $CANONICAL ]] || {
      echo "canonical Petrel object store is missing: $CANONICAL" >&2
      exit 1
    }
    command -v jj >/dev/null 2>&1 || {
      echo "jj is required for --local-jj-candidate" >&2
      exit 1
    }

    CANDIDATE=$(jj -R "$CANDIDATE_ROOT" log -r @ --no-graph -T 'commit_id')
    require_full_commit "$CANDIDATE" || {
      echo "jj did not resolve the candidate to one full commit ID" >&2
      exit 1
    }
    /usr/bin/git -C "$CANONICAL" cat-file -e "$CANDIDATE^{commit}" || {
      echo "candidate object is absent from the canonical Git object store" >&2
      exit 1
    }

    TMP=$(mktemp -d /tmp/petrel-api-compatibility.XXXXXX)
    trap 'rm -rf "$TMP"' EXIT
    /usr/bin/git init --bare "$TMP/mirror.git"
    /usr/bin/git --git-dir="$TMP/mirror.git" fetch --no-tags "$CANONICAL" "$CANDIDATE"
    [[ $(/usr/bin/git --git-dir="$TMP/mirror.git" rev-parse FETCH_HEAD) == "$CANDIDATE" ]] || {
      echo "candidate fetch did not preserve the exact commit" >&2
      exit 1
    }
    /usr/bin/git --git-dir="$TMP/mirror.git" update-ref refs/heads/petrel-candidate "$CANDIDATE"
    /usr/bin/git --git-dir="$TMP/mirror.git" fetch --no-tags "$CANONICAL" \
      refs/tags/0.1.0:refs/tags/0.1.0
    /usr/bin/git clone --no-checkout "$TMP/mirror.git" "$TMP/worktree"
    /usr/bin/git -C "$TMP/worktree" checkout --detach "$CANDIDATE"
    [[ $(/usr/bin/git -C "$TMP/worktree" rev-parse HEAD) == "$CANDIDATE" ]] || {
      echo "disposable checkout is not the exact candidate" >&2
      exit 1
    }
    verify_tag_and_ancestry "$TMP/worktree" "$CANDIDATE"
    run_diagnosis "$TMP/worktree"
    ;;

  --current-git-checkout)
    [[ -e $ROOT/.git ]] || {
      echo "--current-git-checkout requires a real full-history Git checkout" >&2
      exit 1
    }
    [[ $(/usr/bin/git -C "$ROOT" rev-parse --is-inside-work-tree) == true ]] || {
      echo "repository root is not a Git worktree" >&2
      exit 1
    }
    [[ $(/usr/bin/git -C "$ROOT" rev-parse --show-toplevel) == "$ROOT" ]] || {
      echo "script root does not match the Git worktree root" >&2
      exit 1
    }
    CANDIDATE=$(/usr/bin/git -C "$ROOT" rev-parse HEAD)
    require_full_commit "$CANDIDATE" || {
      echo "Git HEAD is not one full commit ID" >&2
      exit 1
    }
    verify_tag_and_ancestry "$ROOT" "$CANDIDATE"
    run_diagnosis "$ROOT"
    ;;
esac
