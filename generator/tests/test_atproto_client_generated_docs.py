import pathlib
import sys
import unittest


GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GENERATOR_DIR))

from main import render_atproto_client


class ATProtoClientGeneratedDocumentationTests(unittest.TestCase):
    def test_authenticated_initializer_documents_access_group(self):
        generated = render_atproto_client("")
        initializer_start = generated.index(
            "    public init(\n"
            "        baseURL: URL = ATProtoClient.defaultBaseURL"
        )
        documentation_start = generated.rfind(
            "    /// - Parameters:", 0, initializer_start
        )
        documentation = generated[documentation_start:initializer_start]

        self.assertIn(
            "///   - accessGroup: Optional keychain access group used for "
            "credential storage.",
            documentation,
        )


if __name__ == "__main__":
    unittest.main()
