import Foundation
@testable import PetrelCore
import Testing

/// DAG-CBOR lane: the fast `hexDump()` must be byte-identical to the original implementation,
/// and the slice-based preflight scan must give the original outcome for every input.
@Suite("DAG-CBOR hexDump and single-copy preflight")
struct DAGCBORCopyAndHexDumpTests {
    private struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test("hexDump is byte-identical to the original for sizes 0...300 and large inputs")
    func hexDumpMatchesLegacy() {
        var rng = SplitMix(state: 0xDA6_CB0B)
        var sizes = Array(0 ... 300)
        sizes += [1023, 1024, 1025, 65_536 + 7]
        for size in sizes {
            let bytes = (0 ..< size).map { _ in UInt8.random(in: 0 ... 255, using: &rng) }
            let data = Data(bytes)
            #expect(Array(data.hexDump().utf8) == Array(data.legacyHexDump().utf8), "size \(size)")
        }
    }

    @Test("hexDump covers every byte value in every column")
    func hexDumpEveryByteEveryColumn() {
        for lead in 0 ..< 16 {
            let data = Data([UInt8](repeating: 0x41, count: lead) + (0 ... 255).map { UInt8($0) })
            #expect(data.hexDump() == data.legacyHexDump(), "lead \(lead)")
        }
    }

    @Test("hexDump of a re-based slice copy equals the original on the same bytes")
    func hexDumpSliceRebasedCopy() {
        let base = Data((0 ..< 100).map { UInt8($0) })
        let rebased = Data(base[37...])
        #expect(rebased.startIndex == 0)
        #expect(rebased.hexDump() == rebased.legacyHexDump())
    }

    /// Inputs spanning every preflight outcome (accept and each rejection kind).
    private static let preflightCorpus: [String] = [
        "a0", "a16161f5", "a2616101616102", "a2616201616102", "a161610100", "05",
        "a16161fb3ff8000000000000", "a16161f93c00", "a16178d82b4100", "a16178d82a6161",
        "a16178d82a4400010203", "a1016161", "bf616101ff", "a161619f0102ff", "a1616162c0af",
        "a162c0af01", "a16161f7", "1c", "a3616101", "a1616e1b8000000000000000",
        "a1616e1800", "a1616e190001", "a1616e1a00000001", "a1616e1b0000000000000001",
        "9b7fffffffffffffff", "bb7fffffffffffffff", "5b7fffffffffffffff00", "7b7fffffffffffffff00",
        "a2616102616101", "a26162016161", "81" + String(repeating: "81", count: 70) + "01",
        "a3616101616202626161f5",
    ]

    private static func bytes(_ hex: String) -> [UInt8] {
        var out: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            out.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        return out
    }

    private static func outcome(_ body: () throws -> Void) -> String {
        do {
            try body()
            return "ok"
        } catch {
            return "\(type(of: error)):\(error)"
        }
    }

    @Test("Slice preflight gives the Data preflight outcome at any start index", arguments: [false, true])
    func slicePreflightMatchesDataPreflight(allowTrailingBytes: Bool) {
        for hex in Self.preflightCorpus {
            let payload = Self.bytes(hex)
            let viaData = Self.outcome {
                try DAGCBOR.decodeCBORPreflight(Data(payload), allowTrailingBytes: allowTrailingBytes)
            }
            let viaSlice = Self.outcome {
                try DAGCBOR.decodeCBORPreflight(bytes: payload[...], allowTrailingBytes: allowTrailingBytes)
            }
            // Same payload behind a 3-byte prefix: the scan must start at the slice's startIndex.
            let framed = [0xFF, 0xFE, 0xFD] + payload
            let viaOffsetSlice = Self.outcome {
                try DAGCBOR.decodeCBORPreflight(bytes: framed[3...], allowTrailingBytes: allowTrailingBytes)
            }
            #expect(viaSlice == viaData, "\(hex)")
            #expect(viaOffsetSlice == viaData, "\(hex)")
        }
    }

    @Test("Empty input keeps the original error")
    func emptyPreflight() {
        #expect(throws: DAGCBORError.decodingFailed("Cannot decode empty data")) {
            try DAGCBOR.decodeCBORPreflight(Data())
        }
        #expect(throws: DAGCBORError.decodingFailed("Cannot decode empty data")) {
            try DAGCBOR.decodeCBORPreflight(bytes: [UInt8]()[...])
        }
        let framed: [UInt8] = [0xA0]
        #expect(throws: DAGCBORError.decodingFailed("Cannot decode empty data")) {
            try DAGCBOR.decodeCBORPreflight(bytes: framed[1...])
        }
    }
}
