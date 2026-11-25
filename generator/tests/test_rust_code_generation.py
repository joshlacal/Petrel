import hashlib
import json
import pathlib
import sys
import unittest

GENERATOR_DIR = pathlib.Path(__file__).resolve().parents[1]
FIXTURE_DIR = pathlib.Path(__file__).resolve().parent / "fixtures"
REPO_ROOT = GENERATOR_DIR.parent
sys.path.insert(0, str(GENERATOR_DIR))

from cycle_detector import CycleDetector
from main import compute_rust_namespace_features
from rust_code_generator import RustCodeGenerator


class RustCodeGenerationTests(unittest.TestCase):
    def test_record_query_procedure_and_xrpc_traits(self):
        record_lex = {
            "lexicon": 1,
            "id": "app.bsky.feed.post",
            "defs": {
                "main": {
                    "type": "record",
                    "key": "tid",
                    "record": {
                        "type": "object",
                        "required": ["text", "createdAt"],
                        "properties": {
                            "text": {"type": "string"},
                            "createdAt": {"type": "string", "format": "datetime"},
                            "reply": {"type": "ref", "ref": "#replyRef"},
                        },
                    },
                },
                "replyRef": {
                    "type": "object",
                    "required": ["root"],
                    "properties": {
                        "root": {"type": "string", "format": "cid"},
                    },
                },
            },
        }
        code = RustCodeGenerator(record_lex).convert()
        self.assertIn("pub struct Post {", code)
        self.assertIn("impl petrel_core::Collection for Post", code)
        self.assertIn('const KEY: petrel_core::RecordKeyType = petrel_core::RecordKeyType::Tid;', code)
        self.assertIn('petrel_core::ObjectWriter::with_type("app.bsky.feed.post")', code)
        self.assertIn("pub extra_data: Option<std::collections::BTreeMap<String, petrel_core::Value>>,", code)
        self.assertIn("pub struct ReplyRef {", code)
        self.assertIn("petrel_core::ObjectWriter::new()", code)
        self.assertNotIn("#[derive(Serialize", code)
        self.assertNotIn("serde(flatten)", code)

    def test_query_defaults_errors_and_binary_or_schemaless_bodies(self):
        query_lex = {
            "lexicon": 1,
            "id": "com.example.getFeed",
            "defs": {
                "main": {
                    "type": "query",
                    "parameters": {
                        "type": "params",
                        "required": ["actor"],
                        "properties": {
                            "actor": {"type": "string", "format": "at-identifier"},
                            "limit": {"type": "integer", "default": 50},
                            "cursor": {"type": "string"},
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["items"],
                            "properties": {
                                "items": {"type": "array", "items": {"type": "string"}},
                                "cursor": {"type": "string"},
                            },
                        },
                    },
                    "errors": [{"name": "NotFound"}, {"name": "BlockedActor"}],
                }
            },
        }
        code = RustCodeGenerator(query_lex).convert()
        self.assertIn("impl petrel_core::XrpcRequest for GetFeed", code)
        self.assertIn("pub limit: i64,", code)
        self.assertIn("limit: 50,", code)
        self.assertIn("pub fn new(actor: petrel_core::AtIdentifier) -> Self", code)
        self.assertIn('petrel_core::xrpc::push_param(out, "limit", &self.limit);', code)
        self.assertIn("impl petrel_core::DeclaredXrpcError for Error", code)
        self.assertIn("petrel_core::DeclaredXrpcError::wire_name(self)", code)
        self.assertIn("impl std::error::Error for Error {}", code)
        # XRPC Output must NOT have extra_data
        output_section = code[code.index("pub struct Output"):code.index("pub enum Error")]
        self.assertNotIn("extra_data", output_section)

        # Schemaless JSON output (labyrinthRelay) -> petrel_core::Bytes
        relay_lex = {
            "lexicon": 1,
            "id": "blue.catbird.labyrinth.labyrinthRelay",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {"encoding": "application/json"},
                    "output": {"encoding": "application/json"},
                }
            },
        }
        relay_code = RustCodeGenerator(relay_lex).convert()
        self.assertIn("type Input = petrel_core::Bytes;", relay_code)
        self.assertIn("type Output = petrel_core::Bytes;", relay_code)

    def test_input_is_strict_and_required_nullable_uses_required_nullable_methods(self):
        lex = json.loads((FIXTURE_DIR / "required_nullable.json").read_text(encoding="utf-8"))
        code = RustCodeGenerator(lex).convert()
        self.assertIn("pub nullable_scalar: Option<String>,", code)
        self.assertIn('writer.required_nullable("nullableScalar", &self.nullable_scalar)?;', code)
        self.assertIn('nullable_scalar: reader.required_nullable("nullableScalar")?,', code)

        proc = {
            "lexicon": 1,
            "id": "com.example.submit",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "properties": {"note": {"type": "string"}},
                        },
                    },
                }
            },
        }
        proc_code = RustCodeGenerator(proc).convert()
        self.assertIn('note: reader.optional_strict("note")?,', proc_code)

    def test_strict_input_rejects_a_malformed_optional_nullable_field(self):
        # A compare-and-swap field such as putRecord's swapRecord is optional
        # and nullable. Reading it leniently would turn a malformed value into
        # "absent" and skip the check the caller asked for.
        proc = {
            "lexicon": 1,
            "id": "com.example.put",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "nullable": ["swap"],
                            "properties": {"swap": {"type": "string", "format": "cid"}},
                        },
                    },
                }
            },
        }
        code = RustCodeGenerator(proc).convert()
        self.assertIn('swap: reader.optional_nullable_strict("swap")?,', code)
        self.assertNotIn('reader.optional_nullable("swap")', code)

    def test_an_input_decodes_strictly_at_every_depth_and_an_output_does_not(self):
        # Nested objects are shared between inputs and outputs and read
        # leniently, so the input itself must put the whole decode in strict
        # scope for a malformed nested optional field to be refused.
        proc = {
            "lexicon": 1,
            "id": "com.example.nested",
            "defs": {
                "main": {
                    "type": "procedure",
                    "input": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["inner"],
                            "properties": {"inner": {"type": "ref", "ref": "#inner"}},
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["inner"],
                            "properties": {"inner": {"type": "ref", "ref": "#inner"}},
                        },
                    },
                },
                "inner": {
                    "type": "object",
                    "properties": {"note": {"type": "string"}},
                },
            },
        }
        code = RustCodeGenerator(proc).convert()
        self.assertEqual(code.count("petrel_core::strictly(|| Self::from_value_in_scope(value))"), 1)
        input_start = code.index("impl petrel_core::FromValue for Input")
        self.assertIn(
            "petrel_core::strictly(",
            code[input_start : code.index("impl Input {", input_start)],
        )
        output_start = code.index("impl petrel_core::FromValue for Output")
        self.assertNotIn("strictly", code[output_start : output_start + 400])
        self.assertIn('note: reader.optional("note"),', code)

    def test_petrel_api_cargo_features_match_computed_namespace_graph(self):
        manifest = json.loads((GENERATOR_DIR / "manifests" / "petrel-core.json").read_text(encoding="utf-8"))
        excl = tuple(manifest["lexicons"]["exclude_namespaces"])
        lex_dir = GENERATOR_DIR / "lexicons"
        cd = CycleDetector()
        lexicons = []
        for p in sorted(lex_dir.rglob("*.json")):
            d = json.loads(p.read_text(encoding="utf-8"))
            lid = d.get("id", "")
            if any(lid == ns or lid.startswith(ns + ".") for ns in excl):
                continue
            lexicons.append((str(p), d))
            for dn, ds in d.get("defs", {}).items():
                cd.add_type(lid, dn, ds)
        features = compute_rust_namespace_features(lexicons, cd.schemas_by_ref)
        cargo_toml = (REPO_ROOT / "rust" / "petrel-api" / "Cargo.toml").read_text(encoding="utf-8")
        for feat, deps in features.items():
            deps_str = ", ".join(f'"{dep}"' for dep in deps)
            self.assertIn(f"{feat} = [{deps_str}]", cargo_toml)

    def test_ordinary_shapes_sha256_pins_are_deterministic(self):
        # Also verify knownValues golden behavior
        kv_lex = {
            "lexicon": 1,
            "id": "blue.catbird.golden.defs",
            "defs": {
                "mode": {
                    "type": "string",
                    "knownValues": ["alpha", "beta-value", "app.bsky.test#token"],
                }
            },
        }
        kv_code = RustCodeGenerator(kv_lex).convert()
        self.assertIn("pub enum Mode {", kv_code)
        self.assertIn("Other(String),", kv_code)
        self.assertEqual(
            hashlib.sha256(kv_code.encode("utf-8")).hexdigest(),
            hashlib.sha256(RustCodeGenerator(kv_lex).convert().encode("utf-8")).hexdigest(),
        )

    def test_prefix_module_inner_doc_precedes_pub_mod_in_mod_rs(self):
        import asyncio
        import tempfile
        from main import generate_rust_from_lexicons_recursive

        with tempfile.TemporaryDirectory() as tmp:
            lex_root = pathlib.Path(tmp) / "lexicons"
            out_root = pathlib.Path(tmp) / "generated"
            lex_root.mkdir()
            (lex_root / "blue.catbird.circle.json").write_text(
                json.dumps({
                    "lexicon": 1,
                    "id": "blue.catbird.circle",
                    "description": "A circle space\nwith multiple lines.",
                    "defs": {"main": {"type": "space"}},
                }),
                encoding="utf-8",
            )
            (lex_root / "blue.catbird.circle.get.json").write_text(
                json.dumps({
                    "lexicon": 1,
                    "id": "blue.catbird.circle.get",
                    "defs": {"main": {"type": "query"}},
                }),
                encoding="utf-8",
            )
            asyncio.run(
                generate_rust_from_lexicons_recursive(
                    str(lex_root), str(out_root), features=True
                )
            )
            mod_rs = (out_root / "blue" / "catbird" / "circle" / "mod.rs").read_text(encoding="utf-8")
            doc_pos = mod_rs.index("//! A circle space")
            pub_mod_pos = mod_rs.index("pub mod get;")
            nsid_pos = mod_rs.index('pub const NSID: &str = "blue.catbird.circle";')
            self.assertLess(doc_pos, pub_mod_pos)
            self.assertLess(pub_mod_pos, nsid_pos)
            # No inner doc comment appears after pub mod
            self.assertNotIn("//!", mod_rs[pub_mod_pos:])

    def test_cursor_params_and_cursor_output_emitted_only_for_string_cursors(self):
        paginated_query = {
            "lexicon": 1,
            "id": "com.example.listItems",
            "defs": {
                "main": {
                    "type": "query",
                    "parameters": {
                        "type": "params",
                        "properties": {
                            "limit": {"type": "integer"},
                            "cursor": {"type": "string"},
                        },
                    },
                    "output": {
                        "encoding": "application/json",
                        "schema": {
                            "type": "object",
                            "required": ["items"],
                            "properties": {
                                "cursor": {"type": "string"},
                                "items": {"type": "array", "items": {"type": "string"}},
                            },
                        },
                    },
                }
            },
        }
        code = RustCodeGenerator(paginated_query).convert()
        self.assertIn("impl petrel_core::xrpc::CursorParams for Parameters", code)
        self.assertIn("impl petrel_core::xrpc::CursorOutput for Output", code)

        int_cursor_sub = {
            "lexicon": 1,
            "id": "com.example.subscribeEvents",
            "defs": {
                "main": {
                    "type": "subscription",
                    "parameters": {
                        "type": "params",
                        "properties": {"cursor": {"type": "integer"}},
                    },
                }
            },
        }
        sub_code = RustCodeGenerator(int_cursor_sub).convert()
        self.assertNotIn("CursorParams", sub_code)


if __name__ == "__main__":
    unittest.main()
