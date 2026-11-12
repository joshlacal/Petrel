import Foundation

/// A reference to a service in the network: a DID, and normally the
/// identifier of one entry in that DID document's `service` array.
///
/// The same `did#service` string appears in three places in the protocol:
///
/// - the `aud` claim of a service-auth token;
/// - the `aud` parameter of `com.atproto.server.getServiceAuth`;
/// - the `atproto-proxy` request header, which asks a PDS to forward a
///   request to that service.
///
/// ```swift
/// let appView = try ATProtoServiceReference("did:web:api.bsky.app#bsky_appview")
/// appView.did        // "did:web:api.bsky.app"
/// appView.serviceID  // "bsky_appview"
/// let labeler = try ATProtoServiceReference(did: "did:web:labeler.example.com", serviceID: "atproto_labeler")
/// request.setValue(labeler.description, forHTTPHeaderField: ATProtoServiceReference.proxyHeaderName)
/// ```
public struct ATProtoServiceReference: Sendable, Hashable, CustomStringConvertible {
    /// The name of the service-proxying request header: `atproto-proxy`.
    public static let proxyHeaderName = "atproto-proxy"

    /// Service identifier of a Bluesky AppView.
    public static let bskyAppViewServiceID = "bsky_appview"
    /// Service identifier of a Bluesky chat service.
    public static let bskyChatServiceID = "bsky_chat"
    /// Service identifier of a feed generator.
    public static let feedGeneratorServiceID = "bsky_fg"
    /// Service identifier of a notification service.
    public static let notificationServiceID = "bsky_notif"
    /// Service identifier of a labeler.
    public static let labelerServiceID = "atproto_labeler"
    /// Service identifier of a Personal Data Server.
    public static let pdsServiceID = "atproto_pds"

    /// The service's DID.
    public let did: String
    /// The service identifier, without its `#`; `nil` for a bare DID, which
    /// the specification keeps only for legacy software.
    public let serviceID: String?

    /// Creates a reference from its parts.
    ///
    /// - Parameters:
    ///   - did: A `did:plc`, hostname-level `did:web`, or other syntactically
    ///     valid DID.
    ///   - serviceID: The service identifier, with or without a leading `#`.
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)``.
    public init(did: String, serviceID: String? = nil) throws {
        guard ServiceAuthSyntax.isDID(did) else {
            throw PetrelCryptoError.invalidIdentifier("service DID is not a valid DID")
        }
        if let serviceID {
            let fragment = serviceID.hasPrefix("#") ? String(serviceID.dropFirst()) : serviceID
            guard ServiceAuthSyntax.isFragment(fragment) else {
                throw PetrelCryptoError.invalidIdentifier("service identifier is not a valid DID fragment")
            }
            self.serviceID = fragment
        } else {
            self.serviceID = nil
        }
        self.did = did
    }

    /// Parses `did` or `did#service`.
    ///
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)``.
    public init(_ string: String) throws {
        guard let parts = ServiceAuthSyntax.splitDIDReference(string) else {
            throw PetrelCryptoError.invalidIdentifier("not a service reference of the form did or did#service")
        }
        did = parts.did
        serviceID = parts.fragment
    }

    /// `did#service`, or the bare DID when there is no service identifier.
    /// This is the string to put in `aud` or in the `atproto-proxy` header.
    public var description: String {
        serviceID.map { "\(did)#\($0)" } ?? did
    }

    /// The value for the `atproto-proxy` header.
    ///
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)`` if the
    ///   reference has no service identifier: a PDS needs one to find the
    ///   endpoint to forward to.
    public func proxyHeaderValue() throws -> String {
        guard serviceID != nil else {
            throw PetrelCryptoError.invalidIdentifier("atproto-proxy needs a service identifier (did#service)")
        }
        return description
    }
}

public extension ServiceAuthAudience {
    /// Accepts tokens addressed to `service`, and optionally to its bare
    /// DID.
    ///
    /// - Parameters:
    ///   - service: This service's own reference.
    ///   - acceptBareDID: Also accept the DID without a service identifier.
    static func service(_ service: ATProtoServiceReference, acceptBareDID: Bool = false) -> ServiceAuthAudience {
        guard let serviceID = service.serviceID else {
            return .exactly(service.did)
        }
        return .service(did: service.did, id: serviceID, acceptBareDID: acceptBareDID)
    }
}
