// File: Base32Scanner.swift
// Description: Byte-level base32 (RFC 4648, no padding) encode/decode and the CID
//              string fast path. Fast paths only ever accept; every input they do
//              not fully accept is handed to the original implementation, which
//              decides and reports exactly as before.
//
// Deployment floor is iOS 18 / macOS 15 / tvOS 18: `String.utf8.span` and
// `InlineArray` need iOS/macOS 26, so input bytes come from
// `utf8.withContiguousStorageIfAvailable` (with a native copy for the rare bridged
// string) and are read through a back-deployed `Span<UInt8>` when the compiler is
// 6.2+; the decode buffer is a stack `withUnsafeTemporaryAllocation`, and output is
// written with `String(unsafeUninitializedCapacity:initializingUTF8With:)` (iOS 14+).

import Foundation

#if compiler(>=6.2)
    typealias Base32Bytes = Span<UInt8>
#else
    typealias Base32Bytes = UnsafeBufferPointer<UInt8>
#endif

enum Base32 {
    // MARK: Byte access

    /// The string's UTF-8 bytes without copying when contiguous, else a native copy.
    @inline(__always)
    static func withUTF8<R>(_ s: String, _ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        if let result = s.utf8.withContiguousStorageIfAvailable(body) {
            return result
        }
        var copy = s
        return copy.withUTF8(body)
    }

    @inline(__always)
    static func withBytes<R>(_ s: String, _ body: (Base32Bytes) -> R) -> R {
        withUTF8(s) { buffer in
            #if compiler(>=6.2)
                let bytes = unsafe Base32Bytes(_unsafeElements: buffer)
            #else
                let bytes = buffer
            #endif
            return body(bytes)
        }
    }

    // MARK: Alphabet

    /// Number of base32 symbols for `byteCount` bytes without padding: ceil(8n / 5).
    @inline(__always)
    static func encodedCount(_ byteCount: Int) -> Int {
        (byteCount * 8 + 4) / 5
    }

    /// Lowercase symbol for a 5-bit value: "a"..."z" for 0...25, "2"..."7" for 26...31.
    @inline(__always)
    static func symbol(_ value: UInt32) -> UInt8 {
        let v = UInt8(truncatingIfNeeded: value)
        return v < 26 ? v &+ 0x61 : v &+ 0x18
    }

    /// 5-bit value of an ASCII base32 symbol in either case, or 0xFF. Folding with
    /// `| 0x20` maps exactly A-Z and a-z onto a-z, so no other byte can alias a
    /// letter. Bytes >= 0x80 are always 0xFF.
    @inline(__always)
    static func value(_ byte: UInt8) -> UInt8 {
        let folded = byte | 0x20
        if folded &- 0x61 < 26 { return folded &- 0x61 }
        if byte &- 0x32 < 6 { return byte &- 0x32 &+ 26 }
        return 0xFF
    }

    // MARK: Encode

    /// The legacy bit accumulator, emitting into a preallocated UTF-8 buffer.
    struct Encoder {
        var value: UInt32 = 0
        var bits = 0

        @inline(__always)
        mutating func append(_ byte: UInt8, into output: UnsafeMutableBufferPointer<UInt8>, at written: inout Int) {
            value = (value << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                output[written] = Base32.symbol((value >> bits) & 0x1F)
                written += 1
            }
        }

        @inline(__always)
        mutating func finish(into output: UnsafeMutableBufferPointer<UInt8>, at written: inout Int) {
            if bits > 0 {
                output[written] = Base32.symbol((value << (5 - bits)) & 0x1F)
                written += 1
            }
        }
    }

    // MARK: Decode

    /// ASCII-only decode of 1...200 base32 symbols (either case). `nil` means "not
    /// accepted here": the caller runs the legacy decoder.
    static func fastDecode(_ string: String) -> Data? {
        withBytes(string) { u -> Data? in
            let n = u.count
            guard n >= 1, n <= 200 else { return nil }
            var result = Data(count: n * 5 / 8)
            let complete = result.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) -> Bool in
                var bits = 0
                var value: UInt32 = 0
                var written = 0
                var i = 0
                while i < n {
                    let symbolValue = Base32.value(u[i])
                    if symbolValue == 0xFF { return false }
                    value = (value << 5) | UInt32(symbolValue)
                    bits += 5
                    if bits >= 8 {
                        bits -= 8
                        raw[written] = UInt8((value >> bits) & 0xFF)
                        written += 1
                    }
                    i += 1
                }
                return true
            }
            return complete ? result : nil
        }
    }
}

extension CID {
    /// Accept-only CID string parse. Returns `nil` unless the input is `b` followed by
    /// 9...99 ASCII base32 symbols (either case) that decode to a CID the legacy
    /// `CID(bytes:)` accepts, in which case the value is identical to the legacy one
    /// (same bit accumulator, same structural checks, same digest bytes).
    static func fastParse(_ cidString: String) -> CID? {
        Base32.withBytes(cidString) { u -> CID? in
            let n = u.count
            guard n >= 10, n <= 100, u[0] == 0x62 else { return nil }
            // 99 symbols decode to at most 61 bytes.
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 64) { out -> CID? in
                var bits = 0
                var value: UInt32 = 0
                var written = 0
                var i = 1
                while i < n {
                    let symbolValue = Base32.value(u[i])
                    if symbolValue == 0xFF { return nil }
                    value = (value << 5) | UInt32(symbolValue)
                    bits += 5
                    if bits >= 8 {
                        bits -= 8
                        out[written] = UInt8((value >> bits) & 0xFF)
                        written += 1
                    }
                    i += 1
                }
                guard written >= 4, out[0] == CID.version, let codec = CIDCodec(rawValue: out[1]) else {
                    return nil
                }
                let hashLength = out[3]
                guard hashLength > 0, hashLength <= 64, written == 4 + Int(hashLength) else { return nil }
                let digest = Data(bytes: out.baseAddress! + 4, count: written - 4)
                return CID(codec: codec, multihash: Multihash(algorithm: out[2], length: hashLength, digest: digest))
            }
        }
    }
}

// MARK: - SPI for equivalence harnesses

/// Read-only probes into the CID/base32 fast paths for equivalence and coverage
/// harnesses. Pure functions; no state or counters on the decode path.
@_spi(LeafScanners)
public enum CIDScannerProbe {
    /// Whether `CID.parse` accepts this input on the fast path.
    public static func parsesOnFastPath(_ cidString: String) -> Bool {
        CID.fastParse(cidString) != nil
    }

    /// Whether `base32Decode` accepts this input on the fast path.
    public static func base32DecodesOnFastPath(_ string: String) -> Bool {
        Base32.fastDecode(string) != nil
    }

    /// The original CID parser, for differential tests.
    public static func legacyParse(_ cidString: String) throws -> CID {
        try CID.legacyParse(cidString)
    }

    /// The original base32 decoder, for differential tests.
    public static func legacyBase32Decode(_ string: String) -> Data? {
        PetrelCore.legacyBase32Decode(string)
    }

    /// The original base32 encoder, for differential tests.
    public static func legacyBase32Encode(_ data: Data) -> String {
        PetrelCore.legacyBase32Encode(data)
    }
}
