import Foundation
import Petrel
import PetrelPLC

/// The four `com.atproto.identity` procedures a PDS offers for changing a
/// hosted account's PLC identity.
///
/// `ATProtoClient.Com.Atproto.Identity` — the generated XRPC namespace —
/// conforms, so the flow runs against a signed-in client as it is:
///
/// ```swift
/// let flow = PLCPDSOperationFlow(api: await client.com.atproto.identity)
/// ```
///
/// The protocol exists so the flow can be exercised against a stand-in.
public protocol PLCPDSIdentityAPI: Sendable {
    /// `com.atproto.identity.getRecommendedDidCredentials`
    func getRecommendedDidCredentials() async throws
        -> (responseCode: Int, data: ComAtprotoIdentityGetRecommendedDidCredentials.Output?)
    /// `com.atproto.identity.requestPlcOperationSignature`
    func requestPlcOperationSignature() async throws -> Int
    /// `com.atproto.identity.signPlcOperation`
    func signPlcOperation(
        input: ComAtprotoIdentitySignPlcOperation.Input
    ) async throws -> (responseCode: Int, data: ComAtprotoIdentitySignPlcOperation.Output?)
    /// `com.atproto.identity.submitPlcOperation`
    func submitPlcOperation(
        input: ComAtprotoIdentitySubmitPlcOperation.Input
    ) async throws -> Int
}

extension ATProtoClient.Com.Atproto.Identity: PLCPDSIdentityAPI {}

/// A failure of the PDS-mediated flow.
public enum PLCPDSFlowError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The PDS answered a procedure with a non-success status.
    case requestFailed(procedure: String, status: Int)
    /// The PDS answered with success but without a usable body.
    case malformedResponse(procedure: String, detail: String)

    /// A one-line description of the failure.
    public var description: String {
        switch self {
        case let .requestFailed(procedure, status):
            "\(procedure) failed with HTTP \(status)"
        case let .malformedResponse(procedure, detail):
            "\(procedure) returned a malformed response: \(detail)"
        }
    }
}

/// The fields of a PLC operation a PDS is asked to change or recommends.
/// A `nil` field is left as it is.
public struct PLCPDSOperationFields: Sendable, Equatable {
    /// Priority-ordered rotation keys, as `did:key` strings.
    public var rotationKeys: [String]?
    /// Priority-ordered aliases.
    public var alsoKnownAs: [String]?
    /// Verification method id to `did:key`.
    public var verificationMethods: [String: String]?
    /// Service id to service.
    public var services: [String: PLCService]?

    /// Creates a set of fields; omitted fields are left unchanged.
    public init(
        rotationKeys: [String]? = nil,
        alsoKnownAs: [String]? = nil,
        verificationMethods: [String: String]? = nil,
        services: [String: PLCService]? = nil
    ) {
        self.rotationKeys = rotationKeys
        self.alsoKnownAs = alsoKnownAs
        self.verificationMethods = verificationMethods
        self.services = services
    }
}

/// Changing a PLC identity through the account's PDS.
///
/// Most accounts do not hold a rotation key themselves: their PDS does. The
/// PDS will sign an operation on the account's behalf once the account
/// holder confirms by email. The flow is:
///
/// 1. ``requestSignatureToken()`` — the PDS emails a confirmation token.
/// 2. ``signOperation(token:changing:)`` — the PDS returns a signed
///    operation that applies the requested changes to the current state.
/// 3. Check what was signed against the identity's verified audit log
///    (`PLCVerifiedAuditLog.verifyNextOperation(_:)`), so that neither the
///    PDS nor anything between you and it can slip in a different change.
/// 4. ``submit(_:)`` — the PDS validates the operation and forwards it to
///    the directory. Submitting directly with `PLCDirectoryClient.submit`
///    works too.
///
/// ``recommendedCredentials()`` is the starting point of an account
/// migration: it asks the *new* PDS which keys and endpoint the identity
/// should carry.
public struct PLCPDSOperationFlow: Sendable {
    private let api: any PLCPDSIdentityAPI

    /// - Parameter api: `await client.com.atproto.identity` of a signed-in
    ///   `ATProtoClient`.
    public init(api: any PLCPDSIdentityAPI) {
        self.api = api
    }

    /// Asks the PDS which rotation keys, aliases, verification methods and
    /// services the identity should have to be hosted there.
    public func recommendedCredentials() async throws -> PLCPDSOperationFields {
        let procedure = ComAtprotoIdentityGetRecommendedDidCredentials.typeIdentifier
        let (status, output) = try await api.getRecommendedDidCredentials()
        guard (200 ... 299).contains(status) else {
            throw PLCPDSFlowError.requestFailed(procedure: procedure, status: status)
        }
        guard let output else {
            throw PLCPDSFlowError.malformedResponse(procedure: procedure, detail: "no body")
        }
        do {
            return try PLCPDSOperationFields(
                rotationKeys: output.rotationKeys,
                alsoKnownAs: output.alsoKnownAs,
                verificationMethods: output.verificationMethods.map(PLCPDSBridge.verificationMethods),
                services: output.services.map(PLCPDSBridge.services)
            )
        } catch {
            throw PLCPDSFlowError.malformedResponse(
                procedure: procedure, detail: String(describing: error)
            )
        }
    }

    /// Asks the PDS to email the account holder a token that authorizes one
    /// ``signOperation(token:changing:)`` call.
    public func requestSignatureToken() async throws {
        let status = try await api.requestPlcOperationSignature()
        guard (200 ... 299).contains(status) else {
            throw PLCPDSFlowError.requestFailed(
                procedure: ComAtprotoIdentityRequestPlcOperationSignature.typeIdentifier,
                status: status
            )
        }
    }

    /// Asks the PDS to sign an operation that applies `changes` to the
    /// identity's current state.
    ///
    /// The result is decoded but not trusted: verify it against the audit
    /// log before submitting it.
    ///
    /// - Parameters:
    ///   - token: The token from the confirmation email.
    ///   - changes: The fields to replace. Fields left `nil` keep their
    ///     current value.
    public func signOperation(
        token: String,
        changing changes: PLCPDSOperationFields
    ) async throws -> PLCSignedOperation {
        let procedure = ComAtprotoIdentitySignPlcOperation.typeIdentifier
        let (status, output) = try await api.signPlcOperation(input: .init(
            token: token,
            rotationKeys: changes.rotationKeys,
            alsoKnownAs: changes.alsoKnownAs,
            verificationMethods: changes.verificationMethods.map(PLCPDSBridge.container(verificationMethods:)),
            services: changes.services.map(PLCPDSBridge.container(services:))
        ))
        guard (200 ... 299).contains(status) else {
            throw PLCPDSFlowError.requestFailed(procedure: procedure, status: status)
        }
        guard let output else {
            throw PLCPDSFlowError.malformedResponse(procedure: procedure, detail: "no body")
        }
        do {
            return try PLCPDSBridge.operation(from: output.operation)
        } catch {
            throw PLCPDSFlowError.malformedResponse(
                procedure: procedure, detail: String(describing: error)
            )
        }
    }

    /// Hands a signed operation to the PDS, which checks that it does not
    /// break the account and forwards it to the PLC directory.
    public func submit(_ operation: PLCSignedOperation) async throws {
        let status = try await api.submitPlcOperation(
            input: .init(operation: PLCPDSBridge.container(for: operation))
        )
        guard (200 ... 299).contains(status) else {
            throw PLCPDSFlowError.requestFailed(
                procedure: ComAtprotoIdentitySubmitPlcOperation.typeIdentifier,
                status: status
            )
        }
    }
}

/// Conversions between `PetrelPLC` values and the untyped
/// `ATProtocolValueContainer` the `com.atproto.identity` lexicons use for
/// PLC operations.
public enum PLCPDSBridge {
    /// A signed operation as the `operation` value of
    /// `com.atproto.identity.submitPlcOperation`.
    public static func container(for operation: PLCSignedOperation) throws -> ATProtocolValueContainer {
        try container(fromJSONObject: JSONSerialization.jsonObject(with: operation.canonicalJSON))
    }

    /// Decodes the `operation` value of
    /// `com.atproto.identity.signPlcOperation`.
    ///
    /// - Throws: `PetrelPLCError.malformed` if the value is not a PLC
    ///   operation.
    public static func operation(from container: ATProtocolValueContainer) throws -> PLCSignedOperation {
        let object = try jsonObject(from: container)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw PetrelPLCError.malformed("PLC operation value is not a JSON object")
        }
        return try PLCOperationCodec.decodeSignedJSON(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    /// A `verificationMethods` map as a lexicon value.
    public static func container(verificationMethods: [String: String]) -> ATProtocolValueContainer {
        .object(verificationMethods.mapValues { .string($0) })
    }

    /// A `services` map as a lexicon value.
    public static func container(services: [String: PLCService]) -> ATProtocolValueContainer {
        .object(services.mapValues { service in
            .object(["type": .string(service.type), "endpoint": .string(service.endpoint)])
        })
    }

    /// Reads a `verificationMethods` map from a lexicon value.
    public static func verificationMethods(_ container: ATProtocolValueContainer) throws -> [String: String] {
        guard let object = try jsonObject(from: container) as? [String: String] else {
            throw PetrelPLCError.malformed("PLC verificationMethods value is malformed")
        }
        return object
    }

    /// Reads a `services` map from a lexicon value.
    public static func services(_ container: ATProtocolValueContainer) throws -> [String: PLCService] {
        guard let object = try jsonObject(from: container) as? [String: [String: String]] else {
            throw PetrelPLCError.malformed("PLC services value is malformed")
        }
        return try object.mapValues { service in
            guard service.count == 2, let type = service["type"], let endpoint = service["endpoint"] else {
                throw PetrelPLCError.malformed("PLC services value is malformed")
            }
            return PLCService(type: type, endpoint: endpoint)
        }
    }

    private static func container(fromJSONObject value: Any) throws -> ATProtocolValueContainer {
        switch value {
        case is NSNull:
            return .null
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return try .array(array.map(container(fromJSONObject:)))
        case let object as [String: Any]:
            return try .object(object.mapValues(container(fromJSONObject:)))
        default:
            // A PLC operation holds only strings, arrays, maps and null.
            throw PetrelPLCError.malformed("PLC operation holds an unsupported JSON value")
        }
    }

    private static func jsonObject(from container: ATProtocolValueContainer) throws -> Any {
        switch container {
        case .null:
            return NSNull()
        case let .string(value):
            return value
        case let .array(values):
            return try values.map(jsonObject(from:))
        case let .object(values):
            return try values.mapValues(jsonObject(from:))
        default:
            // Numbers, booleans, links, bytes and typed records have no
            // place in a PLC operation.
            throw PetrelPLCError.malformed("PLC operation holds an unsupported lexicon value")
        }
    }
}
