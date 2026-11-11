import Foundation
import Petrel
import PetrelCrypto
import Testing

/// The snippets of `Petrel.docc/Identity.md`, compiled against the public API only (no
/// `@testable import`) and run against test doubles. If one of these stops compiling, the
/// article is wrong.
@Suite("Identity documentation examples")
struct DIDResolutionDocumentationTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let handle = "atproto.com"
    private let signingKey = "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"

    /// The article's `FixedDNS`, verbatim.
    struct FixedDNS: IdentityDNSResolver {
        let records: [String: [String]]

        func queryTXT(name: String) async throws -> [String] {
            records[name] ?? []
        }
    }

    /// An `IdentityHTTPTransport` written by a package user.
    struct FixedHTTP: IdentityHTTPTransport {
        let bodies: [String: String]

        func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
            guard let body = bodies[request.url.absoluteString] else {
                return IdentityHTTPResponse(statusCode: 404, body: Data())
            }
            return IdentityHTTPResponse(statusCode: 200, body: Data(body.utf8))
        }
    }

    private func makeResolver(options: IdentityResolver.Options = IdentityResolver.Options()) -> IdentityResolver {
        let document = IdentityFixtures.document(
            did: did, handles: [handle],
            verificationMethods: [[
                "id": "\(did)#atproto", "type": "Multikey", "controller": did, "publicKeyMultibase": signingKey,
            ]],
            services: [["id": "#atproto_labeler", "type": "AtprotoLabeler", "serviceEndpoint": "https://mod.example.com"]]
        )
        return IdentityResolver(
            options: options,
            cache: InMemoryIdentityCache(capacity: 50000),
            httpTransport: FixedHTTP(bodies: [
                "\(options.plcDirectoryURL.absoluteString)/\(did)": document,
            ]),
            dnsResolver: FixedDNS(records: ["_atproto.\(handle)": ["did=\(did)"]])
        )
    }

    @Test("Overview: a handle resolves to a verified identity")
    func overview() async throws {
        let resolver = makeResolver()

        let identity = try await resolver.resolveIdentity("atproto.com")

        #expect(identity.did.didString() == did)
        #expect(identity.handle.value == "atproto.com")
        #expect(identity.pdsEndpoint?.absoluteString == "https://pds.example.com")
        #expect(try identity.signingKey() == ATProtoJWTVerificationKey(PLCDIDKeyCodec.decode("did:key:" + signingKey)))
    }

    @Test("Handle to DID, and DID to document")
    func handleAndDocument() async throws {
        let resolver = makeResolver()

        let resolved = try await resolver.resolveHandle("atproto.com")
        #expect(resolved.didString() == did)

        let document = try await resolver.resolveDIDDocument("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(document.claimedHandle?.value == handle)
        #expect(document.pdsEndpoint != nil)
        _ = try document.atprotoSigningKey()
        #expect(try document.atprotoSigningDIDKey() == "did:key:" + signingKey)
        #expect(try document.serviceEndpoint(.labeler).absoluteString == "https://mod.example.com")
        #expect(throws: IdentityError.missingService(did: did, id: "#bsky_fg")) {
            try document.serviceEndpoint(.feedGenerator)
        }
    }

    @Test("A verified identity, and handle.invalid")
    func verifiedIdentity() async throws {
        let resolver = makeResolver()
        var shown: [String] = []
        func show(_ text: String) { shown.append(text) }

        let identity = try await resolver.resolveIdentity("did:plc:ewvi7nxzyoun6zhxrhs64oiz")

        if identity.isHandleVerified {
            show("@\(identity.handle)")
        } else {
            show(identity.did.didString())
        }
        #expect(shown == ["@atproto.com"])

        // The same DID when its handle's domain no longer points at it.
        let unverified = IdentityResolver(
            httpTransport: FixedHTTP(bodies: [
                "https://plc.directory/\(did)": IdentityFixtures.document(did: did, handles: [handle]),
            ]),
            dnsResolver: FixedDNS(records: [:])
        )
        let broken = try await unverified.resolveIdentity(did)
        #expect(!broken.isHandleVerified)
        #expect(broken.handle.value == "handle.invalid")
        #expect(broken.handleVerification == .doesNotResolve)
        #expect(broken.claimedHandle?.value == handle)
    }

    @Test("Verifying a signature from another account: key, service endpoint and forced refresh")
    func signingKeyForServiceAuth() async throws {
        let resolver = makeResolver()
        let issuerDID = did

        let key = try await resolver.resolveSigningKey(for: issuerDID)
        let pds = try await resolver.resolveServiceEndpoint(for: issuerDID, service: .pds)
        let currentKey = try await resolver.resolveSigningKey(for: issuerDID, forceRefresh: true)

        #expect(key == currentKey)
        #expect(pds.absoluteString == "https://pds.example.com")
    }

    @Test("Configuration: PLC directory, strategy, timeout, cache policy and cache")
    func configuration() async throws {
        let options = IdentityResolver.Options(
            plcDirectoryURL: URL(string: "https://plc.example.net")!,
            handleStrategy: .direct,
            timeout: 3,
            cachePolicy: IdentityCachePolicy(freshFor: 15 * 60, maximumAge: 6 * 60 * 60)
        )
        let resolver = makeResolver(options: options)

        let resolved = try await resolver.resolveHandle(handle)
        #expect(resolved.didString() == did)
        #expect(resolver.options.plcDirectoryURL.host == "plc.example.net")
        await resolver.invalidate(did: did)
        await resolver.invalidate(handle: handle)
        await resolver.clearCache()
    }

    @Test("With ATProtoClient: a resolver passed as didResolver")
    func clientIntegration() async throws {
        let resolver = makeResolver()
        let client = await ATProtoClient(
            baseURL: URL(string: "https://public.api.bsky.app")!,
            didResolver: resolver
        )

        let resolved = try await client.resolveHandleToDID(handle: "atproto.com")
        let identity = try await client.resolveIdentity(resolved)

        #expect(resolved == did)
        #expect(identity.isHandleVerified)
        #expect(client.identityResolver === resolver)
    }

    @Test("Errors: the cases a caller is expected to tell apart")
    func errors() async throws {
        let resolver = makeResolver()
        var outcomes: [String] = []

        for input in ["not a handle", "nobody.example.com", "laptop.local"] {
            do {
                _ = try await resolver.resolveHandle(input)
            } catch IdentityError.invalidHandleSyntax {
                outcomes.append("syntax")
            } catch IdentityError.handleNotFound {
                outcomes.append("not found")
            } catch IdentityError.handleNotClaimedByDID {
                outcomes.append("not claimed")
            } catch IdentityError.handleLookupFailed {
                outcomes.append("lookup failed")
            } catch IdentityError.reservedHandleTLD {
                outcomes.append("reserved")
            }
        }
        #expect(outcomes == ["syntax", "not found", "reserved"])

        await #expect(throws: IdentityError.unsupportedDIDMethod(did: "did:key:zabc", method: "key")) {
            try await resolver.resolveDIDDocument("did:key:zabc")
        }
        await #expect(throws: IdentityError.unsupportedDIDWebPath("did:web:example.com:user")) {
            try await resolver.resolveDIDDocument("did:web:example.com:user")
        }
        await #expect(throws: IdentityError.invalidDIDSyntax("did:plc:")) {
            try await resolver.resolveDIDDocument("did:plc:")
        }
    }
}
