//
//  DIDWebIdentifier.swift
//  Petrel
//

import Foundation

/// A `did:web` identifier that AT Protocol accepts, and the one place its rules are checked.
///
/// AT Protocol narrows the W3C `did:web` method (see the DID specification, "did:web in AT
/// Protocol"):
///
/// - only hostname-level DIDs are supported; a DID with path segments (`did:web:host:path`) is
///   rejected;
/// - the hostname follows the handle rules: at least two labels, ASCII letters, digits and
///   hyphens, a top-level label that does not start with a digit, and none of the reserved
///   top-level domains (`.alt`, `.arpa`, `.example`, `.internal`, `.invalid`, `.local`,
///   `.localhost`, `.onion`);
/// - `localhost` is the single exception, allowed for testing and development, and it is the
///   only host that may carry a port (written `%3A<port>`);
/// - `.test` hosts are for development as well.
///
/// The type depends on Foundation alone so every module that needs these rules can share it.
///
/// ```swift
/// let web = try DIDWebIdentifier("did:web:example.com")
/// web.documentURL // https://example.com/.well-known/did.json
/// ```
public struct DIDWebIdentifier: Sendable, Hashable, CustomStringConvertible {
    /// Why a string is not an acceptable AT Protocol `did:web`.
    public enum ValidationError: Error, Sendable, Equatable {
        /// The string does not start with `did:web:` or contains characters a DID may not contain.
        case notDIDWeb
        /// The DID has path segments after the hostname, which AT Protocol does not support.
        case pathNotSupported
        /// The hostname is empty, not lowercase, an IP address, a bare top-level domain, or
        /// otherwise not a valid hostname.
        case invalidHostname
        /// The hostname ends in a reserved top-level domain.
        case reservedTopLevelDomain
        /// A port was given for a host other than `localhost`, or the port is not `1...65535`.
        case portNotAllowed
        /// The host is `localhost` or a `.test` name and development hosts were not allowed.
        case developmentHostNotAllowed
    }

    /// The top-level domains that must fail registration and resolution.
    public static let reservedTopLevelDomains: Set<String> = [
        "alt", "arpa", "example", "internal", "invalid", "local", "localhost", "onion",
    ]

    /// The DID exactly as given.
    public let did: String
    /// The lowercase hostname.
    public let host: String
    /// The port. Present only when `host` is `localhost`.
    public let port: Int?

    /// Whether the host is `localhost` or a `.test` name, which are for development only.
    public var isDevelopmentHost: Bool {
        host == "localhost" || host.hasSuffix(".test")
    }

    /// The URL of the DID document: `https://<host>/.well-known/did.json`.
    ///
    /// `localhost` uses `http`, as the reference implementation does, because a development
    /// server on the loopback interface has no certificate.
    public var documentURL: URL {
        var components = URLComponents()
        components.scheme = host == "localhost" ? "http" : "https"
        components.host = host
        components.port = port
        components.path = "/.well-known/did.json"
        guard let url = components.url else {
            // `host` and `port` were validated in `init`, so this cannot fail.
            preconditionFailure("validated did:web produced no URL")
        }
        return url
    }

    public var description: String { did }

    /// Validates `did` against the AT Protocol `did:web` rules.
    ///
    /// - Parameters:
    ///   - did: The DID string. It is not trimmed or case-normalized.
    ///   - allowingDevelopmentHosts: Whether `localhost` (with an optional port) and `.test`
    ///     hosts are accepted. The specification allows them in testing and development only,
    ///     so the default is `false`.
    /// - Throws: ``ValidationError``.
    public init(_ did: String, allowingDevelopmentHosts: Bool = false) throws {
        let prefix = "did:web:"
        guard did.hasPrefix(prefix), did.utf8.count <= 2048 else {
            throw ValidationError.notDIDWeb
        }
        let identifier = did.dropFirst(prefix.count)
        // The DID grammar: ASCII letters, digits and `._:%-`, not ending in `:` or `%`.
        guard !identifier.isEmpty,
              identifier.utf8.allSatisfy(Self.isDIDIdentifierByte),
              identifier.last != ":", identifier.last != "%"
        else {
            throw ValidationError.notDIDWeb
        }

        let segments = identifier.split(separator: ":", omittingEmptySubsequences: false)
        guard segments.count == 1, let authority = segments.first else {
            throw ValidationError.pathNotSupported
        }

        let hostPart: Substring
        var portPart: Substring?
        if let separator = authority.range(of: "%3A", options: .caseInsensitive) {
            hostPart = authority[..<separator.lowerBound]
            portPart = authority[separator.upperBound...]
        } else {
            hostPart = authority
        }
        // Any other percent escape would decode to a character a hostname cannot contain.
        guard !hostPart.contains("%") else {
            throw ValidationError.invalidHostname
        }
        let host = String(hostPart)

        if host == "localhost" {
            guard allowingDevelopmentHosts else {
                throw ValidationError.developmentHostNotAllowed
            }
        } else {
            guard portPart == nil else {
                throw ValidationError.portNotAllowed
            }
            guard Self.isValidHostname(host) else {
                throw ValidationError.invalidHostname
            }
            let topLevelDomain = host.split(separator: ".").last.map(String.init) ?? ""
            guard !Self.reservedTopLevelDomains.contains(topLevelDomain) else {
                throw ValidationError.reservedTopLevelDomain
            }
            if topLevelDomain == "test", !allowingDevelopmentHosts {
                throw ValidationError.developmentHostNotAllowed
            }
        }

        var port: Int?
        if let portPart {
            guard !portPart.isEmpty, portPart.utf8.count <= 5,
                  portPart.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let value = Int(portPart), (1 ... 65535).contains(value)
            else {
                throw ValidationError.portNotAllowed
            }
            port = value
        }

        self.did = did
        self.host = host
        self.port = port
    }

    /// Whether `did` is an acceptable AT Protocol `did:web`.
    public static func isValid(_ did: String, allowingDevelopmentHosts: Bool = false) -> Bool {
        (try? DIDWebIdentifier(did, allowingDevelopmentHosts: allowingDevelopmentHosts)) != nil
    }

    private static func isDIDIdentifierByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 48 ... 57, 65 ... 90, 97 ... 122: // 0-9 A-Z a-z
            return true
        case 46, 95, 58, 37, 45: // . _ : % -
            return true
        default:
            return false
        }
    }

    /// The handle hostname grammar, lowercase only: two or more labels of 1...63 letters, digits
    /// and hyphens, no leading or trailing hyphen, and a final label that starts with a letter.
    /// IPv4 literals fail the last rule and IPv6 literals cannot be written without `:`.
    private static func isValidHostname(_ host: String) -> Bool {
        guard !host.isEmpty, host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            let bytes = Array(label.utf8)
            guard (1 ... 63).contains(bytes.count), bytes.first != 45, bytes.last != 45,
                  bytes.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 })
            else {
                return false
            }
        }
        guard let first = labels.last?.utf8.first, first >= 97, first <= 122 else { return false }
        return true
    }
}
