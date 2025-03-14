import Foundation

/// Key for accessing original data in a decoder's userInfo
extension CodingUserInfoKey {
    static let originalData = CodingUserInfoKey(rawValue: "originalData")!
}

/// Thread-safe configuration for controlling recursive decoding behavior
public struct DecodingConfiguration: Sendable {
    /// Maximum recursion depth before switching to deferred parsing
    public let threshold: Int
    /// Whether to log detailed information about deep recursion detection
    public let debugMode: Bool

    /// Default configuration
    public static let standard = DecodingConfiguration(threshold: 10, debugMode: false)

    /// Create a custom configuration
    public init(threshold: Int, debugMode: Bool = false) {
        self.threshold = threshold
        self.debugMode = debugMode
    }
}

/// Actor that provides thread-safe access to the current configuration
public actor DecodingConfigurationManager {
    /// Shared instance for global configuration
    public static let shared = DecodingConfigurationManager()

    /// Current configuration
    private var configuration = DecodingConfiguration.standard

    /// Update the configuration
    public func updateConfiguration(_ newConfig: DecodingConfiguration) {
        configuration = newConfig
    }

    /// Get the current configuration
    public func getConfiguration() -> DecodingConfiguration {
        return configuration
    }
}

/// Protocol for types that can defer loading of nested content
public protocol PendingDataLoadable: Sendable {
    var hasPendingData: Bool { get }
    mutating func loadPendingData() async
}

/// Wrapper for deferred decoding of deeply nested data
public struct PendingDecodeData: Codable, Sendable, Equatable {
    public let rawData: Data
    public let type: String
    
    public init(rawData: Data, type: String) {
        self.rawData = rawData
        self.type = type
    }

    public static func == (lhs: PendingDecodeData, rhs: PendingDecodeData) -> Bool {
        return lhs.type == rhs.type
    }
}

/// Utility for decoding JSON safely without stack overflow
public enum SafeDecoder {
    /// Decode JSON data into a model safely
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        // Create decoder with the original data in userInfo
        let decoder = JSONDecoder()
        decoder.userInfo[.originalData] = data
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            if await DecodingConfigurationManager.shared.getConfiguration().debugMode {
                print("🔍 Standard decoding failed, error: \(error)")
            }
            
            // For complex failures, try the detached task approach
            return try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        // Create a fresh decoder in a detached task
                        let isolatedDecoder = JSONDecoder()
                        isolatedDecoder.userInfo[.originalData] = data
                        let result = try isolatedDecoder.decode(type, from: data)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Extracts a portion of JSON data based on coding path
    public static func extractNestedJSON(from data: Data, at path: [CodingKey]) throws -> Data? {
        guard !path.isEmpty else { return data }
        
        // Parse the original JSON
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        // Navigate to the nested location
        var currentObject: Any = jsonObject
        for key in path {
            if let keyIndex = key.intValue {
                // Handle array indexing
                guard let array = currentObject as? [Any], keyIndex < array.count else {
                    return nil
                }
                currentObject = array[keyIndex]
            } else {
                // Handle dictionary key access
                guard let dict = currentObject as? [String: Any],
                      let value = dict[key.stringValue] else {
                    return nil
                }
                currentObject = value
            }
        }
        
        // Convert the nested object back to JSON data
        return try JSONSerialization.data(withJSONObject: currentObject)
    }
    
    /// Decode with timeout protection for complex structures
    public static func decodeWithTimeout<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        timeout: TimeInterval = 5.0
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the decoding task
            group.addTask {
                try await decode(type, from: data)
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
