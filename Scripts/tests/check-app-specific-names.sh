#!/usr/bin/env bash
# Fails when an application-specific name (an app, server or host the maintainer runs) appears in
# the generic SDK's library sources, package manifests or generator, outside the reviewed
# exceptions in Scripts/app-specific-names-allowlist.txt. Also fails on allowlist entries that
# no longer match anything, so exceptions are removed together with the code they excuse.
#
# Usage: Scripts/tests/check-app-specific-names.sh [repository root]

set -euo pipefail

ROOT=${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}
ALLOWLIST="$ROOT/Scripts/app-specific-names-allowlist.txt"
PATTERN='catbird|catmos|swan'
SCAN=(Sources Package.swift Server/Sources Server/Package.swift generator/templates)

cd "$ROOT"
[[ -f $ALLOWLIST ]] || {
    echo "missing allowlist: $ALLOWLIST" >&2
    exit 2
}

targets=()
for path in "${SCAN[@]}"; do
    [[ -e $path ]] && targets+=("$path")
done
while IFS= read -r file; do
    targets+=("$file")
done < <(find generator -maxdepth 1 -name '*.py' -type f | LC_ALL=C sort)

# Allowlist lines: <path or directory/>|<fixed substring of the line, or *>|<reason>
paths=()
needles=()
while IFS= read -r line || [[ -n $line ]]; do
    [[ -z ${line//[[:space:]]/} || ${line:0:1} == "#" ]] && continue
    IFS='|' read -r path needle reason <<<"$line"
    if [[ -z $path || -z $needle || -z ${reason//[[:space:]]/} ]]; then
        echo "malformed allowlist line (want path|substring|reason): $line" >&2
        exit 2
    fi
    paths+=("$path")
    needles+=("$needle")
done <"$ALLOWLIST"

used=()
for ((i = 0; i < ${#paths[@]}; i++)); do used+=(0); done

violations=0
while IFS= read -r hit; do
    file=${hit%%:*}
    rest=${hit#*:}
    text=${rest#*:}
    allowed=0
    for ((i = 0; i < ${#paths[@]}; i++)); do
        path=${paths[$i]}
        if [[ $path == */ ]]; then
            [[ $file == "$path"* ]] || continue
        else
            [[ $file == "$path" ]] || continue
        fi
        if [[ ${needles[$i]} == "*" || $text == *"${needles[$i]}"* ]]; then
            allowed=1
            used[i]=1
        fi
    done
    if ((allowed == 0)); then
        echo "app-specific name: $hit" >&2
        violations=$((violations + 1))
    fi
done < <(grep -rnIiE "$PATTERN" "${targets[@]}" || true)

stale=0
for ((i = 0; i < ${#paths[@]}; i++)); do
    if ((used[i] == 0)); then
        echo "stale allowlist entry (matches nothing): ${paths[$i]}|${needles[$i]}" >&2
        stale=$((stale + 1))
    fi
done

if ((violations > 0 || stale > 0)); then
    echo "Use neutral names (Petrel.<Area> labels, example.com hosts) or caller-supplied configuration;" >&2
    echo "add an allowlist entry only for a documented compatibility constant." >&2
    exit 1
fi
echo "No app-specific names outside Scripts/app-specific-names-allowlist.txt."
