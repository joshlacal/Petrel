import Foundation
@testable import Petrel
import Testing

/// DAG-CBOR map keys are byte strings, but Swift `String` equality (and so `Dictionary`
/// and SwiftCBOR's `[CBOR: CBOR]`) compares by Unicode canonical equivalence. A map whose
/// keys are the NFC and NFD spellings of "é" is byte-distinct and correctly ordered, yet
/// decoding it into a dictionary used to keep one value and silently drop the other.
@Suite("DAG-CBOR: canonically equivalent map keys")
struct DAGCBORCanonicallyEquivalentKeyTests {
    /// {"é" (NFC, C3 A9): 1, "é" (NFD, 65 CC 81): 2}, keys in DAG-CBOR order (length first).
    static let equivalentKeys = Data([0xA2, 0x62, 0xC3, 0xA9, 0x01, 0x63, 0x65, 0xCC, 0x81, 0x02])

    /// {"é" (NFC): 1, "f": 2}: byte-distinct keys that are not equivalent.
    static let distinctKeys = Data([0xA2, 0x61, 0x66, 0x02, 0x62, 0xC3, 0xA9, 0x01])

    @Test("preflight rejects keys that differ in bytes but compare equal as Swift strings")
    func preflightRejectsEquivalentKeys() throws {
        #expect(throws: DAGCBORError.self) {
            try DAGCBOR.decodeCBORPreflight(Self.equivalentKeys)
        }
        try DAGCBOR.decodeCBORPreflight(Self.distinctKeys)
    }
}
