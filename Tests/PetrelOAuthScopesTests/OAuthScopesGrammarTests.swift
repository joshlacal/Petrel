import Foundation
import Testing
@testable import PetrelOAuthScopes

/// The grammar layer on its own: `ScopeToken`, `ScopeStringSyntax`,
/// `ScopeParameterBag` and `AtprotoSyntax`, plus the schema-level rejections
/// with their exact error case.
///
/// The one-to-one ports of the reference implementation's test files live in
/// `Upstream/`; this suite covers what those do not name.
@Suite("OAuth scope grammar layer")
struct OAuthScopesGrammarTests {
    // MARK: ScopeToken

    @Test
    func scopeTokenExcludesQuoteAndBackslash() {
        #expect(ScopeToken.isScopeToken("account:email"))
        #expect(!ScopeToken.isScopeToken("has space"))
        #expect(!ScopeToken.isScopeToken("has\"quote"))
        #expect(!ScopeToken.isScopeToken("has\\backslash"))
        #expect(!ScopeToken.isScopeToken(""))
        #expect(ScopeToken("atproto")?.rawValue == "atproto")
        #expect(ScopeToken("two tokens") == nil)
    }

    // MARK: ScopeStringSyntax lexing

    @Test
    func emptyPositionalIsLegalAndDistinctFromAbsent() throws {
        let withColon = try ScopeStringSyntax.parse("my-res:")
        #expect(withColon.positional == "")
        let bare = try ScopeStringSyntax.parse("my-res")
        #expect(bare.positional == nil)
    }

    @Test
    func theFirstQuestionMarkStartsTheQuery() throws {
        let syntax = try ScopeStringSyntax.parse("rpc:a?b=1")
        #expect(syntax.positional == "a")
        #expect(syntax.parameters.values(for: "b") == ["1"])

        // A later `?` belongs to the value it appears in
        // (lib/syntax-string.test.ts:34-41).
        let later = try ScopeStringSyntax.parse("rpc:foo.bar?aud=did:foo:bar?lxm=bar.baz")
        #expect(later.positional == "foo.bar")
        #expect(later.parameters.values(for: "aud") == ["did:foo:bar?lxm=bar.baz"])
        #expect(later.parameters.orderedKeys() == ["aud"])
    }

    @Test
    func laterHashIsALiteralNotAFragment() throws {
        // scopes/include-scope.test.ts:31-40 — this is a query string, not a URL.
        let a = try ScopeStringSyntax.parse("include:com.example.baz?aud=did:web:example.com%23my_service")
        let b = try ScopeStringSyntax.parse("include:com.example.baz?aud=did:web:example.com#my_service")
        #expect(a.parameters.values(for: "aud") == ["did:web:example.com#my_service"])
        #expect(b.parameters.values(for: "aud") == ["did:web:example.com#my_service"])
    }

    @Test
    func isScopeStringRejectsSuperstringFalsePositives() {
        #expect(!ScopeStringSyntax.isScopeString("prefixes", for: "prefix"))
        #expect(ScopeStringSyntax.isScopeString("prefix", for: "prefix"))
        #expect(ScopeStringSyntax.isScopeString("prefix:x", for: "prefix"))
        #expect(ScopeStringSyntax.isScopeString("prefix?x=1", for: "prefix"))
    }

    // MARK: percent-decoding

    @Test
    func positionalPercentDecodingThrowsOnMalformedEscape() {
        // `decodeURIComponent` throws `URIError` here (lib/syntax-string.ts:62-64).
        for scope in ["account:100%", "repo:%zz", "repo:%E0%A4%A", "repo:%4"] {
            #expect(throws: ScopeParseError.malformedPercentEncoding(scope)) {
                try ScopeStringSyntax.parse(scope)
            }
        }
    }

    @Test
    func queryPercentDecodingIsLossyAndNeverThrows() throws {
        // `URLSearchParams` keeps a malformed escape as literal bytes. Whether
        // the value is acceptable is then up to the parameter's validator.
        let syntax = try ScopeStringSyntax.parse("rpc:com.example.method?aud=did:web:ex%ample.com")
        #expect(syntax.parameters.values(for: "aud") == ["did:web:ex%ample.com"])
        #expect(try ScopeStringSyntax.parse("my-res?x=%").parameters.values(for: "x") == ["%"])
        #expect(try ScopeStringSyntax.parse("my-res?x=%4").parameters.values(for: "x") == ["%4"])
        // Invalid UTF-8 becomes U+FFFD.
        #expect(try ScopeStringSyntax.parse("my-res?x=%FF").parameters.values(for: "x") == ["\u{FFFD}"])
    }

    @Test
    func emptyQueryPairIsSkippedNotRejected() throws {
        // scopes/rpc-permission.test.ts:311-314.
        let syntax = try ScopeStringSyntax.parse("rpc:com.example.method1?&aud=*")
        #expect(syntax.parameters.values(for: "aud") == ["*"])
        #expect(syntax.parameters.entries.count == 1)
    }

    @Test
    func aPairWithoutEqualsHasAnEmptyValue() throws {
        let syntax = try ScopeStringSyntax.parse("my-res?flag&x=1")
        #expect(syntax.parameters.single("flag") == .present(""))
        #expect(syntax.parameters.single("x") == .present("1"))
        // Only the first `=` separates name from value.
        #expect(try ScopeStringSyntax.parse("my-res?x=a=b").parameters.single("x") == .present("a=b"))
    }

    @Test
    func plusFoldsToSpaceOnlyInQueryValues() throws {
        let syntax = try ScopeStringSyntax.parse("my-res:a+b?key=a+b")
        #expect(syntax.positional == "a+b")
        #expect(syntax.parameters.values(for: "key") == ["a b"])
    }

    @Test
    func singleLookupDistinguishesAbsentPresentAndRepeated() throws {
        let syntax = try ScopeStringSyntax.parse("my-res?x=1&y=2&y=3")
        #expect(syntax.parameters.single("x") == .present("1"))
        #expect(syntax.parameters.single("y") == .repeated(["2", "3"]))
        #expect(syntax.parameters.single("z") == .absent)
        #expect(syntax.parameters.multiple("y") == ["2", "3"])
        #expect(syntax.parameters.multiple("z") == nil)
        #expect(syntax.getMulti("z") == .absent)
        #expect(syntax.getMulti("y") == .values(["2", "3"]))
    }

    // MARK: canonical serialiser

    @Test
    func canonicalSerialiserUsesFormEncodingForQueryAndUriComponentForPositional() throws {
        let syntax = ScopeStringSyntax(
            prefix: "rpc",
            positional: "com.example.service",
            parameters: ScopeParameterBag([.init(key: "aud", value: "did:web:example.com#service_id")])
        )
        // "#" is not un-escaped by `normalizeURIComponent`, so it stays `%23`
        // (scopes/rpc-permission.test.ts:30-35).
        #expect(try syntax.canonicalString() == "rpc:com.example.service?aud=did:web:example.com%23service_id")
    }

    @Test
    func tildeSurvivesRawInPositionalButIsEscapedInQuery() throws {
        // `encodeURIComponent` leaves `~` alone; `URLSearchParams` encodes it.
        let positionalTilde = ScopeStringSyntax(prefix: "my-res", positional: "a~b")
        #expect(try positionalTilde.canonicalString() == "my-res:a~b")

        let queryTilde = ScopeStringSyntax(
            prefix: "my-res",
            positional: "x",
            parameters: ScopeParameterBag([.init(key: "key", value: "a~b")])
        )
        #expect(try queryTilde.canonicalString() == "my-res:x?key=a%7Eb")
    }

    @Test
    func spaceIsPercentTwentyInPositionalAndPlusInQuery() throws {
        let syntax = ScopeStringSyntax(
            prefix: "my-res",
            positional: "a b",
            parameters: ScopeParameterBag([.init(key: "key", value: "a b")])
        )
        #expect(try syntax.canonicalString() == "my-res:a%20b?key=a+b")
    }

    @Test
    func canonicalStringIsAlwaysAScopeToken() {
        // A value that would put `"` in the output is refused, not emitted.
        let syntax = ScopeStringSyntax(prefix: "my\"res")
        #expect(throws: ScopeParseError.notAScopeToken("my\"res")) { try syntax.canonicalString() }
    }

    // MARK: AtprotoSyntax — DID / NSID / record key

    @Test
    func nsidHyphenAndDigitRules() {
        // packages/syntax/src/nsid.ts:164-180.
        #expect(!AtprotoSyntax.isValidNSID("com.example.foo-bar")) // no hyphen in the name segment
        #expect(!AtprotoSyntax.isValidNSID("com.example-.foo")) // no segment ends with a hyphen
        #expect(!AtprotoSyntax.isValidNSID("com.-example.foo")) // nor starts with one
        #expect(AtprotoSyntax.isValidNSID("com.ex-ample.foo"))
        #expect(AtprotoSyntax.isValidNSID("com.9example.foo")) // a middle segment may start with a digit
        #expect(!AtprotoSyntax.isValidNSID("9com.example.foo")) // the first segment may not
        #expect(!AtprotoSyntax.isValidNSID("com.example.1foo")) // nor may the name segment
        #expect(AtprotoSyntax.isValidNSID("com.example.foo1"))
    }

    @Test
    func nsidRequiresAtLeastThreeSegments() {
        #expect(!AtprotoSyntax.isValidNSID("short.a"))
        #expect(!AtprotoSyntax.isValidNSID("com"))
        #expect(!AtprotoSyntax.isValidNSID(""))
        #expect(!AtprotoSyntax.isValidNSID("com..foo"))
        #expect(!AtprotoSyntax.isValidNSID("com.example.foo."))
        #expect(AtprotoSyntax.isValidNSID("a.b.c"))
        #expect(AtprotoSyntax.isValidNSID("com.example.foo"))
    }

    @Test
    func nsidLengthLimits() {
        let segment63 = String(repeating: "a", count: 63)
        let segment64 = String(repeating: "a", count: 64)
        #expect(AtprotoSyntax.isValidNSID("com.\(segment63).foo"))
        #expect(!AtprotoSyntax.isValidNSID("com.\(segment64).foo"))
        #expect(AtprotoSyntax.isValidNSID("com.example.\(segment63)"))
        #expect(!AtprotoSyntax.isValidNSID("com.example.\(segment64)"))
        // 317 bytes in total is the limit.
        let head = Array(repeating: segment63, count: 4).joined(separator: ".")
        #expect(AtprotoSyntax.isValidNSID("\(head).\(String(repeating: "b", count: 57)).foo"))
        #expect(!AtprotoSyntax.isValidNSID("\(head).\(String(repeating: "b", count: 58)).foo"))
    }

    @Test
    func didSyntaxRejectsTrailingColonAndBareDidPrefix() {
        #expect(!AtprotoSyntax.isValidDID("did:"))
        #expect(!AtprotoSyntax.isValidDID("did:plc:"))
        #expect(!AtprotoSyntax.isValidDID("did:web:example.com:"))
        #expect(!AtprotoSyntax.isValidDID("not-a-did"))
        #expect(!AtprotoSyntax.isValidDID("did:PLC:abc"))
        #expect(AtprotoSyntax.isValidDID("did:plc:abc123xyz"))
        #expect(AtprotoSyntax.isValidDID("did:web:example.com"))
    }

    @Test
    func recordKeySyntax() {
        for accepted in ["self", "3jui7kd54zh2y", "a.b-c_d~e:f", String(repeating: "x", count: 512)] {
            #expect(AtprotoSyntax.isValidRecordKey(accepted))
        }
        for rejected in ["", "hello world", ".", "..", "a/b", "a#b", String(repeating: "x", count: 513)] {
            #expect(!AtprotoSyntax.isValidRecordKey(rejected))
        }
    }

    // MARK: AtprotoSyntax — DID references

    @Test
    func didRefAbsoluteUpstreamVectors() {
        // packages/did/tests/did-ref.test.ts
        #expect(AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:l3rouwludahu3ui3bt66mfvj#atproto"))
        #expect(AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:example.com#service_id"))
        #expect(AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:example.com#atproto_label"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:l3rouwludahu3ui3bt66mfvj"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:example.com"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("#atproto"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute(""))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:l3rouwludahu3ui3bt66mfvj#"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:l3rouwludahu3ui3bt66mfvj##foo"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:l3rouwludahu3ui3bt66mfvj#a#b"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:foo:bar#baz")) // method is neither plc nor web
        // The method-agnostic predicate accepts it: the two are separate checks.
        #expect(AtprotoSyntax.isValidDIDRefAbsolute("did:foo:bar#baz"))
    }

    @Test
    func atprotoDidWebExcludesPathsAndNonLocalhostPorts() {
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:example.com:admin#atproto"))
        #expect(AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:localhost%3A8080#atproto"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:web:example.com%3A8443#atproto"))
        #expect(AtprotoSyntax.isValidAtprotoDID("did:web:localhost"))
        #expect(!AtprotoSyntax.isValidAtprotoDID("did:web:localhost:8080"))
    }

    @Test
    func atprotoDidPlcIsFixedLengthBase32() {
        #expect(AtprotoSyntax.isValidAtprotoDID("did:plc:z72i7hdynmk6r22z27h6tvur"))
        #expect(!AtprotoSyntax.isValidAtprotoDID("did:plc:z72i7hdynmk6r22z27h6tvu")) // 23 characters
        #expect(!AtprotoSyntax.isValidAtprotoDID("did:plc:z72i7hdynmk6r22z27h6tvu1")) // `1` is not base32
        #expect(!AtprotoSyntax.isValidAtprotoDID("did:plc:Z72I7HDYNMK6R22Z27H6TVUR"))
        #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute("did:plc:111#service_id"))
    }

    @Test
    func didCorePercentEscapesAreUppercaseHexadecimal() {
        // `assertDidMsid`, packages/did/src/did.ts:173-199.
        #expect(AtprotoSyntax.isValidDIDRefAbsolute("did:example:a%3Ab#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:example:a%3ab#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:example:a%#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:example:a%4#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:example:a:#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:example:#x"))
        #expect(AtprotoSyntax.isValidDIDRefAbsolute("did:ex4mple:a#x"))
        #expect(!AtprotoSyntax.isValidDIDRefAbsolute("did:Example:a#x"))
    }

    // MARK: schema-level rejections, with the exact error case

    @Test
    func positionalAndNamedConflictIsPinnedAcrossFamilies() {
        // lib/parser.ts:124-127 — the positional and named form of the same
        // parameter together are rejected, whether or not the values agree.
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "account", key: "attr")) {
            try AccountPermission.parse("account:email?attr=repo")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "account", key: "attr")) {
            try AccountPermission.parse("account:email?attr=email")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "identity", key: "attr")) {
            try IdentityPermission.parse("identity:handle?attr=*")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "repo", key: "collection")) {
            // The example the permission specification gives.
            try RepoPermission.parse("repo:com.example.record?collection=com.example.other")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "blob", key: "accept")) {
            try BlobPermission.parse("blob:image/png?accept=image/jpeg")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "include", key: "nsid")) {
            try IncludeScope.parse("include:com.example.foo?nsid=com.example.foo")
        }
        #expect(throws: ScopeParseError.positionalAndNamedConflict(prefix: "rpc", key: "lxm")) {
            // scopes/rpc-permission.test.ts:65-71.
            try RpcPermission.parse("rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2")
        }
    }

    @Test
    func repeatedSingleValuedParameterIsPinnedAcrossFamilies() {
        // lib/syntax-string.ts:18-23 -> lib/parser.ts:121-122 — a single-valued
        // parameter given more than once is rejected, not resolved to its
        // first or last value. `repo` and `blob` declare no single-valued
        // parameter and cannot produce this error.
        #expect(throws: ScopeParseError.repeatedSingleValuedParameter(prefix: "account", key: "attr")) {
            try AccountPermission.parse("account?attr=email&attr=repo")
        }
        #expect(throws: ScopeParseError.repeatedSingleValuedParameter(prefix: "identity", key: "attr")) {
            try IdentityPermission.parse("identity?attr=handle&attr=*")
        }
        #expect(throws: ScopeParseError.repeatedSingleValuedParameter(prefix: "include", key: "nsid")) {
            try IncludeScope.parse("include?nsid=com.example.foo&nsid=com.example.bar")
        }
        #expect(throws: ScopeParseError.repeatedSingleValuedParameter(prefix: "include", key: "aud")) {
            try IncludeScope.parse(
                "include:com.example.foo?aud=did:web:example.com%23a&aud=did:web:example.com%23b"
            )
        }
        #expect(throws: ScopeParseError.repeatedSingleValuedParameter(prefix: "rpc", key: "aud")) {
            try RpcPermission.parse(
                "rpc:com.example.method?aud=did:web:example.com%23a&aud=did:web:example.com%23b"
            )
        }
    }

    @Test
    func eachRejectionHasItsOwnErrorCase() {
        #expect(throws: ScopeParseError.unknownParameter(prefix: "identity", key: "action")) {
            try IdentityPermission.parse("identity:*?action=manage")
        }
        #expect(throws: ScopeParseError.missingRequiredParameter(prefix: "rpc", key: "aud")) {
            try RpcPermission.parse("rpc:com.example.method")
        }
        #expect(throws: ScopeParseError.missingRequiredParameter(prefix: "blob", key: "accept")) {
            try BlobPermission.parse("blob")
        }
        #expect(throws: ScopeParseError.invalidPositionalValue(prefix: "repo", key: "collection", value: "invalid")) {
            try RepoPermission.parse("repo:invalid")
        }
        // An empty positional is present and invalid, not absent.
        #expect(throws: ScopeParseError.invalidPositionalValue(prefix: "rpc", key: "lxm", value: "")) {
            try RpcPermission.parse("rpc:?aud=*")
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "repo", key: "action", value: "*")) {
            try RepoPermission.parse("repo:*?action=*")
        }
        #expect(throws: ScopeParseError.forbiddenParameterCombination(prefix: "rpc", detail: "aud=* and lxm=* together")) {
            try RpcPermission.parse("rpc:*?aud=*")
        }
        #expect(throws: ScopeParseError.prefixMismatch(expected: "repo", actual: "rpc:com.example.method?aud=*")) {
            try RepoPermission.parse("rpc:com.example.method?aud=*")
        }
        #expect(throws: ScopeParseError.unknownPrefix("openid")) {
            try ATProtoScope.parse("openid")
        }
    }

    @Test
    func errorDescriptionsDoNotEchoTheScope() {
        let secret = "repo:com.example.SECRET?action=nope"
        let errors: [ScopeParseError] = [
            .notAScopeToken(secret), .malformedPercentEncoding(secret), .unknownPrefix(secret),
            .prefixMismatch(expected: "repo", actual: secret),
            .invalidParameterValue(prefix: "repo", key: "action", value: secret),
            .invalidPositionalValue(prefix: "repo", key: "collection", value: secret),
        ]
        for error in errors {
            #expect(!error.description.contains("SECRET"))
        }
    }

    @Test
    func percentEscapedPositionalDecodesBeforeValidation() throws {
        let decoded = try RepoPermission.parse("repo:com%2Eexample%2Efoo")
        #expect(decoded.collection == [.nsid("com.example.foo")])
        #expect(try decoded.canonicalScopeString() == "repo:com.example.foo")
    }
}
