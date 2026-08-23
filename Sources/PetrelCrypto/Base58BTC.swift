import Foundation

public enum Base58BTC {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let lookup: [UInt8: Int] = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) })

    public static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var digits = [UInt8](repeating: 0, count: data.count * 138 / 100 + 1)
        var digitLength = 1
        for byte in data {
            var carry = Int(byte)
            for index in 0 ..< digitLength {
                carry += Int(digits[index]) << 8
                digits[index] = UInt8(carry % 58)
                carry /= 58
            }
            while carry > 0 {
                digits[digitLength] = UInt8(carry % 58)
                digitLength += 1
                carry /= 58
            }
        }
        let leadingZeros = data.prefix { $0 == 0 }.count
        var output = [UInt8](repeating: alphabet[0], count: leadingZeros)
        output.append(contentsOf: digits[..<digitLength].reversed().map { alphabet[Int($0)] })
        return String(decoding: output, as: UTF8.self)
    }

    public static func decode(_ value: String) throws -> Data {
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty, bytes.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("base58btc value")
        }
        var output = [UInt8](repeating: 0, count: bytes.count * 733 / 1_000 + 1)
        var outputLength = 1
        for byte in bytes {
            guard let digit = lookup[byte] else {
                throw PetrelCryptoError.invalidIdentifier("base58btc value")
            }
            var carry = digit
            for index in 0 ..< outputLength {
                carry += Int(output[index]) * 58
                output[index] = UInt8(carry & 0xff)
                carry >>= 8
            }
            while carry > 0 {
                output[outputLength] = UInt8(carry & 0xff)
                outputLength += 1
                carry >>= 8
            }
        }
        let leadingZeros = bytes.prefix { $0 == alphabet[0] }.count
        return Data(repeating: 0, count: leadingZeros) + Data(output[..<outputLength].reversed())
    }
}
