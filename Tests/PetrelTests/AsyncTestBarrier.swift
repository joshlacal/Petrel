import Foundation
import Synchronization

struct TimeoutError: Error, CustomStringConvertible, Sendable {
    var description: String { "Timed out waiting for synchronization point" }
}

/// Single-shot asynchronous barrier with bounded wait, built on a locked,
/// single-resume continuation that carries its own success-or-timeout result.
final class AsyncBarrier: @unchecked Sendable {
    private struct State {
        var isSignaled = false
        var timedOut = false
        var waiters: [CheckedContinuation<Bool, Never>] = []
    }

    private let state = Mutex<State>(State())

    func signal() {
        let list = state.withLock { s -> [CheckedContinuation<Bool, Never>] in
            if s.isSignaled || s.timedOut {
                return []
            }
            s.isSignaled = true
            let list = s.waiters
            s.waiters.removeAll()
            return list
        }
        for w in list {
            w.resume(returning: true)
        }
    }

    func wait(timeoutNanoseconds: UInt64 = 5_000_000_000, onTimeout: (@Sendable () -> Void)? = nil) async throws -> Bool {
        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let immediateResult: Bool? = state.withLock { s in
                if s.isSignaled {
                    return true
                }
                if s.timedOut {
                    return false
                }
                s.waiters.append(continuation)
                return nil
            }

            if let result = immediateResult {
                continuation.resume(returning: result)
                return
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                let list = self.state.withLock { s -> [CheckedContinuation<Bool, Never>] in
                    guard !s.isSignaled, !s.timedOut else {
                        return []
                    }
                    s.timedOut = true
                    let pending = s.waiters
                    s.waiters.removeAll()
                    return pending
                }
                for w in list {
                    w.resume(returning: false)
                }
            }
        }
        if !success {
            onTimeout?()
        }
        return success
    }

    func waitUntilSignaled(timeoutNanoseconds: UInt64 = 5_000_000_000, onTimeout: (@Sendable () -> Void)? = nil) async throws {
        let signaled = try await wait(timeoutNanoseconds: timeoutNanoseconds, onTimeout: onTimeout)
        guard signaled else {
            throw TimeoutError()
        }
    }
}

/// Blocks one synchronous storage retrieval until the test releases it,
/// backed by `AsyncBarrier` with bounded, non-hanging waits.
final class RetrievalGate: @unchecked Sendable {
    private let barrier = AsyncBarrier()
    private let releaseSemaphore = DispatchSemaphore(value: 0)
    private let consumed = Mutex<Bool>(false)

    func enter() {
        let shouldSignal = consumed.withLock { isConsumed -> Bool in
            if isConsumed {
                return false
            }
            isConsumed = true
            return true
        }
        if !shouldSignal {
            return
        }
        barrier.signal()
        releaseSemaphore.wait()
    }

    func waitUntilHeld(timeoutNanoseconds: UInt64 = 5_000_000_000) async throws {
        do {
            try await barrier.waitUntilSignaled(timeoutNanoseconds: timeoutNanoseconds)
        } catch {
            release()
            throw error
        }
    }

    func release() {
        releaseSemaphore.signal()
    }
}
