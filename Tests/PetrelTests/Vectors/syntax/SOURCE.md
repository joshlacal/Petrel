# Syntax interop vectors

Verbatim copy of the `syntax/` directory of
<https://github.com/bluesky-social/atproto-interop-tests> at commit `056e5741`
(2026-07-01), the repository the AT Protocol specifications name as the
authority for identifier and string-format test vectors. 24 files, 536 vectors.
Licence: CC0 1.0 (`LICENSE-CC0`, copied from the same commit).

The files are data, not documentation: do not edit, trim or reformat them.
Several vectors are significant only because of leading or trailing whitespace.

Reading rule (the one the reference TypeScript suite uses): split on `\n`, skip
empty lines and lines that start with `#`, and use every other line unchanged.
`Tests/PetrelTests/SyntaxVectorTests.swift` loads every file through
`Bundle.module` and asserts the exact vector count of each one, so a truncated
or partially copied file fails the suite.

To update: replace the `.txt` files with the upstream ones, change the commit
above, and adjust `SyntaxVectors.expectedCounts`.
