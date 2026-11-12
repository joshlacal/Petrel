import PetrelOAuthScopes
import Testing

/// General (resource-independent) scope string syntax.
///
/// The vectors of `lib/syntax.test.ts` and `lib/syntax-string.test.ts` of
/// `@atproto/oauth-scopes`, plus the "Scope String Syntax" section of the
/// permission specification.
@Suite("Client scope model: scope string syntax")
struct ClientScopeModelSyntaxTests {
    struct Vector: Sendable, CustomTestStringConvertible {
        let scope: String
        let resource: String
        let positional: String?
        let parameters: [String: [String]]

        var testDescription: String { scope }
    }

    // MARK: syntax-string.test.ts

    static let structureVectors: [Vector] = [
        Vector(scope: "my-res", resource: "my-res", positional: nil, parameters: [:]),
        Vector(scope: "my-res:my-pos", resource: "my-res", positional: "my-pos", parameters: [:]),
        Vector(scope: "my-res:", resource: "my-res", positional: "", parameters: [:]),
        Vector(
            scope: "my-res:foo?x=value&y=value-y",
            resource: "my-res",
            positional: "foo",
            parameters: ["x": ["value"], "y": ["value-y"]]
        ),
        Vector(
            scope: "my-res?x=value&y=value-y",
            resource: "my-res",
            positional: nil,
            parameters: ["x": ["value"], "y": ["value-y"]]
        ),
        Vector(
            scope: "my-res?x=foo&x=bar&x=baz",
            resource: "my-res",
            positional: nil,
            parameters: ["x": ["foo", "bar", "baz"]]
        ),
        // Only the first "?" starts the parameters, and a ":" after it is
        // part of a value.
        Vector(
            scope: "rpc:foo.bar?aud=did:foo:bar?lxm=bar.baz",
            resource: "rpc",
            positional: "foo.bar",
            parameters: ["aud": ["did:foo:bar?lxm=bar.baz"]]
        ),
        Vector(
            scope: "my-res?x=a:b",
            resource: "my-res",
            positional: nil,
            parameters: ["x": ["a:b"]]
        ),
        // A pair without "=" has an empty value; empty pairs are skipped.
        Vector(scope: "my-res?flag", resource: "my-res", positional: nil, parameters: ["flag": [""]]),
        Vector(scope: "my-res?&x=1&&", resource: "my-res", positional: nil, parameters: ["x": ["1"]]),
        Vector(scope: "my-res?x=a=b", resource: "my-res", positional: nil, parameters: ["x": ["a=b"]]),
    ]

    @Test("splits resource, positional and parameters", arguments: structureVectors)
    func structure(_ vector: Vector) throws {
        let syntax = try ScopeStringSyntax.parse(vector.scope)
        #expect(syntax.prefix == vector.resource)
        #expect(syntax.positional == vector.positional)
        #expect(syntax.parameters.multiple("nonexistent") == nil)
        #expect(syntax.parameters.single("nonexistent") == .absent)
        #expect(Set(syntax.parameters.orderedKeys()) == Set(vector.parameters.keys))
        for (name, values) in vector.parameters {
            #expect(syntax.parameters.multiple(name) == values)
            #expect(syntax.parameters.single(name) == (values.count == 1 ? .present(values[0]) : .repeated(values)))
        }
    }

    @Test("keeps named parameters next to a positional one")
    func positionalWithNamedParameters() throws {
        let syntax = try ScopeStringSyntax.parse("my-res:pos?x=value")
        #expect(syntax.positional == "pos")
        #expect(syntax.parameters.multiple("x") == ["value"])
        #expect(syntax.parameters.entries == [.init(key: "x", value: "value")])
    }

    @Test("percent-decodes the positional part")
    func positionalPercentDecoding() throws {
        #expect(try ScopeStringSyntax.parse("my-res:my%20pos").positional == "my pos")
    }

    @Test("percent-decodes parameter names and values")
    func parameterPercentDecoding() throws {
        let syntax = try ScopeStringSyntax.parse("my-res?x=my%20value&%79=%C3%A9")
        #expect(syntax.parameters.multiple("x") == ["my value"])
        #expect(syntax.parameters.multiple("y") == ["\u{E9}"])
    }

    @Test("allows a colon in the positional part")
    func colonInPositional() throws {
        #expect(try ScopeStringSyntax.parse("my-res:my:pos").positional == "my:pos")
    }

    // MARK: syntax.test.ts (isScopeStringFor)

    static let resourceVectors: [(String, String, Bool)] = [
        ("prefix", "prefix", true),
        ("prefix", "differentResource", false),
        ("prefix:positional", "prefix", true),
        ("differentResource:positional", "prefix", false),
        ("prefix?param=value", "prefix", true),
        ("prefix", "prefi", false),
        ("prefix:pos", "prefi", false),
        ("prefix?param=value", "prefi", false),
        ("prefix", "fix", false),
        ("prefix:pos", "fix", false),
        ("prefix?param=value", "fix", false),
        ("differentResource?param=value", "prefix", false),
    ]

    @Test("identifies the resource a scope is for", arguments: resourceVectors)
    func resourceMatching(scope: String, resource: String, expected: Bool) throws {
        #expect(ScopeStringSyntax.isScopeString(scope, for: resource) == expected)
        let syntax = try ScopeStringSyntax.parse(scope)
        #expect((syntax.prefix == resource) == expected)
    }

    // MARK: Specification: general syntax without semantics

    /// "Scope strings that match the general syntax, but do not have valid
    /// semantics under the current resource definitions".
    static let syntaxOnlyVectors: [Vector] = [
        Vector(scope: "resource", resource: "resource", positional: nil, parameters: [:]),
        Vector(
            scope: "resource:positional?key=val",
            resource: "resource",
            positional: "positional",
            parameters: ["key": ["val"]]
        ),
        Vector(
            scope: "resource:positional&thing?key=val",
            resource: "resource",
            positional: "positional&thing",
            parameters: ["key": ["val"]]
        ),
        Vector(
            scope: "service:did:web:com.example#type?key=val",
            resource: "service",
            positional: "did:web:com.example#type",
            parameters: ["key": ["val"]]
        ),
        Vector(scope: "resource:", resource: "resource", positional: "", parameters: [:]),
        Vector(scope: "resource:?", resource: "resource", positional: "", parameters: [:]),
        Vector(scope: "resource:&", resource: "resource", positional: "&", parameters: [:]),
        Vector(scope: "resource?", resource: "resource", positional: nil, parameters: [:]),
    ]

    @Test("spec: strings matching the general syntax parse as syntax", arguments: syntaxOnlyVectors)
    func specSyntaxOnlyParses(_ vector: Vector) throws {
        let syntax = try ScopeStringSyntax.parse(vector.scope)
        #expect(syntax.prefix == vector.resource)
        #expect(syntax.positional == vector.positional)
        #expect(syntax.parameters.entries.count == vector.parameters.values.map(\.count).reduce(0, +))
        for (name, values) in vector.parameters {
            #expect(syntax.parameters.multiple(name) == values)
        }
    }

    @Test("spec: strings matching only the general syntax are not scopes", arguments: syntaxOnlyVectors)
    func specSyntaxOnlyIsNotAScope(_ vector: Vector) {
        #expect(throws: ScopeParseError.unknownPrefix(vector.scope)) {
            try ATProtoScope(vector.scope)
        }
    }

    // MARK: Token alphabet

    /// (string, error of the syntax parser, error of the scope parser).
    ///
    /// The syntax parser checks the RFC 6749 `scope-token` alphabet first. The
    /// scope parser dispatches on the resource name before that, so a string
    /// that names no known resource is reported as such.
    static let notScopeTokens: [(String, ScopeParseError, ScopeParseError)] = [
        // "Examples which do not match the general syntax".
        ("resource:positional?key=qu\u{E9}bec", .notAScopeToken("resource:positional?key=qu\u{E9}bec"), .unknownPrefix("resource:positional?key=qu\u{E9}bec")),
        ("emoji:\u{263A}\u{FE0F}", .notAScopeToken("emoji:\u{263A}\u{FE0F}"), .unknownPrefix("emoji:\u{263A}\u{FE0F}")),
        // The empty string.
        ("", .notAScopeToken(""), .unknownPrefix("")),
        // Whitespace.
        ("repo:foo bar", .notAScopeToken("repo:foo bar"), .notAScopeToken("repo:foo bar")),
        (" atproto", .notAScopeToken(" atproto"), .unknownPrefix(" atproto")),
        ("atproto ", .notAScopeToken("atproto "), .unknownPrefix("atproto ")),
        ("atproto\u{A}", .notAScopeToken("atproto\u{A}"), .unknownPrefix("atproto\u{A}")),
        ("repo:\u{9}com.example.foo", .notAScopeToken("repo:\u{9}com.example.foo"), .notAScopeToken("repo:\u{9}com.example.foo")),
        ("atproto transition:generic", .notAScopeToken("atproto transition:generic"), .unknownPrefix("atproto transition:generic")),
        ("repo:com.example.foo\u{A0}", .notAScopeToken("repo:com.example.foo\u{A0}"), .notAScopeToken("repo:com.example.foo\u{A0}")),
        ("repo:com.example.foo\u{2003}", .notAScopeToken("repo:com.example.foo\u{2003}"), .notAScopeToken("repo:com.example.foo\u{2003}")),
        // RFC 6749 section 3.3: scope-token = 1*( %x21 / %x23-5B / %x5D-7E ).
        ("repo:\"com.example.foo\"", .notAScopeToken("repo:\"com.example.foo\""), .notAScopeToken("repo:\"com.example.foo\"")),
        ("repo:com.example\\foo", .notAScopeToken("repo:com.example\\foo"), .notAScopeToken("repo:com.example\\foo")),
        ("repo:com.example.foo\u{7F}", .notAScopeToken("repo:com.example.foo\u{7F}"), .notAScopeToken("repo:com.example.foo\u{7F}")),
        ("repo:com.example.foo\u{0}", .notAScopeToken("repo:com.example.foo\u{0}"), .notAScopeToken("repo:com.example.foo\u{0}")),
        ("repo:com.example.f\u{F6}o", .notAScopeToken("repo:com.example.f\u{F6}o"), .notAScopeToken("repo:com.example.f\u{F6}o")),
        ("r\u{E9}po:com.example.foo", .notAScopeToken("r\u{E9}po:com.example.foo"), .unknownPrefix("r\u{E9}po:com.example.foo")),
        ("repo:com.example.foo?action=cr\u{E9}ate", .notAScopeToken("repo:com.example.foo?action=cr\u{E9}ate"), .notAScopeToken("repo:com.example.foo?action=cr\u{E9}ate")),
    ]

    @Test("rejects strings that are not an OAuth scope-token", arguments: notScopeTokens)
    func notAScopeToken(scope: String, syntaxError: ScopeParseError, scopeError: ScopeParseError) {
        #expect(syntaxError == .notAScopeToken(scope))
        #expect(throws: syntaxError) { try ScopeStringSyntax.parse(scope) }
        #expect(throws: scopeError) { try ATProtoScope(scope) }
        #expect(ScopeToken(scope) == nil)
    }

    @Test("accepts every other printable ASCII character")
    func printableASCII() throws {
        let positional = "!#$&'()*+,-./0123456789:;<=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~"
        let syntax = try ScopeStringSyntax.parse("x:" + positional)
        #expect(syntax.prefix == "x")
        #expect(syntax.positional == positional)
        #expect(ScopeToken("x:" + positional)?.rawValue == "x:" + positional)
    }

    // MARK: Percent-encoding

    /// (string, error of the syntax parser, error of the scope parser).
    static let malformedPositional: [(String, ScopeParseError, ScopeParseError)] = [
        ("repo:%zz", .malformedPercentEncoding("repo:%zz"), .malformedPercentEncoding("repo:%zz")),
        ("repo:com.example.foo%", .malformedPercentEncoding("repo:com.example.foo%"), .malformedPercentEncoding("repo:com.example.foo%")),
        ("repo:com.example.foo%4", .malformedPercentEncoding("repo:com.example.foo%4"), .malformedPercentEncoding("repo:com.example.foo%4")),
        // Not UTF-8 once decoded.
        ("repo:%FF", .malformedPercentEncoding("repo:%FF"), .malformedPercentEncoding("repo:%FF")),
        ("repo:%C3", .malformedPercentEncoding("repo:%C3"), .malformedPercentEncoding("repo:%C3")),
    ]

    @Test("rejects malformed percent-encoding in the positional part", arguments: malformedPositional)
    func malformedPositionalEncoding(scope: String, syntaxError: ScopeParseError, scopeError: ScopeParseError) {
        #expect(syntaxError == .malformedPercentEncoding(scope))
        #expect(throws: syntaxError) { try ScopeStringSyntax.parse(scope) }
        #expect(throws: scopeError) { try ATProtoScope(scope) }
    }

    // DIFFERENCE 1: the parameter part is decoded the way `URLSearchParams`
    // decodes it, which never fails: a malformed escape stays as written and
    // invalid UTF-8 becomes U+FFFD. The syntax parser therefore accepts these
    // strings; the scope is still rejected, by the parameter's own validation.
    /// (string, decoded name, decoded value, error of the scope parser)
    static let malformedParameter: [(String, String, String, ScopeParseError)] = [
        (
            "repo:com.example.foo?action=%",
            "action", "%",
            .invalidParameterValue(prefix: "repo", key: "action", value: "%")
        ),
        (
            "repo:com.example.foo?action=%G0",
            "action", "%G0",
            .invalidParameterValue(prefix: "repo", key: "action", value: "%G0")
        ),
        (
            "repo:com.example.foo?%=create",
            "%", "create",
            .unknownParameter(prefix: "repo", key: "%")
        ),
        (
            "repo:com.example.foo?action=%C3%28",
            "action", "\u{FFFD}(",
            .invalidParameterValue(prefix: "repo", key: "action", value: "\u{FFFD}(")
        ),
    ]

    @Test("keeps malformed percent-encoding in the parameter part as written", arguments: malformedParameter)
    func malformedParameterEncoding(scope: String, name: String, value: String, scopeError: ScopeParseError) throws {
        let syntax = try ScopeStringSyntax.parse(scope)
        #expect(syntax.parameters.entries == [.init(key: name, value: value)])
        #expect(throws: scopeError) { try ATProtoScope(scope) }
    }

    @Test("accepts lowercase and uppercase hex digits")
    func hexDigitCase() throws {
        #expect(try ScopeStringSyntax.parse("x:%2f%2F").positional == "//")
    }

    // MARK: Serialization

    /// (input, serialized, whether the serialized form reads back to the same
    /// parts)
    static let serializationVectors: [(String, String, Bool)] = [
        ("my-res", "my-res", true),
        ("my-res:", "my-res:", true),
        ("my-res:my-pos", "my-res:my-pos", true),
        ("my-res:foo?x=value&y=value-y", "my-res:foo?x=value&y=value-y", true),
        ("my-res?x=foo&x=bar&x=baz", "my-res?x=foo&x=bar&x=baz", true),
        // An empty parameter part is dropped.
        ("my-res?", "my-res", true),
        ("my-res:pos?", "my-res:pos", true),
        ("my-res:pos?&", "my-res:pos", true),
        // Reserved characters are escaped ...
        ("my-res:a%23b%3Fc%26d%3De%20f", "my-res:a%23b%3Fc%26d%3De%20f", true),
        ("my-res:a#b&c=d", "my-res:a%23b%26c%3Dd", true),
        ("my-res?x=a#b", "my-res?x=a%23b", true),
        ("my-res?x=a%26b%3Dc", "my-res?x=a%26b%3Dc", true),
        // ... while ":", "/", "," and "@" are left readable.
        ("my-res:a%3Ab%2Fc%2Cd%40e", "my-res:a:b/c,d@e", true),
        ("my-res?x=a%3Ab%2Fc%2Cd%40e", "my-res?x=a:b/c,d@e", true),
        // encodeURIComponent leaves !~*'() bare in the positional part, the
        // form serializer escapes !~'() in the parameters.
        ("my-res:!~*'()", "my-res:!~*'()", true),
        ("my-res?x=!~*'()", "my-res?x=%21%7E*%27%28%29", true),
        // A space is "%20" in the positional part and "+" in the parameters.
        ("my-res:a%20b", "my-res:a%20b", true),
        ("my-res?x=a%20b", "my-res?x=a+b", true),
        // "+" is a literal plus in the positional part.
        ("my-res:a+b", "my-res:a+b", true),
        ("my-res:a%2Bb", "my-res:a+b", true),
        // DIFFERENCE 2: in the parameter part "+" is a space when read ...
        ("my-res?x=a+b", "my-res?x=a+b", true),
        // ... and an escaped plus is written back bare, so it reads back as a
        // space.
        ("my-res?x=a%2Bb", "my-res?x=a+b", false),
        // DIFFERENCE 3: a literal "%" is written back bare, so the result is
        // either not decodable or decodes once more.
        ("my-res:100%25", "my-res:100%", false),
        ("my-res?x=%253A", "my-res?x=%3A", false),
        // Non-ASCII values are written as percent-encoded UTF-8.
        ("my-res:%C3%A9?x=%E2%98%BA", "my-res:%C3%A9?x=%E2%98%BA", true),
    ]

    @Test("serializes with the reference implementation's escaping", arguments: serializationVectors)
    func serialization(input: String, expected: String, readsBack: Bool) throws {
        let syntax = try ScopeStringSyntax.parse(input)
        let serialized = try syntax.canonicalString()
        #expect(serialized == expected)

        let reparsed = try? ScopeStringSyntax.parse(serialized)
        let sameParts = reparsed?.prefix == syntax.prefix
            && reparsed?.positional == syntax.positional
            && reparsed?.parameters == syntax.parameters
        #expect(sameParts == readsBack)
    }

    /// Reference parity: `URLSearchParams` decodes "+" as a space.
    @Test("a plus sign in a parameter value is a space")
    func plusIsSpace() throws {
        let syntax = try ScopeStringSyntax.parse("blob?accept=image/svg+xml")
        #expect(syntax.parameters.multiple("accept") == ["image/svg xml"])
        #expect(try ScopeStringSyntax.parse("blob?accept=image/svg%2Bxml").parameters.multiple("accept") == ["image/svg+xml"])
        #expect(try ScopeStringSyntax.parse("blob:image/svg+xml").positional == "image/svg+xml")
    }
}
