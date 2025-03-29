//
//  DIDDocHandler.swift
//  Petrel
//
//  Created by Josh LaCalamito on 2/3/24.
//

import Foundation

public struct DIDDocument: ATProtocolCodable, ATProtocolValue {
    let context: [String]
    let id: String
    let alsoKnownAs: [String]
    let verificationMethod: [VerificationMethod]
    let service: [Service]

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
        map = map.adding(key: "@context", value: self.context) // Array of Strings
        map = map.adding(key: "id", value: self.id)
        if !self.alsoKnownAs.isEmpty { // Only add if not empty, common practice
             map = map.adding(key: "alsoKnownAs", value: self.alsoKnownAs)
        }

        // Convert verificationMethod array
        let verificationMethodsCBOR = try self.verificationMethod.map { try $0.toCBORValue() }
        if !verificationMethodsCBOR.isEmpty {
            map = map.adding(key: "verificationMethod", value: verificationMethodsCBOR)
        }

        // Convert service array
        let servicesCBOR = try self.service.map { try $0.toCBORValue() }
        if !servicesCBOR.isEmpty {
            map = map.adding(key: "service", value: servicesCBOR)
        }

        return map
    }
}

public struct Service: ATProtocolCodable, ATProtocolValue {
    let id: String
    let type: String
    let serviceEndpoint: String

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherService = other as? Service else { return false }
        return id == otherService.id && type == otherService.type
            && serviceEndpoint == otherService.serviceEndpoint
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "id", value: self.id)
        map = map.adding(key: "type", value: self.type)
        map = map.adding(key: "serviceEndpoint", value: self.serviceEndpoint)
        return map
    }
}

public struct VerificationMethod: ATProtocolCodable, ATProtocolValue {
    let id: String
    let type: String
    let controller: String
    let publicKeyMultibase: String

    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherVerificationMethod = other as? VerificationMethod else { return false }
        return id == otherVerificationMethod.id && type == otherVerificationMethod.type
            && controller == otherVerificationMethod.controller
            && publicKeyMultibase == otherVerificationMethod.publicKeyMultibase
    }

    public func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "id", value: self.id)
        map = map.adding(key: "type", value: self.type)
        map = map.adding(key: "controller", value: self.controller)
        map = map.adding(key: "publicKeyMultibase", value: self.publicKeyMultibase)
        return map
    }
}
