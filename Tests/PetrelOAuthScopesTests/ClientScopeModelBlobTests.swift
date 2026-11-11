import PetrelOAuthScopes
import Testing

/// `blob` permissions: the vectors of `scopes/blob-permission.test.ts` and
/// `lib/mime.test.ts` of `@atproto/oauth-scopes`.
@Suite("Client scope model: blob permission")
struct ClientScopeModelBlobTests {
    // MARK: Parsing

    @Test("parses a positional scope")
    func positional() throws {
        #expect(try BlobPermission.parse("blob:image/png").accept == [.exact("image", "png")])
    }

    /// Values are kept in the order given, as in the reference
    /// implementation; the canonical form sorts them. See DIFFERENCE 4.
    @Test("parses multiple accept parameters")
    func multipleAccept() throws {
        let scope = try BlobPermission.parse("blob?accept=image/png&accept=image/jpeg")
        #expect(scope.accept == [.exact("image", "png"), .exact("image", "jpeg")])
        #expect(try scope.canonicalScopeString() == "blob?accept=image/jpeg&accept=image/png")
        #expect(
            try ClientScopeModelTestSupport.blob(["image/png", "image/jpeg"]).canonicalScopeString()
                == scope.canonicalScopeString()
        )
    }

    static let invalid: [(String, ScopeParseError)] = [
        ("blob", .missingRequiredParameter(prefix: "blob", key: "accept")),
        ("blob?", .missingRequiredParameter(prefix: "blob", key: "accept")),
        ("invalid", .prefixMismatch(expected: "blob", actual: "invalid")),
        ("scope", .prefixMismatch(expected: "blob", actual: "scope")),
        ("blob:invalid", .invalidPositionalValue(prefix: "blob", key: "accept", value: "invalid")),
        ("blob?accept=invalid-mime", .invalidParameterValue(prefix: "blob", key: "accept", value: "invalid-mime")),
        ("blob?accept=invalid", .invalidParameterValue(prefix: "blob", key: "accept", value: "invalid")),
        ("blob:*/**", .invalidPositionalValue(prefix: "blob", key: "accept", value: "*/**")),
        ("blob:*/png", .invalidPositionalValue(prefix: "blob", key: "accept", value: "*/png")),
        ("blob:*", .invalidPositionalValue(prefix: "blob", key: "accept", value: "*")),
        ("blob:/image", .invalidPositionalValue(prefix: "blob", key: "accept", value: "/image")),
        ("blob:", .invalidPositionalValue(prefix: "blob", key: "accept", value: "")),
        ("blob:image/", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image/")),
        ("blob:image//png", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image//png")),
        ("blob:image/png/extra", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image/png/extra")),
        ("blob:image/**", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image/**")),
        ("blob:image/p*", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image/p*")),
        ("blob:image/%20png", .invalidPositionalValue(prefix: "blob", key: "accept", value: "image/ png")),
        ("blob?accept=image/png&accept=nope", .invalidParameterValue(prefix: "blob", key: "accept", value: "nope")),
        ("blob:image/png?accept=image/jpeg", .positionalAndNamedConflict(prefix: "blob", key: "accept")),
        ("blob:image/png?foo=bar", .unknownParameter(prefix: "blob", key: "foo")),
        ("blob:image/png?action=create", .unknownParameter(prefix: "blob", key: "action")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try BlobPermission.parse(scope) }
    }

    // MARK: mime.test.ts

    @Test(
        "isAccept: valid accept patterns",
        arguments: ["image/png", "application/json", "text/html", "image/*", "*/*"]
    )
    func validAccept(_ accept: String) throws {
        let scope = try ClientScopeModelTestSupport.blob([accept])
        #expect(scope.accept.map(\.stringValue) == [accept])
        #expect(try scope.canonicalScopeString() == "blob:" + accept)
        #expect(AcceptPattern(accept)?.stringValue == accept)
    }

    @Test(
        "isAccept: invalid accept patterns",
        arguments: ["image//png", "/png", "image/", "image/**", "*/png", "*", "image/png/extra", "image", "image/ png", ""]
    )
    func invalidAccept(_ accept: String) {
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "blob", key: "accept", value: accept)) {
            try ATProtoScope.blob(accept: [accept])
        }
        #expect(AcceptPattern(accept) == nil)
    }

    @Test("isMime: concrete MIME types match", arguments: ["image/png", "application/json"])
    func validMIME(_ mime: String) throws {
        #expect(try BlobPermission.parse("blob:*/*").matches(.init(mime: mime)))
        #expect(ConcreteMime(mime) != nil)
    }

    /// Nothing but a concrete MIME type can be matched, even by `*/*`.
    @Test(
        "isMime: anything else never matches",
        arguments: ["image/*", "*/*", "image/png/extra", "*/mime", "/png", "image/", "image", "image/ png", "image//png", "/mime", ""]
    )
    func invalidMIME(_ mime: String) throws {
        #expect(try !BlobPermission.parse("blob:*/*").matches(.init(mime: mime)))
        #expect(try !BlobPermission.parse("blob:image/*").matches(.init(mime: mime)))
        #expect(ConcreteMime(mime) == nil)
    }

    /// (accept, mime, matches)
    static let matching: [(String, String, Bool)] = [
        ("image/png", "image/png", true),
        ("image/*", "image/jpeg", true),
        ("image/*", "image/gif", true),
        ("image/png", "image/jpeg", false),
        ("image/*", "text/html", false),
        ("*/*", "application/json", true),
        ("image/png", "*/mime", false),
        ("image/png", "image", false),
        ("image/*", "image//png", false),
        ("image/*", "image/ png", false),
        ("*/*", "image/", false),
        ("*/*", "/mime", false),
        // Beyond the reference vectors.
        ("image/*", "imagex/png", false),
        ("image/*", "image", false),
        ("image/png", "image/pngx", false),
        ("image/png", "image/pn", false),
    ]

    @Test("matchesAccept", arguments: matching)
    func matchesAccept(accept: String, mime: String, expected: Bool) throws {
        #expect(try ClientScopeModelTestSupport.blob([accept]).matches(.init(mime: mime)) == expected)
        #expect(ATProtoScopeSet(scope: "blob:" + accept).allowsBlob(.init(mime: mime)) == expected)
    }

    @Test("matchesAnyAccept")
    func matchesAnyAccept() throws {
        let accepts = try ClientScopeModelTestSupport.blob(["image/png", "application/json"])
        #expect(accepts.matches(.init(mime: "image/png")))
        #expect(accepts.matches(.init(mime: "application/json")))
        #expect(!accepts.matches(.init(mime: "text/html")))

        let single = try ClientScopeModelTestSupport.blob(["image/*"])
        #expect(single.matches(.init(mime: "image/jpeg")))
        #expect(!single.matches(.init(mime: "text/html")))
    }

    /// The reference matcher returns false for an empty accept list; a scope
    /// with no accept value can not be built or parsed here.
    @Test("an empty accept list is not a permission")
    func emptyAccept() {
        #expect(throws: ScopeParseError.missingRequiredParameter(prefix: "blob", key: "accept")) {
            try ATProtoScope.blob(accept: [])
        }
        // The memberwise initializer does not validate (DIFFERENCE 7); such a
        // permission matches nothing.
        #expect(!BlobPermission(accept: []).matches(.init(mime: "image/png")))
    }

    // MARK: Building (scopeNeededFor)

    @Test("builds the scope needed for a MIME type")
    func scopeNeededFor() throws {
        #expect(try ATProtoScope.blob(accept: ["image/png"]).scopeString == "blob:image/png")
        #expect(try ATProtoScope.blob(accept: ["application/json"]).scopeString == "blob:application/json")
        #expect(try BlobPermission.scopeNeeded(for: .init(mime: "image/png")) == "blob:image/png")
    }

    // MARK: Matching

    @Test("matches an exact MIME type")
    func matchesExact() throws {
        #expect(try BlobPermission.parse("blob:image/png").matches(.init(mime: "image/png")))
    }

    @Test("matches any MIME type with the wildcard")
    func matchesWildcard() throws {
        let scope = try BlobPermission.parse("blob:*/*")
        #expect(scope.matches(.init(mime: "image/jpeg")))
        #expect(scope.matches(.init(mime: "application/json")))
    }

    @Test("matches a subtype wildcard")
    func matchesSubtypeWildcard() throws {
        #expect(try BlobPermission.parse("blob:image/*").matches(.init(mime: "image/gif")))
    }

    @Test("does not match a different MIME type")
    func doesNotMatchOther() throws {
        #expect(try !BlobPermission.parse("blob:image/png").matches(.init(mime: "image/jpeg")))
    }

    @Test("matches multiple accept values")
    func matchesMultiple() throws {
        let scope = try BlobPermission.parse("blob?accept=image/png&accept=image/jpeg")
        #expect(scope.matches(.init(mime: "image/png")))
        #expect(scope.matches(.init(mime: "image/jpeg")))
        #expect(!scope.matches(.init(mime: "image/gif")))
    }

    // MARK: Formatting

    @Test("formats multiple accepts as sorted named parameters")
    func formatsMultiple() throws {
        #expect(
            try BlobPermission(accept: [.exact("image", "png"), .exact("image", "jpeg")]).canonicalScopeString()
                == "blob?accept=image/jpeg&accept=image/png"
        )
    }

    @Test("strips redundant accept values")
    func stripsRedundant() throws {
        let canonical = { (accept: [String]) in try ClientScopeModelTestSupport.blob(accept).canonicalScopeString() }
        #expect(try canonical(["*/*", "image/*"]) == "blob:*/*")
        #expect(try canonical(["*/*", "image/png"]) == "blob:*/*")
        #expect(try canonical(["image/*", "image/png"]) == "blob:image/*")
        #expect(try canonical(["image/png", "image/*", "text/html"]) == "blob?accept=image/*&accept=text/html")
        #expect(try canonical(["image/png", "*/*"]) == canonical(["*/*"]))
    }

    @Test("uses the positional form for a single accept")
    func formatsSingle() throws {
        #expect(try BlobPermission(accept: [.exact("image", "png")]).canonicalScopeString() == "blob:image/png")
        #expect(try BlobPermission(accept: [.type("image")]).canonicalScopeString() == "blob:image/*")
        #expect(try BlobPermission(accept: [.any]).canonicalScopeString() == "blob:*/*")
    }

    /// MIME types are case-insensitive, and the canonical form is lowercased.
    @Test("lowercases accept values in the canonical form")
    func lowercases() throws {
        let scope = try BlobPermission.parse("blob:IMAGE/PNG")
        #expect(try scope.canonicalScopeString() == "blob:image/png")
        #expect(try ClientScopeModelTestSupport.blob(["Image/*", "image/PNG"]).canonicalScopeString() == "blob:image/*")
    }

    // PENDING-FIX 2 (fixed in the shared target): a permission written in
    // upper case matches what its lowercased canonical form matches.
    @Test("matches by the lowercased accept value")
    func matchesLowercased() throws {
        let scope = try BlobPermission.parse("blob:IMAGE/PNG")
        #expect(scope.accept == [.exact("image", "png")])
        #expect(scope.matches(.init(mime: "image/png")))
        #expect(ATProtoScopeSet(scope: "blob:IMAGE/PNG").allowsBlob(.init(mime: "image/png")))
        #expect(!scope.matches(.init(mime: "image/jpeg")))
    }

    // DIFFERENCE 10: the media type being matched is compared without regard
    // to letter case as well, so `IMAGE/PNG` is covered by `blob:image/png`
    // and by `blob:image/*`. The reference implementation compares the
    // strings exactly and refuses it.
    @Test("matches a media type given in upper case")
    func matchesUppercaseTarget() throws {
        #expect(try BlobPermission.parse("blob:image/png").matches(.init(mime: "IMAGE/PNG")))
        #expect(try BlobPermission.parse("blob:IMAGE/PNG").matches(.init(mime: "Image/Png")))
        #expect(try ClientScopeModelTestSupport.blob(["image/*"]).matches(.init(mime: "IMAGE/png")))
        #expect(ATProtoScopeSet(scope: "blob:image/*").allowsBlob(.init(mime: "IMAGE/png")))
        #expect(try !ClientScopeModelTestSupport.blob(["image/*"]).matches(.init(mime: "TEXT/png")))
    }

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("blob:image/png", "blob:image/png"),
        ("blob:image/*", "blob:image/*"),
        ("blob:*/*", "blob:*/*"),
        ("blob?accept=image/png", "blob:image/png"),
        ("blob?accept=image/png&accept=image/jpeg", "blob?accept=image/jpeg&accept=image/png"),
        ("blob?accept=image/png&accept=*/*", "blob:*/*"),
        ("blob?accept=image/png&accept=image/*", "blob:image/*"),
        ("blob?accept=video/*&accept=image/*", "blob?accept=image/*&accept=video/*"),
        ("blob:IMAGE/PNG", "blob:image/png"),
        ("blob:image%2Fpng", "blob:image/png"),
        ("blob:%2A%2F%2A", "blob:*/*"),
        ("blob:application/vnd.api+json", "blob:application/vnd.api+json"),
        ("blob:image/svg%2Bxml", "blob:image/svg+xml"),
        // Like the reference `isAccept`, only the `type/subtype` shape is
        // checked; whatever else the value holds is escaped when written.
        ("blob:text/plain;charset=utf-8", "blob:text/plain%3Bcharset%3Dutf-8"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try BlobPermission.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point", arguments: consistency)
    func roundTrips(input _: String, expected: String) throws {
        #expect(try BlobPermission.parse(expected).canonicalScopeString() == expected)
    }

    // MARK: Reference parity

    /// A repeated value is written once but stays in the named form, so the
    /// canonical form of the canonical form differs.
    @Test("a repeated accept value keeps the named form")
    func repeatedAccept() throws {
        let scope = try BlobPermission.parse("blob?accept=image/png&accept=image/png")
        #expect(try scope.canonicalScopeString() == "blob?accept=image/png")
        #expect(try BlobPermission.parse("blob?accept=image/png").canonicalScopeString() == "blob:image/png")
    }

    /// "+" in a parameter value is a space when read, so the named form of a
    /// MIME type containing one has to escape it; the canonical form writes it
    /// bare again. The positional form is unaffected.
    @Test("a MIME type containing a plus sign must be escaped in the named form")
    func plusInNamedForm() throws {
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "blob", key: "accept", value: "image/svg xml")) {
            try BlobPermission.parse("blob?accept=image/svg+xml")
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "blob", key: "accept", value: "image/svg xml")) {
            try BlobPermission.parse("blob?accept=image/svg+xml&accept=image/png")
        }

        let scope = try BlobPermission.parse("blob?accept=image/svg%2Bxml&accept=image/png")
        #expect(scope.accept == [.exact("image", "svg+xml"), .exact("image", "png")])
        #expect(scope.matches(.init(mime: "image/svg+xml")))
        #expect(!scope.matches(.init(mime: "image/svg xml")))
        #expect(try scope.canonicalScopeString() == "blob?accept=image/png&accept=image/svg+xml")
        #expect(try ClientScopeModelTestSupport.blob(["image/svg+xml", "image/png"]) == scope)

        let positional = try BlobPermission.parse("blob:image/svg+xml")
        #expect(positional.accept == [.exact("image", "svg+xml")])
        #expect(try positional.canonicalScopeString() == "blob:image/svg+xml")
    }
}
