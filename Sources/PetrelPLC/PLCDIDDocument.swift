import Foundation
import PetrelCrypto

/// The W3C DID document a PLC directory renders for an identity
/// (`GET /:did`).
///
/// A DID document is a *presentation* of the identity's state: it leaves out
/// the rotation keys and is not signed. To act on an identity you do not
/// already trust the directory about, verify the audit log instead
/// (``PLCDirectoryClient/fetchVerifiedAuditLog(did:)``) and render the
/// document from its state with ``init(data:)``.
public struct PLCDIDDocument: Sendable, Equatable, Codable {
    /// One entry of `verificationMethod`.
    public struct VerificationMethod: Sendable, Equatable, Codable {
        /// `<did>#<id>`.
        public let id: String
        /// `Multikey`.
        public let type: String
        /// The DID.
        public let controller: String
        /// The key as a multibase string: the `did:key` without its prefix.
        public let publicKeyMultibase: String

        /// Creates a verification method.
        public init(id: String, type: String, controller: String, publicKeyMultibase: String) {
            self.id = id
            self.type = type
            self.controller = controller
            self.publicKeyMultibase = publicKeyMultibase
        }
    }

    /// One entry of `service`.
    public struct Service: Sendable, Equatable, Codable {
        /// `#<id>`.
        public let id: String
        /// The service type.
        public let type: String
        /// The service URL.
        public let serviceEndpoint: String

        /// Creates a service entry.
        public init(id: String, type: String, serviceEndpoint: String) {
            self.id = id
            self.type = type
            self.serviceEndpoint = serviceEndpoint
        }
    }

    /// The JSON-LD `@context`.
    public let context: [String]
    /// The DID.
    public let id: String
    /// Aliases, for atproto `at://<handle>`.
    public let alsoKnownAs: [String]
    /// The public keys the identity publishes.
    public let verificationMethod: [VerificationMethod]
    /// The services the identity publishes.
    public let service: [Service]

    /// Creates a document from its parts.
    public init(
        context: [String],
        id: String,
        alsoKnownAs: [String],
        verificationMethod: [VerificationMethod],
        service: [Service]
    ) {
        self.context = context
        self.id = id
        self.alsoKnownAs = alsoKnownAs
        self.verificationMethod = verificationMethod
        self.service = service
    }

    /// Renders the DID document for an identity's state, as the reference
    /// library's `formatDidDoc` does.
    ///
    /// Verification methods and services are emitted in ascending order of
    /// their ids so that the result is deterministic; a directory emits them
    /// in the order of the operation's JSON, which a DID document does not
    /// make significant.
    public init(data: PLCDocumentData) {
        var context = [
            "https://www.w3.org/ns/did/v1",
            "https://w3id.org/security/multikey/v1",
        ]
        var methods = [VerificationMethod]()
        for (keyID, didKey) in data.verificationMethods.sorted(by: { $0.key < $1.key }) {
            let suite: String? = switch (try? ATProtoPublicKey(didKey: didKey))?.curve {
            case .p256: "https://w3id.org/security/suites/ecdsa-2019/v1"
            case .k256: "https://w3id.org/security/suites/secp256k1-2019/v1"
            // A key type with no known suite still renders as a Multikey.
            case nil: nil
            }
            if let suite, !context.contains(suite) {
                context.append(suite)
            }
            methods.append(VerificationMethod(
                id: "\(data.did)#\(keyID)",
                type: "Multikey",
                controller: data.did,
                publicKeyMultibase: didKey.hasPrefix("did:key:")
                    ? String(didKey.dropFirst("did:key:".count))
                    : didKey
            ))
        }
        self.init(
            context: context,
            id: data.did,
            alsoKnownAs: data.alsoKnownAs,
            verificationMethod: methods,
            service: data.services.sorted(by: { $0.key < $1.key }).map { serviceID, service in
                Service(id: "#\(serviceID)", type: service.type, serviceEndpoint: service.endpoint)
            }
        )
    }

    /// The handle named by the first `at://` alias, without the prefix.
    public var handle: String? {
        alsoKnownAs.first { $0.hasPrefix("at://") }.map { String($0.dropFirst(5)) }
    }

    /// The endpoint of the `#atproto_pds` service.
    public var pdsEndpoint: String? {
        service.first {
            ($0.id == "#\(PLCATProfile.pdsServiceID)" || $0.id == "\(id)#\(PLCATProfile.pdsServiceID)")
                && $0.type == PLCATProfile.pdsServiceType
        }?.serviceEndpoint
    }

    /// The `#atproto` verification method's key, when it is a P-256 or
    /// K-256 `Multikey`.
    public var atprotoSigningKey: ATProtoPublicKey? {
        let method = verificationMethod.first {
            $0.id == "\(id)#\(PLCATProfile.signingKeyID)" || $0.id == "#\(PLCATProfile.signingKeyID)"
        }
        guard let method else { return nil }
        return try? ATProtoPublicKey(
            verificationMethodType: method.type,
            publicKeyMultibase: method.publicKeyMultibase
        )
    }

    private enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id
        case alsoKnownAs
        case verificationMethod
        case service
    }

    /// Decodes a DID document. Absent arrays decode as empty.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        context = try container.decodeIfPresent([String].self, forKey: .context) ?? []
        id = try container.decode(String.self, forKey: .id)
        alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs) ?? []
        verificationMethod = try container.decodeIfPresent(
            [VerificationMethod].self, forKey: .verificationMethod
        ) ?? []
        service = try container.decodeIfPresent([Service].self, forKey: .service) ?? []
    }
}
