import Foundation

/// Fixed-width big-endian scalar arithmetic for the group orders of the two
/// AT Protocol curves.
///
/// This is the single home of the "low-S" rule: `s <= floor(n / 2)`. The half
/// order is *derived* from the group order by a one-bit right shift rather
/// than written out as a second literal, so the two can never disagree.
enum ECDSAScalar {
    static let byteCount = 32
    static let compactSignatureByteCount = 64

    /// Group order `n` of the curve as 32 big-endian bytes.
    static func order(of curve: ATProtoKeyCurve) -> [UInt8] {
        switch curve {
        case .p256: return p256Order
        case .k256: return k256Order
        }
    }

    /// `floor(n / 2)` as 32 big-endian bytes.
    static func halfOrder(of curve: ATProtoKeyCurve) -> [UInt8] {
        switch curve {
        case .p256: return p256HalfOrder
        case .k256: return k256HalfOrder
        }
    }

    /// NIST P-256 (secp256r1) group order, FIPS 186-4 D.1.2.3.
    private static let p256Order: [UInt8] = [
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
        0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
    ]

    /// secp256k1 group order, SEC 2 v2 section 2.4.1.
    private static let k256Order: [UInt8] = [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
        0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b,
        0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41,
    ]

    private static let p256HalfOrder = shiftedRightByOne(p256Order)
    private static let k256HalfOrder = shiftedRightByOne(k256Order)

    static func shiftedRightByOne(_ value: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: value.count)
        var carry: UInt8 = 0
        for index in value.indices {
            result[index] = (value[index] >> 1) | (carry << 7)
            carry = value[index] & 1
        }
        return result
    }

    static func compare(_ lhs: some Collection<UInt8>, _ rhs: some Collection<UInt8>) -> ComparisonResult {
        precondition(lhs.count == rhs.count)
        for (left, right) in zip(lhs, rhs) {
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    /// `0 < scalar < n`.
    static func isValid(_ scalar: some Collection<UInt8>, curve: ATProtoKeyCurve) -> Bool {
        scalar.count == byteCount
            && scalar.contains(where: { $0 != 0 })
            && compare(scalar, order(of: curve)) == .orderedAscending
    }

    /// `scalar <= floor(n / 2)`.
    static func isLow(_ scalar: some Collection<UInt8>, curve: ATProtoKeyCurve) -> Bool {
        scalar.count == byteCount && compare(scalar, halfOrder(of: curve)) != .orderedDescending
    }

    /// `n - scalar`. The caller has already proven `0 < scalar < n`.
    static func negated(_ scalar: some Collection<UInt8>, curve: ATProtoKeyCurve) -> [UInt8] {
        let minuend = order(of: curve)
        let subtrahend = Array(scalar)
        precondition(subtrahend.count == byteCount)
        var result = [UInt8](repeating: 0, count: byteCount)
        var borrow = 0
        for index in stride(from: byteCount - 1, through: 0, by: -1) {
            var value = Int(minuend[index]) - Int(subtrahend[index]) - borrow
            if value < 0 {
                value += 256
                borrow = 1
            } else {
                borrow = 0
            }
            result[index] = UInt8(value)
        }
        precondition(borrow == 0)
        return result
    }

    /// Whether `compact` is a structurally valid 64-byte `r || s` pair for
    /// the curve: both scalars in `1 ..< n`.
    static func isStructurallyValid(compact: Data, curve: ATProtoKeyCurve) -> Bool {
        guard compact.count == compactSignatureByteCount else { return false }
        return isValid(compact.prefix(byteCount), curve: curve)
            && isValid(compact.suffix(byteCount), curve: curve)
    }

    /// Folds a structurally valid compact signature to its low-S twin.
    static func lowSForm(ofStructurallyValid compact: Data, curve: ATProtoKeyCurve) -> Data {
        let s = compact.suffix(byteCount)
        guard !isLow(s, curve: curve) else { return compact }
        return Data(compact.prefix(byteCount)) + Data(negated(s, curve: curve))
    }
}
