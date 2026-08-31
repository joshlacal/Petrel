import Foundation
@testable import Petrel

/// Serializes tests that mutate `KeychainManager`'s process-global storage
/// override or rely on the platform default while another test could override
/// it. Actor suite serialization is not sufficient across separate suites.
private actor StorageOverrideTestLock {
    static let shared = StorageOverrideTestLock()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

func withSerializedStorageOverrideTest<T>(
    _ body: () async throws -> T
) async rethrows -> T {
    await StorageOverrideTestLock.shared.acquire()
    do {
        let result = try await body()
        await StorageOverrideTestLock.shared.release()
        return result
    } catch {
        await StorageOverrideTestLock.shared.release()
        throw error
    }
}

final class GroupAwareInMemorySecureStorage: SecureStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    private func fullKey(_ key: String, _ namespace: String, _ accessGroup: String?) -> String {
        "\(namespace)|\(accessGroup ?? "")|\(key)"
    }

    func store(key: String, value: Data, namespace: String, accessGroup: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        items[fullKey(key, namespace, accessGroup)] = value
    }

    func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = items[fullKey(key, namespace, accessGroup)] else {
            throw KeychainError.itemRetrievalError(status: -25300)
        }
        return data
    }

    func delete(key: String, namespace: String, accessGroup: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        let k = fullKey(key, namespace, accessGroup)
        _ = items.removeValue(forKey: k)
    }

    func deleteAll(namespace: String, accessGroup: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        let prefix = "\(namespace)|\(accessGroup ?? "")|"
        items = items.filter { !$0.key.hasPrefix(prefix) }
    }

    func storeDPoPKeyRepresentation(_ representation: Data, keyTag: String, accessGroup: String?) throws {
        try store(key: keyTag, value: representation, namespace: "dpopkeys", accessGroup: accessGroup)
    }

    func retrieveDPoPKeyRepresentation(keyTag: String, accessGroup: String?) throws -> Data {
        try retrieve(key: keyTag, namespace: "dpopkeys", accessGroup: accessGroup)
    }

    func deleteDPoPKey(keyTag: String, accessGroup: String?) throws {
        try delete(key: keyTag, namespace: "dpopkeys", accessGroup: accessGroup)
    }
}

func withGroupAwareStorage<T>(
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        let backend = GroupAwareInMemorySecureStorage()
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body()
    }
}
