# Moderation vectors

Test data for the moderation decision engine (`Sources/Petrel/Helpers/Moderation`).
Everything here comes from the reference implementation, `packages/api` of
[bluesky-social/atproto](https://github.com/bluesky-social/atproto) (`@atproto/api`
0.20.26, commit `0e1042e65d5df27030849167773728b84d469182`, MIT / Apache-2.0).
The moderation sources and tests of that commit differ from upstream `main` as of
2026-11-11 only in import style and formatting.

| File | Source | How it was produced |
|---|---|---|
| `labels.json` | `packages/api/definitions/labels.json` | Byte-for-byte copy. |
| `behaviors.json` | `packages/api/tests/moderation-behaviors.test.ts` | The `USERS`, `CONFIGURATIONS` and `SCENARIOS` object literals, evaluated with Node and written with `JSON.stringify`. `SCENARIOS` is an array of `{ name, ...scenario }` so the scenario names and their order survive. |
| `custom-labels.json` | `packages/api/tests/moderation-custom-labels.test.ts` | The `TESTS` array literal, evaluated and written the same way. |
| `quoteposts.json` | `packages/api/tests/moderation-quoteposts.test.ts` | The `TESTS` array literal, evaluated and written the same way. |

The conversion is mechanical: nothing was edited, added or dropped by hand.
To regenerate after an upstream change, evaluate the same literals again:

```js
// node convert.mjs <path to packages/api> <this directory>
import { readFileSync, writeFileSync } from 'node:fs'
const [, , apiDir, outDir] = process.argv
const read = (p) => readFileSync(`${apiDir}/${p}`, 'utf8')
function literal(src, name) {
  const start = src.search(new RegExp(`^const ${name}\\b`, 'm'))
  const eq = src.indexOf('=', start)
  const end = /^[}\]]$/m.exec(src.slice(eq))
  return new Function(`return (${src.slice(eq + 1, eq + end.index + 1)})`)()
}
const write = (name, value) =>
  writeFileSync(`${outDir}/${name}`, JSON.stringify(value, null, 2) + '\n')
const behaviors = read('tests/moderation-behaviors.test.ts')
write('behaviors.json', {
  users: literal(behaviors, 'USERS'),
  configurations: literal(behaviors, 'CONFIGURATIONS'),
  scenarios: Object.entries(literal(behaviors, 'SCENARIOS')).map(([name, s]) => ({ name, ...s })),
})
write('custom-labels.json', literal(read('tests/moderation-custom-labels.test.ts'), 'TESTS'))
write('quoteposts.json', literal(read('tests/moderation-quoteposts.test.ts'), 'TESTS'))
```

The tests that read these files are `Tests/PetrelTests/Moderation*Tests.swift`.
They iterate every entry; none of the expected values is repeated in Swift.
