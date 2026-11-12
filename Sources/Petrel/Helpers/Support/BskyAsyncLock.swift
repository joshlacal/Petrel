import Foundation

/// A FIFO async mutex. Used to serialize read-modify-write cycles (for example
/// preference updates) so two concurrent setters cannot overwrite each other.
actor BskyAsyncLock {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init() {}

    private func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// Runs `body` while holding the lock. The lock is released on return and on throw.
    nonisolated func withLock<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        do {
            let result = try await body()
            await release()
            return result
        } catch {
            await release()
            throw error
        }
    }
}

/// Hands out one ``BskyAsyncLock`` per ``NetworkService``.
///
/// ``BskyAgent`` is a lightweight value created on every `client.bsky` access,
/// so the lock that serializes preference writes cannot live in the agent
/// itself. Keying it on the network service gives every agent of one client the
/// same lock.
// @unchecked Sendable: `entries` is read and written only under `guardLock`.
final class BskyAsyncLockRegistry: @unchecked Sendable {
    static let shared = BskyAsyncLockRegistry()

    private struct Entry {
        weak var owner: NetworkService?
        let lock: BskyAsyncLock
    }

    private let guardLock = NSLock()
    private var entries: [ObjectIdentifier: Entry] = [:]

    func lock(for networkService: NetworkService) -> BskyAsyncLock {
        guardLock.withLock {
            entries = entries.filter { $0.value.owner != nil }
            let key = ObjectIdentifier(networkService)
            if let entry = entries[key] {
                return entry.lock
            }
            let lock = BskyAsyncLock()
            entries[key] = Entry(owner: networkService, lock: lock)
            return lock
        }
    }
}
