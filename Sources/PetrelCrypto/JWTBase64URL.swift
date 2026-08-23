import Foundation

/// Canonical unpadded Base64URL encoding and decoding used by JOSE and ATProto.
public enum JWTBase64URL {
    /// Encodes data to canonical unpadded Base64URL text.
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes only canonical unpadded base64url text. Accepting permissive
    /// Base64 variants would make signatures and digests ambiguous.
    public static func decode(_ value: String, maxBytes: Int = 16_384) throws -> Data {
        guard !value.isEmpty, !value.contains("="), value.utf8.allSatisfy({ byte in
            (65 ... 90).contains(byte) || (97 ... 122).contains(byte) ||
                (48 ... 57).contains(byte) || byte == 45 || byte == 95
        }) else {
            throw PetrelCryptoError.malformed("invalid base64url value")
        }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let paddingCount = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: paddingCount))
        guard let decoded = Data(base64Encoded: base64),
              decoded.count <= maxBytes,
              encode(decoded) == value else {
            throw PetrelCryptoError.malformed("invalid base64url value")
        }
        return decoded
    }
}

public extension Data {
    func base64URLEncodedString() -> String {
        JWTBase64URL.encode(self)
    }

    init?(base64URLEncoded value: String) {
        guard let decoded = try? JWTBase64URL.decode(value, maxBytes: 16_384 * 1024) else {
            return nil
        }
        self = decoded
    }
}
