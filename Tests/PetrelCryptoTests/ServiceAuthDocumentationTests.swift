import Foundation
import PetrelCrypto
import Testing

/// The code in `Sources/PetrelCrypto/PetrelCrypto.docc/ServiceAuth.md`,
/// compiled and run. Each test body between the `// doc:` markers is the
/// snippet as printed in the article; keep the two in step.
@Suite("ServiceAuth documentation examples")
struct ServiceAuthDocumentationTests {
    /// Stands in for whatever a service uses to look up DID documents.
    struct Directory: Sendable {
        struct NotFound: Error {}

        var keys: [String: ATProtoPublicKey] = [:]

        func publicKeyMultibase(for did: String, keyID: String, bypassCache _: Bool) async throws -> String {
            guard let key = keys[did + keyID] else { throw NotFound() }
            return key.multikey
        }
    }

    // doc: "Authenticate a request"
    struct FeedGenerator {
        let verifier: ServiceAuthVerifier

        init(keyResolver: any ServiceAuthKeyResolver) {
            verifier = ServiceAuthVerifier(
                // This service's DID and service identifier. PDSes that predate
                // the Spring 2026 specification send the bare DID when proxying.
                audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
                keyResolver: keyResolver,
                replayStore: InMemoryServiceAuthReplayStore()
            )
        }

        /// GET /xrpc/app.bsky.feed.getFeedSkeleton
        func getFeedSkeleton(authorizationHeader: String?) async -> (status: Int, body: [String: String]) {
            do {
                let caller = try await verifier.verify(
                    authorizationHeader: authorizationHeader,
                    method: .exactly("app.bsky.feed.getFeedSkeleton")
                )
                return (200, ["viewer": caller.issuer])
            } catch {
                // 401 {"error": "BadJwtAudience", "message": "jwt audience does not match service did"}
                return (error.httpStatus, ["error": error.xrpcErrorName, "message": error.message])
            }
        }
    }

    // end doc

    @Test("Mint a token, then authenticate the request that carries it")
    func mintAndAuthenticate() async throws {
        // doc: "Mint a token"
        let keypair = K256Keypair.generate()

        let token = try await ServiceJWT.mint(
            issuer: "did:plc:abcdefghijklmnopqrstuvwx",
            audience: "did:web:feed.example.com#bsky_fg",
            lexiconMethod: "app.bsky.feed.getFeedSkeleton",
            signer: keypair
        )
        let authorization = ServiceJWT.bearerAuthorization(token) // "Bearer eyJ…"
        // end doc
        #expect(authorization.hasPrefix("Bearer eyJ"))

        // doc: "Resolve the issuer's key"
        let directory = Directory(keys: ["did:plc:abcdefghijklmnopqrstuvwx#atproto": keypair.publicKey])
        let resolver = ClosureServiceAuthKeyResolver { did, keyID, forceRefresh in
            let multikey = try await directory.publicKeyMultibase(for: did, keyID: keyID, bypassCache: forceRefresh)
            return try ATProtoPublicKey(multikey: multikey)
        }
        // Cache keys, and stop forged tokens from forcing a DID resolution each.
        let keyResolver = CachingServiceAuthKeyResolver(upstream: resolver)
        // end doc

        let feedGenerator = FeedGenerator(keyResolver: keyResolver)
        let accepted = await feedGenerator.getFeedSkeleton(authorizationHeader: authorization)
        #expect(accepted.status == 200)
        #expect(accepted.body == ["viewer": "did:plc:abcdefghijklmnopqrstuvwx"])

        // The same token again, no token, and a token for another service.
        let replayed = await feedGenerator.getFeedSkeleton(authorizationHeader: authorization)
        #expect(replayed.status == 401)
        #expect(replayed.body["error"] == "BadJwt")

        let anonymous = await feedGenerator.getFeedSkeleton(authorizationHeader: nil)
        #expect(anonymous.status == 401)
        #expect(anonymous.body == ["error": "MissingJwt", "message": "missing jwt"])

        let elsewhere = try await ServiceJWT.mint(
            issuer: "did:plc:abcdefghijklmnopqrstuvwx",
            audience: "did:web:other.example.com#bsky_fg",
            lexiconMethod: "app.bsky.feed.getFeedSkeleton",
            signer: keypair
        )
        let misdirected = await feedGenerator.getFeedSkeleton(
            authorizationHeader: ServiceJWT.bearerAuthorization(elsewhere)
        )
        #expect(misdirected.status == 401)
        #expect(misdirected.body == [
            "error": "BadJwtAudience", "message": "jwt audience does not match service did",
        ])

        // doc: "Verify against a key you already hold"
        let claims = try ServiceJWT.verify(
            token,
            publicKey: keypair.publicKey,
            expectedAudience: "did:web:feed.example.com#bsky_fg",
            expectedMethod: "app.bsky.feed.getFeedSkeleton"
        )
        // end doc
        #expect(claims.iss == "did:plc:abcdefghijklmnopqrstuvwx")
        #expect(try ServiceJWT.inspect(token).lexiconMethod == "app.bsky.feed.getFeedSkeleton")
    }

    @Test("A labeler signs with its labeling key; an AppView opts in to it")
    func labelerAndConfiguration() async throws {
        let labelingKey = P256Keypair.generate()

        // doc: "Mint a token" (second snippet)
        let labelerToken = try await ServiceJWT.mint(
            issuer: "did:web:labeler.example.com",
            audience: "did:web:appview.example.com#bsky_appview",
            lexiconMethod: "com.atproto.label.queryLabels",
            signer: labelingKey,
            keyID: "#atproto_label",
            lifetime: 5 * 60
        )
        // end doc

        let keyResolver = StaticServiceAuthKeyResolver(keysByID: [
            "did:web:labeler.example.com": ["#atproto_label": labelingKey.publicKey],
        ])

        // doc: "Choose what to accept"
        var configuration = ServiceAuthVerifier.Configuration(
            audience: .exactly("did:web:appview.example.com#bsky_appview")
        )
        // Labelers sign with their labeling key.
        configuration.acceptedKeyIDs = ["#atproto", "#atproto_label"]
        // This service only ever expects the usual one-minute tokens.
        configuration.maximumLifetime = 5 * 60
        // Insist on typ, iat and jti, which the specification lists as required.
        configuration.requiredClaims = .specification

        let appView = ServiceAuthVerifier(configuration: configuration, keyResolver: keyResolver)
        // end doc

        let caller = try await appView.verify(
            token: labelerToken, method: .exactly("com.atproto.label.queryLabels")
        )
        #expect(caller.issuer == "did:web:labeler.example.com")
        #expect(caller.keyID == "#atproto_label")

        // The audience string is an ATProtoServiceReference.
        let reference = try ATProtoServiceReference(caller.audience)
        #expect(reference.did == "did:web:appview.example.com")
        #expect(reference.serviceID == ATProtoServiceReference.bskyAppViewServiceID)
    }
}
