import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum AccountIdentifiers {
    public static func validateDID(_ did: String) throws -> String {
        let bytes = Array(did.utf8)
        guard bytes.count <= 2_048,
              bytes.allSatisfy({ $0 >= 0x21 && $0 <= 0x7e }) else {
            throw PetrelPLCError.invalidIdentifier("account DID")
        }
        let components = did.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count >= 3, components[0] == "did" else {
            throw PetrelPLCError.invalidIdentifier("account DID")
        }

        switch components[1] {
        case "plc":
            guard components.count == 3,
                  components[2].utf8.count == 24,
                  components[2].utf8.allSatisfy({
                      ($0 >= 97 && $0 <= 122) || ($0 >= 50 && $0 <= 55)
                  }) else {
                throw PetrelPLCError.invalidIdentifier("account DID")
            }
        case "web":
            try validateWebDIDComponents(components)
        default:
            throw PetrelPLCError.invalidIdentifier("unsupported account DID method")
        }
        return did
    }

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

    private static func validateWebDIDComponents(_ components: [Substring]) throws {
        let authority = String(components[2])
        let authorityParts = authority.components(separatedBy: "%3A")
        guard (1 ... 2).contains(authorityParts.count) else {
            throw PetrelPLCError.invalidIdentifier("did:web authority")
        }
        let host = authorityParts[0]
        try validateCanonicalDNSName(host)
        if authorityParts.count == 2 {
            guard let port = UInt16(authorityParts[1]), port > 0, String(port) == authorityParts[1] else {
                throw PetrelPLCError.invalidIdentifier("did:web port")
            }
        }
        for segment in components.dropFirst(3) {
            guard !segment.isEmpty, segment != ".", segment != ".." else {
                throw PetrelPLCError.invalidIdentifier("did:web path segment")
            }
            try validateCanonicalWebPathSegment(segment)
        }
    }

    private static func validateCanonicalDNSName(_ name: String) throws {
        let input = Array(name.utf8)
        guard !input.isEmpty, input.count <= 253,
              input.allSatisfy({
                  ($0 >= 97 && $0 <= 122)
                      || ($0 >= 48 && $0 <= 57)
                      || $0 == 45
                      || $0 == 46
              }) else {
            throw PetrelPLCError.invalidIdentifier("did:web DNS name")
        }
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({
                  !$0.isEmpty
                      && $0.utf8.count <= 63
                      && $0.first != "-"
                      && $0.last != "-"
              }),
              labels.last?.allSatisfy(\.isNumber) == false else {
            throw PetrelPLCError.invalidIdentifier("did:web DNS name")
        }
    }

    private static func validateCanonicalWebPathSegment(_ segment: Substring) throws {
        let bytes = Array(segment.utf8)
        guard !bytes.isEmpty, bytes.count <= 255 else {
            throw PetrelPLCError.invalidIdentifier("did:web path segment")
        }
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if isUnreserved(byte) {
                index += 1
                continue
            }
            if byte == UInt8(ascii: "%") {
                guard index + 2 < bytes.count,
                      isUppercaseHex(bytes[index + 1]),
                      isUppercaseHex(bytes[index + 2]),
                      let decoded = decodedHex(bytes[index + 1], bytes[index + 2]),
                      !isUnreserved(decoded) else {
                    throw PetrelPLCError.invalidIdentifier("did:web path segment percent-encoding")
                }
                index += 3
                continue
            }
            throw PetrelPLCError.invalidIdentifier("did:web path segment")
        }
    }

    private static func isUnreserved(_ byte: UInt8) -> Bool {
        (byte >= 97 && byte <= 122)
            || (byte >= 65 && byte <= 90)
            || (byte >= 48 && byte <= 57)
            || byte == 45
            || byte == 46
            || byte == 95
            || byte == 126
    }

    private static func isUppercaseHex(_ byte: UInt8) -> Bool {
        (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 70)
    }

    private static func decodedHex(_ first: UInt8, _ second: UInt8) -> UInt8? {
        guard let high = hexValue(first), let low = hexValue(second) else { return nil }
        return (high << 4) | low
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48 ... 57: byte - 48
        case 65 ... 70: byte - 65 + 10
        default: nil
        }
    }
}
