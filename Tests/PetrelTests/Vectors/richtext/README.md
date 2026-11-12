# Rich text vectors

Test data for rich text facet detection (`Sources/Petrel/Helpers/RichText`),
taken from the reference implementation: `packages/api` of
[bluesky-social/atproto](https://github.com/bluesky-social/atproto) (`@atproto/api`
0.20.26, commit `0e1042e65d5df27030849167773728b84d469182`, MIT / Apache-2.0).

| File | Source | How it was produced |
|---|---|---|
| `detection.json` | `packages/api/tests/rich-text-detection.test.ts` | The four array literals of the file (`inputs` and `outputs` of "correctly handles a set of text inputs", and the `inputs` tables of the tag and cashtag suites), evaluated with Node and written with `JSON.stringify`. |

`segments[i]` pairs input `i` with its expected output. Each expected segment is
`[text]` for plain text or `[text, value]` for a facet, where `value` is the
link URI or the mention DID. The reference test resolves every handle `h` to
`did:fake:h`; the Swift test does the same.

The conversion is mechanical: nothing was edited, added or dropped by hand.
To regenerate after an upstream change:

```js
// node richtext.mjs <path to packages/api> <this directory>
import { readFileSync, writeFileSync } from 'node:fs'
const [, , apiDir, outDir] = process.argv
const src = readFileSync(`${apiDir}/tests/rich-text-detection.test.ts`, 'utf8')
const lines = src.split('\n')
// Every `const inputs…= [` / `const outputs…= [` array literal, in file order.
function literals() {
  const found = []
  for (let i = 0; i < lines.length; i++) {
    const m = /^(\s*)const (inputs|outputs)\b/.exec(lines[i])
    if (!m) continue
    let open = i
    while (!/= \[$/.test(lines[open])) open++
    let close = open + 1
    while (lines[close] !== `${m[1]}]`) close++
    const body = lines.slice(open + 1, close).join('\n')
    found.push({ name: m[2], value: new Function(`return [${body}\n]`)() })
    i = close
  }
  return found
}
const [inputs, outputs, tags, cashtags] = literals().map((l) => l.value)
if (inputs.length !== outputs.length) throw new Error('inputs/outputs length mismatch')
const table = (rows) => rows.map(([text, tags, indices]) => ({ text, tags, indices }))
writeFileSync(
  `${outDir}/detection.json`,
  JSON.stringify(
    {
      segments: inputs.map((text, i) => ({ text, segments: outputs[i] })),
      tags: table(tags),
      cashtags: table(cashtags),
    },
    null,
    2,
  ) + '\n',
)
```

The test that reads this file is `Tests/PetrelTests/RichTextDetectionTests.swift`.
It iterates every entry; none of the expected values is repeated in Swift.
