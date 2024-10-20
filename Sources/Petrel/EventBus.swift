//
//  EventBus.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/17/24.
//

import Foundation

/// A centralized EventBus for publishing and subscribing to events.
actor EventBus {
    static let shared = EventBus()

    /// List of active continuations for all subscribers.
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    private init() {}

    /// Publishes an event to all active subscribers.
    func publish(_ event: Event) {
        for (_, continuation) in continuations {
            continuation.yield(event)
        }
    }

    /// Subscribes to the EventBus and returns a unique AsyncStream<Event> for the subscriber.
    ///
    /// - Returns: An `AsyncStream<Event>` that emits events as they are published.
    func subscribe() -> AsyncStream<Event> {
        let id = UUID()
        let stream = AsyncStream<Event> { continuation in
            // Add the continuation to the list
            continuations[id] = continuation

            // Remove the continuation when the stream is terminated
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
        return stream
    }

    /// Removes a continuation based on its UUID.
    ///
    /// - Parameter id: The UUID of the continuation to remove.
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
