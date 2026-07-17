import Foundation

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
