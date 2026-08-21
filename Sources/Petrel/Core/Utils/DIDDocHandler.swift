//
//  DIDDocHandler.swift
//  Petrel
//
//  Created by Josh LaCalamito on 2/3/24.
//

import Foundation

public struct DIDDocument: ATProtocolCodable, ATProtocolValue {
    public let context: [String]
    public let id: String
    public let alsoKnownAs: [String]
    public let verificationMethod: [VerificationMethod]
    public let service: [Service]

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
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.context = try container.decodeIfPresent([String].self, forKey: .context) ?? []
        self.id = try container.decode(String.self, forKey: .id)
        self.alsoKnownAs = try container.decodeIfPresent([String].self, forKey: .alsoKnownAs) ?? []
        self.verificationMethod = try container.decodeIfPresent([VerificationMethod].self, forKey: .verificationMethod) ?? []
        self.service = try container.decodeIfPresent([Service].self, forKey: .service) ?? []
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

public struct Service: ATProtocolCodable, ATProtocolValue {
    public let id: String
    public let type: String
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

public struct VerificationMethod: ATProtocolCodable, ATProtocolValue {
    public let id: String
    public let type: String
    public let controller: String
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
