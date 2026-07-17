import json
import pathlib
import re
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator


class SwiftWarningFreeGenerationTests(unittest.TestCase):
    immutable_header_lexicons = (
        "com/atproto/identity/requestPlcOperationSignature.json",
        "com/atproto/repo/importRepo.json",
        "com/atproto/server/activateAccount.json",
        "com/atproto/server/deleteSession.json",
        "com/atproto/server/requestAccountDelete.json",
        "com/atproto/server/requestEmailConfirmation.json",
    )
    nonthrowing_binary_output_lexicons = (
        "chat/bsky/actor/exportAccountData.json",
        "com/atproto/sync/getBlob.json",
        "com/atproto/sync/getBlocks.json",
        "com/atproto/sync/getCheckout.json",
        "com/atproto/sync/getRecord.json",
        "com/atproto/sync/getRepo.json",
    )

    @staticmethod
    def render(relative_path: str) -> str:
        lexicon_path = GENERATOR_DIR / "lexicons" / relative_path
        lexicon = json.loads(lexicon_path.read_text(encoding="utf-8"))
        return SwiftCodeGenerator(lexicon).convert()

    def test_headers_are_constants_when_the_endpoint_adds_no_headers(self):
        for relative_path in self.immutable_header_lexicons:
            with self.subTest(lexicon=relative_path):
                generated = self.render(relative_path)
                self.assertEqual(
                    re.findall(r"\b(?:let|var) headers: \[String: String\]", generated),
                    ["let headers: [String: String]"],
                )

    def test_nonthrowing_binary_outputs_are_not_wrapped_in_do_catch(self):
        for relative_path in self.nonthrowing_binary_output_lexicons:
            with self.subTest(lexicon=relative_path):
                generated = self.render(relative_path)
                success_start = generated.index(
                    "if (200...299).contains(responseCode)"
                )
                success_end = generated.index("} else {", success_start)
                success_path = generated[success_start:success_end]

                self.assertRegex(
                    success_path,
                    re.compile(
                        r"let decodedData = \w+\.Output\(data: responseData\)\s*"
                        r"return \(responseCode, decodedData\)",
                        re.DOTALL,
                    ),
                )
                self.assertNotIn("do {", success_path)
                self.assertNotIn("catch {", success_path)

    def test_open_unions_without_declared_refs_omit_unused_scaffolding(self):
        generated = self.render("site/standard/document.json")

        for union_name in (
            "SiteStandardDocumentContentUnion",
            "SiteStandardDocumentLinksUnion",
        ):
            with self.subTest(union=union_name):
                start = generated.index(f"public enum {union_name}")
                next_union = generated.find("\npublic enum ", start + 1)
                outer_end = len(generated)
                end = min(
                    position
                    for position in (next_union, outer_end)
                    if position >= 0
                )
                union = generated[start:end]

                self.assertNotIn(
                    "var container = encoder.container(keyedBy: CodingKeys.self)",
                    union,
                )
                self.assertNotIn("var map = OrderedCBORMap()", union)

                equality_start = union.index("public static func ==")
                equality_end = union.index("public func isEqual", equality_start)
                self.assertNotIn("default:", union[equality_start:equality_end])


if __name__ == "__main__":
    unittest.main()
