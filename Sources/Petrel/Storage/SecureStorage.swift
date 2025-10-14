//
//  SecureStorage.swift
//  Petrel
//
//  Cross-platform secure storage protocol
//

import Foundation
import CryptoKit

/// Protocol for secure storage backends across different platforms
protocol SecureStorage: Sendable {
    /// Store data securely
    func store(key: String, value: Data, namespace: String) throws
    
    /// Retrieve data securely
    func retrieve(key: String, namespace: String) throws -> Data
    
    /// Delete specific item
    func delete(key: String, namespace: String) throws
    
    /// Delete all items in a namespace
    func deleteAll(namespace: String) throws
    
    /// Store a DPoP private key
    func storeDPoPKey(_ key: P256.Signing.PrivateKey, keyTag: String) throws
    
    /// Retrieve a DPoP private key
    func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey
    
    /// Delete a DPoP private key
    func deleteDPoPKey(keyTag: String) throws
}
