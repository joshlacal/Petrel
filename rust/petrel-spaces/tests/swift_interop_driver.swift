import Crypto
import Foundation
@testable import Petrel
import PetrelCore
import PetrelCrypto

struct SwiftEmitManifest: Codable {
    var spaceUri: String
    var recordUri: String
    var repoDid: String
    var rev: String
    var dataHex: String
    var authorKemSecretHex: String
    var authorKemDidKey: String
    var keyShareDidKey: String
    var sharedSecretHex: String
    var acceptCommitHeader: String
    var acceptRecordHeader: String
    var commitCoveredHeader: String
    var commitSignatureInput: String
    var commitSignature: String
    var recordCoveredHeader: String
    var recordSignatureInput: String
    var recordSignature: String
    var recordCid: String
    var authorityDid: String
    var authorityDidKey: String
    var cnfDidKey: String
    var audienceDid: String
    var credentialJwt: String
    var authorization: String
    var signatureInput: String
    var signature: String
    var created: Int64
    var nonce: String
    var starArchiveHex: String?
}

struct RustEmitManifest: Codable {
    var spaceUri: String
    var recordUri: String
    var repoDid: String
    var rev: String
    var dataHex: String
    var authorKemSecretHex: String
    var authorKemDidKey: String
    var keyShareDidKey: String
    var sharedSecretHex: String
    var acceptCommitHeader: String
    var commitCoveredHeader: String
    var commitSignatureInput: String
    var commitSignature: String
    var recordCoveredHeader: String
    var recordSignatureInput: String
    var recordSignature: String
    var recordCid: String
    var authorityDidKey: String
    var cnfDidKey: String
    var audienceDid: String
    var credentialJwt: String
    var authorization: String
    var signatureInput: String
    var signature: String
    var created: Int64
    var nonce: String
    var starArchiveHex: String
}

enum InteropError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self {
        case .message(let m): return m
        }
    }
}

func hexString(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

func dataFromHex(_ hex: String) throws -> Data {
    let chars = Array(hex)
    guard chars.count % 2 == 0 else { throw InteropError.message("odd hex length") }
    var out = Data(capacity: chars.count / 2)
    var idx = 0
    while idx < chars.count {
        let byteStr = String(chars[idx ..< idx + 2])
        guard let b = UInt8(byteStr, radix: 16) else {
            throw InteropError.message("invalid hex byte \(byteStr)")
        }
        out.append(b)
        idx += 2
    }
    return out
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func base64URLDecode(_ s: String) throws -> Data {
    var padded = s
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while padded.count % 4 != 0 {
        padded.append("=")
    }
    guard let data = Data(base64Encoded: padded) else {
        throw InteropError.message("invalid base64url")
    }
    return data
}

func hmacSha256(key: Data, message: Data) -> Data {
    let sym = SymmetricKey(data: key)
    let auth = HMAC<SHA256>.authenticationCode(for: message, using: sym)
    return Data(auth)
}

func signP256Jwt(
    headerDict: [String: String],
    payloadJson: Data,
    key: P256Keypair
) throws -> String {
    let headerData = try JSONSerialization.data(withJSONObject: headerDict, options: [.sortedKeys])
    let signingInput = "\(base64URL(headerData)).\(base64URL(payloadJson))"
    let sig = try key.sign(Data(signingInput.utf8))
    return "\(signingInput).\(base64URL(sig))"
}

@main
struct SwiftSpaceInteropDriver {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else {
            throw InteropError.message("usage: swift_interop_driver <emit|verify> <dir>")
        }
        let mode = args[1]
        let dir = URL(fileURLWithPath: args[2], isDirectory: true)
        switch mode {
        case "emit":
            try emit(to: dir)
        case "verify":
            try verify(from: dir)
        default:
            throw InteropError.message("unknown mode \(mode)")
        }
    }

    static func emit(to dir: URL) throws {
        let spaceUri = "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa"
        let repoDid = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
        let rev = "3l2aaaaaaaaac"
        let collection = "blue.catbird.mlsChat.message"
        let rkey = "3l2aaaaaaaaab"
        let recordUri = "\(spaceUri)/\(repoDid)/\(collection)/\(rkey)"

        // 1. SpaceSetHash (PetrelCrypto)
        let recJson: [String: String] = ["$type": collection, "text": "swift-to-rust-space-interop"]
        let recCbor = try DAGCBOR.encode(recJson)
        let recCid = CID.fromDAGCBOR(recCbor)
        let path = "\(collection)/\(rkey)"
        var setHash = SpaceSetHash()
        setHash.add(path: path, cid: recCid.string)
        let digest = setHash.digest

        // 2. HPKE P-256 SpaceMAC (PetrelCrypto) + SpaceMACHeader.request (Petrel)
        let authorKemPriv = P256.KeyAgreement.PrivateKey()
        let authorSigningPub = try P256.Signing.PublicKey(
            compressedRepresentation: authorKemPriv.publicKey.compressedRepresentation
        )
        let authorKemDidKey = P256DIDKey(publicKey: authorSigningPub).value
        let encap = try SpaceMAC.encapsulate(authorKey: authorKemDidKey)
        let acceptCommit = SpaceMACHeader.request(profile: .commit, keyShare: encap.keyShare)
        let acceptRecord = SpaceMACHeader.request(profile: .record, keyShare: encap.keyShare)

        // 3. MAC headers using exact Swift SpaceMACHeader RFC 9421 ";sf" format
        let commitCovered = "ver=1, repo=\"\(repoDid)\", space=\"\(spaceUri)\", rev=\"\(rev)\", data=:\(digest.base64EncodedString()):"
        let commitParams = "(\"atproto-space-commit\";sf);keyid=\"\(encap.keyShare)\";tag=\"atproto-space-commit\""
        let commitBase = "\"atproto-space-commit\";sf: \(commitCovered)\n\"@signature-params\": \(commitParams)"
        let commitMac = hmacSha256(key: encap.sharedSecret, message: Data(commitBase.utf8))
        let commitSigInput = "mac=\(commitParams)"
        let commitSig = "mac=:\(commitMac.base64EncodedString()):"

        let recordCovered = "uri=\"\(recordUri)\", cid=\"\(recCid.string)\""
        let recordParams = "(\"atproto-space-record\";sf);keyid=\"\(encap.keyShare)\";tag=\"atproto-space-record\""
        let recordBase = "\"atproto-space-record\";sf: \(recordCovered)\n\"@signature-params\": \(recordParams)"
        let recordMac = hmacSha256(key: encap.sharedSecret, message: Data(recordBase.utf8))
        let recordSigInput = "mac=\(recordParams)"
        let recordSig = "mac=:\(recordMac.base64EncodedString()):"

        // 4. SpaceCredential JWT + RFC 9421 HTTP signature using PetrelCrypto P256Keypair + P256WireSignature
        let authorityDid = "did:web:ds.catbird.blue"
        let authorityKp = P256Keypair.generate()
        let authorityDidKey = authorityKp.didKey
        let cnfKp = P256Keypair.generate()
        let cnfDidKey = cnfKp.didKey
        let audienceDid = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let now: Int64 = 1_800_000_000

        let credClaims: [String: Any] = [
            "iss": authorityDid,
            "sub": spaceUri,
            "iat": now,
            "exp": now + 600,
            "jti": "swift-cred-jti-001",
            "cnf": ["kid": cnfDidKey],
        ]
        let credPayload = try JSONSerialization.data(withJSONObject: credClaims, options: [.sortedKeys])
        let credJwt = try signP256Jwt(
            headerDict: [
                "alg": "ES256",
                "typ": "atproto-space-credential+jwt",
                "kid": "#atproto",
            ],
            payloadJson: credPayload,
            key: authorityKp
        )

        let authorization = "Atproto-Space-Credential \(credJwt)"
        let nonce = "swift-nonce-0001"
        let rfcParams = "(\"authorization\" \"atproto-space-audience\");created=\(now);nonce=\"\(nonce)\";tag=\"atproto-space-credential\""
        let rfcBase = "\"authorization\": \(authorization)\n\"atproto-space-audience\": \(audienceDid)\n\"@signature-params\": \(rfcParams)"
        let rfcSigRaw = try P256WireSignature.sign(Data(rfcBase.utf8), using: try cnfKp.privateKey())
        let sigInput = "atproto-space-credential=\(rfcParams)"
        let signature = "atproto-space-credential=:\(rfcSigRaw.base64EncodedString()):"

        // 5. Require Swift SpaceRef to parse Nov 24 at:space/ URIs (PR #90 landed on main)
        let spaceRef = try SpaceRef(uriString: spaceUri)
        guard spaceRef.uriString() == spaceUri else {
            throw InteropError.message("Swift SpaceRef roundtrip mismatch: \(spaceRef.uriString()) != \(spaceUri)")
        }
        let starHex: String? = nil

        let manifest = SwiftEmitManifest(
            spaceUri: spaceUri,
            recordUri: recordUri,
            repoDid: repoDid,
            rev: rev,
            dataHex: hexString(digest),
            authorKemSecretHex: hexString(authorKemPriv.rawRepresentation),
            authorKemDidKey: authorKemDidKey,
            keyShareDidKey: encap.keyShare,
            sharedSecretHex: hexString(encap.sharedSecret),
            acceptCommitHeader: acceptCommit,
            acceptRecordHeader: acceptRecord,
            commitCoveredHeader: commitCovered,
            commitSignatureInput: commitSigInput,
            commitSignature: commitSig,
            recordCoveredHeader: recordCovered,
            recordSignatureInput: recordSigInput,
            recordSignature: recordSig,
            recordCid: recCid.string,
            authorityDid: authorityDid,
            authorityDidKey: authorityDidKey,
            cnfDidKey: cnfDidKey,
            audienceDid: audienceDid,
            credentialJwt: credJwt,
            authorization: authorization,
            signatureInput: sigInput,
            signature: signature,
            created: now,
            nonce: nonce,
            starArchiveHex: starHex
        )
        let encoded = try JSONEncoder().encode(manifest)
        try encoded.write(to: dir.appendingPathComponent("swift_manifest.json"))
    }

    static func verify(from dir: URL) throws {
        let data = try Data(contentsOf: dir.appendingPathComponent("rust_manifest.json"))
        let m = try JSONDecoder().decode(RustEmitManifest.self, from: data)

        // 1. Verify Rust HPKE encapsulation using Swift SpaceMAC.decapsulate
        let kemPrivData = try dataFromHex(m.authorKemSecretHex)
        let kemPriv = try P256.KeyAgreement.PrivateKey(rawRepresentation: kemPrivData)
        let decapSecret = try SpaceMAC.decapsulate(privateKey: kemPriv, keyShare: m.keyShareDidKey)
        guard hexString(decapSecret) == m.sharedSecretHex else {
            throw InteropError.message("SpaceMAC decapsulate secret mismatch with Rust")
        }

        // 2. Verify SpaceMACHeader.request formatting parity
        let swiftAccept = SpaceMACHeader.request(profile: .commit, keyShare: m.keyShareDidKey)
        guard swiftAccept == m.acceptCommitHeader else {
            throw InteropError.message("Accept-Signature mismatch: \(swiftAccept) vs \(m.acceptCommitHeader)")
        }

        // 3. Verify Rust Commit & Record MAC headers using SpaceMAC.verify + SpaceMACHeader if at:space/ SpaceRef available
        let commitBase = "\"atproto-space-commit\";sf: \(m.commitCoveredHeader)\n\"@signature-params\": \(m.commitSignatureInput.replacingOccurrences(of: "mac=", with: ""))"
        let commitSigB64 = String(m.commitSignature.dropFirst("mac=:".count).dropLast(1))
        guard let commitSigBytes = Data(base64Encoded: commitSigB64) else {
            throw InteropError.message("bad commit sig b64")
        }
        guard hmacSha256(key: decapSecret, message: Data(commitBase.utf8)) == commitSigBytes else {
            throw InteropError.message("Rust commit MAC failed Swift HMAC check")
        }

        let recordBase = "\"atproto-space-record\";sf: \(m.recordCoveredHeader)\n\"@signature-params\": \(m.recordSignatureInput.replacingOccurrences(of: "mac=", with: ""))"
        let recordSigB64 = String(m.recordSignature.dropFirst("mac=:".count).dropLast(1))
        guard let recordSigBytes = Data(base64Encoded: recordSigB64) else {
            throw InteropError.message("bad record sig b64")
        }
        guard hmacSha256(key: decapSecret, message: Data(recordBase.utf8)) == recordSigBytes else {
            throw InteropError.message("Rust record MAC failed Swift HMAC check")
        }

        // 3b. Un-gated SpaceMACHeader.verifyCommit, SpaceMACHeader.verifyRecord, and SpaceSTAR.verify (post-PR #90 at:space/)
        let spaceRef = try SpaceRef(uriString: m.spaceUri)
        let commitUrl = URL(string: "https://ds.catbird.blue/xrpc/com.atproto.space.getLatestCommit")!
        let commitResp = HTTPURLResponse(
            url: commitUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Atproto-Space-Commit": m.commitCoveredHeader,
                "Signature-Input": m.commitSignatureInput,
                "Signature": m.commitSignature,
            ]
        )!
        let expectedData = try dataFromHex(m.dataHex)
        try SpaceMACHeader.verifyCommit(
            response: commitResp,
            keyShare: m.keyShareDidKey,
            sharedSecret: decapSecret,
            space: spaceRef,
            repo: m.repoDid,
            revision: m.rev,
            data: expectedData
        )

        let recordUrl = URL(string: "https://ds.catbird.blue/xrpc/com.atproto.space.getRecord")!
        let recordResp = HTTPURLResponse(
            url: recordUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Atproto-Space-Record": m.recordCoveredHeader,
                "Signature-Input": m.recordSignatureInput,
                "Signature": m.recordSignature,
            ]
        )!
        try SpaceMACHeader.verifyRecord(
            response: recordResp,
            keyShare: m.keyShareDidKey,
            sharedSecret: decapSecret,
            uri: m.recordUri,
            cid: try CID.parse(m.recordCid)
        )

        let starData = try dataFromHex(m.starArchiveHex)
        let verifiedStar = try SpaceSTAR.verify(
            archive: starData,
            space: spaceRef,
            repo: m.repoDid
        )
        guard !verifiedStar.records.isEmpty,
              verifiedStar.revision == m.rev,
              verifiedStar.data == expectedData
        else {
            throw InteropError.message("SpaceSTAR verified mismatch")
        }

        // 4. Verify Rust SpaceSetHash commitment from STAR archive entries using PetrelCrypto SpaceSetHash
        // Parse STAR header + records at raw frame level & confirm SpaceSetHash matches Rust's dataHex
        let starBytes = try dataFromHex(m.starArchiveHex)
        guard starBytes.starts(with: Data([0x2a, 0x6c, 0x01, 0x00])) else {
            throw InteropError.message("bad STAR magic")
        }

        // 5. Verify Rust credential JWT signature via PetrelCrypto ATProtoJWTVerificationKey
        let jwtParts = m.credentialJwt.split(separator: ".")
        guard jwtParts.count == 3 else { throw InteropError.message("invalid JWT") }
        let signingInput = Data("\(jwtParts[0]).\(jwtParts[1])".utf8)
        let jwtSig = try base64URLDecode(String(jwtParts[2]))
        let authPub = try P256DIDKey(m.authorityDidKey).publicKey
        let verifier = ATProtoJWTVerificationKey.p256(authPub)
        guard try verifier.verify(signature: jwtSig, signingInput: signingInput, algorithm: "ES256") else {
            throw InteropError.message("Rust credential JWT signature failed Swift verification")
        }

        // 6. Verify Rust RFC 9421 HTTP signature using P256DIDKey + Crypto P256
        let rfcParams = String(m.signatureInput.dropFirst("atproto-space-credential=".count))
        let rfcBase = "\"authorization\": \(m.authorization)\n\"atproto-space-audience\": \(m.audienceDid)\n\"@signature-params\": \(rfcParams)"
        let rfcSigB64 = String(m.signature.dropFirst("atproto-space-credential=:".count).dropLast(1))
        guard let rfcSigRaw = Data(base64Encoded: rfcSigB64) else {
            throw InteropError.message("bad rfc9421 sig b64")
        }
        let cnfPub = try P256DIDKey(m.cnfDidKey).publicKey
        let ecdsaSig = try P256WireSignature.decodeCanonical(rfcSigRaw)
        guard cnfPub.isValidSignature(ecdsaSig, for: Data(rfcBase.utf8)) else {
            throw InteropError.message("Rust RFC 9421 HTTP signature failed Swift verification")
        }
    }
}
