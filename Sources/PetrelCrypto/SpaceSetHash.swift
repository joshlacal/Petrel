import CPetrelBLAKE3
import Crypto
import Foundation

/// Spaces LtHash: 1,024 little-endian 16-bit lanes, added modulo 2^16.
public struct SpaceSetHash: Sendable {
    private var state = Data(repeating: 0, count: 2048)

    public init() {}

    public mutating func add(path: String, cid: String) {
        let element = Data("\(path)/\(cid)".utf8)
        var hasher = petrel_blake3_hasher()
        petrel_blake3_hasher_init(&hasher)
        element.withUnsafeBytes { petrel_blake3_hasher_update(&hasher, $0.baseAddress, $0.count) }
        var expanded = [UInt8](repeating: 0, count: 2048)
        expanded.withUnsafeMutableBufferPointer { petrel_blake3_hasher_finalize(&hasher, $0.baseAddress, $0.count) }
        for offset in stride(from: 0, to: 2048, by: 2) {
            let existing = UInt16(state[offset]) | UInt16(state[offset + 1]) << 8
            let addition = UInt16(expanded[offset]) | UInt16(expanded[offset + 1]) << 8
            let result = existing &+ addition
            state[offset] = UInt8(truncatingIfNeeded: result)
            state[offset + 1] = UInt8(truncatingIfNeeded: result >> 8)
        }
    }

    public var digest: Data { Data(SHA256.hash(data: state)) }
}
