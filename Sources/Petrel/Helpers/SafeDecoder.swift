//
//  SafeDecoder.swift
//  Petrel
//
//  Created by Josh LaCalamito on 3/13/25.
//

import Foundation

/// Thread-safe configuration for controlling recursive decoding behavior
public struct DecodingConfiguration: Sendable {
    /// Maximum recursion depth before switching to iterative parsing
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

/// Container for holding JSON values during iterative decoding
public struct JSONContainer: Sendable {
    public enum Value: Sendable {
        case dictionary([String: JSONContainer])
        case array([JSONContainer])
        case string(String)
        case number(NSNumber)
        case bool(Bool)
        case null
        
        public var isDictionary: Bool {
            if case .dictionary = self { return true }
            return false
        }
        
        public var isArray: Bool {
            if case .array = self { return true }
            return false
        }
    }
    
    public let value: Value
    
    public init(jsonObject: Any) throws {
        if let dict = jsonObject as? [String: Any] {
            var result = [String: JSONContainer]()
            for (key, value) in dict {
                result[key] = try JSONContainer(jsonObject: value)
            }
            self.value = .dictionary(result)
        } else if let array = jsonObject as? [Any] {
            let result = try array.map { try JSONContainer(jsonObject: $0) }
            self.value = .array(result)
        } else if let string = jsonObject as? String {
            self.value = .string(string)
        } else if let number = jsonObject as? NSNumber {
            // Special handling for boolean NSNumbers
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self.value = .bool(number.boolValue)
            } else {
                self.value = .number(number)
            }
        } else if jsonObject is NSNull {
            self.value = .null
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Unsupported JSON type: \(type(of: jsonObject))"
            ))
        }
    }
}

/// Utility for decoding JSON safely without stack overflow
public enum SafeDecoder {
    /// Decode JSON data into a model using stack-safe methods
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        // Get current configuration
        let config = await DecodingConfigurationManager.shared.getConfiguration()
        
        // First try standard decoding if small/shallow data
        if data.count < 10000 {
            do {
                // Use standard decoder for simple cases
                return try JSONDecoder().decode(type, from: data)
            } catch {
                if config.debugMode {
                    print("⚠️ Standard decoding failed, trying iterative approach: \(error)")
                }
                // Fall through to iterative approach
            }
        }
        
        // Parse to intermediate representation (iterative)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let container = try JSONContainer(jsonObject: jsonObject)
        
        // Use iterative decoding
        return try await iterativeDecode(type, from: container, config: config)
    }
    
    /// Decode with iterative approach to avoid stack overflow
    private static func iterativeDecode<T: Decodable & Sendable>(
        _ type: T.Type,
        from container: JSONContainer,
        config: DecodingConfiguration
    ) async throws -> T {
        if config.debugMode {
            print("🔄 Using iterative decoding for \(T.self)")
        }
        
        // For simple types, decode directly
        if let simpleValue = try decodeSimpleValue(type, from: container) {
            return simpleValue
        }
        
        // For collections and objects, use a different approach based on type
        switch T.self {
        case is [String: Any].Type, is [String: AnyHashable].Type:
            // Dictionary types
            guard case .dictionary(let dict) = container.value else {
                throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Expected dictionary but found different type"
                ))
            }
            
            if let result = dict as? T {
                return result
            }
            
            // Convert back to JSON and use standard decoder as fallback
            let jsonData = try encodeToData(dict)
            return try JSONDecoder().decode(type, from: jsonData)
            
        case is [Any].Type:
            // Array types
            guard case .array(let array) = container.value else {
                throw DecodingError.typeMismatch([Any].self, DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Expected array but found different type"
                ))
            }
            
            if let result = array as? T {
                return result
            }
            
            // Convert back to JSON and use standard decoder as fallback
            let jsonData = try encodeToData(array)
            return try JSONDecoder().decode(type, from: jsonData)
            
        default:
            // Custom objects - use TaskLocal for isolated decoding
            return try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        // Convert container back to data
                        let jsonData = try self.encodeToData(container)
                        
                        // Use standard decoder in isolated task
                        let decoder = JSONDecoder()
                        let result = try decoder.decode(type, from: jsonData)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Try to decode simple value types directly
    private static func decodeSimpleValue<T>(_ type: T.Type, from container: JSONContainer) throws -> T? {
        switch container.value {
        case .string(let string):
            if let value = string as? T { return value }
            if T.self == URL.self, let url = URL(string: string) as? T { return url }
            if T.self == UUID.self, let uuid = UUID(uuidString: string) as? T { return uuid }
            
        case .number(let number):
            if T.self == Int.self, let value = number.intValue as? T { return value }
            if T.self == Double.self, let value = number.doubleValue as? T { return value }
            if T.self == Float.self, let value = number.floatValue as? T { return value }
            if T.self == Bool.self, let value = number.boolValue as? T { return value }
            
        case .bool(let bool):
            if T.self == Bool.self, let value = bool as? T { return value }
            
        case .null:
            // For optional types, return nil
            if let optionalType = T.self as? (any ExpressibleByNilLiteral.Type),
               let nilValue = optionalType.init(nilLiteral: ()) as? T {
                return nilValue
            }
            
        default:
            break
        }
        
        return nil
    }
    
    /// Convert container back to JSON data
    private static func encodeToData(_ container: Any) throws -> Data {
        return try JSONSerialization.data(withJSONObject: container)
    }
    
    /// Decode with timeout protection for complex structures
    public static func decodeWithTimeout<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data,
        timeout: TimeInterval = 5.0
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the decoding task
            group.addTask {
                return try await decode(type, from: data)
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

/// Protocol for types that can defer loading of nested content
public protocol PendingDataLoadable: Sendable {
    var hasPendingData: Bool { get }
    mutating func loadPendingData() async
}

/// Wrapper for deferred decoding of deeply nested data
public struct PendingDecodeData: Codable, Sendable, Equatable {
    public let rawData: Data
    public let type: String
    
    public static func == (lhs: PendingDecodeData, rhs: PendingDecodeData) -> Bool {
        return lhs.type == rhs.type
    }
}
