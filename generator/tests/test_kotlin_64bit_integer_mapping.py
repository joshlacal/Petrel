"""Kotlin width for lexicon integers that carry 64-bit values.

An integer with no maximum above Int.MAX_VALUE is widened to Kotlin Long by its
field name. A field whose whole name is one of the 64-bit suffix words
(`sequencerTerm` for `SequencerTerm`) and an integer field ending in `At`
(a timestamp, such as unix microseconds) must both decode as Long, while
ordinary unbounded integers such as counts stay Int.
"""
import pathlib
import re
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from kotlin_code_generator import KotlinCodeGenerator
from kotlin_type_converter import KotlinTypeConverter


def segment_lexicon():
    return {
        "lexicon": 1,
        "id": "blue.catbird.test.listSegments",
        "defs": {
            "main": {
                "type": "query",
                "output": {
                    "encoding": "application/json",
                    "schema": {
                        "type": "object",
                        "required": ["segments", "sequencerTerm"],
                        "properties": {
                            "segments": {
                                "type": "array",
                                "items": {"type": "ref", "ref": "#segment"},
                            },
                            "sequencerTerm": {"type": "integer"},
                            "eventCount": {"type": "integer"},
                        },
                    },
                },
            },
            "segment": {
                "type": "object",
                "required": ["minWitnessedAt", "maxWitnessedAt", "eventCount"],
                "properties": {
                    "minWitnessedAt": {"type": "integer"},
                    "maxWitnessedAt": {"type": "integer"},
                    "eventCount": {"type": "integer"},
                    "createdAt": {"type": "string", "format": "datetime"},
                },
            },
        },
    }


def property_type(source, name):
    match = re.search(r"\bval\s+" + re.escape(name) + r"\s*:\s*([A-Za-z0-9_.<>?]+)", source)
    if match is None:
        raise AssertionError(f"no property {name!r} in generated Kotlin")
    return match.group(1)


class Kotlin64BitIntegerMappingTests(unittest.TestCase):
    def setUp(self):
        self.source = KotlinCodeGenerator(segment_lexicon()).convert()

    def test_bare_sequencer_term_is_long(self):
        self.assertEqual(property_type(self.source, "sequencerTerm"), "Long")

    def test_microsecond_witnessed_at_timestamps_are_long(self):
        self.assertEqual(property_type(self.source, "minWitnessedAt"), "Long")
        self.assertEqual(property_type(self.source, "maxWitnessedAt"), "Long")

    def test_unbounded_counts_stay_int(self):
        self.assertIn(property_type(self.source, "eventCount"), {"Int", "Int?"})

    def test_bare_suffix_words_match_exactly_not_by_case_folding(self):
        # Lowercasing a short suffix such as `Ms` would capture `items`; only a
        # name equal to the whole suffix word with a lowercase first letter matches.
        self.assertTrue(KotlinTypeConverter._is_64bit_integer({}, "sequencerTerm"))
        self.assertTrue(KotlinTypeConverter._is_64bit_integer({}, "epochNumber"))
        self.assertFalse(KotlinTypeConverter._is_64bit_integer({}, "items"))
        self.assertFalse(KotlinTypeConverter._is_64bit_integer({}, "limit"))

    def test_at_suffix_requires_a_lowercase_letter_before_it(self):
        self.assertTrue(KotlinTypeConverter._is_64bit_integer({}, "witnessedAt"))
        self.assertFalse(KotlinTypeConverter._is_64bit_integer({}, "at"))
        self.assertFalse(KotlinTypeConverter._is_64bit_integer({}, "seat"))


if __name__ == "__main__":
    unittest.main()
