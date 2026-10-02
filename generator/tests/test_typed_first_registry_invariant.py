"""The generated half of typed-first's one-writer-per-wire-id invariant.

Runtime overlay registrations are checked by the Swift registry tests. This
checks the complete committed core projection, including nested model types,
so a future generator change cannot silently give two generated types the same
wire identity while leaving the core registry's verified bit enabled.
"""

import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class TypedFirstRegistryInvariantTests(unittest.TestCase):
    def test_generated_wire_identifiers_have_one_declaring_type(self):
        declarations = {}
        for source in (ROOT / "Sources/Petrel/Generated/Lexicons").rglob("*.swift"):
            for wire_id in re.findall(
                r'public static let typeIdentifier\s*=\s*"([^"\n]+)"',
                source.read_text(),
            ):
                self.assertNotIn(
                    wire_id, declarations,
                    f"{wire_id} is emitted by both {declarations.get(wire_id)} and {source}; "
                    "typed-first may only trust ids with a single generated writer",
                )
                declarations[wire_id] = source
        self.assertGreater(len(declarations), 300, "the whole core projection must be checked")

    def test_generated_record_writers_use_their_declared_identity(self):
        # All object/record writers use Self.typeIdentifier in both encodings;
        # union framing delegates to the member's corresponding writer.
        json_writes = 0
        cbor_writes = 0
        for source in (ROOT / "Sources/Petrel/Generated/Lexicons").rglob("*.swift"):
            text = source.read_text()
            for expression in re.findall(r'try container\.encode\(([^\n]+), forKey: \.typeIdentifier\)', text):
                self.assertEqual(expression, "Self.typeIdentifier", source)
                json_writes += 1
            for expression in re.findall(r'map\.append\(key: "\$type", value: ([^\n]+)\)', text):
                self.assertEqual(expression, "Self.typeIdentifier", source)
                cbor_writes += 1
        self.assertGreater(json_writes, 300)
        self.assertEqual(json_writes, cbor_writes)


if __name__ == "__main__":
    unittest.main()
