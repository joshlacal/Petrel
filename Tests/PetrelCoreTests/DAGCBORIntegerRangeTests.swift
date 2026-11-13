import Foundation
import PetrelCore
import Testing

/// The data model's integer is a signed 64-bit value, so the encoder refuses
/// unsigned values above `Int64.max` instead of writing what no conforming
/// decoder accepts.
@Suite("DAG-CBOR: integer range")
struct DAGCBORIntegerRangeTests {
    @Test("unsigned values up to Int64.max encode; larger ones are refused")
    func unsignedRange() throws {
        let largest = try DAGCBOR.encodeValue(UInt64(Int64.max))
        #expect(largest == Data([0x1b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]))
        #expect(try DAGCBOR.encodeValue(Int64.max) == largest)
        #expect(try DAGCBOR.encodeValue(UInt(Int64.max)) == largest)

        for value in [UInt64(Int64.max) + 1, UInt64.max] {
            #expect(throws: DAGCBORError.self) { try DAGCBOR.encodeValue(value) }
            #expect(throws: DAGCBORError.self) { try DAGCBOR.encodeValue(UInt(value)) }
            #expect(throws: DAGCBORError.self) { try DAGCBOR.encodeValue(["n": value]) }
        }
    }
}
