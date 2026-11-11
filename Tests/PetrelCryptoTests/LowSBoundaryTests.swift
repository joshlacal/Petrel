import Crypto
import Foundation
import PetrelCrypto
import secp256k1
import Testing

/// Pins the low-S threshold `floor(n / 2)` for both curves **without**
/// reading any constant from the implementation.
///
/// The group order `n` is taken from the standards as a hex string, proved
/// to be the real order by asking each cryptographic library (`n - 1` is a
/// valid private scalar, `n` is not), and then halved here with separate
/// 64-bit limb arithmetic. A wrong byte in the implementation's threshold —
/// as happened once for P-256 — cannot hide behind a test that copies it.
@Suite("Low-S boundary is exactly floor(n / 2)")
struct LowSBoundaryTests {
    struct Curve: Sendable, CustomTestStringConvertible {
        let curve: ATProtoKeyCurve
        /// Group order from the standard, big-endian hex.
        let orderHex: String
        /// `floor(n / 2)` as published, used only as a cross-check on this
        /// file's own arithmetic.
        let publishedHalfOrderHex: String

        var testDescription: String { curve.rawValue }
    }

    static let curves: [Curve] = [
        // FIPS 186-4 D.1.2.3, "n".
        Curve(
            curve: .p256,
            orderHex: "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
            publishedHalfOrderHex: "7fffffff800000007fffffffffffffffde737d56d38bcf4279dce5617e3192a8"
        ),
        // SEC 2 v2 2.4.1, "n".
        Curve(
            curve: .k256,
            orderHex: "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
            publishedHalfOrderHex: "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0"
        ),
    ]

    @Test("The order used by this test is the library's group order", arguments: curves)
    func orderLiteralIsTheRealGroupOrder(_ parameters: Curve) throws {
        let order = try TestUInt256(hex: parameters.orderHex)
        let orderMinusOne = order.subtracting(.one)

        switch parameters.curve {
        case .p256:
            _ = try P256.Signing.PrivateKey(rawRepresentation: orderMinusOne.data)
            #expect(throws: (any Error).self) {
                _ = try P256.Signing.PrivateKey(rawRepresentation: order.data)
            }
        case .k256:
            _ = try secp256k1.Signing.PrivateKey(dataRepresentation: orderMinusOne.data)
            #expect(throws: (any Error).self) {
                _ = try secp256k1.Signing.PrivateKey(dataRepresentation: order.data)
            }
        }
    }

    @Test("Independent arithmetic: 2 * half + 1 == n", arguments: curves)
    func halfOrderArithmetic(_ parameters: Curve) throws {
        let order = try TestUInt256(hex: parameters.orderHex)
        let half = order.shiftedRightByOne()

        #expect(half.adding(half).adding(.one) == order)
        #expect(half.hex == parameters.publishedHalfOrderHex)
    }

    @Test("s == n/2 is low-S; s == n/2 + 1 is not", arguments: curves)
    func boundaryIsExact(_ parameters: Curve) throws {
        let curve = parameters.curve
        let order = try TestUInt256(hex: parameters.orderHex)
        let half = order.shiftedRightByOne()
        let halfPlusOne = half.adding(.one)
        let r = TestUInt256.one.data

        // Accepted side of the boundary.
        #expect(ATProtoSignature.isLowS(r + half.data, curve: curve))
        #expect(ATProtoSignature.isCanonical(r + half.data, curve: curve))
        #expect(ATProtoSignature.isCanonical(r + TestUInt256.one.data, curve: curve))
        #expect(ATProtoSignature.isCanonical(order.subtracting(.one).data + half.data, curve: curve))

        // Rejected side.
        #expect(!ATProtoSignature.isLowS(r + halfPlusOne.data, curve: curve))
        #expect(!ATProtoSignature.isCanonical(r + halfPlusOne.data, curve: curve))
        #expect(!ATProtoSignature.isCanonical(r + order.subtracting(.one).data, curve: curve))

        // Out-of-range scalars are never canonical.
        let zero = Data(repeating: 0, count: 32)
        #expect(!ATProtoSignature.isCanonical(zero + half.data, curve: curve))
        #expect(!ATProtoSignature.isCanonical(r + zero, curve: curve))
        #expect(!ATProtoSignature.isCanonical(order.data + half.data, curve: curve))
        #expect(!ATProtoSignature.isCanonical(r + order.data, curve: curve))
        #expect(!ATProtoSignature.isCanonical(Data(repeating: 0xff, count: 32) + half.data, curve: curve))

        // Folding: n - (n/2 + 1) == n/2, and n/2 itself is left alone.
        #expect(try ATProtoSignature.canonicalize(r + halfPlusOne.data, curve: curve) == r + half.data)
        #expect(try ATProtoSignature.canonicalize(r + half.data, curve: curve) == r + half.data)
        #expect(try ATProtoSignature.canonicalize(r + order.subtracting(.one).data, curve: curve) == r + TestUInt256.one.data)
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoSignature.canonicalize(r + order.data, curve: curve)
        }
        #expect(throws: PetrelCryptoError.self) {
            _ = try ATProtoSignature.canonicalize(r + zero, curve: curve)
        }
    }

    @Test("P256WireSignature uses the same exact boundary")
    func p256WireSignatureBoundary() throws {
        let parameters = Self.curves[0]
        let order = try TestUInt256(hex: parameters.orderHex)
        let half = order.shiftedRightByOne()
        let halfPlusOne = half.adding(.one)
        let r = TestUInt256.one.data

        #expect(P256WireSignature.isCanonicalLowS(r + half.data))
        _ = try P256WireSignature.decodeCanonical(r + half.data)
        #expect(try P256WireSignature.canonicalize(r + half.data) == r + half.data)

        #expect(!P256WireSignature.isCanonicalLowS(r + halfPlusOne.data))
        #expect(throws: PetrelCryptoError.self) {
            _ = try P256WireSignature.decodeCanonical(r + halfPlusOne.data)
        }
        // A signer must never turn a low-S value into a high-S one: the
        // value just above the boundary folds down onto the boundary.
        #expect(try P256WireSignature.canonicalize(r + halfPlusOne.data) == r + half.data)
        // The lax decoder takes both sides.
        _ = try P256WireSignature.decodeMalleabilityTolerant(r + halfPlusOne.data)
    }

    @Test("The K-256 canonical-signature check uses the same exact boundary")
    func k256CanonicalBoundary() throws {
        let parameters = Self.curves[1]
        let order = try TestUInt256(hex: parameters.orderHex)
        let half = order.shiftedRightByOne()
        let r = TestUInt256.one.data

        #expect(ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(r + half.data))
        #expect(!ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(r + half.adding(.one).data))
        #expect(!ATProtoJWTVerificationKey.isCanonicalSecp256k1Signature(order.data + half.data))
    }

    @Test("Exactly one of (r, s) and (r, n - s) is low-S, and signers always emit it", arguments: curves)
    func signersEmitTheLowTwin(_ parameters: Curve) async throws {
        let curve = parameters.curve
        let order = try TestUInt256(hex: parameters.orderHex)
        let keypair = ATProtoCrypto.generateKeypair(curve: curve)

        for index in 0 ..< 64 {
            let message = Data("low-S message \(index)".utf8)
            let signature = try await keypair.sign(message)
            #expect(signature.count == 64)
            #expect(ATProtoSignature.isCanonical(signature, curve: curve))

            // Build the malleated twin with this file's arithmetic.
            let s = try TestUInt256(data: Data(signature.suffix(32)))
            let twin = Data(signature.prefix(32)) + order.subtracting(s).data
            #expect(!ATProtoSignature.isLowS(twin, curve: curve))

            #expect(keypair.publicKey.isValidSignature(signature, for: message))
            #expect(!keypair.publicKey.isValidSignature(twin, for: message))
            #expect(keypair.publicKey.isValidSignature(twin, for: message, options: .jwt))
            #expect(try ATProtoSignature.canonicalize(twin, curve: curve) == signature)
        }
    }
}

/// Minimal 256-bit unsigned integer on four 64-bit limbs, most significant
/// first. Deliberately a different representation from the implementation's
/// byte arrays.
struct TestUInt256: Equatable, Sendable {
    var limbs: [UInt64]

    static let one = TestUInt256(limbs: [0, 0, 0, 1])

    init(limbs: [UInt64]) {
        precondition(limbs.count == 4)
        self.limbs = limbs
    }

    init(hex: String) throws {
        guard hex.count == 64 else { throw PetrelCryptoError.malformed("expected 64 hex characters") }
        var limbs: [UInt64] = []
        var remaining = Substring(hex)
        while !remaining.isEmpty {
            guard let limb = UInt64(remaining.prefix(16), radix: 16) else {
                throw PetrelCryptoError.malformed("not hex")
            }
            limbs.append(limb)
            remaining = remaining.dropFirst(16)
        }
        self.init(limbs: limbs)
    }

    init(data: Data) throws {
        guard data.count == 32 else { throw PetrelCryptoError.malformed("expected 32 bytes") }
        let bytes = Array(data)
        self.init(limbs: (0 ..< 4).map { limb in
            bytes[limb * 8 ..< limb * 8 + 8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        })
    }

    var hex: String {
        limbs.map { limb in
            let digits = String(limb, radix: 16)
            return String(repeating: "0", count: 16 - digits.count) + digits
        }.joined()
    }

    var data: Data {
        Data(limbs.flatMap { limb in (0 ..< 8).map { UInt8(truncatingIfNeeded: limb >> (56 - 8 * $0)) } })
    }

    func shiftedRightByOne() -> TestUInt256 {
        var result = limbs
        for index in stride(from: 3, through: 0, by: -1) {
            let carryIn: UInt64 = index > 0 ? (limbs[index - 1] & 1) << 63 : 0
            result[index] = limbs[index] >> 1 | carryIn
        }
        return TestUInt256(limbs: result)
    }

    func adding(_ other: TestUInt256) -> TestUInt256 {
        var result = limbs
        var carry = false
        for index in stride(from: 3, through: 0, by: -1) {
            let (partial, overflowA) = limbs[index].addingReportingOverflow(other.limbs[index])
            let (sum, overflowB) = partial.addingReportingOverflow(carry ? 1 : 0)
            result[index] = sum
            carry = overflowA || overflowB
        }
        precondition(!carry, "256-bit overflow")
        return TestUInt256(limbs: result)
    }

    func subtracting(_ other: TestUInt256) -> TestUInt256 {
        var result = limbs
        var borrow = false
        for index in stride(from: 3, through: 0, by: -1) {
            let (partial, overflowA) = limbs[index].subtractingReportingOverflow(other.limbs[index])
            let (difference, overflowB) = partial.subtractingReportingOverflow(borrow ? 1 : 0)
            result[index] = difference
            borrow = overflowA || overflowB
        }
        precondition(!borrow, "256-bit underflow")
        return TestUInt256(limbs: result)
    }
}
