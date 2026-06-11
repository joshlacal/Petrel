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

/// Keychain accessibility levels for items Petrel stores (tokens, session data,
/// DPoP keys). Trade-off: device-only levels never leave the device (no iCloud
/// keychain sync, not restored to a new device), which is correct for
/// DPoP-bound sessions — the DPoP private key is device-bound regardless, so a
/// synced token would be unusable on another device anyway. Ignored on non-Apple
/// platforms.
public enum KeychainAccessibility: Sendable {
    /// Available after the first unlock following boot; never leaves this device. Default.
    case afterFirstUnlockThisDeviceOnly
    /// Available after the first unlock; included in encrypted backups and
    /// restorable to other devices. Use only if you migrate sessions yourself.
    case afterFirstUnlock
    /// Available only while the device is unlocked; never leaves this device.
    /// Strictest — background token refresh fails while the device is locked.
    case whenUnlockedThisDeviceOnly
}

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
