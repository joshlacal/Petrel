#if os(iOS) || os(macOS)

import Foundation
import Security
import Testing
@testable import Petrel

@Suite("Apple Keychain Store")
struct AppleKeychainStoreTests {
    @Test("replacement failure preserves the existing item without deleting")
    func replacementFailureIsAtomic() {
        let recorder = KeychainOperationRecorder(updateStatuses: [-50])
        let store = AppleKeychainStore(operations: recorder.operations)

        #expect(throws: KeychainError.self) {
            try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: "group.test")
        }
        #expect(recorder.calls == [.update])
        #expect(recorder.lastUpdateData == Data("new".utf8))
    }

    @Test("absent item uses add")
    func absentItemUsesAdd() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecItemNotFound], addStatuses: [errSecSuccess])
        let store = AppleKeychainStore(operations: recorder.operations)

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update, .add])
    }

    @Test("duplicate add retries update")
    func duplicateAddRetriesUpdate() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecItemNotFound, errSecSuccess], addStatuses: [errSecDuplicateItem])
        let store = AppleKeychainStore(operations: recorder.operations)

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update, .add, .update])
    }

    @Test("successful replacement only updates")
    func successfulReplacementOnlyUpdates() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecSuccess])
        let store = AppleKeychainStore(operations: recorder.operations)

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update])
    }
}

private final class KeychainOperationRecorder: @unchecked Sendable {
    enum Call: Equatable { case update, add, delete }

    private(set) var calls: [Call] = []
    private(set) var lastUpdateData: Data?
    private var updateStatuses: [OSStatus]
    private var addStatuses: [OSStatus]

    init(updateStatuses: [OSStatus] = [], addStatuses: [OSStatus] = []) {
        self.updateStatuses = updateStatuses
        self.addStatuses = addStatuses
    }

    var operations: AppleKeychainStore.Operations {
        AppleKeychainStore.Operations(
            update: { [self] _, attributes in
                calls.append(.update)
                lastUpdateData = (attributes as NSDictionary)[kSecValueData as String] as? Data
                return updateStatuses.isEmpty ? errSecSuccess : updateStatuses.removeFirst()
            },
            add: { [self] _, _ in
                calls.append(.add)
                return addStatuses.isEmpty ? errSecSuccess : addStatuses.removeFirst()
            },
            delete: { [self] _ in
                calls.append(.delete)
                return errSecSuccess
            }
        )
    }
}

#endif
