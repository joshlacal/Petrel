//
//  SafeDecoder.swift
//  Petrel
//
//  Created by Josh LaCalamito on 3/13/25.
//

import Foundation

public enum RecursionGuard: Sendable {
    /// Configurable threshold that can be adjusted at runtime
    public static let threshold: Int = 10

    /// Debug mode to log deep recursion detections
    public static let debugMode: Bool = false
}

public enum SafeDecoder {
    /// Smart decoder that only uses async decoding when necessary
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data, depth: Int = 0) async throws -> T {
        // Only use detached task for deep structures to avoid unnecessary overhead
        if depth > RecursionGuard.threshold {
            if RecursionGuard.debugMode {
                print("⚠️ Deep recursion detected (depth: \(depth)). Using isolated decoding for \(T.self)")
            }

            return try await withCheckedThrowingContinuation { continuation in
                Task.detached(priority: .userInitiated) {
                    do {
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(type, from: data)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } else {
            // Use standard decoding for shallow structures
            return try JSONDecoder().decode(type, from: data)
        }
    }

    /// Version with timeout protection for very complex structures
    public static func decodeWithTimeout<T: Decodable & Sendable>(_ type: T.Type, from data: Data, depth: Int = 0, timeout: TimeInterval = 5.0) async throws -> T {
        if depth <= RecursionGuard.threshold {
            // No need for timeout protection on shallow structures
            return try JSONDecoder().decode(type, from: data)
        }

        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the decoding task
            group.addTask {
                try await decode(type, from: data, depth: depth)
            }

            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Decoding of \(T.self) timed out after \(timeout) seconds"
                ))
            }

            // Return the first result (either decoded data or timeout)
            let result = try await group.next()!
            group.cancelAll() // Cancel any remaining tasks
            return result
        }
    }
}
