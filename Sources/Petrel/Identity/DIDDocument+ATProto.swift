//
//  DIDDocument+ATProto.swift
//  Petrel
//

import Foundation
import PetrelCrypto

/// The id fragment and type that name a service in a DID document.
///
/// ```swift
/// let labeler = try document.serviceEndpoint(.labeler)
/// let custom = try document.serviceEndpoint(DIDServiceIdentifier(id: "#my_service", type: "MyService"))
/// ```
public struct DIDServiceIdentifier: Sendable, Hashable {
    /// The id fragment, including `#`, such as `#atproto_pds`.
    public let id: String
    /// The required `type`, or `nil` to accept any type.
    public let type: String?

    /// Creates an identifier. A missing leading `#` is added.
    public init(id: String, type: String? = nil) {
        self.id = id.hasPrefix("#") ? id : "#" + id
        self.type = type
    }

    /// The account's Personal Data Server: `#atproto_pds`, `AtprotoPersonalDataServer`.
    public static let pds = DIDServiceIdentifier(id: "#atproto_pds", type: "AtprotoPersonalDataServer")
    /// A labeler: `#atproto_labeler`, `AtprotoLabeler`.
    public static let labeler = DIDServiceIdentifier(id: "#atproto_labeler", type: "AtprotoLabeler")
    /// A feed generator: `#bsky_fg`, `BskyFeedGenerator`.
    public static let feedGenerator = DIDServiceIdentifier(id: "#bsky_fg", type: "BskyFeedGenerator")
    /// A notification service: `#bsky_notif`, `BskyNotificationService`.
    public static let notificationService = DIDServiceIdentifier(id: "#bsky_notif", type: "BskyNotificationService")
    /// A chat service: `#bsky_chat`, `BskyChatService`.
    public static let chat = DIDServiceIdentifier(id: "#bsky_chat", type: "BskyChatService")
    /// An AppView: `#bsky_appview`, `BskyAppView`.
    public static let appView = DIDServiceIdentifier(id: "#bsky_appview", type: "BskyAppView")
}

public extension DIDDocument {
    // MARK: Handle

    /// The handle the document claims: the first `alsoKnownAs` entry that is `at://` followed by
    /// a syntactically valid handle and nothing else.
    ///
    /// A claimed handle is not a verified one. It is trustworthy only after it resolves back to
    /// this DID; ``IdentityResolver/resolveIdentity(_:forceRefresh:)`` does that check.
    var claimedHandle: Handle? {
        for alias in alsoKnownAs where alias.hasPrefix("at://") {
            if let handle = try? Handle(handleString: String(alias.dropFirst("at://".count))) {
                return handle
            }
        }
        return nil
    }

    // MARK: Services

    /// The first service whose id is `identifier.id`, written as a fragment or as this DID
    /// followed by the fragment, and whose type matches when a type is required.
    ///
    /// `nil` also when the first such entry in the document could not be read (for example
    /// its `serviceEndpoint` is a map): later entries with the same id are ignored.
    func service(_ identifier: DIDServiceIdentifier) -> Service? {
        guard case let .readable(entry)? = firstServiceEntry(identifier) else { return nil }
        return entry
    }

    /// The endpoint of the first matching service, checked against the DID specification: an
    /// `https` URL (or `http` to `localhost`, `127.0.0.1` or `::1`) with a host and nothing
    /// besides scheme, host and port.
    ///
    /// Later entries with the same id are ignored even when the first one is unusable, whether
    /// its endpoint is not a URI string or is a URI that fails these checks.
    ///
    /// - Throws: ``IdentityError/missingService(did:id:)`` or
    ///   ``IdentityError/invalidServiceEndpoint(did:id:)``.
    func serviceEndpoint(_ identifier: DIDServiceIdentifier) throws -> URL {
        let entry: Service
        switch firstServiceEntry(identifier) {
        case nil:
            throw IdentityError.missingService(did: id, id: identifier.id)
        case .unreadable:
            throw IdentityError.invalidServiceEndpoint(did: id, id: identifier.id)
        case let .readable(readable):
            entry = readable
        }
        guard let url = Self.validatedServiceEndpoint(entry.serviceEndpoint) else {
            throw IdentityError.invalidServiceEndpoint(did: id, id: identifier.id)
        }
        return url
    }

    /// The account's PDS endpoint, or `nil` when the document has no valid `#atproto_pds` service.
    var pdsEndpoint: URL? { try? serviceEndpoint(.pds) }
    /// The `#atproto_labeler` endpoint, or `nil`.
    var labelerEndpoint: URL? { try? serviceEndpoint(.labeler) }
    /// The `#bsky_fg` feed generator endpoint, or `nil`.
    var feedGeneratorEndpoint: URL? { try? serviceEndpoint(.feedGenerator) }
    /// The `#bsky_notif` notification service endpoint, or `nil`.
    var notificationServiceEndpoint: URL? { try? serviceEndpoint(.notificationService) }
    /// The `#bsky_chat` chat service endpoint, or `nil`.
    var chatEndpoint: URL? { try? serviceEndpoint(.chat) }

    // MARK: Keys

    /// The first verification method whose id is `fragment`, written as a fragment or as this
    /// DID followed by the fragment.
    func verificationMethod(withID fragment: String) -> VerificationMethod? {
        let fragment = fragment.hasPrefix("#") ? fragment : "#" + fragment
        return verificationMethod.first { matches($0.id, fragment: fragment) }
    }

    /// The account's signing key: the first `#atproto` verification method that is controlled by
    /// this DID and decodes to a P-256 or secp256k1 public key.
    ///
    /// `Multikey` and the legacy `EcdsaSecp256r1VerificationKey2019` and
    /// `EcdsaSecp256k1VerificationKey2019` encodings are accepted.
    ///
    /// - Throws: ``IdentityError/missingSigningKey(did:)``.
    func atprotoSigningKey() throws -> ATProtoJWTVerificationKey {
        guard let key = verificationKeys(withID: "#atproto").first else {
            throw IdentityError.missingSigningKey(did: id)
        }
        return ATProtoJWTVerificationKey(key)
    }

    /// The account's signing key as a `did:key` string.
    ///
    /// - Throws: ``IdentityError/missingSigningKey(did:)``.
    func atprotoSigningDIDKey() throws -> String {
        guard let key = verificationKeys(withID: "#atproto").first else {
            throw IdentityError.missingSigningKey(did: id)
        }
        return key.didKey
    }

    /// The first verification method with id `fragment` that is controlled by this DID and
    /// decodes to a public key, such as `#atproto_label` for a labeler's signing key.
    ///
    /// - Throws: ``IdentityError/missingVerificationMethod(did:id:)``.
    func verificationKey(withID fragment: String) throws -> PLCDIDVerificationKey {
        let fragment = fragment.hasPrefix("#") ? fragment : "#" + fragment
        guard let key = verificationKeys(withID: fragment).first else {
            throw IdentityError.missingVerificationMethod(did: id, id: fragment)
        }
        return key
    }
}

extension DIDDocument {
    /// Every key published under `fragment` that this DID controls and that decodes, in
    /// document order. Entries that fail any of those checks are skipped, so the first element
    /// is "the first valid key" of the DID specification.
    func verificationKeys(withID fragment: String) -> [PLCDIDVerificationKey] {
        verificationMethod.lazy
            .filter { self.matches($0.id, fragment: fragment) && $0.controller == self.id }
            .compactMap { Self.decodeKey($0) }
    }

    private static func decodeKey(_ method: VerificationMethod) -> PLCDIDVerificationKey? {
        guard !method.publicKeyMultibase.isEmpty else { return nil }
        switch method.type {
        case "Multikey":
            return try? PLCDIDKeyCodec.decode("did:key:" + method.publicKeyMultibase)
        case "EcdsaSecp256r1VerificationKey2019":
            return try? PLCDIDKeyCodec.decodeLegacyMultibase(method.publicKeyMultibase, curve: .p256)
        case "EcdsaSecp256k1VerificationKey2019":
            return try? PLCDIDKeyCodec.decodeLegacyMultibase(method.publicKeyMultibase, curve: .secp256k1)
        default:
            return nil
        }
    }

    /// Whether an entry id is `fragment`, relative (`#atproto`) or fully qualified
    /// (`<this DID>#atproto`).
    private func matches(_ entryID: String, fragment: String) -> Bool {
        entryID == fragment || entryID == id + fragment
    }

    private enum ServiceEntry {
        case readable(Service)
        case unreadable
    }

    /// The first service entry, in document order and counting unreadable entries, whose id
    /// and type match `identifier`.
    private func firstServiceEntry(_ identifier: DIDServiceIdentifier) -> ServiceEntry? {
        func isMatch(id entryID: String, type: String?) -> Bool {
            matches(entryID, fragment: identifier.id) && (identifier.type == nil || type == identifier.type)
        }
        let unreadable = Dictionary(
            unreadableServices.map { ($0.position, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var readable = service.makeIterator()
        for position in 0 ..< (service.count + unreadable.count) {
            if let entry = unreadable[position] {
                if isMatch(id: entry.id, type: entry.type) { return .unreadable }
            } else if let entry = readable.next() {
                if isMatch(id: entry.id, type: entry.type) { return .readable(entry) }
            }
        }
        return nil
    }

    /// `endpoint` as a URL when it is only a scheme, a host and an optional port over `https`,
    /// or over `http` to a loopback host.
    static func validatedServiceEndpoint(_ endpoint: String) -> URL? {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/"
        else {
            return nil
        }
        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
        guard scheme == "https" || (scheme == "http" && isLoopback) else {
            return nil
        }
        return URL(string: endpoint)
    }
}
