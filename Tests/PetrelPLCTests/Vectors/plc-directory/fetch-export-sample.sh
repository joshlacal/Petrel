#!/usr/bin/env bash
# Downloads a bulk sample of the public PLC directory's operation log for
# PLCCorpusTests.externalCorpus. Read-only: unauthenticated GET /export only.
#
#   Tests/PetrelPLCTests/Vectors/plc-directory/fetch-export-sample.sh /tmp/plc-sample
#   PETREL_PLC_CORPUS_DIR=/tmp/plc-sample swift test --filter PLCCorpusTests
#
# 62 pages of 1,000 operations (about 60 MB): 50 in the legacy export format
# starting from 26 points between November 2022 and November 2026, and 12 in
# the sequenced format. The log is append-only, so the same requests return
# the same operations later. Set PLC_DIRECTORY to sample a mirror instead.
set -euo pipefail

out=${1:?usage: fetch-export-sample.sh OUTPUT_DIRECTORY}
directory=${PLC_DIRECTORY:-https://plc.directory}
mkdir -p "$out"

page() { # page FILE AFTER
  [[ -s $1 ]] && return 0
  curl --fail --silent --show-error --retry 3 --max-time 120 \
    --user-agent "petrel-plc-corpus-sample/1.0" \
    --get --data-urlencode "count=1000" --data-urlencode "after=$2" \
    "$directory/export" --output "$1.part"
  mv "$1.part" "$1"
  sleep 0.5
}

# Legacy format: START_TIMESTAMP PAGES. Each further page continues from the
# createdAt of the last line of the page before it.
while read -r start pages; do
  after=$start
  for ((i = 0; i < pages; i++)); do
    file="$out/legacy-${start%%T*}-${start:11:2}${start:14:2}-$i.jsonl"
    page "$file" "$after"
    after=$(tail -n 1 "$file" | grep -o '"createdAt":"[^"]*"' | head -n 1 | cut -d '"' -f 4)
    [[ -n $after ]] || break
  done
done <<'STARTS'
2022-11-17T00:00:00.000Z 1
2022-12-15T00:00:00.000Z 3
2023-02-01T00:00:00.000Z 1
2023-03-02T00:00:00.000Z 3
2023-03-06T00:00:00.000Z 3
2023-03-10T00:00:00.000Z 1
2023-03-25T00:00:00.000Z 1
2023-04-05T00:00:00.000Z 1
2023-04-12T00:00:00.000Z 1
2023-04-20T00:00:00.000Z 1
2023-05-18T22:00:00.000Z 3
2023-05-30T06:50:00.000Z 3
2023-07-10T00:00:00.000Z 1
2023-09-20T00:00:00.000Z 3
2024-01-05T00:00:00.000Z 3
2024-02-08T00:00:00.000Z 1
2024-05-09T03:00:00.000Z 3
2024-08-30T00:00:00.000Z 3
2024-11-15T00:00:00.000Z 1
2025-01-15T00:00:00.000Z 3
2025-06-10T00:00:00.000Z 1
2025-07-20T00:00:00.000Z 3
2025-12-10T00:00:00.000Z 1
2026-03-15T00:00:00.000Z 3
2026-06-01T00:00:00.000Z 1
2026-11-01T00:00:00.000Z 1
STARTS

# Sequenced format: two consecutive pages after each sequence number.
for sequence in 1000000 20000000 60000000 100000000 130000000 135000000; do
  page "$out/sequenced-$sequence.jsonl" "$sequence"
  page "$out/sequenced-$((sequence + 1000)).jsonl" "$((sequence + 1000))"
done

total=0
files=0
for file in "$out"/*.jsonl; do
  total=$((total + $(grep -c . "$file")))
  files=$((files + 1))
done
echo "$total operations in $files files under $out"
