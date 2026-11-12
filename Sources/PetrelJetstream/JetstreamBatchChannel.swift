import Foundation
import PetrelFirehose

/// Bounded hand-off between `JetstreamClient`'s producer task and the consumer's iteration.
///
/// `yield` suspends while the buffer is full, so backfill and the live socket advance only as
/// fast as the consumer. The cursor of a batch is saved when the consumer asks for the next
/// one, which is the earliest point at which the batch is known to have been processed.
actor JetstreamBatchChannel {
  private let capacity: Int
  private let cursorStorage: (any FirehoseCursorStorage)?
  private var buffer: [JetstreamBatch] = []
  private var finished = false
  private var failure: (any Error)?
  private var producerWaiters: [CheckedContinuation<Void, Never>] = []
  private var consumerWaiter: CheckedContinuation<Void, Never>?
  private var deliveredCursor: Int64?
  private var savedCursor: Int64 = 0

  init(capacity: Int, cursorStorage: (any FirehoseCursorStorage)?) {
    self.capacity = max(1, capacity)
    self.cursorStorage = cursorStorage
  }

  /// Producer side. Returns once the batch is buffered, or immediately after the consumer left.
  func yield(_ batch: JetstreamBatch) async {
    while buffer.count >= capacity, !finished {
      await withCheckedContinuation { producerWaiters.append($0) }
    }
    guard !finished else { return }
    buffer.append(batch)
    resumeConsumer()
  }

  /// Producer side: no more batches. Buffered batches are still delivered.
  func finish(throwing error: (any Error)? = nil) {
    guard !finished else { return }
    finished = true
    failure = error
    resumeConsumer()
    resumeProducers()
  }

  /// Consumer side: the stream was cancelled or dropped.
  func cancel() {
    finished = true
    failure = nil
    buffer.removeAll()
    resumeConsumer()
    resumeProducers()
  }

  /// Consumer side.
  func next() async throws -> JetstreamBatch? {
    if let cursor = deliveredCursor {
      deliveredCursor = nil
      // Only sequence numbers move the watermark. A batch delivered before the first
      // sequenced event carries the starting cursor, which on the v2 API may still be a
      // unix-microsecond timestamp; persisting it would put the watermark above every
      // sequence number that follows, and nothing would be saved again.
      if cursor > savedCursor, cursor < JetstreamSubscriptionRunner.timestampCursorFloor {
        savedCursor = cursor
        try? await cursorStorage?.saveCursor(cursor)
      }
    }
    while true {
      if !buffer.isEmpty {
        let batch = buffer.removeFirst()
        deliveredCursor = batch.lastCursor
        if !producerWaiters.isEmpty {
          producerWaiters.removeFirst().resume()
        }
        return batch
      }
      if finished {
        if let failure {
          self.failure = nil
          throw failure
        }
        return nil
      }
      await withCheckedContinuation { consumerWaiter = $0 }
    }
  }

  private func resumeConsumer() {
    consumerWaiter?.resume()
    consumerWaiter = nil
  }

  private func resumeProducers() {
    let waiters = producerWaiters
    producerWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
  }
}

/// Cancels the producer when the consumer drops the stream without cancelling its task.
final class JetstreamProducerLifetime: Sendable {
  private let task: Task<Void, Never>
  private let channel: JetstreamBatchChannel

  init(task: Task<Void, Never>, channel: JetstreamBatchChannel) {
    self.task = task
    self.channel = channel
  }

  func next() async throws -> JetstreamBatch? {
    try await channel.next()
  }

  func cancel() {
    task.cancel()
    let channel = channel
    Task { await channel.cancel() }
  }

  deinit {
    cancel()
  }
}
