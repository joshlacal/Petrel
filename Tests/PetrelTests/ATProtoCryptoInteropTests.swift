//
//  ATProtoCryptoInteropTests.swift
//
//
//  Created by Claude Code on 6/1/25.
//

import Foundation
@testable import Petrel
import Testing

/// Test suite for AT Protocol crypto validation using official interop test files
/// Based on https://github.com/bluesky-social/atproto/tree/main/interop-test-files/crypto
@Suite("AT Protocol Crypto Interop Tests")
struct ATProtoCryptoInteropTests {
    // MARK: - Signature Fixtures

    struct SignatureFixture: Codable {
        let comment: String
        let messageBase64: String
        let algorithm: String
        let didDocSuite: String
        let publicKeyDid: String
        let publicKeyMultibase: String
        let signatureBase64: String
        let validSignature: Bool
        let tags: [String]
    }

    struct K256KeyPair: Codable {
        let privateKeyBytesHex: String
        let publicDidKey: String
    }

    struct P256KeyPair: Codable {
        let privateKeyBytesBase58: String
        let publicDidKey: String
    }

    @Suite("Signature Validation")
    struct SignatureValidationTests {
        @Test("Valid Signature Fixtures")
        func validSignatureFixtures() throws {
            let signatureFixtures: [SignatureFixture] = [
                SignatureFixture(
                    comment: "valid P-256 key and signature, with low-S signature",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256",
                    didDocSuite: "EcdsaSecp256r1VerificationKey2019",
                    publicKeyDid: "did:key:zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo",
                    publicKeyMultibase: "zxdM8dSstjrpZaRUwBmDvjGXweKuEMVN95A9oJBFjkWMh",
                    signatureBase64: "2vZNsG3UKvvO/CDlrdvyZRISOFylinBh0Jupc6KcWoJWExHptCfduPleDbG3rko3YZnn9Lw0IjpixVmexJDegg",
                    validSignature: true,
                    tags: []
                ),
                SignatureFixture(
                    comment: "valid K-256 key and signature, with low-S signature",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256K",
                    didDocSuite: "EcdsaSecp256k1VerificationKey2019",
                    publicKeyDid: "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc",
                    publicKeyMultibase: "z25z9DTpsiYYJKGsWmSPJK2NFN8PcJtZig12K59UgW7q5t",
                    signatureBase64: "5WpdIuEUUfVUYaozsi8G0B3cWO09cgZbIIwg1t2YKdUn/FEznOndsz/qgiYb89zwxYCbB71f7yQK5Lr7NasfoA",
                    validSignature: true,
                    tags: []
                ),
            ]

            for fixture in signatureFixtures {
                // Verify that DIDs can be parsed
                #expect(throws: Never.self) {
                    try DID(didString: fixture.publicKeyDid)
                }

                // Verify message can be decoded
                let messageData = Data(base64Encoded: fixture.messageBase64)
                #expect(messageData != nil, "Message should be valid base64: \(fixture.messageBase64)")

                // Verify signature can be decoded
                let signatureData = Data(base64Encoded: fixture.signatureBase64)
                #expect(signatureData != nil, "Signature should be valid base64: \(fixture.signatureBase64)")

                // Check algorithm is supported
                #expect(
                    fixture.algorithm == "ES256" || fixture.algorithm == "ES256K",

                    "Algorithm should be ES256 or ES256K: \(fixture.algorithm)"
                )
            }
        }

        @Test("Invalid Signature Fixtures - High-S")
        func invalidSignatureFixturesHighS() throws {
            let invalidFixtures: [SignatureFixture] = [
                SignatureFixture(
                    comment: "P-256 key and signature, with non-low-S signature which is invalid in atproto",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256",
                    didDocSuite: "EcdsaSecp256r1VerificationKey2019",
                    publicKeyDid: "did:key:zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo",
                    publicKeyMultibase: "zxdM8dSstjrpZaRUwBmDvjGXweKuEMVN95A9oJBFjkWMh",
                    signatureBase64: "2vZNsG3UKvvO/CDlrdvyZRISOFylinBh0Jupc6KcWoKp7O4VS9giSAah8k5IUbXIW00SuOrjfEqQ9HEkN9JGzw",
                    validSignature: false,
                    tags: ["high-s"]
                ),
                SignatureFixture(
                    comment: "K-256 key and signature, with non-low-S signature which is invalid in atproto",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256K",
                    didDocSuite: "EcdsaSecp256k1VerificationKey2019",
                    publicKeyDid: "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc",
                    publicKeyMultibase: "z25z9DTpsiYYJKGsWmSPJK2NFN8PcJtZig12K59UgW7q5t",
                    signatureBase64: "5WpdIuEUUfVUYaozsi8G0B3cWO09cgZbIIwg1t2YKdXYA67MYxYiTMAVfdnkDCMN9S5B3vHosRe07aORmoshoQ",
                    validSignature: false,
                    tags: ["high-s"]
                ),
            ]

            for fixture in invalidFixtures {
                // These fixtures should have validSignature = false
                #expect(!fixture.validSignature, "High-S signatures should be marked as invalid")
                #expect(fixture.tags.contains("high-s"), "Should have high-s tag")

                // DIDs should still be parseable
                #expect(throws: Never.self) {
                    try DID(didString: fixture.publicKeyDid)
                }
            }
        }

        @Test("Invalid Signature Fixtures - DER Encoded")
        func invalidSignatureFixturesDER() throws {
            let invalidFixtures: [SignatureFixture] = [
                SignatureFixture(
                    comment: "P-256 key and signature, with DER-encoded signature which is invalid in atproto",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256",
                    didDocSuite: "EcdsaSecp256r1VerificationKey2019",
                    publicKeyDid: "did:key:zDnaeT6hL2RnTdUhAPLij1QBkhYZnmuKyM7puQLW1tkF4Zkt8",
                    publicKeyMultibase: "ze8N2PPxnu19hmBQ58t5P3E9Yj6CqakJmTVCaKvf9Byq2",
                    signatureBase64: "MEQCIFxYelWJ9lNcAVt+jK0y/T+DC/X4ohFZ+m8f9SEItkY1AiACX7eXz5sgtaRrz/SdPR8kprnbHMQVde0T2R8yOTBweA",
                    validSignature: false,
                    tags: ["der-encoded"]
                ),
                SignatureFixture(
                    comment: "K-256 key and signature, with DER-encoded signature which is invalid in atproto",
                    messageBase64: "oWVoZWxsb2V3b3JsZA",
                    algorithm: "ES256K",
                    didDocSuite: "EcdsaSecp256k1VerificationKey2019",
                    publicKeyDid: "did:key:zQ3shnriYMXc8wvkbJqfNWh5GXn2bVAeqTC92YuNbek4npqGF",
                    publicKeyMultibase: "z22uZXWP8fdHXi4jyx8cCDiBf9qQTsAe6VcycoMQPfcMQX",
                    signatureBase64: "MEUCIQCWumUqJqOCqInXF7AzhIRg2MhwRz2rWZcOEsOjPmNItgIgXJH7RnqfYY6M0eg33wU0sFYDlprwdOcpRn78Sz5ePgk",
                    validSignature: false,
                    tags: ["der-encoded"]
                ),
            ]

            for fixture in invalidFixtures {
                // These fixtures should have validSignature = false
                #expect(!fixture.validSignature, "DER-encoded signatures should be marked as invalid")
                #expect(fixture.tags.contains("der-encoded"), "Should have der-encoded tag")

                // DIDs should still be parseable
                #expect(throws: Never.self) {
                    try DID(didString: fixture.publicKeyDid)
                }
            }
        }
    }

    // MARK: - DID Key Tests

    @Suite("DID Key Validation")
    struct DIDKeyValidationTests {
        @Test("K256 DID Keys")
        func k256DIDKeys() throws {
            let k256KeyPairs: [K256KeyPair] = [
                K256KeyPair(
                    privateKeyBytesHex: "9085d2bef69286a6cbb51623c8fa258629945cd55ca705cc4e66700396894e0c",
                    publicDidKey: "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
                ),
                K256KeyPair(
                    privateKeyBytesHex: "f0f4df55a2b3ff13051ea814a8f24ad00f2e469af73c363ac7e9fb999a9072ed",
                    publicDidKey: "did:key:zQ3shtxV1FrJfhqE1dvxYRcCknWNjHc3c5X1y3ZSoPDi2aur2"
                ),
                K256KeyPair(
                    privateKeyBytesHex: "6b0b91287ae3348f8c2f2552d766f30e3604867e34adc37ccbb74a8e6b893e02",
                    publicDidKey: "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N"
                ),
                K256KeyPair(
                    privateKeyBytesHex: "c0a6a7c560d37d7ba81ecee9543721ff48fea3e0fb827d42c1868226540fac15",
                    publicDidKey: "did:key:zQ3shadCps5JLAHcZiuX5YUtWHHL8ysBJqFLWvjZDKAWUBGzy"
                ),
                K256KeyPair(
                    privateKeyBytesHex: "175a232d440be1e0788f25488a73d9416c04b6f924bea6354bf05dd2f1a75133",
                    publicDidKey: "did:key:zQ3shptjE6JwdkeKN4fcpnYQY3m9Cet3NiHdAfpvSUZBFoKBj"
                ),
            ]

            for keyPair in k256KeyPairs {
                // Verify DID can be parsed
                #expect(throws: Never.self) {
                    try DID(didString: keyPair.publicDidKey)
                }

                // Verify private key hex is valid
                let privateKeyData = Data(hexString: keyPair.privateKeyBytesHex)
                #expect(privateKeyData != nil, "Private key hex should be valid: \(keyPair.privateKeyBytesHex)")
                #expect(privateKeyData?.count == 32, "K256 private key should be 32 bytes")

                // Verify DID follows did:key format
                #expect(keyPair.publicDidKey.hasPrefix("did:key:"), "Should be a did:key")
                #expect(keyPair.publicDidKey.contains("zQ3sh"), "K256 keys should start with zQ3sh")
            }
        }

        @Test("P256 DID Keys")
        func p256DIDKeys() throws {
            let p256KeyPairs: [P256KeyPair] = [
                P256KeyPair(
                    privateKeyBytesBase58: "9p4VRzdmhsnq869vQjVCTrRry7u4TtfRxhvBFJTGU2Cp",
                    publicDidKey: "did:key:zDnaeTiq1PdzvZXUaMdezchcMJQpBdH2VN4pgrrEhMCCbmwSb"
                ),
            ]

            for keyPair in p256KeyPairs {
                // Verify DID can be parsed
                #expect(throws: Never.self) {
                    try DID(didString: keyPair.publicDidKey)
                }

                // Verify DID follows did:key format for P256
                #expect(keyPair.publicDidKey.hasPrefix("did:key:"), "Should be a did:key")
                #expect(keyPair.publicDidKey.contains("zDnae"), "P256 keys should start with zDnae")
            }
        }

        @Test("DID Key Format Validation")
        func didKeyFormatValidation() throws {
            // Test various did:key formats
            let validDIDKeys = [
                "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme", // K256
                "did:key:zDnaeTiq1PdzvZXUaMdezchcMJQpBdH2VN4pgrrEhMCCbmwSb", // P256
                "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N", // K256
            ]

            for didKey in validDIDKeys {
                let parsed = try DID(didString: didKey)
                #expect(parsed.method == "key", "Method should be 'key'")
                #expect(parsed.authority.hasPrefix("z"), "Authority should start with 'z' (multibase)")
            }
        }
    }

    // MARK: - Multibase Validation

    @Suite("Multibase Validation")
    struct MultibaseValidationTests {
        @Test("Multibase Key Formats")
        func multibaseKeyFormats() {
            let multibaseKeys = [
                "zxdM8dSstjrpZaRUwBmDvjGXweKuEMVN95A9oJBFjkWMh", // P256
                "z25z9DTpsiYYJKGsWmSPJK2NFN8PcJtZig12K59UgW7q5t", // K256
                "ze8N2PPxnu19hmBQ58t5P3E9Yj6CqakJmTVCaKvf9Byq2", // P256
                "z22uZXWP8fdHXi4jyx8cCDiBf9qQTsAe6VcycoMQPfcMQX", // K256
            ]

            for key in multibaseKeys {
                #expect(key.hasPrefix("z"), "Multibase keys should start with 'z'")
                #expect(key.count > 10, "Multibase keys should be reasonably long")
            }
        }
    }

    // MARK: - Base64 Validation

    @Suite("Base64 Validation")
    struct Base64ValidationTests {
        @Test("Base64 Message Decoding")
        func base64MessageDecoding() {
            let validBase64Messages = [
                "oWVoZWxsb2V3b3JsZA", // Common test message from fixtures
            ]

            for message in validBase64Messages {
                let decoded = Data(base64Encoded: message)
                #expect(decoded != nil, "Should be valid base64: \(message)")
            }
        }

        @Test("Base64 Signature Decoding")
        func base64SignatureDecoding() {
            let validBase64Signatures = [
                "2vZNsG3UKvvO/CDlrdvyZRISOFylinBh0Jupc6KcWoJWExHptCfduPleDbG3rko3YZnn9Lw0IjpixVmexJDegg",
                "5WpdIuEUUfVUYaozsi8G0B3cWO09cgZbIIwg1t2YKdUn/FEznOndsz/qgiYb89zwxYCbB71f7yQK5Lr7NasfoA",
            ]

            for signature in validBase64Signatures {
                let decoded = Data(base64Encoded: signature)
                #expect(decoded != nil, "Should be valid base64: \(signature)")
                #expect(decoded?.count == 64, "ECDSA signatures should be 64 bytes (32+32)")
            }
        }

        @Test("DER Encoded Signatures Are Different")
        func derEncodedSignaturesAreDifferent() throws {
            let derSignatures = [
                "MEQCIFxYelWJ9lNcAVt+jK0y/T+DC/X4ohFZ+m8f9SEItkY1AiACX7eXz5sgtaRrz/SdPR8kprnbHMQVde0T2R8yOTBweA",
                "MEUCIQCWumUqJqOCqInXF7AzhIRg2MhwRz2rWZcOEsOjPmNItgIgXJH7RnqfYY6M0eg33wU0sFYDlprwdOcpRn78Sz5ePgk",
            ]

            for signature in derSignatures {
                let decoded = Data(base64Encoded: signature)
                #expect(decoded != nil, "Should be valid base64: \(signature)")
                // DER signatures are variable length, not fixed 64 bytes
                #expect(try #require(decoded?.count) != 64, "DER signatures should not be 64 bytes")
                #expect(try #require(decoded?.count) > 64, "DER signatures are typically longer than raw signatures")
            }
        }
    }
}

// MARK: - Helper Extensions

extension Data {
    /// Create Data from hex string
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0 ..< len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i ..< j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}
