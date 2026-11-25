#!/usr/bin/python3
"""Turn the Swift fences in `///` documentation comments into compilable files.

A fence in a documentation comment is a fragment: it uses values the surrounding
prose introduces (`client`, `post`, `keypair`). Each one is wrapped in a function
whose parameters supply those values, so the compiler can check it against the
real API. The parameters come from Scripts/doc-comment-examples/contexts.json.

Usage: extract-doc-comment-examples.py OUTPUT_DIRECTORY [--root DIR] [--contexts FILE]

Writes one `<name>.swift` per fence, or `<name>.skipped` for a fence the context
table marks as not compilable on its own. Fails when the table names a fence that
does not exist, or when a fence no longer begins with the line the table recorded
for it, so an entry cannot drift onto a different example.
"""

import json
import os
import re
import sys

FENCE_OPEN = re.compile(r"^\s*///\s?```swift\s*$")
FENCE_CLOSE = re.compile(r"^\s*///\s?```\s*$")
COMMENT_PREFIX = re.compile(r"^\s*/// ?")
# `{ … }` and `{ ... }` stand for a body the example leaves out.
ELIDED_BODY = re.compile(r"\{ ?(…|\.\.\.) ?\}")


def fail(message):
    print("doc-comment examples: " + message, file=sys.stderr)
    sys.exit(1)


def swift_sources(root):
    for directory, subdirectories, files in os.walk(os.path.join(root, "Sources")):
        # Generated code carries lexicon descriptions, not hand-written examples, and DocC
        # catalogs are covered by the compile-example markers in their articles.
        subdirectories[:] = sorted(
            name for name in subdirectories if name != "Generated" and not name.endswith(".docc")
        )
        for name in sorted(files):
            if name.endswith(".swift"):
                yield os.path.join(directory, name)


def fences(path):
    with open(path, encoding="utf-8") as source:
        lines = source.read().split("\n")
    index = 0
    while index < len(lines):
        if FENCE_OPEN.match(lines[index]):
            first_line = index + 2  # 1-based number of the first line inside the fence
            body = []
            index += 1
            while index < len(lines) and not FENCE_CLOSE.match(lines[index]):
                if not COMMENT_PREFIX.match(lines[index]):
                    fail("%s:%d: Swift fence is not closed inside its comment" % (path, first_line - 1))
                body.append(COMMENT_PREFIX.sub("", lines[index]))
                index += 1
            if index == len(lines):
                fail("%s:%d: Swift fence is not closed" % (path, first_line - 1))
            yield first_line, body
        index += 1


def main(arguments):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    contexts_path = None
    positional = []
    while arguments:
        argument = arguments.pop(0)
        if argument in ("--root", "--contexts") and arguments:
            value = arguments.pop(0)
            if argument == "--root":
                root = os.path.abspath(value)
            else:
                contexts_path = value
        else:
            positional.append(argument)
    if len(positional) != 1:
        print(__doc__.strip().split("\n\n")[2], file=sys.stderr)
        sys.exit(64)
    output = positional[0]
    if contexts_path is None:
        contexts_path = os.path.join(root, "Scripts", "doc-comment-examples", "contexts.json")

    os.makedirs(output, exist_ok=True)
    if os.listdir(output):
        fail("output directory must be empty: " + output)
    with open(contexts_path, encoding="utf-8") as contexts_file:
        table = json.load(contexts_file)
    imports = "".join("import %s\n" % module for module in table["imports"])
    contexts = table["examples"]
    unused = set(contexts)

    written = skipped = 0
    for path in swift_sources(root):
        relative = os.path.relpath(path, root)
        for ordinal, (first_line, body) in enumerate(fences(path), start=1):
            key = "%s#%d" % (relative, ordinal)
            context = contexts.get(key, {})
            unused.discard(key)
            starts = next((line.strip() for line in body if line.strip()), "")
            if not starts:
                fail("%s:%d: empty Swift fence" % (relative, first_line))
            if context and context.get("starts") != starts:
                fail(
                    "%s:%d: the context for %s was written for an example beginning\n    %s\n"
                    "but the example there now begins\n    %s\n"
                    "Update Scripts/doc-comment-examples/contexts.json."
                    % (relative, first_line, key, context.get("starts"), starts)
                )
            name = re.sub(r"[^A-Za-z0-9]+", "-", relative[len("Sources/"):-len(".swift")]).lower()
            name = "%s-%d" % (name, ordinal)
            if "skip" in context:
                with open(os.path.join(output, name + ".skipped"), "w", encoding="utf-8") as file:
                    file.write(context["skip"] + "\n")
                skipped += 1
                continue
            lines = [imports, "// %s:%d\n" % (relative, first_line)]
            lines.append(
                "func docCommentExample_%s(%s) async throws {\n"
                % (re.sub(r"[^A-Za-z0-9]", "_", name), context.get("parameters", ""))
            )
            lines.extend("    %s\n" % line for line in context.get("setup", []))
            # Diagnostics name the documentation comment, not the generated file.
            lines.append('#sourceLocation(file: "%s", line: %d)\n' % (relative, first_line))
            lines.extend(ELIDED_BODY.sub("{ }", line) + "\n" for line in body)
            lines.append("#sourceLocation()\n}\n")
            with open(os.path.join(output, name + ".swift"), "w", encoding="utf-8") as file:
                file.write("".join(lines))
            written += 1

    if unused:
        fail(
            "contexts.json names examples that do not exist: %s\n"
            "Keys are `<path>#<n>` for the n-th Swift fence in that file's documentation comments."
            % ", ".join(sorted(unused))
        )
    if written == 0:
        fail("no Swift fences found in documentation comments")
    print("doc-comment examples: %d extracted, %d skipped" % (written, skipped))


if __name__ == "__main__":
    main(sys.argv[1:])
