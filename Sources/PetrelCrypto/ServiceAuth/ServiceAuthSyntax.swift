import Foundation

/// Identifier syntax checks used by service authentication.
///
/// `PetrelCrypto` sits below the `Petrel` target, so it cannot use that
/// target's `DID` and `NSID` types. These checks follow the same
/// specification text (the "DID Identifier Syntax" and "NSID Syntax"
/// sections) and are exercised against the official interop syntax vectors.
enum ServiceAuthSyntax {
    /// Longest DID the protocol allows.
    static let maximumDIDBytes = 2048
    /// Longest NSID the protocol allows.
    static let maximumNSIDBytes = 317
    /// Longest fragment accepted after a DID.
    static let maximumFragmentBytes = 512

    // MARK: DID

    /// The generic DID syntax: `did:` + lowercase method + `:` + an
    /// identifier of `A-Z a-z 0-9 . _ : % -` that does not end in `:` or `%`.
    static func isGenericDID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count <= maximumDIDBytes, bytes.count >= 7,
              bytes.starts(with: Array("did:".utf8)) else {
            return false
        }
        var index = 4
        let methodStart = index
        while index < bytes.count, bytes[index] >= 0x61, bytes[index] <= 0x7A {
            index += 1
        }
        guard index > methodStart, index < bytes.count, bytes[index] == 0x3A else {
            return false
        }
        index += 1
        guard index < bytes.count else { return false }
        for byte in bytes[index...] {
            guard isAlphanumeric(byte) || byte == 0x2E || byte == 0x5F || byte == 0x3A
                || byte == 0x25 || byte == 0x2D else {
                return false
            }
        }
        let last = bytes[bytes.count - 1]
        return last != 0x3A && last != 0x25
    }

    /// A DID a service-auth token may name as its issuer or audience: the
    /// generic syntax, plus the method rules for the methods the protocol
    /// defines.
    ///
    /// - `did:plc`: 24 base32 characters.
    /// - `did:web`: a hostname only — no path; a port only on `localhost`.
    /// - `did:key`: a P-256 or K-256 multikey.
    /// - any other method: generic syntax only.
    static func isDID(_ value: String) -> Bool {
        guard isGenericDID(value) else { return false }
        let parts = value.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        let identifier = parts[2]
        switch parts[1] {
        case "plc":
            return identifier.utf8.count == 24 && identifier.utf8.allSatisfy {
                ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x32 && $0 <= 0x37)
            }
        case "web":
            return isWebDIDIdentifier(identifier)
        case "key":
            return (try? PLCDIDKeyCodec.decode(value)) != nil
        default:
            return true
        }
    }

    private static func isWebDIDIdentifier(_ identifier: Substring) -> Bool {
        // Path-based did:web (further `:` segments) is not supported in atproto.
        guard !identifier.contains(":") else { return false }
        let pieces = String(identifier).components(separatedBy: "%3A")
        guard (1 ... 2).contains(pieces.count), !pieces[0].contains("%") else { return false }
        let host = pieces[0]
        if pieces.count == 2 {
            // Ports are allowed for localhost only.
            let port = pieces[1]
            guard host == "localhost",
                  !port.isEmpty, port.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
                  port.count == 1 || port.first != "0",
                  let number = UInt16(port), number > 0 else {
                return false
            }
            return true
        }
        return host == "localhost" || isHostname(host)
    }

    private static func isHostname(_ name: String) -> Bool {
        guard name.utf8.count <= 253 else { return false }
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            let bytes = Array(label.utf8)
            guard !bytes.isEmpty, bytes.count <= 63,
                  bytes.allSatisfy({ ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2D }),
                  bytes.first != 0x2D, bytes.last != 0x2D else {
                return false
            }
        }
        // As for handles: the top-level domain does not start with a digit.
        guard let first = labels[labels.count - 1].utf8.first else { return false }
        return !(first >= 0x30 && first <= 0x39)
    }

    // MARK: DID with fragment

    /// Splits `did` or `did#fragment`. Returns `nil` unless the DID passes
    /// ``isDID(_:)`` and the fragment, if any, passes ``isFragment(_:)``.
    static func splitDIDReference(_ value: String) -> (did: String, fragment: String?)? {
        let parts = value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, isDID(String(first)) else { return nil }
        guard parts.count == 2 else { return (String(first), nil) }
        let fragment = String(parts[1])
        guard isFragment(fragment) else { return nil }
        return (String(first), fragment)
    }

    /// A DID-document fragment name without its `#`: 1–512 characters of
    /// `A-Z a-z 0-9 . _ ~ : % -`. Service identifiers (`bsky_appview`,
    /// `atproto_labeler`) and key identifiers (`atproto`) all fit.
    static func isFragment(_ value: String) -> Bool {
        let bytes = value.utf8
        guard !bytes.isEmpty, bytes.count <= maximumFragmentBytes else { return false }
        return bytes.allSatisfy {
            isAlphanumeric($0) || $0 == 0x2E || $0 == 0x5F || $0 == 0x7E || $0 == 0x3A || $0 == 0x25 || $0 == 0x2D
        }
    }

    /// A `kid` header value: `#` followed by a fragment name, no DID.
    static func isKeyID(_ value: String) -> Bool {
        value.hasPrefix("#") && isFragment(String(value.dropFirst()))
    }

    // MARK: NSID

    /// NSID syntax: at least three period-separated segments, a domain
    /// authority of hostname labels whose first segment does not start with
    /// a digit, and a name of letters and digits that does not start with a
    /// digit.
    static func isNSID(_ value: String) -> Bool {
        let bytes = value.utf8
        guard bytes.count <= maximumNSIDBytes, bytes.allSatisfy({ $0 < 0x80 }) else { return false }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false).map { Array($0.utf8) }
        guard segments.count >= 3 else { return false }
        let authority = segments.dropLast()
        guard authority.reduce(0, { $0 + $1.count }) + authority.count - 1 <= 253 else { return false }
        for (index, segment) in authority.enumerated() {
            guard !segment.isEmpty, segment.count <= 63,
                  segment.allSatisfy({ isAlphanumeric($0) || $0 == 0x2D }),
                  segment.first != 0x2D, segment.last != 0x2D else {
                return false
            }
            if index == 0, let first = segment.first, first >= 0x30, first <= 0x39 {
                return false
            }
        }
        let name = segments[segments.count - 1]
        guard let first = name.first, name.count <= 63,
              name.allSatisfy(isAlphanumeric), !(first >= 0x30 && first <= 0x39) else {
            return false
        }
        return true
    }

    // MARK: Opaque claim values

    /// Non-empty printable ASCII without spaces, at most `maximumBytes` long.
    static func isPrintableASCII(_ value: String, maximumBytes: Int) -> Bool {
        let bytes = value.utf8
        return !bytes.isEmpty && bytes.count <= maximumBytes && bytes.allSatisfy { $0 >= 0x21 && $0 <= 0x7E }
    }

    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }
}
