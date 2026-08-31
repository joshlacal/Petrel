#if os(iOS) || os(macOS)

import Foundation
import Security
import Testing
@testable import Petrel

@Suite("Apple Keychain Store", .serialized)
struct AppleKeychainStoreTests {
    @Test("replacement failure preserves the existing item without deleting")
    func replacementFailureIsAtomic() {
        let recorder = KeychainOperationRecorder(updateStatuses: [-50])
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        #expect(throws: KeychainError.self) {
            try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: "group.test")
        }
        #expect(recorder.calls == [.update])
        #expect(recorder.lastUpdateData == Data("new".utf8))
    }

    @Test("absent item uses add")
    func absentItemUsesAdd() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecItemNotFound], addStatuses: [errSecSuccess])
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update, .add])
    }

    @Test("duplicate add retries update")
    func duplicateAddRetriesUpdate() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecItemNotFound, errSecSuccess], addStatuses: [errSecDuplicateItem])
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update, .add, .update])
    }

    @Test("successful replacement only updates")
    func successfulReplacementOnlyUpdates() throws {
        let recorder = KeychainOperationRecorder(updateStatuses: [errSecSuccess])
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        try store.store(key: "session", value: Data("new".utf8), namespace: "test", accessGroup: nil)

        #expect(recorder.calls == [.update])
    }

    @Test("queries include named access group explicitly")
    func queriesIncludeNamedAccessGroup() throws {
        let testData = Data("sample-value".utf8)
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess],
            copyMatchingResults: [testData as CFData],
            updateStatuses: [errSecSuccess]
        )
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        try store.store(key: "item", value: testData, namespace: "test", accessGroup: "group.test.named")
        _ = try store.retrieve(key: "item", namespace: "test", accessGroup: "group.test.named")
        try store.delete(key: "item", namespace: "test", accessGroup: "group.test.named")

        #expect(recorder.updateQueries.first?.0[kSecAttrAccessGroup as String] as? String == "group.test.named")
        #expect(recorder.copyMatchingQueries.first?[kSecAttrAccessGroup as String] as? String == "group.test.named")
        #expect(recorder.deleteQueries.first?[kSecAttrAccessGroup as String] as? String == "group.test.named")
    }

    @Test("queries include resolved default access group when accessGroup is nil")
    func queriesIncludeResolvedDefaultAccessGroupWhenNil() throws {
        let testData = Data("sample-value".utf8)
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess],
            copyMatchingResults: [testData as CFData],
            updateStatuses: [errSecSuccess]
        )
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "TEAM12345.blue.catbird.default")

        try store.store(key: "item", value: testData, namespace: "test", accessGroup: nil)
        _ = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        try store.delete(key: "item", namespace: "test", accessGroup: nil)

        #expect(recorder.updateQueries.first?.0[kSecAttrAccessGroup as String] as? String == "TEAM12345.blue.catbird.default")
        #expect(recorder.copyMatchingQueries.first?[kSecAttrAccessGroup as String] as? String == "TEAM12345.blue.catbird.default")
        #expect(recorder.deleteQueries.first?[kSecAttrAccessGroup as String] as? String == "TEAM12345.blue.catbird.default")
    }

    @Test("retrieve routes through operations seam")
    func retrieveRoutesThroughOperationsSeam() throws {
        let testData = Data("sample-payload".utf8)
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess],
            copyMatchingResults: [testData as CFData]
        )
        let store = AppleKeychainStore(operations: recorder.operations, defaultAccessGroup: "test.group")

        let retrieved = try store.retrieve(key: "item", namespace: "test", accessGroup: "group.test")
        #expect(retrieved == testData)
        #expect(recorder.calls == [.copyMatching])
    }

    @Test("failed default access group resolution fails closed without emitting unscoped query")
    func failedDefaultAccessGroupResolutionFailsClosed() {
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecInteractionNotAllowed],
            addStatuses: [errSecInteractionNotAllowed]
        )
        let store = AppleKeychainStore(operations: recorder.operations)

        #expect(throws: KeychainError.self) {
            try store.store(key: "item", value: Data("sample".utf8), namespace: "test", accessGroup: nil)
        }
        #expect(throws: KeychainError.self) {
            _ = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        }
        #expect(throws: KeychainError.self) {
            try store.delete(key: "item", namespace: "test", accessGroup: nil)
        }

        // Verify no query was emitted without kSecAttrAccessGroup
        for query in recorder.updateQueries {
            #expect(query.0[kSecAttrAccessGroup as String] != nil)
        }
        for query in recorder.copyMatchingQueries {
            if (query[kSecAttrAccount as String] as? String)?.hasPrefix("petrel.defaultGroupProbe.") != true {
                #expect(query[kSecAttrAccessGroup as String] != nil)
            }
        }
        for query in recorder.deleteQueries {
            if (query[kSecAttrAccount as String] as? String)?.hasPrefix("petrel.defaultGroupProbe.") != true {
                #expect(query[kSecAttrAccessGroup as String] != nil)
            }
        }
    }

    @Test("default access group resolution retries after initial failure")
    func defaultAccessGroupResolutionRetriesAfterInitialFailure() throws {
        let probeAttrs: [String: Any] = [kSecAttrAccessGroup as String: "TEAM12345.blue.catbird.retry"]
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess, errSecSuccess],
            copyMatchingResults: [probeAttrs as CFDictionary, Data("sample".utf8) as CFData],
            updateStatuses: [errSecSuccess],
            addStatuses: [errSecInteractionNotAllowed, errSecSuccess]
        )
        let store = AppleKeychainStore(operations: recorder.operations)

        #expect(throws: KeychainError.self) {
            _ = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        }

        let testData = Data("sample".utf8)
        let retrieved = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        #expect(retrieved == testData)
    }

    @Test("failed first probe does not poison subsequent resolutions")
    func failedFirstProbeDoesNotPoisonSubsequentResolutions() throws {
        let probeAttrs: [String: Any] = [kSecAttrAccessGroup as String: "TEAM12345.blue.catbird.retry-success"]
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecAuthFailed, errSecSuccess, errSecSuccess, errSecSuccess],
            copyMatchingResults: [nil, probeAttrs as CFDictionary, Data("first-read".utf8) as CFData, Data("second-read".utf8) as CFData],
            updateStatuses: [errSecSuccess, errSecSuccess],
            addStatuses: [errSecInteractionNotAllowed, errSecSuccess, errSecSuccess],
            deleteStatuses: [errSecSuccess, errSecSuccess]
        )
        let store = AppleKeychainStore(operations: recorder.operations)

        // Attempt 1: Add probe fails with interactionNotAllowed -> fail closed
        #expect(throws: KeychainError.self) {
            _ = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        }

        // Attempt 2: Add probe succeeds, but copyMatching probe fails with authFailed -> fail closed
        #expect(throws: KeychainError.self) {
            _ = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        }

        // Attempt 3: Probe succeeds completely -> access group resolved and cached, retrieve succeeds
        let firstRead = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        #expect(firstRead == Data("first-read".utf8))

        // Attempt 4: Success is cached -> subsequent operation succeeds without re-probing
        let secondRead = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        #expect(secondRead == Data("second-read".utf8))
    }

    @Test("default access group cache is instance-isolated")
    func defaultAccessGroupCacheIsInstanceIsolated() throws {
        // Store A fails closed
        let recorderA = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecInteractionNotAllowed],
            addStatuses: [errSecInteractionNotAllowed]
        )
        let storeA = AppleKeychainStore(operations: recorderA.operations)

        // Store B succeeds
        let probeAttrs: [String: Any] = [kSecAttrAccessGroup as String: "TEAM12345.blue.catbird.isolated"]
        let recorderB = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess, errSecSuccess],
            copyMatchingResults: [probeAttrs as CFDictionary, Data("isolated-data".utf8) as CFData],
            updateStatuses: [errSecSuccess],
            addStatuses: [errSecSuccess]
        )
        let storeB = AppleKeychainStore(operations: recorderB.operations)

        // Store B can retrieve and resolves group
        let retrievedB = try storeB.retrieve(key: "item", namespace: "test", accessGroup: nil)
        #expect(retrievedB == Data("isolated-data".utf8))

        // Store A still fails closed without cross-instance cache contamination
        #expect(throws: KeychainError.self) {
            _ = try storeA.retrieve(key: "item", namespace: "test", accessGroup: nil)
        }
    }

    @Test("probe cleanup failure does not prevent successful access group resolution")
    func probeCleanupFailureDoesNotPreventSuccessfulResolution() throws {
        let probeAttrs: [String: Any] = [kSecAttrAccessGroup as String: "TEAM12345.blue.catbird.deletefail"]
        let recorder = KeychainOperationRecorder(
            copyMatchingStatuses: [errSecSuccess, errSecSuccess],
            copyMatchingResults: [probeAttrs as CFDictionary, Data("sample-cleanup".utf8) as CFData],
            updateStatuses: [errSecSuccess],
            addStatuses: [errSecSuccess],
            deleteStatuses: [errSecAuthFailed]
        )
        let store = AppleKeychainStore(operations: recorder.operations)

        let retrieved = try store.retrieve(key: "item", namespace: "test", accessGroup: nil)
        #expect(retrieved == Data("sample-cleanup".utf8))
        #expect(recorder.calls.contains(.delete))
    }
}

private final class KeychainOperationRecorder: @unchecked Sendable {
    enum Call: Equatable { case copyMatching, update, add, delete }

    private(set) var calls: [Call] = []
    private(set) var lastUpdateData: Data?
    private(set) var copyMatchingQueries: [[String: Any]] = []
    private(set) var updateQueries: [([String: Any], [String: Any])] = []
    private(set) var addQueries: [[String: Any]] = []
    private(set) var deleteQueries: [[String: Any]] = []

    private var copyMatchingStatuses: [OSStatus]
    private var copyMatchingResults: [CFTypeRef?]
    private var updateStatuses: [OSStatus]
    private var addStatuses: [OSStatus]
    private var deleteStatuses: [OSStatus]

    init(
        copyMatchingStatuses: [OSStatus] = [],
        copyMatchingResults: [CFTypeRef?] = [],
        updateStatuses: [OSStatus] = [],
        addStatuses: [OSStatus] = [],
        deleteStatuses: [OSStatus] = []
    ) {
        self.copyMatchingStatuses = copyMatchingStatuses
        self.copyMatchingResults = copyMatchingResults
        self.updateStatuses = updateStatuses
        self.addStatuses = addStatuses
        self.deleteStatuses = deleteStatuses
    }

    var operations: AppleKeychainStore.Operations {
        AppleKeychainStore.Operations(
            copyMatching: { [self] query, result in
                calls.append(.copyMatching)
                if let dict = query as? [String: Any] {
                    copyMatchingQueries.append(dict)
                }
                if let result {
                    result.pointee = copyMatchingResults.isEmpty ? nil : copyMatchingResults.removeFirst()
                }
                return copyMatchingStatuses.isEmpty ? errSecSuccess : copyMatchingStatuses.removeFirst()
            },
            update: { [self] query, attributes in
                calls.append(.update)
                let qDict = (query as? [String: Any]) ?? [:]
                let aDict = (attributes as? [String: Any]) ?? [:]
                updateQueries.append((qDict, aDict))
                lastUpdateData = (attributes as NSDictionary)[kSecValueData as String] as? Data
                return updateStatuses.isEmpty ? errSecSuccess : updateStatuses.removeFirst()
            },
            add: { [self] query, _ in
                calls.append(.add)
                if let dict = query as? [String: Any] {
                    addQueries.append(dict)
                }
                return addStatuses.isEmpty ? errSecSuccess : addStatuses.removeFirst()
            },
            delete: { [self] query in
                calls.append(.delete)
                if let dict = query as? [String: Any] {
                    deleteQueries.append(dict)
                }
                return deleteStatuses.isEmpty ? errSecSuccess : deleteStatuses.removeFirst()
            }
        )
    }
}

#endif
