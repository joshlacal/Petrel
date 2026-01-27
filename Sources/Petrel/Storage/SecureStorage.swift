//
//  SecureStorage.swift
//  Petrel
//
//  Cross-platform secure storage protocol
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation

/// Protocol for secure storage backends across different platforms
protocol SecureStorage: Sendable {
    /// Store data securely
    func store(key: String, value: Data, namespace: String, accessGroup: String?) throws

    /// Retrieve data securely
    func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data

    /// Delete specific item
    func delete(key: String, namespace: String, accessGroup: String?) throws

    /// Delete all items in a namespace
    func deleteAll(namespace: String, accessGroup: String?) throws

    /// Store a DPoP private key
    func storeDPoPKey(_ key: P256.Signing.PrivateKey, keyTag: String, accessGroup: String?) throws

    /// Retrieve a DPoP private key
    func retrieveDPoPKey(keyTag: String, accessGroup: String?) throws -> P256.Signing.PrivateKey

    /// Delete a DPoP private key
    func deleteDPoPKey(keyTag: String, accessGroup: String?) throws
}
