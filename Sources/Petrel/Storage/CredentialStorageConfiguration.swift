import Crypto
import Foundation

/// Selects credential storage for one client without changing any other client.
public struct CredentialStorageConfiguration: Sendable {
    let backend: (any SecureStorage)?
    let identifier: String

    /// Uses Petrel's existing platform storage selection and accessibility policy.
    public static let platformDefault = CredentialStorageConfiguration(backend: nil, identifier: "")

    /// Uses the existing encrypted-file format in an explicitly selected directory.
    /// Supply the durable AES key used for this directory, or set PETREL_MASTER_KEY
    /// to its Base64 representation. No key is generated, persisted, or logged.
    ///
    /// A directory is bound to one key. The first configuration writes a small encrypted
    /// key-check file (`.petrel-key-check`); every later configuration, including one in
    /// another process, must decrypt it, and existing credential files must decrypt too.
    /// Otherwise this throws ``EncryptedFileCredentialStorageError/keyMismatch(directory:)``
    /// before anything is written, so a second key can never overwrite credentials the
    /// first one stored.
    ///
    /// The directory and files must be owned by the current user; storage enforces
    /// owner-only permissions. Temporary paths and symlinks are rejected.
    /// Access groups are an Apple Keychain feature and are unavailable with files.
    #if os(Linux) || os(macOS) || os(iOS)
        public static func encryptedFiles(directory: URL, masterKey: Data? = nil) throws -> Self {
            guard directory.isFileURL, directory.path.hasPrefix("/") else {
                throw FileEncryptedStore.FileEncryptedStoreError.invalidConfiguration
            }
            let backend = try FileEncryptedStore(
                storageDirectory: directory,
                masterKey: masterKey.map { SymmetricKey(data: $0) }
            )
            try backend.validateExistingCredentials()
            try backend.establishKeyCheck()
            return Self(backend: backend, identifier: directory.standardizedFileURL.path)
        }
    #endif
}

/// Why an encrypted-file credential directory was refused.
public enum EncryptedFileCredentialStorageError: Error, Sendable, Equatable, LocalizedError {
    /// The directory's key-check file or one of its credentials does not decrypt with the
    /// key supplied: the directory belongs to another key (or the file was damaged).
    /// Nothing was read or written. The associated value is the standardized directory path.
    case keyMismatch(directory: String)

    /// A description that names the directory but never the key.
    public var errorDescription: String? {
        switch self {
        case let .keyMismatch(directory):
            "The encrypted credential directory \(directory) belongs to a different key."
        }
    }
}

/// Keeps the legacy platform route intact while explicit backends bypass its
/// process-wide caches. File reads always decrypt bytes from their own directory.
struct CredentialStorageBackend: Sendable {
    let configuration: CredentialStorageConfiguration

    func store(key: String, value: Data, namespace: String, accessGroup: String?) throws {
        if let backend = configuration.backend {
            try backend.store(key: key, value: value, namespace: namespace, accessGroup: accessGroup)
        } else {
            try KeychainManager.store(key: key, value: value, namespace: namespace, accessGroup: accessGroup)
        }
    }

    func retrieve(key: String, namespace: String, accessGroup: String?, bypassCache: Bool = false) throws -> Data {
        if let backend = configuration.backend {
            return try backend.retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        }
        return try KeychainManager.retrieve(key: key, namespace: namespace, accessGroup: accessGroup, bypassCache: bypassCache)
    }

    func delete(key: String, namespace: String, accessGroup: String?) throws {
        if let backend = configuration.backend {
            try backend.delete(key: key, namespace: namespace, accessGroup: accessGroup)
        } else {
            try KeychainManager.delete(key: key, namespace: namespace, accessGroup: accessGroup)
        }
    }

    func storeDPoPKeyRepresentation(_ representation: Data, keyTag: String, accessGroup: String?) throws {
        if let backend = configuration.backend {
            try backend.storeDPoPKeyRepresentation(representation, keyTag: keyTag, accessGroup: accessGroup)
        } else {
            try KeychainManager.storeDPoPKeyRepresentation(representation, keyTag: keyTag, accessGroup: accessGroup)
        }
    }

    func retrieveDPoPKeyRepresentation(keyTag: String, accessGroup: String?) throws -> Data {
        if let backend = configuration.backend {
            return try backend.retrieveDPoPKeyRepresentation(keyTag: keyTag, accessGroup: accessGroup)
        }
        return try KeychainManager.retrieveDPoPKeyRepresentation(keyTag: keyTag, accessGroup: accessGroup)
    }

    func deleteDPoPKey(keyTag: String, accessGroup: String?) throws {
        if let backend = configuration.backend {
            try backend.deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
        } else {
            try KeychainManager.deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
        }
    }

    // The platform route keeps calling KeychainManager's own async wrappers so the
    // default path is byte-for-byte the pre-existing behavior. Explicit backends
    // offload the same blocking file I/O to a background queue.
    func retrieveAsync(key: String, namespace: String, accessGroup: String?, bypassCache: Bool = false) async throws -> Data {
        guard configuration.backend != nil else {
            return try await KeychainManager.retrieveAsync(
                key: key, namespace: namespace, accessGroup: accessGroup, bypassCache: bypassCache
            )
        }
        return try await offload { try retrieve(key: key, namespace: namespace, accessGroup: accessGroup) }
    }

    func storeAsync(key: String, value: Data, namespace: String, accessGroup: String?) async throws {
        guard configuration.backend != nil else {
            return try await KeychainManager.storeAsync(key: key, value: value, namespace: namespace, accessGroup: accessGroup)
        }
        try await offload { try store(key: key, value: value, namespace: namespace, accessGroup: accessGroup) }
    }

    func deleteAsync(key: String, namespace: String, accessGroup: String?) async throws {
        guard configuration.backend != nil else {
            return try await KeychainManager.deleteAsync(key: key, namespace: namespace, accessGroup: accessGroup)
        }
        try await offload { try delete(key: key, namespace: namespace, accessGroup: accessGroup) }
    }

    private func offload<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try operation() })
            }
        }
    }
}
