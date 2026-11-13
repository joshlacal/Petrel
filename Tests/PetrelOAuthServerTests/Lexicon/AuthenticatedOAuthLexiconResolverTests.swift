import Crypto
import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelOAuthServer
@testable import PetrelOAuthServerLexicon
import PetrelRepo
import PetrelRepoTestSupport
import Testing

/// DNS answers by name; a name absent from the table has no TXT records.
struct StubLexiconDNS: IdentityDNSResolver {
    var records: [String: [String]] = [:]
    var failing = false

    func queryTXT(name: String) async throws -> [String] {
        if failing { throw IdentityError.timedOut(name) }
        return records[name] ?? []
    }
}

struct StubLexiconAuthorities: OAuthLexiconAuthorityResolving {
    var authorities: [String: OAuthLexiconAuthority] = [:]
    var error: OAuthLexiconAuthorityError?

    func resolveAuthority(did: String) async throws -> OAuthLexiconAuthority {
        if let error { throw error }
        guard let authority = authorities[did] else { throw OAuthLexiconAuthorityError.documentUnavailable }
        return authority
    }
}

/// One authority (`foo.example.com` → `did:plc:…` → `https://pds.example.com`)
/// serving one proof CAR.
struct LexiconResolverScenario {
    static let nsid = PublicRepositoryProofFixtureBuilder.defaultNSID
    static let did = PublicRepositoryProofFixtureBuilder.defaultRequestedDID
    static let pds = "https://pds.example.com"
    static let txtName = "_lexicon.foo.example.com"

    let fixture: PublicRepositoryProofFixture
    let transport = StubTransport()
    var dns = StubLexiconDNS(records: [Self.txtName: ["did=\(Self.did)"]])
    var authorities: StubLexiconAuthorities

    static var getRecordURL: String {
        "\(pds)/xrpc/com.atproto.sync.getRecord?did=\(did)&collection=com.atproto.lexicon.schema&rkey=\(nsid)"
    }

    /// - Parameters:
    ///   - signedByCommitKey: name the key that signed the commit in the DID
    ///     document, rather than the requested DID's own key.
    ///   - curve: the curve of the repository's signing keys.
    init(
        _ variant: PublicRepositoryProofFixtureVariant = .valid,
        signedByCommitKey: Bool = false,
        curve: ATProtoKeyCurve = .p256
    ) async throws {
        fixture = try await PublicRepositoryProofFixtureBuilder.build(variant, curve: curve)
        let key = signedByCommitKey ? fixture.commitPublicKey : fixture.documentPublicKey
        authorities = StubLexiconAuthorities(authorities: [
            Self.did: OAuthLexiconAuthority(pdsEndpoint: URL(string: Self.pds)!, signingKey: key),
        ])
        transport.serve(Self.getRecordURL, .init(contentType: "application/vnd.ipld.car", body: fixture.carBytes))
    }

    func resolver(pins: Bool = true) throws -> AuthenticatedOAuthLexiconResolver {
        let transport: any OAuthRemoteTransport = pins ? self.transport : NonPinningTransport(inner: self.transport)
        return try AuthenticatedOAuthLexiconResolver(
            fetcher: OAuthRemoteDocumentFetcher(
                policy: OAuthRemoteFetchPolicy(), resolver: StubResolver(), transport: transport
            ),
            dns: dns,
            authorities: authorities,
            clock: TestClock(),
            deadlines: .relaxed
        )
    }
}

struct NonPinningTransport: OAuthRemoteTransport {
    let inner: StubTransport
    var pinsConnectionsToApprovedPeers: Bool { false }

    func get(url: URL, approvedPeers: Set<OAuthIPAddress>, timeout: TimeInterval, maximumBodyBytes: Int) async throws -> OAuthRemoteHTTPResponse {
        try await inner.get(url: url, approvedPeers: approvedPeers, timeout: timeout, maximumBodyBytes: maximumBodyBytes)
    }
}

extension AuthenticatedOAuthLexiconResolver.Deadlines {
    /// Far beyond anything a fake needs, so load cannot trip them.
    static let relaxed = Self(dns: 300, didDocument: 300, recordFetch: 300)
}

/// The failure `performResolution` stopped at, or nil when it resolved.
func resolverFailure(_ resolver: AuthenticatedOAuthLexiconResolver, _ nsid: String = LexiconResolverScenario.nsid) async -> OAuthLexiconResolverFailure? {
    do {
        _ = try await resolver.performResolution(nsid)
        return nil
    } catch let failure as OAuthLexiconResolverFailure {
        return failure
    } catch {
        Issue.record("unexpected error \(error)")
        return nil
    }
}

@Suite("Permission sets: authenticated Lexicon resolution")
struct AuthenticatedOAuthLexiconResolverTests {
    @Test(
        "a proved record resolves to its permission set, URI and CID, fetched with sync.getRecord",
        arguments: ATProtoKeyCurve.allCases
    )
    func resolvesValidProof(curve: ATProtoKeyCurve) async throws {
        let scenario = try await LexiconResolverScenario(curve: curve)
        #expect(scenario.fixture.documentPublicKey.curve == curve)
        let resolution = try await scenario.resolver().resolve(LexiconResolverScenario.nsid)
        guard case let .resolved(.permissionSet(set), sourceURI, cid) = resolution else {
            Issue.record("\(resolution)")
            return
        }
        #expect(sourceURI == "at://\(LexiconResolverScenario.did)/com.atproto.lexicon.schema/\(LexiconResolverScenario.nsid)")
        #expect(cid == scenario.fixture.recordCID.string)
        #expect(set.permissions.map(\.resource) == ["repo"])
        #expect(scenario.transport.requests == [LexiconResolverScenario.getRecordURL])
    }

    @Test("every broken proof is refused at the step that catches it, on either curve", arguments: [
        (PublicRepositoryProofFixtureVariant.twoCARRoots, false, OAuthLexiconResolverFailure.carRootCountInvalid),
        (.crossRepositorySubstitution, false, .commitDIDMismatch),
        // Signature valid under the key named in the document: only the DID
        // equality refuses it.
        (.crossRepositorySubstitution, true, .commitDIDMismatch),
        (.flippedCommitSignatureByte, false, .commitSignatureInvalid),
        (.commitSignedWithUnnamedKey, false, .commitSignatureInvalid),
        (.recordPresentButUnlinked, false, .recordNotInProof),
        (.omittedPathNode, false, .recordNotInProof),
        (.recordTypeMismatch("com.example.foo.item"), false, .recordTypeMismatch),
        (.lexiconIDMismatch("com.example.foo.other"), false, .documentIDMismatch),
    ], ATProtoKeyCurve.allCases)
    func refusesBrokenProofs(
        vector: (PublicRepositoryProofFixtureVariant, Bool, OAuthLexiconResolverFailure),
        curve: ATProtoKeyCurve
    ) async throws {
        let (variant, signedByCommitKey, expected) = vector
        let scenario = try await LexiconResolverScenario(variant, signedByCommitKey: signedByCommitKey, curve: curve)
        let resolver = try scenario.resolver()
        #expect(await resolverFailure(resolver) == expected)
        #expect(try await resolver.resolve(LexiconResolverScenario.nsid) == .unresolvable)
    }

    @Test("the _lexicon TXT record must name exactly one DID", arguments: [
        ([String](), OAuthLexiconResolverFailure.noAuthorityDIDInTXT),
        (["v=spf1 -all"], .noAuthorityDIDInTXT),
        (["did=did:plc:4bqe3ktjrmrpkjfvqrpxnpgs", "did=did:plc:ycluxdyq7qzjvhqhqvhthfxa"], .multipleAuthorityDIDsInTXT),
        // Two identical lines are still two.
        (["did=did:plc:4bqe3ktjrmrpkjfvqrpxnpgs", "did=did:plc:4bqe3ktjrmrpkjfvqrpxnpgs"], .multipleAuthorityDIDsInTXT),
        (["did=not-a-did"], .invalidAuthorityDIDInTXT),
    ])
    func txtRecords(records: [String], expected: OAuthLexiconResolverFailure) async throws {
        var scenario = try await LexiconResolverScenario()
        scenario.dns = StubLexiconDNS(records: [LexiconResolverScenario.txtName: records])
        #expect(try await resolverFailure(scenario.resolver()) == expected)
        #expect(scenario.transport.requests.isEmpty)
    }

    @Test("DNS, DID document and NSID failures map to their typed failures")
    func authorityFailures() async throws {
        var scenario = try await LexiconResolverScenario()
        #expect(try await resolverFailure(scenario.resolver(), "not an nsid") == .invalidNSID)

        scenario.dns.failing = true
        #expect(try await resolverFailure(scenario.resolver()) == .dnsUnavailable)
        scenario.dns.failing = false

        scenario.authorities.error = .documentIncomplete
        #expect(try await resolverFailure(scenario.resolver()) == .authorityDocumentIncomplete)
        scenario.authorities.error = .documentUnavailable
        #expect(try await resolverFailure(scenario.resolver()) == .authorityDocumentUnavailable)
        #expect(scenario.transport.requests.isEmpty)
    }

    @Test("the record fetch keeps the server's outbound policy: pinned transport, exact 200, size cap")
    func fetchPolicy() async throws {
        let scenario = try await LexiconResolverScenario()
        // A transport that cannot pin is refused before any request.
        #expect(try await resolverFailure(scenario.resolver(pins: false)) == .recordFetchFailed)
        #expect(scenario.transport.requests.isEmpty)

        scenario.transport.serve(LexiconResolverScenario.getRecordURL, .init(status: 404, body: Data("{}".utf8)))
        #expect(try await resolverFailure(scenario.resolver()) == .recordFetchFailed)

        // A policy that admits more than 256 KiB would remove the CPU bound.
        #expect(throws: OAuthLexiconResolverConfigurationError.self) {
            try AuthenticatedOAuthLexiconResolver(fetcher: OAuthRemoteDocumentFetcher(
                policy: OAuthRemoteFetchPolicy(maximumBodyBytes: 512 * 1024), transport: scenario.transport
            ))
        }
    }

    @Test("an authentic document that is not a permission set resolves as .other")
    func notAPermissionSet() async throws {
        var scenario = try await LexiconResolverScenario()
        let fixture = try await PublicRepositoryProofFixtureBuilder.build(record: PublicRecord([
            "$type": .string("com.atproto.lexicon.schema"),
            "lexicon": .integer(1),
            "id": .string(LexiconResolverScenario.nsid),
            "defs": .object(["main": .object(["type": .string("query")])]),
        ]))
        scenario.authorities.authorities[LexiconResolverScenario.did] = OAuthLexiconAuthority(
            pdsEndpoint: URL(string: LexiconResolverScenario.pds)!, signingKey: fixture.documentPublicKey
        )
        scenario.transport.serve(LexiconResolverScenario.getRecordURL, .init(body: fixture.carBytes))
        let resolution = try await scenario.resolver().resolve(LexiconResolverScenario.nsid)
        guard case .resolved(.other, _, _) = resolution else {
            Issue.record("\(resolution)")
            return
        }
    }

    @Test("by default the DID document comes from the PLC directory through the same pinned fetcher")
    func identityAuthority() async throws {
        let scenario = try await LexiconResolverScenario()
        let did = LexiconResolverScenario.did
        func serveDocument(_ key: ATProtoPublicKey) throws {
            let document: [String: Any] = [
                "id": did,
                "verificationMethod": [[
                    "id": "\(did)#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": key.multikey,
                ]],
                "service": [[
                    "id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": LexiconResolverScenario.pds,
                ]],
            ]
            scenario.transport.serve(
                "https://plc.directory/\(did)",
                .init(contentType: "application/did+ld+json", body: try JSONSerialization.data(withJSONObject: document))
            )
        }
        try serveDocument(scenario.fixture.documentPublicKey)
        let fetcher = OAuthRemoteDocumentFetcher(
            policy: try OAuthRemoteFetchPolicy(), resolver: StubResolver(), transport: scenario.transport
        )
        let clock = TestClock()
        let resolver = try AuthenticatedOAuthLexiconResolver(
            fetcher: fetcher, dns: scenario.dns, authorities: nil, clock: clock, deadlines: .relaxed
        )
        let resolution = try await resolver.resolve(LexiconResolverScenario.nsid)
        guard case .resolved(.permissionSet, _, _) = resolution else {
            Issue.record("\(resolution)")
            return
        }
        #expect(scenario.transport.requests == ["https://plc.directory/\(did)", LexiconResolverScenario.getRecordURL])

        // A second NSID under the same authority reuses the cached DID document.
        _ = try await resolver.resolve(LexiconResolverScenario.nsid)
        #expect(scenario.transport.requests.filter { $0.hasPrefix("https://plc.directory/") }.count == 1)

        // The authority rotates its signing key, to the other curve. Once the
        // five-minute authority cache lapses, the new document is fetched, not
        // an identity-layer copy of the old one.
        let rotated = try await PublicRepositoryProofFixtureBuilder.build(curve: .k256)
        try serveDocument(rotated.documentPublicKey)
        scenario.transport.serve(LexiconResolverScenario.getRecordURL, .init(contentType: "application/vnd.ipld.car", body: rotated.carBytes))
        clock.advance(OAuthLexiconResolutionBudget.refreshThresholdSeconds + 1)
        let afterRotation = try await resolver.resolve(LexiconResolverScenario.nsid)
        guard case let .resolved(_, _, cid) = afterRotation else {
            Issue.record("\(afterRotation)")
            return
        }
        #expect(cid == rotated.recordCID.string)
        #expect(scenario.transport.requests.filter { $0.hasPrefix("https://plc.directory/") }.count == 2)
    }

    @Test("include: works end to end with the authenticated resolver: PAR, consent, token, resource")
    func includeEndToEnd() async throws {
        let scenario = try await LexiconResolverScenario()
        let include = "include:\(LexiconResolverScenario.nsid)"
        let harness = try TestServer(
            lexiconResolver: CachingOAuthLexiconResolver(upstream: scenario.resolver(), cache: InMemoryOAuthStore()),
            webClientScopes: ["atproto", include]
        )
        let client = try TestClient(harness)
        let tokens = try await client.signIn(scope: "atproto \(include)")
        #expect(tokens.scope == "atproto \(include)")
        let grant = try await authenticate(
            OAuthResourceServerVerifier(authorizationServer: harness.server), client, token: tokens.accessToken
        )
        try grant.requireRepo(collection: "com.example.foo.item", action: .create)
        #expect(throws: OAuthResourceAuthorizationFailure.self) {
            try grant.requireRepo(collection: "com.example.bar.item", action: .create)
        }
        #expect(scenario.transport.requests.contains(LexiconResolverScenario.getRecordURL))
    }
}
