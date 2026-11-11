import Crypto
import Foundation

/// How strictly a signature's *encoding* is checked before the ECDSA
/// equation is evaluated.
///
/// AT Protocol requires the "low-S" variant and the 64-byte compact encoding
/// for signatures over CBOR objects (repository commits, labels, PLC
/// operations), and says verifiers MUST reject anything else. The same
/// section exempts JWTs: "This does not impact JWT signature validation, for
/// example service auth tokens or OAuth tokens."
///
/// ``strict`` is the default everywhere. Pass ``jwt`` when verifying a JOSE
/// signature, and ``allowMalleable`` only for parity with the TypeScript
/// reference's `allowMalleableSig` option.
public struct ATProtoSignatureVerificationOptions: Sendable, Hashable {
    /// Accept `(r, n - s)` as well as `(r, s)`.
    public var allowHighS: Bool
    /// Accept an ASN.1 DER `ECDSA-Sig-Value` as well as 64-byte `r || s`.
    public var allowDER: Bool

    /// Creates a custom policy. Prefer the named presets.
    public init(allowHighS: Bool, allowDER: Bool) {
        self.allowHighS = allowHighS
        self.allowDER = allowDER
    }

    /// 64-byte compact encoding, low-S only. Required for commits, labels,
    /// PLC operations and every other signature over a CBOR object.
    public static let strict = ATProtoSignatureVerificationOptions(allowHighS: false, allowDER: false)

    /// 64-byte compact encoding (RFC 7518 section 3.4), either S value. Use for
    /// service-auth and OAuth JWTs, whose signers (WebCrypto, Secure
    /// Enclave, HSMs) do not normalize S.
    public static let jwt = ATProtoSignatureVerificationOptions(allowHighS: true, allowDER: false)

    /// Either S value and either encoding. Matches
    /// `verifySignature(..., { allowMalleableSig: true })` in
    /// `@atproto/crypto`.
    public static let allowMalleable = ATProtoSignatureVerificationOptions(allowHighS: true, allowDER: true)
}

/// Encoding rules for AT Protocol ECDSA signatures, for both curves.
///
/// A signature on the wire is always 64 bytes: `r || s`, each a 32-byte
/// big-endian integer, with `s <= floor(n / 2)` ("low-S").
public enum ATProtoSignature {
    /// Length of the compact `r || s` encoding.
    public static let compactByteCount = ECDSAScalar.compactSignatureByteCount

    /// Whether `signature` is exactly 64 bytes with `0 < r < n` and
    /// `0 < s <= floor(n / 2)`. This is a structural check only; it does not
    /// verify the signature against a key.
    public static func isCanonical(_ signature: Data, curve: ATProtoKeyCurve) -> Bool {
        ECDSAScalar.isStructurallyValid(compact: signature, curve: curve)
            && ECDSAScalar.isLow(signature.suffix(ECDSAScalar.byteCount), curve: curve)
    }

    /// Whether the S half of a 64-byte signature is at most `floor(n / 2)`.
    /// Returns `false` for input of any other length.
    public static func isLowS(_ signature: Data, curve: ATProtoKeyCurve) -> Bool {
        signature.count == compactByteCount
            && ECDSAScalar.isLow(signature.suffix(ECDSAScalar.byteCount), curve: curve)
    }

    /// Converts a signature a *trusted local signer* produced into the wire
    /// form: 64-byte compact, low-S.
    ///
    /// Accepts either 64-byte `r || s` or ASN.1 DER — hardware and cloud
    /// signers commonly return DER and do not normalize S. Never call this on
    /// a signature received from the network: folding S on an untrusted
    /// input would defeat the malleability check. Use
    /// ``ATProtoPublicKey/isValidSignature(_:for:options:)`` for those.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if the input is neither
    ///   encoding or a scalar is out of range.
    public static func canonicalize(_ signature: Data, curve: ATProtoKeyCurve) throws -> Data {
        let compact: Data
        if signature.count == compactByteCount {
            compact = signature
        } else {
            compact = try compactRepresentation(fromDER: signature, curve: curve)
        }
        guard ECDSAScalar.isStructurallyValid(compact: compact, curve: curve) else {
            throw PetrelCryptoError.malformed("\(curve.jwtAlgorithm) signature scalar is out of range")
        }
        return ECDSAScalar.lowSForm(ofStructurallyValid: compact, curve: curve)
    }

    /// Strictly parses an ASN.1 DER `ECDSA-Sig-Value` into 64-byte `r || s`
    /// without changing S.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if the DER is invalid.
    public static func compactRepresentation(fromDER der: Data, curve: ATProtoKeyCurve) throws -> Data {
        switch curve {
        case .p256:
            do {
                return try P256.Signing.ECDSASignature(derRepresentation: der).rawRepresentation
            } catch {
                throw PetrelCryptoError.malformed("P-256 DER signature is malformed")
            }
        case .k256:
            return try K256Backend.compactSignature(fromDER: der)
        }
    }

    /// The compact candidates `signature` may denote under `options`, DER
    /// reading first (as the TypeScript reference does).
    static func compactCandidates(
        _ signature: Data,
        curve: ATProtoKeyCurve,
        options: ATProtoSignatureVerificationOptions
    ) -> [Data] {
        var candidates: [Data] = []
        if options.allowDER, signature.first == 0x30,
           let fromDER = try? compactRepresentation(fromDER: signature, curve: curve) {
            candidates.append(fromDER)
        }
        if signature.count == compactByteCount {
            candidates.append(signature)
        }
        return candidates
    }
}
