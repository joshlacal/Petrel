import Foundation
@testable import Petrel
import Testing

@Suite("RFC 4648 bytes decoding")
struct BytesBase64DecodingTests {
    @Test("Every byte value round-trips through padded and unpadded base64")
    func everyByteValueRoundTrips() throws {
        let allBytes = Array(UInt8.min ... UInt8.max)
        let payloads = [Data(), Data(allBytes), Data(allBytes + [0]), Data(allBytes + [0, 255])]

        for expected in payloads {
            let padded = expected.base64EncodedString()
            let unpadded = String(padded.prefix { $0 != "=" })
            for encoded in [padded, unpadded] {
                try expectDecodedBytes(encoded, equalTo: expected)
            }
        }
    }

    /// RFC 4648 §3.5 lets a decoder ignore the bits of the last character that do not
    /// complete a byte. The official interop suite relies on it: `record-data-valid.json`
    /// contains `"$bytes": "123"`, whose last character carries two such bits.
    @Test("Unused bits of the terminal sextet are ignored")
    func terminalSextetsIgnoreUnusedBits() throws {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

        for (index, character) in alphabet.enumerated() {
            for (payload, padding, divisor) in [("A\(character)", "==", 16), ("AA\(character)", "=", 4)] {
                // The same payload with the unused bits cleared.
                let canonicalLast = alphabet[index - index % divisor]
                let canonical = String(payload.dropLast()) + String(canonicalLast) + padding
                let expected = try #require(Data(base64Encoded: canonical))
                for encoded in [payload, payload + padding] {
                    try expectDecodedBytes(encoded, equalTo: expected)
                }
            }
        }

        try expectDecodedBytes("123", equalTo: Data([0xD7, 0x6D]))
    }

    @Test("Non-alphabet ASCII, Unicode, and malformed padding remain rejected")
    func invalidAlphabetAndPaddingAreRejected() throws {
        let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        for byte in UInt8.min ... 127 where !alphabet.contains(byte) && byte != 61 {
            let character = String(UnicodeScalar(byte))
            try expectRejectedBytes("AAA" + character)
        }
        for encoded in ["AAAé", "AAAＡ", "AAA🙂", "AAA\u{200D}", "A", "AA=", "AA===", "AA=A", "=AAA", "A=AA", "====", "AAAA="] {
            try expectRejectedBytes(encoded)
        }
    }

    private func expectDecodedBytes(_ encoded: String, equalTo expected: Data) throws {
        let json = try JSONEncoder().encode(["$bytes": encoded])
        #expect(try JSONDecoder().decode(Bytes.self, from: json).data == expected)
        let dynamic = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        guard case let .bytes(bytes) = dynamic else {
            Issue.record("Expected an exact $bytes object for \(encoded)")
            return
        }
        #expect(bytes.data == expected)
    }

    private func expectRejectedBytes(_ encoded: String) throws {
        let json = try JSONEncoder().encode(["$bytes": encoded])
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Bytes.self, from: json)
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        }
    }
}
