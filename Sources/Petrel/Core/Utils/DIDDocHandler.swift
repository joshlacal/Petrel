//
//  DIDDocHandler.swift
//  Petrel
//
//  Created by Josh LaCalamito on 2/3/24.
//

import Foundation

/// A DID document, reduced to the parts AT Protocol reads.
///
/// Decoding is tolerant of everything the W3C DID Core data model allows that AT Protocol has
/// no use for, so one unusual entry does not make an otherwise usable document unreadable:
///
/// - `@context` may be a single string or an array; non-string members are skipped.
/// - a `service` entry whose `serviceEndpoint` is a map or a set, rather than a URI string, or
///   that has no `type`, is left out of ``service``. AT Protocol defines only URI endpoints. Its
///   position still counts for the first-match rule: when it is the first entry for an id,
///   ``serviceEndpoint(_:)`` throws rather than using a later entry.
/// - a `verificationMethod` entry without `id`, `type` or `controller` is left out of
///   ``verificationMethod``. An entry that has those but no `publicKeyMultibase` (for example
///   one that uses `publicKeyJwk`) is kept with an empty ``VerificationMethod/publicKeyMultibase``
///   and never yields a key.
///
/// `id` is required. Use the AT Protocol accessors (``claimedHandle``, ``pdsEndpoint``,
/// ``atprotoSigningKey()``, ``serviceEndpoint(_:)``) rather than reading the arrays directly;
/// they apply the first-match, controller and endpoint rules of the DID specification.
public struct DIDDocument: ATProtocolCodable, ATProtocolValue {
    /// The JSON-LD contexts, in document order.
    public let context: [String]
    /// The DID the document describes.
    public let id: String
    /// Alternative identifiers. A handle appears as `at://<handle>`.
    public let alsoKnownAs: [String]
    /// The verification methods with a readable `id`, `type` and `controller`.
    public let verificationMethod: [VerificationMethod]
    /// The services with a string `serviceEndpoint`.
    public let service: [Service]
    /// Service entries with an `id` that could not be read as a ``Service``, with their
    /// position among all entries that have an `id`. Empty for a document built in code.
    let unreadableServices: [UnreadableService]

    /// A `service` entry that has an `id` but no string `serviceEndpoint` or no `type`.
    struct UnreadableService: Sendable, Hashable {
        /// Index among the document's service entries that have an `id`.
        let position: Int
        let id: String
        let type: String?
    }

    public init(
        context: [String] = [],
        id: String,
        alsoKnownAs: [String] = [],
        verificationMethod: [VerificationMethod] = [],
        service: [Service] = []
    ) {
        self.context = context
        self.id = id
        self.alsoKnownAs = alsoKnownAs
        self.verificationMethod = verificationMethod
        self.service = service
        self.unreadableServices = []
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let single = try? container.decode(String.self, forKey: .context) {
            self.context = [single]
        } else {
            self.context = Self.decodeTolerantly(String.self, from: container, forKey: .context)
        }
        self.id = try container.decode(String.self, forKey: .id)
        self.alsoKnownAs = Self.decodeTolerantly(String.self, from: container, forKey: .alsoKnownAs)
        self.verificationMethod = Self.decodeTolerantly(
            VerificationMethod.self, from: container, forKey: .verificationMethod
        )
        let slots = Self.decodeTolerantly(ServiceSlot.self, from: container, forKey: .service)
        var readable: [Service] = []
        var unreadable: [UnreadableService] = []
        for (position, slot) in slots.enumerated() {
            switch slot {
            case let .readable(service):
                readable.append(service)
            case let .unreadable(id, type):
                unreadable.append(UnreadableService(position: position, id: id, type: type))
            }
        }
        self.service = readable
        self.unreadableServices = unreadable
    }

    /// One `service` entry: a readable ``Service``, or just the `id` (and `type`) of one that
    /// is not. Entries without a string `id` fail to decode and are dropped.
    private enum ServiceSlot: Decodable {
        case readable(Service)
        case unreadable(id: String, type: String?)

        private enum Keys: String, CodingKey {
            case id, type
        }

        init(from decoder: Decoder) throws {
            if let service = try? Service(from: decoder) {
                self = .readable(service)
                return
            }
            let container = try decoder.container(keyedBy: Keys.self)
            self = try .unreadable(
                id: container.decode(String.self, forKey: .id),
                type: try? container.decode(String.self, forKey: .type)
            )
        }
    }

    /// One array element that decodes to `nil` instead of failing the whole array.
    private struct Tolerant<Element: Decodable>: Decodable {
        let element: Element?

        init(from decoder: Decoder) throws {
            element = try? Element(from: decoder)
        }
    }

    /// The elements of the array at `key` that decode as `Element`, in order. A missing key, a
    /// value that is not an array, and elements of another shape all contribute nothing.
    private static func decodeTolerantly<Element: Decodable>(
        _: Element.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [Element] {
        guard let elements = try? container.decode([Tolerant<Element>].self, forKey: key) else {
            return []
        }
        return elements.compactMap(\.element)
    }

    enum CodingKeys: String, CodingKey {
        case context = "@context"
        case id, alsoKnownAs, verificationMethod, service
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherDIDDoc = other as? DIDDocument else { return false }
        return context == otherDIDDoc.context && id == otherDIDDoc.id
            && alsoKnownAs == otherDIDDoc.alsoKnownAs
            && verificationMethod == otherDIDDoc.verificationMethod
            && service == otherDIDDoc.service
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()

        // Add fields in order
        map.append(key: "@context", value: context) // Array of Strings
        map.append(key: "id", value: id)
        if !alsoKnownAs.isEmpty { // Only add if not empty, common practice
            map.append(key: "alsoKnownAs", value: alsoKnownAs)
        }

        // Convert verificationMethod array
        let verificationMethodsCBOR = try verificationMethod.map { try $0.toCBORValue() }
        if !verificationMethodsCBOR.isEmpty {
            map.append(key: "verificationMethod", value: verificationMethodsCBOR)
        }

        // Convert service array
        let servicesCBOR = try service.map { try $0.toCBORValue() }
        if !servicesCBOR.isEmpty {
            map.append(key: "service", value: servicesCBOR)
        }

        return map
    }
}

/// A `service` entry of a DID document whose endpoint is a URI string.
public struct Service: ATProtocolCodable, ATProtocolValue {
    /// The entry's id: a fragment (`#atproto_pds`) or a full DID URL (`did:plc:…#atproto_pds`).
    public let id: String
    /// The service type, such as `AtprotoPersonalDataServer`.
    public let type: String
    /// The endpoint, unvalidated. ``DIDDocument/serviceEndpoint(_:)`` returns it as a checked URL.
    public let serviceEndpoint: String

    public init(id: String, type: String, serviceEndpoint: String) {
        self.id = id
        self.type = type
        self.serviceEndpoint = serviceEndpoint
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.serviceEndpoint = try container.decode(String.self, forKey: .serviceEndpoint)
    }

    enum CodingKeys: String, CodingKey {
        case id, type, serviceEndpoint
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherService = other as? Service else { return false }
        return id == otherService.id && type == otherService.type
            && serviceEndpoint == otherService.serviceEndpoint
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "id", value: id)
        map.append(key: "type", value: type)
        map.append(key: "serviceEndpoint", value: serviceEndpoint)
        return map
    }
}

/// A `verificationMethod` entry of a DID document.
public struct VerificationMethod: ATProtocolCodable, ATProtocolValue {
    /// The entry's id: a fragment (`#atproto`) or a full DID URL (`did:plc:…#atproto`).
    public let id: String
    /// `Multikey`, or one of the legacy types `EcdsaSecp256r1VerificationKey2019` and
    /// `EcdsaSecp256k1VerificationKey2019`.
    public let type: String
    /// The DID that controls the key. AT Protocol requires it to be the document's own DID.
    public let controller: String
    /// The multibase-encoded public key, or an empty string when the entry has none.
    public let publicKeyMultibase: String

    public init(id: String, type: String, controller: String, publicKeyMultibase: String) {
        self.id = id
        self.type = type
        self.controller = controller
        self.publicKeyMultibase = publicKeyMultibase
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.controller = try container.decode(String.self, forKey: .controller)
        self.publicKeyMultibase = try container.decodeIfPresent(String.self, forKey: .publicKeyMultibase) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, type, controller, publicKeyMultibase
    }

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherVerificationMethod = other as? VerificationMethod else { return false }
        return id == otherVerificationMethod.id && type == otherVerificationMethod.type
            && controller == otherVerificationMethod.controller
            && publicKeyMultibase == otherVerificationMethod.publicKeyMultibase
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map.append(key: "id", value: id)
        map.append(key: "type", value: type)
        map.append(key: "controller", value: controller)
        map.append(key: "publicKeyMultibase", value: publicKeyMultibase)
        return map
    }
}
