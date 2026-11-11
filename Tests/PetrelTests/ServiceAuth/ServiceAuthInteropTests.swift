import Foundation
@testable import PetrelCrypto
import Testing

/// Cross-implementation evidence for service authentication.
///
/// `Vectors/service-auth/service-jwt-vectors.json` holds tokens minted by the
/// TypeScript reference implementation (`@atproto/xrpc-server`
/// `createServiceJwt`), by OpenSSL and by `jose`, each labelled with what
/// the reference `verifyJwt` did with it. Petrel must reach the same verdict
/// for the same reason, except where the file documents a deliberate
/// difference.
///
/// `petrel-minted-tokens.json` and `petrel-minted-tokens.verified-by-ts.json`
/// are the other direction: tokens Petrel minted, and what the reference
/// verifier, OpenSSL and `jose` said about them.
///
/// `Vectors/service-auth/README.md` says how each file was produced.
@Suite("Service auth: cross-implementation vectors")
struct ServiceAuthInteropTests {
    // MARK: Vector model

    struct Document: Decodable, Sendable {
        let now: Int
        let generator: [String: String]
        let keys: [String: Key]
        let vectors: [Vector]
    }

    struct Key: Decodable, Sendable {
        let curve: String
        let privateKeyHex: String
        let didKey: String
    }

    struct Vector: Decodable, Sendable, CustomTestStringConvertible {
        struct Verifier: Decodable, Sendable {
            let audience: String?
            let lxm: String?
            let key: String
            let refreshedKey: String
        }

        struct Payload: Decodable, Sendable {
            let iss: String
            let aud: String
            let exp: Int64
            let iat: Int64?
            let lxm: String?
            let jti: String?
        }

        struct Lookup: Decodable, Sendable {
            let iss: String
            let forceRefresh: Bool
        }

        struct Reference: Decodable, Sendable {
            let ok: Bool
            let error: String?
            let message: String?
            let payload: Payload?
            let keyLookups: [Lookup]
        }

        struct Difference: Decodable, Sendable {
            let ok: Bool
            let error: String?
            let reason: String
            let okWith: String?
        }

        let name: String
        let description: String
        let source: String
        let token: String
        let highS: Bool?
        let verifier: Verifier
        let ts: Reference
        let petrel: Difference?

        var testDescription: String { name }
    }

    static let document: Document = load("service-jwt-vectors")
    static var now: Date { Date(timeIntervalSince1970: TimeInterval(document.now)) }

    /// Serves one key before a refresh and another after, for any issuer and
    /// key id, recording each lookup — the same shape as the `getSigningKey`
    /// callback the vectors were generated with.
    actor Resolver: ServiceAuthKeyResolver {
        private(set) var refreshFlags: [Bool] = []
        private let cached: ATProtoPublicKey
        private let refreshed: ATProtoPublicKey

        init(cached: ATProtoPublicKey, refreshed: ATProtoPublicKey) {
            self.cached = cached
            self.refreshed = refreshed
        }

        func signingKey(for _: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
            refreshFlags.append(forceRefresh)
            return forceRefresh ? refreshed : cached
        }

        func signingKey(for did: String, keyID _: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
            try await signingKey(for: did, forceRefresh: forceRefresh)
        }
    }

    static func publicKey(_ name: String) throws -> ATProtoPublicKey {
        try ATProtoPublicKey(didKey: #require(document.keys[name]).didKey)
    }

    static func configuration(for vector: Vector) -> ServiceAuthVerifier.Configuration {
        // Everything else is the default configuration: the point is that a
        // verifier set up the obvious way agrees with the reference.
        ServiceAuthVerifier.Configuration(
            audience: vector.verifier.audience.map { .exactly($0) } ?? .unchecked
        )
    }

    static func verify(
        _ vector: Vector,
        configuration: ServiceAuthVerifier.Configuration
    ) async throws -> (result: Result<VerifiedServiceAuth, ServiceAuthError>, refreshFlags: [Bool]) {
        let resolver = try Resolver(
            cached: publicKey(vector.verifier.key), refreshed: publicKey(vector.verifier.refreshedKey)
        )
        let verifier = ServiceAuthVerifier(configuration: configuration, keyResolver: resolver)
        let result: Result<VerifiedServiceAuth, ServiceAuthError>
        do {
            result = try await .success(verifier.verify(
                authorizationHeader: "Bearer \(vector.token)",
                method: vector.verifier.lxm.map { .exactly($0) } ?? .optional,
                now: now
            ))
        } catch {
            result = .failure(error)
        }
        return (result, await resolver.refreshFlags)
    }

    // MARK: Reference → Petrel

    @Test("The vector file is the one the generator wrote, complete")
    func vectorFileShape() throws {
        let document = Self.document
        #expect(document.generator["@atproto/xrpc-server"] != nil)
        #expect(document.vectors.count == 63)
        #expect(Set(document.vectors.map(\.name)).count == document.vectors.count)

        // Tokens the reference accepts exist for both curves, in both S
        // heights, from the reference minter and from other signers.
        for curve in ["k256", "p256"] {
            let accepted = document.vectors.filter { $0.ts.ok && $0.petrel == nil && $0.name.contains(curve) }
            #expect(accepted.contains { $0.source == "createServiceJwt" && $0.highS == false }, "\(curve)")
            #expect(accepted.contains { $0.source.hasPrefix("createServiceJwt") && $0.highS == true }, "\(curve)")
            #expect(accepted.contains { $0.source.hasPrefix("node:crypto") && $0.highS == true }, "\(curve)")
            #expect(accepted.contains { $0.verifier.key != $0.verifier.refreshedKey }, "\(curve)")
        }
        #expect(document.vectors.contains { $0.source.hasPrefix("jose") && $0.highS == true && $0.ts.ok })
    }

    @Test("Petrel reaches the reference's verdict on every vector", arguments: document.vectors)
    func referenceVerdict(_ vector: Vector) async throws {
        let (result, refreshFlags) = try await Self.verify(vector, configuration: Self.configuration(for: vector))
        let expectedOK = vector.petrel?.ok ?? vector.ts.ok
        let expectedError = vector.petrel.map(\.error) ?? vector.ts.error

        switch result {
        case let .success(caller):
            #expect(expectedOK, "Petrel accepted a token it should refuse (\(expectedError ?? "?")): \(vector.description)")
            let payload = try #require(vector.ts.payload)
            #expect(caller.claims.iss == payload.iss)
            #expect(caller.claims.aud == payload.aud)
            #expect(caller.claims.exp == payload.exp)
            #expect(caller.claims.iat == payload.iat)
            #expect(caller.claims.lxm == payload.lxm)
            #expect(caller.claims.jti == payload.jti)
            #expect(payload.iss.hasPrefix(caller.issuer))
            // Same key lookups as the reference: one, or two across a rotation.
            #expect(refreshFlags == vector.ts.keyLookups.map(\.forceRefresh))
        case let .failure(error):
            #expect(!expectedOK, "Petrel refused a token the reference accepts: \(error) — \(vector.description)")
            #expect(error.xrpcErrorName == expectedError, "\(error)")
            #expect(error.httpStatus == 401)
        }
    }

    @Test(
        "Each documented difference is a default, not a limitation",
        arguments: document.vectors.filter { $0.petrel?.okWith != nil }
    )
    func documentedDifferences(_ vector: Vector) async throws {
        var configuration = Self.configuration(for: vector)
        switch try #require(vector.petrel?.okWith) {
        case "allowMalleable":
            // Reference parity: DER-encoded signatures, as allowMalleableSig admits.
            configuration.signatureOptions = .allowMalleable
        case "maximumLifetime=3h":
            configuration.maximumLifetime = 3 * 60 * 60
        case "acceptedKeyIDs=#atproto_label":
            configuration.acceptedKeyIDs = ["#atproto", "#atproto_label"]
        case let other:
            Issue.record("unknown okWith \(other)")
        }
        let (result, _) = try await Self.verify(vector, configuration: configuration)
        let caller = try result.get()
        #expect(caller.claims.exp == vector.ts.payload?.exp)
    }

    @Test(
        "The pinned-key primitive accepts every token the reference accepts",
        arguments: document.vectors.filter { $0.ts.ok && $0.petrel == nil }
    )
    func pinnedKeyPrimitive(_ vector: Vector) throws {
        let claims = try ServiceJWT.verify(
            vector.token,
            publicKey: Self.publicKey(vector.verifier.refreshedKey),
            expectedAudience: vector.verifier.audience,
            expectedMethod: vector.verifier.lxm,
            now: Self.now
        )
        #expect(claims.exp == vector.ts.payload?.exp)
        let inspection = try ServiceJWT.inspect(vector.token)
        #expect(inspection.issuer == vector.ts.payload?.iss)
        #expect(inspection.lexiconMethod == vector.ts.payload?.lxm)
    }

    @Test(
        "The pinned-key primitive honours allowMalleable for DER signatures",
        arguments: document.vectors.filter { $0.petrel?.okWith == "allowMalleable" }
    )
    func pinnedKeyPrimitiveAllowMalleable(_ vector: Vector) throws {
        let key = try Self.publicKey(vector.verifier.refreshedKey)
        // Refused by default: a DER signature is not a JWS signature.
        #expect(throws: (any Error).self) {
            try ServiceJWT.verify(
                vector.token, publicKey: key,
                expectedAudience: vector.verifier.audience, expectedMethod: vector.verifier.lxm, now: Self.now
            )
        }
        // Accepted on explicit opt-in, through both pinned-key overloads.
        let claims = try ServiceJWT.verify(
            vector.token, publicKey: key, signatureOptions: .allowMalleable,
            expectedAudience: vector.verifier.audience, expectedMethod: vector.verifier.lxm, now: Self.now
        )
        #expect(claims.exp == vector.ts.payload?.exp)
        let viaJWTKey = try ServiceJWT.verify(
            vector.token, publicKey: ATProtoJWTVerificationKey(key), signatureOptions: .allowMalleable,
            expectedAudience: vector.verifier.audience, expectedMethod: vector.verifier.lxm, now: Self.now
        )
        #expect(viaJWTKey == claims)
    }

    // MARK: Petrel → reference

    struct MintedDocument: Codable, Sendable {
        struct Token: Codable, Sendable {
            let name: String
            let curve: String
            let didKey: String
            let audience: String?
            let lxm: String?
            let token: String
        }

        var description: String
        var now: Int
        var tokens: [Token]
    }

    struct VerifiedDocument: Decodable, Sendable {
        struct Entry: Decodable, Sendable {
            struct ReferenceResult: Decodable, Sendable {
                let ok: Bool
                let error: String?
            }

            let name: String
            let token: String
            let verifyJwt: ReferenceResult
            let strictLowS: Bool
            let openssl: Bool
            let jose: Bool?
        }

        let generator: [String: String]
        let results: [Entry]
    }

    /// Mints one token per case with `keypair`, through every minting entry
    /// point.
    static func mintCases(
        _ keypair: any ATProtoKeypair,
        label: String,
        now: Date
    ) async throws -> [MintedDocument.Token] {
        let issuer = "did:plc:abcdefghijklmnopqrstuvwx"
        let curve = keypair.curve.rawValue
        func entry(_ name: String, audience: String, lxm: String?, token: String) -> MintedDocument.Token {
            .init(
                name: "petrel-\(label)-\(name)", curve: curve, didKey: keypair.didKey, audience: audience, lxm: lxm,
                token: token
            )
        }
        let feed = "did:web:feed.example.com#bsky_fg"
        let skeleton = "app.bsky.feed.getFeedSkeleton"
        return try await [
            entry("lxm", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: issuer, audience: feed, lexiconMethod: skeleton, signer: keypair, now: now
            )),
            entry("no-lxm", audience: "did:web:feed.example.com", lxm: nil, token: ServiceJWT.mint(
                issuer: issuer, audience: "did:web:feed.example.com", lexiconMethod: nil, signer: keypair, now: now
            )),
            entry("kid", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: issuer, audience: feed, lexiconMethod: skeleton, signer: keypair, keyID: "#atproto", now: now
            )),
            entry("upload-30min", audience: "did:web:pds.example.com", lxm: "com.atproto.repo.uploadBlob", token: ServiceJWT.mint(
                issuer: issuer, audience: "did:web:pds.example.com", lexiconMethod: "com.atproto.repo.uploadBlob",
                signer: keypair, now: now, lifetime: 30 * 60
            )),
            entry("1h", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: issuer, audience: feed, lexiconMethod: skeleton, signer: keypair, now: now, lifetime: 60 * 60
            )),
            entry("legacy-issuer-fragment", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: issuer + "#atproto_labeler", audience: feed, lexiconMethod: skeleton, signer: keypair, now: now
            )),
            entry("did-web-issuer", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: "did:web:labeler.example.com", audience: feed, lexiconMethod: skeleton, signer: keypair, now: now
            )),
            entry("event-id-overload", audience: feed, lxm: skeleton, token: ServiceJWT.mint(
                issuer: issuer, audience: feed, method: skeleton, eventID: "event-1", signer: keypair, now: now
            )),
        ]
    }

    static let minted: MintedDocument = load("petrel-minted-tokens")
    static let verifiedByReference: VerifiedDocument = load("petrel-minted-tokens.verified-by-ts")

    @Test("The reference implementation verified every vendored Petrel-minted token")
    func referenceAcceptedPetrelTokens() throws {
        let minted = Self.minted
        let verified = Self.verifiedByReference
        #expect(verified.generator["@atproto/xrpc-server"] != nil)
        #expect(minted.tokens.count == 16)
        #expect(Set(minted.tokens.map(\.curve)) == ["k256", "p256"])

        for token in minted.tokens {
            // The result file is about exactly this token string.
            let entry = try #require(verified.results.first { $0.name == token.name }, "\(token.name)")
            #expect(entry.token == token.token, "\(token.name)")
            #expect(entry.verifyJwt.ok, "\(token.name): verifyJwt said \(entry.verifyJwt.error ?? "?")")
            #expect(entry.strictLowS, "\(token.name): @atproto/crypto strict (low-S, compact) verification")
            #expect(entry.openssl, "\(token.name): OpenSSL verification")
            if token.curve == "p256" {
                #expect(entry.jose == true, "\(token.name): jose verification")
            }
        }
    }

    @Test("Petrel verifies the same vendored tokens", arguments: minted.tokens.map(\.name))
    func petrelAcceptsItsVendoredTokens(_ name: String) async throws {
        let token = try #require(Self.minted.tokens.first { $0.name == name })
        let now = Date(timeIntervalSince1970: TimeInterval(Self.minted.now))
        let issuerDID = try ServiceJWT.inspect(token.token).issuerDID
        let verifier = try ServiceAuthVerifier(
            audience: .exactly(#require(token.audience)),
            keyResolver: StaticServiceAuthKeyResolver(keys: [issuerDID: ATProtoPublicKey(didKey: token.didKey)])
        )
        let caller = try await verifier.verify(
            token: token.token, method: token.lxm.map { .exactly($0) } ?? .optional, now: now
        )
        #expect(caller.issuer == issuerDID)
        #expect(caller.lexiconMethod == token.lxm)
    }

    /// Regenerates `petrel-minted-tokens.json`. Run with
    /// `PETREL_SERVICE_AUTH_WRITE_TOKENS=/path/petrel-minted-tokens.json`,
    /// then `verify-petrel-tokens.mjs` on the result (see the README).
    @Test(
        "Write the Petrel-minted token file",
        .enabled(if: ProcessInfo.processInfo.environment["PETREL_SERVICE_AUTH_WRITE_TOKENS"] != nil)
    )
    func writeMintedTokens() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["PETREL_SERVICE_AUTH_WRITE_TOKENS"])
        let now = Self.now
        let k256 = try K256Keypair(hex: #require(Self.document.keys["k256"]).privateKeyHex)
        let p256 = try P256Keypair(hex: #require(Self.document.keys["p256"]).privateKeyHex)
        let document = try await MintedDocument(
            description: "Service-auth JWTs minted by Petrel (ServiceJWT.mint) with the fixed test keys from service-jwt-vectors.json, at the pinned clock. Verified by the TypeScript reference in petrel-minted-tokens.verified-by-ts.json.",
            now: Self.document.now,
            tokens: Self.mintCases(k256, label: "k256", now: now) + Self.mintCases(p256, label: "p256", now: now)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try (encoder.encode(document) + Data("\n".utf8)).write(to: URL(fileURLWithPath: path))
    }

    #if os(macOS) || os(Linux)
        /// The live round trip: mint fresh tokens with fresh random keys and
        /// hand them to the TypeScript reference in a child process.
        ///
        /// Needs Node.js and a directory with `@atproto/xrpc-server`,
        /// `@atproto/crypto` and `jose` installed; set
        /// `PETREL_TS_INTEROP_DIR` to it. Skipped otherwise.
        @Test(
            "Freshly minted tokens verify in the TypeScript reference (live)",
            .enabled(if: ProcessInfo.processInfo.environment["PETREL_TS_INTEROP_DIR"] != nil)
        )
        func liveReferenceVerification() async throws {
            let directory = try #require(ProcessInfo.processInfo.environment["PETREL_TS_INTEROP_DIR"])
            let script = try #require(Bundle.module.url(
                forResource: "verify-petrel-tokens", withExtension: "mjs", subdirectory: "Vectors/service-auth"
            ))
            let now = Date()
            let document = try await MintedDocument(
                description: "live",
                now: Int(now.timeIntervalSince1970),
                tokens: Self.mintCases(K256Keypair.generate(), label: "k256", now: now)
                    + Self.mintCases(P256Keypair.generate(), label: "p256", now: now)
            )
            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("petrel-service-auth-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratch) }
            let input = scratch.appendingPathComponent("tokens.json")
            let output = scratch.appendingPathComponent("verified.json")
            try JSONEncoder().encode(document).write(to: input)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                ProcessInfo.processInfo.environment["PETREL_TS_INTEROP_NODE"] ?? "node",
                script.path, input.path, output.path,
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)

            let verified = try JSONDecoder().decode(VerifiedDocument.self, from: Data(contentsOf: output))
            #expect(verified.results.count == document.tokens.count)
            for entry in verified.results {
                #expect(entry.verifyJwt.ok, "\(entry.name): \(entry.verifyJwt.error ?? "?")")
                #expect(entry.strictLowS, "\(entry.name)")
                #expect(entry.openssl, "\(entry.name)")
                #expect(entry.jose != false, "\(entry.name)")
            }
        }
    #endif

    // MARK: Identifier syntax

    @Test("DID syntax follows the official interop vectors")
    func didSyntaxVectors() throws {
        let valid = try Self.lines("did_syntax_valid")
        let invalid = try Self.lines("did_syntax_invalid")
        #expect(valid.count >= 20)
        #expect(invalid.count >= 15)
        for did in valid {
            #expect(ServiceAuthSyntax.isGenericDID(did), "should be a DID: \(did.prefix(80))")
        }
        for did in invalid {
            #expect(!ServiceAuthSyntax.isGenericDID(did), "should not be a DID: \(did.prefix(80))")
            #expect(!ServiceAuthSyntax.isDID(did), "should not be a DID: \(did.prefix(80))")
        }
        // On top of the generic syntax, the method rules of the two methods
        // atproto defines (did.mdx, "did:web in AT Protocol").
        for did in [
            "did:plc:7iza6de2dwap2sbkpav7c6c6", "did:web:example.com", "did:web:localhost",
            "did:web:localhost%3A1234", "did:example:123456789abcdefghi",
        ] {
            #expect(ServiceAuthSyntax.isDID(did), "\(did)")
        }
        for did in [
            "did:plc:tooshort", "did:plc:7IZA6DE2DWAP2SBKPAV7C6C6", "did:web:example.com:user:alice",
            "did:web:example.com%3A8080", "did:web:example", "did:web:example.123", "did:web:-example.com",
            "did:web:localhost%3A0", "did:web:localhost%3A99999", "did:key:zNotAKey",
        ] {
            #expect(!ServiceAuthSyntax.isDID(did), "\(did)")
        }
    }

    @Test("NSID syntax follows the official interop vectors")
    func nsidSyntaxVectors() throws {
        let valid = try Self.lines("nsid_syntax_valid")
        let invalid = try Self.lines("nsid_syntax_invalid")
        #expect(valid.count >= 15)
        #expect(invalid.count >= 20)
        for nsid in valid {
            #expect(ServiceJWT.isNSID(nsid), "should be an NSID: \(nsid.prefix(80))")
        }
        for nsid in invalid {
            #expect(!ServiceJWT.isNSID(nsid), "should not be an NSID: \(nsid.prefix(80))")
        }
    }

    // MARK: Loading

    static func load<T: Decodable>(_ name: String) -> T {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Vectors/service-auth"
        ) else {
            fatalError("missing vector file Vectors/service-auth/\(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("could not decode Vectors/service-auth/\(name).json: \(error)")
        }
    }

    /// The non-blank, non-comment lines of a syntax vector file.
    static func lines(_ name: String) throws -> [String] {
        let url = try #require(Bundle.module.url(
            forResource: name, withExtension: "txt", subdirectory: "Vectors/service-auth/syntax"
        ))
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.hasPrefix("#") }
    }
}
