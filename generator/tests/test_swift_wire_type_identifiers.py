import pathlib
import sys
import tempfile
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from swift_code_generator import SwiftCodeGenerator


EXPECTED_WIRE_TYPES = {
    "blue.moji.collection.item#formats_v0",
    "blue.moji.collection.item#formats_v1",
    "blue.moji.collection.item#stickerFormats_v0",
    "blue.moji.embed.sticker#formats_v0",
    "blue.moji.richtext.facet#formats_v0",
    "blue.moji.richtext.facet#formats_v1",
}


class SwiftWireTypeIdentifierTests(unittest.TestCase):
    def test_preserves_raw_underscore_bearing_definition_fragments(self):
        lexicons = {
            "blue.moji.collection.item": (
                "formats_v0",
                "formats_v1",
                "stickerFormats_v0",
            ),
            "blue.moji.embed.sticker": ("formats_v0",),
            "blue.moji.richtext.facet": ("formats_v0", "formats_v1"),
        }

        with tempfile.TemporaryDirectory() as output_directory:
            output_path = pathlib.Path(output_directory)
            rendered_sources = []
            for lexicon_id, definition_names in lexicons.items():
                lexicon = {
                    "lexicon": 1,
                    "id": lexicon_id,
                    "defs": {
                        name: {"type": "object", "properties": {}}
                        for name in definition_names
                    },
                }
                rendered = SwiftCodeGenerator(lexicon).convert()
                rendered_file = output_path / f"{lexicon_id}.swift"
                rendered_file.write_text(rendered, encoding="utf-8")
                rendered_sources.append(rendered_file.read_text(encoding="utf-8"))

            generated = "\n".join(rendered_sources)

        for wire_type in EXPECTED_WIRE_TYPES:
            fragment = wire_type.split("#", 1)[1]
            camelized_fragment = (
                fragment.replace("formats_v0", "formatsV0")
                .replace("formats_v1", "formatsV1")
                .replace("stickerFormats_v0", "stickerFormatsV0")
            )
            with self.subTest(wire_type=wire_type):
                self.assertIn(f'typeIdentifier = "{wire_type}"', generated)
                self.assertNotIn(
                    f'typeIdentifier = "{wire_type.split("#", 1)[0]}#{camelized_fragment}"',
                    generated,
                )


if __name__ == "__main__":
    unittest.main()
