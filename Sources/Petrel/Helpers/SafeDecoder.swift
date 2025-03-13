//
//  SafeDecoder.swift
//  Petrel
//
//  Created by Josh LaCalamito on 3/13/25.
//


// SafeDecoder.swift
import Foundation

public enum SafeDecoder {
    public static func decodeAsync<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        // Force decoding to happen on a fresh stack with its own memory
        return try await withCheckedThrowingContinuation { continuation in
            Task(priority: .userInitiated) {
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(type, from: data)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}