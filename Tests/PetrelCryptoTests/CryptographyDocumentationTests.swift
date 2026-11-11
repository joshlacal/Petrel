import Foundation
import PetrelCrypto
import Testing

/// Compiles and runs the examples in
/// `Sources/PetrelCrypto/PetrelCrypto.docc/Cryptography.md`, section by
/// section, so the article cannot drift from the API.
@Suite("DocC: Keys, Signing and Verification")
struct CryptographyDocumentationTests {
    @Test("Generate a key and sign / Verify a signature / Strict by default")
    func generateSignVerify() async throws {
        // --- Generate a key and sign
        let keypair = ATProtoCrypto.generateKeypair() // K-256
        let message = Data("hello world".utf8)

        let signature = try await keypair.sign(message) // 64 bytes, low-S
        let didKey = keypair.didKey // "did:key:zQ3sh…"

        #expect(signature.count == 64)
        #expect(didKey.hasPrefix("did:key:zQ3sh"))

        // --- Verify a signature
        let valid = try ATProtoCrypto.verifySignature(
            didKey: didKey,
            data: message,
            signature: signature
        )
        #expect(valid)

        let publicKey = try ATProtoPublicKey(didKey: didKey)
        let alsoValid = publicKey.isValidSignature(signature, for: message)
        #expect(alsoValid)

        // --- Strict by default, lax on request
        let highS = try highSTwin(of: signature, curve: .k256)
        #expect(publicKey.isValidSignature(highS, for: message) == false)
        #expect(publicKey.isValidSignature(highS, for: message, options: .jwt) == true)
    }

    @Test("Import and export private keys")
    func importAndExport() throws {
        let imported = try K256Keypair(
            hex: "9085d2bef69286a6cbb51623c8fa258629945cd55ca705cc4e66700396894e0c"
        )
        #expect(imported.didKey == "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme")

        let raw = imported.exportRawRepresentation() // 32 bytes
        let multibase = try imported.exportMultibase() // "z…", names its curve
        let restored = try ATProtoCrypto.importKeypair(privateMultibase: multibase)

        #expect(raw.count == 32)
        #expect(multibase.hasPrefix("z"))
        #expect(restored.didKey == imported.didKey)
        #expect(restored.curve == .k256)
    }

    @Test("Public key encodings")
    func publicKeyEncodings() throws {
        let key = try ATProtoPublicKey(multikey: "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")
        #expect(key.curve == .k256)
        #expect(key.didKey == "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")

        // The same key as an older DID document wrote it.
        let legacy = try ATProtoPublicKey(
            verificationMethodType: "EcdsaSecp256k1VerificationKey2019",
            publicKeyMultibase: "zQYEBzXeuTM9UR3rfvNag6L3RNAs5pQZyYPsomTsgQhsxLdEgCrPTLgFna8yqCnxPpNT7DBk6Ym3dgPKNu86vt9GR"
        )
        #expect(legacy == key)
    }

    @Test("Keys that live somewhere else")
    func externalAndEnclaveSigners() async throws {
        // Stand-in for a remote key service that signs a digest and answers in DER.
        struct KeyService: Sendable {
            let key = P256Keypair.generate()
            func sign(digest: Data, message: Data) async throws -> Data {
                precondition(digest == ATProtoCrypto.sha256(message))
                return try derEncoding(of: key.sign(message), curve: .p256)
            }
        }
        let keyService = KeyService()
        let rotationKey = keyService.key.publicKey
        let operationBytes = Data("unsigned PLC operation".utf8)

        let remote = ATProtoExternalSigner(publicKey: rotationKey) { request in
            // `request.message` is the bytes; `request.sha256Digest` is their hash.
            try await keyService.sign(digest: request.sha256Digest, message: request.message)
        }
        let operationSignature = try await remote.sign(operationBytes)

        #expect(ATProtoSignature.isCanonical(operationSignature, curve: .p256))
        #expect(rotationKey.isValidSignature(operationSignature, for: operationBytes))

        #if canImport(CryptoKit) && canImport(Security) && (os(iOS) || os(macOS) || os(visionOS))
            let message = Data("hello world".utf8)
            if ATProtoKeypairTests.canCreateSecureEnclaveKey {
                let enclaveKey = try SecureEnclaveP256Signer.generate()
                let enclaveSignature = try enclaveKey.sign(message) // low-S, like any other
                #expect(enclaveKey.publicKey.isValidSignature(enclaveSignature, for: message))
            }
        #endif
    }

    @Test("Service-auth tokens")
    func serviceAuthTokens() async throws {
        let keypair = ATProtoCrypto.generateKeypair()

        let token = try await ServiceJWT.mint(
            issuer: "did:plc:abcdefghijklmnopqrstuvwx",
            audience: "did:web:api.bsky.app",
            method: "com.atproto.repo.getRecord",
            eventID: UUID().uuidString,
            signer: keypair
        )
        let claims = try ServiceJWT.verify(token, publicKey: keypair.publicKey)

        #expect(claims.iss == "did:plc:abcdefghijklmnopqrstuvwx")
        #expect(claims.lxm == "com.atproto.repo.getRecord")
    }
}
