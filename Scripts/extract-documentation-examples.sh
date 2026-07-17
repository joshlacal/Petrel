#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "usage: $0 OUTPUT_DIRECTORY DOCUMENTATION_FILE..." >&2
    exit 64
fi

output_dir=$1
shift

if [[ -e $output_dir && ! -d $output_dir ]]; then
    echo "documentation example output is not a directory: $output_dir" >&2
    exit 1
fi
mkdir -p "$output_dir"
if [[ -n $(find "$output_dir" -mindepth 1 -print -quit) ]]; then
    echo "documentation example output must be empty: $output_dir" >&2
    exit 1
fi

for documentation_file in "$@"; do
    [[ -f $documentation_file ]] || {
        echo "documentation source is missing: $documentation_file" >&2
        exit 1
    }
done

/usr/bin/awk -v output_dir="$output_dir" '
    function fail(message) {
        print FILENAME ": " message > "/dev/stderr"
        failed = 1
        exit 1
    }

    FNR == 1 && NR != 1 && (waiting_for_fence || in_example) {
        fail("compile example crosses a documentation-file boundary")
    }

    /^<!-- compile-example: [a-z0-9][a-z0-9-]* -->$/ {
        if (waiting_for_fence || in_example) {
            fail("nested compile-example marker")
        }
        name = $0
        sub(/^<!-- compile-example: /, "", name)
        sub(/ -->$/, "", name)
        if (seen[name]) {
            fail("duplicate compile-example marker: " name)
        }
        seen[name] = 1
        output = output_dir "/" name ".swift"
        waiting_for_fence = 1
        next
    }

    waiting_for_fence && $0 == "```swift" {
        waiting_for_fence = 0
        in_example = 1
        example_lines = 0
        example_count += 1
        next
    }

    waiting_for_fence {
        fail("compile-example marker must immediately precede a Swift fence")
    }

    !in_example && $0 == "```swift" {
        fail("unmarked Swift fence")
    }

    in_example && $0 == "```" {
        if (example_lines == 0) {
            fail("empty compile-example fence: " name)
        }
        close(output)
        in_example = 0
        next
    }

    in_example {
        print > output
        example_lines += 1
    }

    END {
        if (!failed && (waiting_for_fence || in_example)) {
            fail("unterminated compile-example fence")
        }
        if (!failed && example_count == 0) {
            fail("no marked Swift examples found")
        }
    }
' "$@"
