import Foundation

/// Syntax validation for the identifiers of an AT Protocol account.
public enum AccountIdentifiers {
    /// Top-level domains a handle or a `did:web` host may not use:
    /// `.alt`, `.arpa`, `.example`, `.internal`, `.invalid`, `.local`,
    /// `.localhost`, `.onion`.
    public static let disallowedTLDs: Set<String> = [
        ".alt", ".arpa", ".example", ".internal", ".invalid", ".local", ".localhost", ".onion",
    ]

    /// Validates an account DID under AT Protocol's rules for its two
    /// supported methods ("Blessed DID Methods", https://atproto.com/specs/did):
    ///
    /// - `did:plc`: exactly 24 base32 characters (`a-z`, `2-7`).
    /// - `did:web`: a bare hostname. No path segments, and no port, so
    ///   `did:web:example.com:user` and `did:web:example.com%3A8080` are
    ///   refused. The hostname follows the handle rules: at least two
    ///   labels, a final label that starts with a letter, and not under a
    ///   reserved top-level domain (``disallowedTLDs``). `localhost`, with
    ///   an optional `%3A<port>`, is accepted for development.
    ///
    /// The same rules as `DID.isValidAtprotoDID` in the `Petrel` module,
    /// which this module does not depend on.
    ///
    /// - Parameters:
    ///   - did: The DID to check.
    ///   - allowLocalhost: Whether `did:web:localhost` is accepted. Pass
    ///     `false` on production paths.
    /// - Returns: `did`, unchanged.
    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)``.
    public static func validateDID(_ did: String, allowLocalhost: Bool = true) throws -> String {
        let bytes = Array(did.utf8)
        guard bytes.count <= 2_048,
              bytes.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw PetrelPLCError.invalidIdentifier("account DID")
        }
        if did.hasPrefix("did:plc:") {
            let identifier = did.utf8.dropFirst(8)
            guard identifier.count == 24,
                  identifier.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 50 && $0 <= 55) }) else {
                throw PetrelPLCError.invalidIdentifier("account DID")
            }
            return did
        }
        guard did.hasPrefix("did:web:") else {
            throw PetrelPLCError.invalidIdentifier("unsupported account DID method")
        }
        try validateWebDIDIdentifier(String(did.dropFirst(8)), allowLocalhost: allowLocalhost)
        return did
    }

    /// Validates a handle (a DNS name of at least two labels) and returns it
    /// lower-cased.
    ///
    /// - Throws: ``PetrelPLCError/invalidIdentifier(_:)``.
    public static func canonicalHandle(_ handle: String) throws -> String {
        let input = Array(handle.utf8)
        guard !input.isEmpty, input.count <= 253,
              input.allSatisfy({
                  ($0 >= 65 && $0 <= 90)
                      || ($0 >= 97 && $0 <= 122)
                      || ($0 >= 48 && $0 <= 57)
                      || $0 == 45
                      || $0 == 46
              }) else {
            throw PetrelPLCError.invalidIdentifier("account handle")
        }

        let canonical = handle.lowercased()
        let labels = canonical.split(separator: ".", omittingEmptySubsequences: false)
        let finalLabelStartsWithASCIIAlpha = labels.last?.utf8.first.map {
            ($0 >= 97 && $0 <= 122)
        } == true
        guard labels.count >= 2,
              labels.allSatisfy({
                  !$0.isEmpty
                      && $0.utf8.count <= 63
                      && $0.first != "-"
                      && $0.last != "-"
              }),
              finalLabelStartsWithASCIIAlpha else {
            throw PetrelPLCError.invalidIdentifier("account handle")
        }
        return canonical
    }

    private static func validateWebDIDIdentifier(_ identifier: String, allowLocalhost: Bool) throws {
        // A colon after the host separates path segments, which atproto
        // does not allow.
        guard !identifier.isEmpty, !identifier.contains(":") else {
            throw PetrelPLCError.invalidIdentifier("did:web must be a bare hostname")
        }
        var host = identifier
        var hasPort = false
        if let escape = identifier.range(of: "%3A", options: .caseInsensitive) {
            let portText = identifier[escape.upperBound...]
            guard !portText.isEmpty,
                  portText.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  let port = Int(portText), (1 ... 65_535).contains(port) else {
                throw PetrelPLCError.invalidIdentifier("did:web port")
            }
            host = String(identifier[..<escape.lowerBound])
            hasPort = true
        }
        if host.lowercased() == "localhost" {
            guard allowLocalhost else {
                throw PetrelPLCError.invalidIdentifier("did:web:localhost is for development only")
            }
            return
        }
        // A port is only allowed on localhost.
        guard !hasPort else {
            throw PetrelPLCError.invalidIdentifier("did:web port")
        }
        let lowercased = try canonicalHostname(host)
        guard !disallowedTLDs.contains(where: { lowercased.hasSuffix($0) }) else {
            throw PetrelPLCError.invalidIdentifier("did:web host uses a reserved top-level domain")
        }
    }

    /// The handle syntax rules, applied to a `did:web` host.
    private static func canonicalHostname(_ host: String) throws -> String {
        do {
            return try canonicalHandle(host)
        } catch {
            throw PetrelPLCError.invalidIdentifier("did:web host")
        }
    }
}
