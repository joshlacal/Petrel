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
    /// to its Base64 representation. Existing credential files must decrypt before
    /// configuration succeeds. No key is generated, persisted, or logged.
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
            return Self(backend: backend, identifier: directory.standardizedFileURL.path)
        }
    #endif
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

    func retrieveAsync(key: String, namespace: String, accessGroup: String?, bypassCache: Bool = false) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try retrieve(key: key, namespace: namespace, accessGroup: accessGroup, bypassCache: bypassCache)
                })
            }
        }
    }

    func storeAsync(key: String, value: Data, namespace: String, accessGroup: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try store(key: key, value: value, namespace: namespace, accessGroup: accessGroup)
                })
            }
        }
    }

    func deleteAsync(key: String, namespace: String, accessGroup: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result {
                    try delete(key: key, namespace: namespace, accessGroup: accessGroup)
                })
            }
        }
    }
}
