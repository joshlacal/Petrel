"""Kotlin emission for endpoints whose output is a raw (non-JSON) body.

A non-JSON output (application/octet-stream, application/vnd.ipld.car, */*,
application/jsonl) becomes a one-field wrapper holding `data: ByteArray`. The
runtime only hands back raw bytes when asked for `ByteArray` itself; asked for
the wrapper it tries to JSON-decode the binary body, fails, and returns a 200
with `data = null`. So the endpoint function must fetch `ByteArray` and wrap it.
"""
import pathlib
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator


def query_lexicon(output):
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.getThing",
        "defs": {
            "main": {
                "type": "query",
                "parameters": {
                    "type": "params",
                    "required": ["id"],
                    "properties": {"id": {"type": "string"}},
                },
                "output": output,
            }
        },
    }


def procedure_lexicon(output):
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.makeThing",
        "defs": {
            "main": {
                "type": "procedure",
                "input": {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "properties": {"id": {"type": "string"}},
                    },
                },
                "output": output,
            }
        },
    }


RAW_FETCH = "client.networkService.performRequest<ByteArray>("
WRAP = (
    "return ATProtoResponse(raw.responseCode, "
    "raw.data?.let { {cls}Output(it) }, raw.errorBody)"
)


class KotlinBinaryOutputGenerationTests(unittest.TestCase):
    def test_binary_encodings_fetch_bytes_and_wrap_them(self):
        for encoding in (
            "application/octet-stream",
            "application/vnd.ipld.car",
            "*/*",
            "application/jsonl",
        ):
            with self.subTest(encoding=encoding):
                source = KotlinCodeGenerator(
                    query_lexicon({"encoding": encoding})
                ).convert()
                self.assertIn("val `data`: ByteArray", source)
                self.assertIn(RAW_FETCH, source)
                self.assertIn(
                    WRAP.replace("{cls}", "BlueCatbirdTestGetThing"), source
                )
                self.assertIn(f'mapOf("Accept" to "{encoding}")', source)
                # The wrapper type must never be the decode target.
                self.assertNotIn(
                    "return client.networkService.performRequest(", source
                )

    def test_json_output_keeps_typed_decode(self):
        source = KotlinCodeGenerator(
            query_lexicon(
                {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "properties": {"name": {"type": "string"}},
                    },
                }
            )
        ).convert()
        self.assertIn("return client.networkService.performRequest(", source)
        self.assertNotIn(RAW_FETCH, source)
        self.assertNotIn("val raw =", source)

    def test_binary_procedure_output_fetches_bytes(self):
        source = KotlinCodeGenerator(
            procedure_lexicon({"encoding": "application/octet-stream"})
        ).convert()
        self.assertIn(RAW_FETCH, source)
        self.assertIn('method = "POST"', source)
        self.assertIn(
            WRAP.replace("{cls}", "BlueCatbirdTestMakeThing"), source
        )

    def test_json_procedure_output_keeps_typed_decode(self):
        source = KotlinCodeGenerator(
            procedure_lexicon(
                {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "properties": {"ok": {"type": "boolean"}},
                    },
                }
            )
        ).convert()
        self.assertIn("return client.networkService.performRequest(", source)
        self.assertNotIn(RAW_FETCH, source)


if __name__ == "__main__":
    unittest.main()
