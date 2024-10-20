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
}
