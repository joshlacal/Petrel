import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/lib/syntax-string.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// The original generates the same eight tests for each of seven scope
/// strings; here each is one parameterised test over those strings.
/// `getSingle` returning `undefined`, a value or `null` is
/// `SingleLookup.absent`, `.present` or `.repeated`; `getMulti` returning
/// `undefined` or an array is `ScopeMultiLookup.absent` or `.values`.
@Suite("lib/syntax-string.test.ts")
struct UpstreamSyntaxStringTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let scope: String
        let prefix: String
        var positional: String?
        var params: [(key: String, values: [String])] = []

        var testDescription: String { scope }
    }

    static let cases: [Case] = [
        Case(scope: "my-res", prefix: "my-res"),
        Case(scope: "my-res:my-pos", prefix: "my-res", positional: "my-pos"),
        Case(scope: "my-res:", prefix: "my-res", positional: ""),
        Case(
            scope: "my-res:foo?x=value&y=value-y", prefix: "my-res", positional: "foo",
            params: [("x", ["value"]), ("y", ["value-y"])]
        ),
        Case(scope: "my-res?x=value&y=value-y", prefix: "my-res", params: [("x", ["value"]), ("y", ["value-y"])]),
        Case(scope: "my-res?x=foo&x=bar&x=baz", prefix: "my-res", params: [("x", ["foo", "bar", "baz"])]),
        Case(
            scope: "rpc:foo.bar?aud=did:foo:bar?lxm=bar.baz", prefix: "rpc", positional: "foo.bar",
            params: [("aud", ["did:foo:bar?lxm=bar.baz"])]
        ),
    ]

    @Suite("ScopeStringSyntax")
    struct ScopeStringSyntaxSuite {
        @Test("should match the expected syntax", arguments: cases)
        func matchesExpectedSyntax(content: Case) throws {
            let syntax = try ScopeStringSyntax.parse(content.scope)
            #expect(syntax.prefix == content.prefix)
            #expect(syntax.positional == content.positional)
        }

        @Test("should match ${scope} prefix", arguments: cases)
        func matchesPrefix(content: Case) throws {
            #expect(try ScopeStringSyntax.parse(content.scope).prefix == content.prefix)
        }

        @Test("should return positional parameter", arguments: cases)
        func returnsPositional(content: Case) throws {
            #expect(try ScopeStringSyntax.parse(content.scope).positional == content.positional)
        }

        @Test("should return undefined for nonexistent single-value param", arguments: cases)
        func nonexistentSingle(content: Case) throws {
            #expect(try ScopeStringSyntax.parse(content.scope).getSingle("nonexistent") == .absent)
        }

        @Test("should return undefined for nonexistent multi-value param", arguments: cases)
        func nonexistentMulti(content: Case) throws {
            #expect(try ScopeStringSyntax.parse(content.scope).getMulti("nonexistent") == .absent)
        }

        @Test("only contain allowed parameters", arguments: cases.filter { !$0.params.isEmpty })
        func onlyAllowedParameters(content: Case) throws {
            let allowed = content.params.map(\.key)
            #expect(try ScopeStringSyntax.parse(content.scope).keys().allSatisfy(allowed.contains))
        }

        @Test("should get an array when reading \"${key}\"", arguments: cases.filter { !$0.params.isEmpty })
        func readsArrays(content: Case) throws {
            let syntax = try ScopeStringSyntax.parse(content.scope)
            for (key, values) in content.params {
                #expect(syntax.getMulti(key) == .values(values))
            }
        }

        @Test(
            "should allow retrieving single-value params / should return null for multi-value params",
            arguments: cases.filter { !$0.params.isEmpty }
        )
        func readsSingles(content: Case) throws {
            let syntax = try ScopeStringSyntax.parse(content.scope)
            for (key, values) in content.params {
                if values.count == 1 {
                    #expect(syntax.getSingle(key) == .present(values[0]))
                } else {
                    #expect(syntax.getSingle(key) == .repeated(values))
                }
            }
        }

        @Suite("invalid positional parameters")
        struct InvalidPositionalParameters {
            @Test("should return null for positional parameters used together with named parameters")
            func positionalWithNamed() throws {
                // Despite its name, the original asserts that the lexer
                // accepts this; the conflict is a schema rule.
                let syntax = try ScopeStringSyntax.parse("my-res:pos?x=value")
                #expect(syntax.getSingle("x") == .present("value"))
                #expect(syntax.getMulti("x") == .values(["value"]))
            }
        }

        @Suite("url encoding")
        struct URLEncoding {
            @Test("should handle URL encoding in positional parameters")
            func positional() throws {
                #expect(try ScopeStringSyntax.parse("my-res:my%20pos").positional == "my pos")
            }

            @Test("should handle URL encoding in named parameters")
            func named() throws {
                #expect(try ScopeStringSyntax.parse("my-res?x=my%20value").getSingle("x") == .present("my value"))
            }

            @Test("should allow colon (:) in positional parameters")
            func colonInPositional() throws {
                #expect(try ScopeStringSyntax.parse("my-res:my:pos").positional == "my:pos")
            }
        }
    }
}
