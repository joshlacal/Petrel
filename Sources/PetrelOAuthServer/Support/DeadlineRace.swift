import Foundation

/// Races an asynchronous operation against a deadline timer using an unstructured
/// deadline relay.
///
/// Unlike structured task groups (which wait for all child tasks to complete before
/// returning or throwing), this unstructured relay completes immediately upon either
/// successful operation completion, deadline expiry, or caller cancellation. When
/// the deadline timer expires, the operation task is cancelled and the caller is
/// resumed immediately with the specified `expiry` error without waiting for an
/// uncooperative or blocked child task to exit.
func oauthRaceWithDeadline<T: Sendable>(
    seconds: Double,
    onExpiry expiry: any Error,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    precondition(seconds > 0)
    let relay = OAuthDeadlineRelay<T>()
    let operationTask = Task {
        do {
            relay.complete(.success(try await operation()))
        } catch {
            relay.complete(.failure(error))
        }
    }
    let nanoseconds = UInt64((seconds * 1_000_000_000).rounded(.up))
    let timeoutTask = Task {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }
        relay.complete(.failure(expiry))
        operationTask.cancel()
    }
    defer {
        operationTask.cancel()
        timeoutTask.cancel()
    }
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            relay.install(continuation)
        }
    } onCancel: {
        relay.complete(.failure(CancellationError()))
        operationTask.cancel()
        timeoutTask.cancel()
    }
}

private final class OAuthDeadlineRelay<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            resume(continuation, with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func complete(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        if let continuation { resume(continuation, with: result) }
    }

    private func resume(
        _ continuation: CheckedContinuation<Value, Error>,
        with result: Result<Value, Error>
    ) {
        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
