import Foundation
@testable import Petrel
import Testing

private final class GroupAwareInMemorySecureStorage: SecureStorage, @unchecked Sendable {
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
        guard items.removeValue(forKey: k) != nil else {
            throw KeychainError.deletionError(status: -25300)
        }
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

private func withGroupAwareStorage<T>(
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        let backend = GroupAwareInMemorySecureStorage()
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body()
    }
}

@Suite("Keychain Access Group Isolation", .serialized)
struct KeychainAccessGroupIsolationTests {
    @Test("Private and named-group storages do not share or migrate data")
    func privateAndNamedGroupDoNotCross() async throws {
        try await withGroupAwareStorage {
            let namespace = "test.group.isolation.\(UUID().uuidString)"
            let privateStorage = KeychainStorage(namespace: namespace, accessGroup: nil)
            let namedStorage = KeychainStorage(namespace: namespace, accessGroup: "group.test.isolated")

            let account = Account(
                did: "did:plc:testprivate123",
                handle: "private.test",
                pdsURL: URL(string: "https://pds.example.com")!
            )

            try await privateStorage.saveAccount(account, for: account.did)

            // Named storage must not find the private account or migrate it
            let namedRead = try await namedStorage.getAccount(for: account.did)
            #expect(namedRead == nil)

            // Private storage must still have its account
            let privateRead = try await privateStorage.getAccount(for: account.did)
            #expect(privateRead?.did == account.did)
        }
    }

    @Test("Construction order does not affect access group isolation")
    func constructionOrderIndependent() async throws {
        try await withGroupAwareStorage {
            let namespace = "test.group.order.\(UUID().uuidString)"
            // Construct named first, then private
            let namedStorage = KeychainStorage(namespace: namespace, accessGroup: "group.test.isolated")
            let privateStorage = KeychainStorage(namespace: namespace, accessGroup: nil)

            let privateAccount = Account(
                did: "did:plc:orderprivate",
                handle: "order.private",
                pdsURL: URL(string: "https://pds.example.com")!
            )
            let namedAccount = Account(
                did: "did:plc:ordernamed",
                handle: "order.named",
                pdsURL: URL(string: "https://pds.example.com")!
            )

            try await privateStorage.saveAccount(privateAccount, for: privateAccount.did)
            try await namedStorage.saveAccount(namedAccount, for: namedAccount.did)

            #expect(try await privateStorage.getAccount(for: privateAccount.did) != nil)
            #expect(try await privateStorage.getAccount(for: namedAccount.did) == nil)
            #expect(try await namedStorage.getAccount(for: namedAccount.did) != nil)
            #expect(try await namedStorage.getAccount(for: privateAccount.did) == nil)
        }
    }

    @Test("Deleting in one access group does not delete in another")
    func deleteIsolation() async throws {
        try await withGroupAwareStorage {
            let namespace = "test.group.delete.\(UUID().uuidString)"
            let privateStorage = KeychainStorage(namespace: namespace, accessGroup: nil)
            let namedStorage = KeychainStorage(namespace: namespace, accessGroup: "group.test.isolated")

            let did = "did:plc:sharedidfortest"
            let account = Account(
                did: did,
                handle: "shared.test",
                pdsURL: URL(string: "https://pds.example.com")!
            )

            try await privateStorage.saveAccount(account, for: did)

            // Delete in named group should not delete private
            try? await namedStorage.deleteAccount(for: did)

            let privateRead = try await privateStorage.getAccount(for: did)
            #expect(privateRead != nil)
        }
    }

    @Test("Concurrent operations across private and named groups remain isolated")
    func concurrentAccessGroupOperations() async throws {
        try await withGroupAwareStorage {
            let namespace = "test.group.concurrent.\(UUID().uuidString)"
            let privateStorage = KeychainStorage(namespace: namespace, accessGroup: nil)
            let namedStorage = KeychainStorage(namespace: namespace, accessGroup: "group.test.concurrent")

            try await withThrowingTaskGroup(of: Void.self) { group in
                for index in 0 ..< 20 {
                    group.addTask {
                        let privateDid = "did:plc:priv\(index)"
                        let namedDid = "did:plc:named\(index)"
                        let privAccount = Account(did: privateDid, handle: "priv\(index).test", pdsURL: URL(string: "https://pds.example.com")!)
                        let namedAccount = Account(did: namedDid, handle: "named\(index).test", pdsURL: URL(string: "https://pds.example.com")!)

                        try await privateStorage.saveAccount(privAccount, for: privateDid)
                        try await namedStorage.saveAccount(namedAccount, for: namedDid)

                        let readPriv = try await privateStorage.getAccount(for: privateDid)
                        let readPrivFromNamed = try await namedStorage.getAccount(for: privateDid)
                        let readNamed = try await namedStorage.getAccount(for: namedDid)
                        let readNamedFromPriv = try await privateStorage.getAccount(for: namedDid)

                        #expect(readPriv?.did == privateDid)
                        #expect(readPrivFromNamed == nil)
                        #expect(readNamed?.did == namedDid)
                        #expect(readNamedFromPriv == nil)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    @Test("DPoP keys remain isolated across access groups")
    func dpopKeyIsolation() async throws {
        try await withGroupAwareStorage {
            let keyData1 = Data([0x01, 0x02, 0x03, 0x04])
            let keyData2 = Data([0x05, 0x06, 0x07, 0x08])

            try KeychainManager.storeDPoPKeyRepresentation(keyData1, keyTag: "tag1", accessGroup: nil)
            try KeychainManager.storeDPoPKeyRepresentation(keyData2, keyTag: "tag1", accessGroup: "group.dpop.test")

            let priv = try KeychainManager.retrieveDPoPKeyRepresentation(keyTag: "tag1", accessGroup: nil)
            let named = try KeychainManager.retrieveDPoPKeyRepresentation(keyTag: "tag1", accessGroup: "group.dpop.test")

            #expect(priv == keyData1)
            #expect(named == keyData2)

            try KeychainManager.deleteDPoPKey(keyTag: "tag1", accessGroup: "group.dpop.test")
            #expect(try KeychainManager.retrieveDPoPKeyRepresentation(keyTag: "tag1", accessGroup: nil) == keyData1)
            #expect(throws: (any Error).self) {
                try KeychainManager.retrieveDPoPKeyRepresentation(keyTag: "tag1", accessGroup: "group.dpop.test")
            }
        }
    }
}
