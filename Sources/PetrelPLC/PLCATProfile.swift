import Crypto
import Foundation
import PetrelCrypto

/// The AT Protocol profile of a PLC identity: an `atproto` signing key, an
/// `at://` handle alias and an `atproto_pds` service.
public enum PLCATProfile {
    /// The `services` key of the account's PDS: `atproto_pds`.
    public static let pdsServiceID = "atproto_pds"
    /// The service type of a PDS: `AtprotoPersonalDataServer`.
    public static let pdsServiceType = "AtprotoPersonalDataServer"
    /// The `verificationMethods` key of the repository signing key: `atproto`.
    public static let signingKeyID = "atproto"

    /// Builds the genesis operation of a new atproto identity, the
    /// counterpart of the reference library's `formatAtprotoOp`.
    ///
    /// - Parameters:
    ///   - handle: The account handle, with or without an `at://` prefix. It
    ///     is validated and lower-cased.
    ///   - signingKey: The repository signing key as a P-256 or K-256
    ///     `did:key`. Best practice is to keep it out of `rotationKeys`.
    ///   - rotationKeys: 1–5 distinct P-256 or K-256 `did:key` values in
    ///     descending authority.
    ///   - pdsEndpoint: The PDS URL, `http` or `https`, without a path. A
    ///     bare host name is given an `https://` scheme.
    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)`` or
    ///   ``PetrelPLCError/malformed(_:)``.
    public static func genesisOperation(
        handle: String,
        signingKey: String,
        rotationKeys: [String],
        pdsEndpoint: String
    ) throws -> PLCUnsignedRegularOperation {
        try PLCUnsignedRegularOperation(
            rotationKeys: rotationKeys,
            verificationMethods: [signingKeyID: signingDIDKey(signingKey)],
            alsoKnownAs: [handleURI(handle)],
            services: [
                pdsServiceID: PLCService(
                    type: pdsServiceType,
                    endpoint: self.pdsEndpoint(pdsEndpoint)
                ),
            ],
            prev: nil
        )
    }

    /// As the `did:key` string variant of `genesisOperation`, taking
    /// validated public keys.
    public static func genesisOperation(
        handle: String,
        signingKey: ATProtoPublicKey,
        rotationKeys: [ATProtoPublicKey],
        pdsEndpoint: String
    ) throws -> PLCUnsignedRegularOperation {
        try genesisOperation(
            handle: handle,
            signingKey: signingKey.didKey,
            rotationKeys: rotationKeys.map(\.didKey),
            pdsEndpoint: pdsEndpoint
        )
    }

    /// Builds an atproto operation from Swift Crypto P-256 keys, with the
    /// PDS restricted to an HTTPS origin on port 443 (or a literal loopback
    /// address). For K-256 keys or another endpoint, use `genesisOperation`.
    public static func regularOperation(
        handle: String,
        signingPublicKey: P256.Signing.PublicKey,
        rotationPublicKeys: [P256.Signing.PublicKey],
        pdsOrigin: URL,
        prev: String?
    ) throws -> PLCUnsignedRegularOperation {
        let canonicalHandle = try AccountIdentifiers.canonicalHandle(handle)
        let origin = try canonicalPDSOrigin(pdsOrigin)
        return try PLCUnsignedRegularOperation(
            rotationKeys: rotationPublicKeys.map { P256DIDKey(publicKey: $0).value },
            verificationMethods: [signingKeyID: P256DIDKey(publicKey: signingPublicKey).value],
            alsoKnownAs: ["at://\(canonicalHandle)"],
            services: [
                pdsServiceID: .init(type: pdsServiceType, endpoint: origin),
            ],
            prev: prev
        )
    }

    /// Validates a handle and returns it as the `at://` URI stored in
    /// `alsoKnownAs`. An `at://` prefix on the input is accepted.
    ///
    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)``.
    public static func handleURI(_ handle: String) throws -> String {
        let bare = handle.hasPrefix("at://") ? String(handle.dropFirst(5)) : handle
        return try "at://" + AccountIdentifiers.canonicalHandle(bare)
    }

    /// Validates a PDS endpoint for the `atproto_pds` service: an `http` or
    /// `https` URL with a host and no credentials, path, query or fragment.
    /// A value with no scheme is given `https://`, as the reference library
    /// does. The result has no trailing slash.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)``.
    public static func pdsEndpoint(_ value: String) throws -> String {
        let withScheme = withHTTPScheme(value)
        guard let components = URLComponents(string: withScheme),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw PetrelPLCError.malformed(
                "PLC PDS endpoint must be an http or https URL without a path"
            )
        }
        var normalized = components
        normalized.path = ""
        guard let result = normalized.string, !result.hasSuffix("/") else {
            throw PetrelPLCError.malformed("PLC PDS endpoint is malformed")
        }
        return result
    }

    /// Validates the repository signing key: a P-256 or K-256 `did:key`,
    /// the two curves atproto accepts for repository signatures.
    ///
    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)``.
    public static func signingDIDKey(_ value: String) throws -> String {
        guard (try? ATProtoPublicKey(didKey: value)) != nil else {
            throw PetrelPLCError.invalidIdentifier(
                "atproto signing key must be a P-256 or K-256 did:key"
            )
        }
        return value
    }

    /// Validates and canonicalizes a PDS origin under the strict policy of
    /// ``regularOperation(handle:signingPublicKey:rotationPublicKeys:pdsOrigin:prev:)``:
    /// HTTPS on port 443, or HTTP on a literal loopback address with an
    /// explicit port.
    public static func canonicalPDSOrigin(_ url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw PetrelPLCError.malformed("PLC PDS endpoint must be an origin")
        }
        let isLiteralLoopback = scheme == "http" && plcIsLoopbackLiteral(host)
        guard scheme == "https" || isLiteralLoopback else {
            throw PetrelPLCError.malformed("PLC PDS endpoint must use HTTPS")
        }
        if scheme == "https", components.port != nil, components.port != 443 {
            throw PetrelPLCError.malformed("PLC PDS endpoint port is invalid")
        }
        if isLiteralLoopback {
            guard let port = components.port, (1 ... 65_535).contains(port) else {
                throw PetrelPLCError.malformed("PLC lab PDS endpoint requires an explicit port")
            }
        }
        var normalized = components
        normalized.path = ""
        guard let value = normalized.url?.absoluteString, !value.hasSuffix("/") else {
            throw PetrelPLCError.malformed("PLC PDS endpoint is malformed")
        }
        return value
    }

    // MARK: Reference normalisation

    /// The reference library's `ensureAtprotoPrefix`, used to present a
    /// legacy `create` operation's handle. No validation: the value is
    /// historical data.
    static func atURI(forHandle handle: String) -> String {
        if handle.hasPrefix("at://") { return handle }
        var stripped = handle
        for scheme in ["http://", "https://"] {
            if let range = stripped.range(of: scheme) {
                stripped.removeSubrange(range)
            }
        }
        return "at://" + stripped
    }

    /// The reference library's `ensureHttpPrefix`.
    static func withHTTPScheme(_ value: String) -> String {
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
        return "https://" + value
    }
}

func plcIsLoopbackLiteral(_ host: String) -> Bool {
    let canonical = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    if canonical == "::1" { return true }
    let parts = canonical.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4,
          let first = UInt8(parts[0]),
          parts.allSatisfy({ part in
              guard let value = UInt8(part) else { return false }
              return String(value) == part
          }) else {
        return false
    }
    return first == 127
}
