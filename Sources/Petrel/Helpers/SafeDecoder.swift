import Foundation

/// Key for accessing original data in a decoder's userInfo
extension CodingUserInfoKey {
  static let originalData = CodingUserInfoKey(rawValue: "originalData")!
  static let debugEnabled = CodingUserInfoKey(rawValue: "debugEnabled")!
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
  /// Log messages when debug mode is enabled
  private static func debugLog(_ message: String, data: Data? = nil, forceOutput: Bool = false)
    async
  {
    let debugMode = await DecodingConfigurationManager.shared.getConfiguration().debugMode
    if forceOutput || debugMode {
      print("🔍 SafeDecoder: \(message)")
      if let data = data, data.count < 10000 {
        if let json = try? JSONSerialization.jsonObject(with: data),
          let prettyData = try? JSONSerialization.data(
            withJSONObject: json, options: .prettyPrinted),
          let prettyString = String(data: prettyData, encoding: .utf8)
        {
          print("📄 JSON Content:\n\(prettyString)")
        } else {
          print("⚠️ Unable to pretty-print JSON - showing raw data")
          print(String(data: data, encoding: .utf8) ?? "Invalid UTF-8 data")
        }
      }
    }
  }

  /// Examine and log if specific fields exist in the JSON
  public static func checkFieldExistence(in data: Data, fields: [String], forceOutput: Bool = true)
  {
    do {
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("❌ JSON is not a dictionary at root level")
        return
      }

      print("🔎 Field existence check in JSON:")
      for field in fields {
        let exists = json[field] != nil
        print("   - \"\(field)\": \(exists ? "✅ EXISTS" : "❌ MISSING")")

        if exists {
          let value = json[field]
          if let valueData = try? JSONSerialization.data(withJSONObject: value as Any),
            let valueStr = String(data: valueData, encoding: .utf8)
          {
            print("     Value: \(valueStr.prefix(100))\(valueStr.count > 100 ? "..." : "")")
          } else {
            print("     Value: \(String(describing: value).prefix(100))")
          }
        } else {
          print("     Available keys: \(json.keys.sorted().joined(separator: ", "))")
        }
      }
    } catch {
      print("❌ Error parsing JSON to check fields: \(error)")
    }
  }

  /// Decode JSON data into a model safely
  public static func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
    await debugLog("Starting to decode \(String(describing: type))", data: data)

    // Create decoder with the original data in userInfo
    let decoder = JSONDecoder()
    decoder.userInfo[.originalData] = data
    decoder.userInfo[.debugEnabled] = true

    do {
      await debugLog("Attempting standard decoding")
      let result = try decoder.decode(type, from: data)
      await debugLog("✅ Standard decoding succeeded")
      return result
    } catch {
      await debugLog("⚠️ Standard decoding failed: \(error)", forceOutput: true)

      // Log specific details for key not found errors
      if let decodingError = error as? DecodingError {
        switch decodingError {
        case .keyNotFound(let key, let context):
          await debugLog(
            "🔑 Missing key: \"\(key.stringValue)\" at path: \(context.codingPath.map { $0.stringValue })",
            forceOutput: true)
          // Try to print the surrounding structure
          if let contextData = try? extractNestedJSON(
            from: data, atPath: context.codingPath.dropLast().map { $0.stringValue })
          {
            await debugLog("📍 Parent context:", data: contextData, forceOutput: true)
            checkFieldExistence(in: contextData, fields: [key.stringValue])
          }
        case .typeMismatch(let type, let context):
          await debugLog(
            "📊 Type mismatch: Expected \(type) at path: \(context.codingPath.map { $0.stringValue })",
            forceOutput: true)
        default:
          await debugLog("🚫 Other decoding error: \(decodingError)", forceOutput: true)
        }
      }

      // For complex failures, try the detached task approach
      await debugLog("↪️ Attempting fallback with detached task")
      return try await withCheckedThrowingContinuation { continuation in
        Task.detached {
          do {
            // Create a fresh decoder in a detached task
            let isolatedDecoder = JSONDecoder()
            isolatedDecoder.userInfo[.originalData] = data
            isolatedDecoder.userInfo[.debugEnabled] = true
            let result = try isolatedDecoder.decode(type, from: data)
            await debugLog("✅ Detached task decoding succeeded")
            continuation.resume(returning: result)
          } catch {
            await debugLog("❌ Detached task decoding also failed: \(error)", forceOutput: true)
            continuation.resume(throwing: error)
          }
        }
      }
    }
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
        try await decode(type, from: data)
      }

      // Add a timeout task
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: [],
            debugDescription: "Decoding of \(T.self) timed out after \(timeout) seconds"
          ))
      }

      // Return the first result (either decoded data or timeout)
      let result = try await group.next()!
      group.cancelAll()  // Cancel any remaining tasks
      return result
    }
  }

  /// Extracts a portion of JSON data based on coding path
  public static func extractNestedJSON(from data: Data, at path: [CodingKey]) throws -> Data? {
    return try extractNestedJSON(from: data, atPath: path.map { $0.stringValue })
  }

  /// Extracts a portion of JSON data based on string path
  public static func extractNestedJSON(from data: Data, atPath path: [String]) throws -> Data {
    guard !path.isEmpty else { return data }

    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    var currentObject: Any = jsonObject
    var currentPath = ""

    for (index, key) in path.enumerated() {
      currentPath += (index > 0 ? "." : "") + key

      if let dict = currentObject as? [String: Any] {
        if let value = dict[key] {
          currentObject = value
          print("✓ Found key '\(key)' at path '\(currentPath)'")
        } else {
          print("❌ Key '\(key)' not found at path '\(currentPath)'")
          print("📋 Available keys: \(dict.keys.sorted().joined(separator: ", "))")
          throw DecodingError.keyNotFound(
            _CustomCodingKey(key),
            DecodingError.Context(
              codingPath: path.prefix(index).map { _CustomCodingKey($0) },
              debugDescription: "Key '\(key)' not found in JSON"
            ))
        }
      } else if let array = currentObject as? [Any], let index = Int(key), index < array.count {
        currentObject = array[index]
        print("✓ Found index \(index) at path '\(currentPath)'")
      } else {
        print(
          "❌ Cannot navigate path '\(currentPath)': expected dictionary or array, got \(type(of: currentObject))"
        )
        throw DecodingError.typeMismatch(
          [String: Any].self,
          DecodingError.Context(
            codingPath: path.prefix(index).map { _CustomCodingKey($0) },
            debugDescription:
              "Expected dictionary at path '\(currentPath)', but found \(type(of: currentObject))"
          ))
      }
    }

    return try JSONSerialization.data(withJSONObject: currentObject)
  }

  /// Load nested data from a pending object
  public static func loadPendingObject<T: Decodable>(
    pendingData: PendingDecodeData, expectedType: String
  ) async -> T? {
    await debugLog("Loading pending object, expected type: \(expectedType)")

    // Ensure we have the correct type
    guard pendingData.type == expectedType else {
      print("❌ Type mismatch: expected \(expectedType) but found \(pendingData.type)")
      return nil
    }

    do {
      await debugLog("Decoding pending data", data: pendingData.rawData)
      return try await decode(T.self, from: pendingData.rawData)
    } catch {
      print("❌ Failed to decode pending data: \(error)")
      return nil
    }
  }

  /// Check if a JSON object has deeply nested structures that might cause stack overflow
  public static func hasDeepNesting(in data: Data, maxDepth: Int = 20) -> Bool {
    do {
      let object = try JSONSerialization.jsonObject(with: data, options: [])
      return checkDepth(of: object, currentDepth: 0, maxDepth: maxDepth)
    } catch {
      return false
    }
  }

  private static func checkDepth(of object: Any, currentDepth: Int, maxDepth: Int) -> Bool {
    // If we're already at max depth, no need to check further
    if currentDepth >= maxDepth {
      return true
    }

    if let dict = object as? [String: Any] {
      // Check each value in the dictionary
      for (_, value) in dict {
        if checkDepth(of: value, currentDepth: currentDepth + 1, maxDepth: maxDepth) {
          return true
        }
      }
    } else if let array = object as? [Any] {
      // Check each item in the array
      for item in array {
        if checkDepth(of: item, currentDepth: currentDepth + 1, maxDepth: maxDepth) {
          return true
        }
      }
    }

    return false
  }

  /// Helper to dump JSON structure with types to debug missing fields
  public static func dumpJSONStructure(data: Data, maxDepth: Int = 5) {
    do {
      let json = try JSONSerialization.jsonObject(with: data)
      print("\n📊 JSON Structure:")
      dumpStructure(json, prefix: "", depth: 0, maxDepth: maxDepth)
    } catch {
      print("❌ Failed to parse JSON for structure dump: \(error)")
    }
  }

  private static func dumpStructure(_ object: Any, prefix: String, depth: Int, maxDepth: Int) {
    if depth >= maxDepth {
      print("\(prefix)⚠️ Max depth reached")
      return
    }

    if let dict = object as? [String: Any] {
      print("\(prefix)📁 Object with \(dict.count) keys")
      for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
        print("\(prefix)  🔑 \"\(key)\" (\(type(of: value)))")
        dumpStructure(value, prefix: "\(prefix)    ", depth: depth + 1, maxDepth: maxDepth)
      }
    } else if let array = object as? [Any] {
      print("\(prefix)📚 Array with \(array.count) items")
      if !array.isEmpty {
        print("\(prefix)  📌 First item (\(type(of: array.first!))):")
        dumpStructure(array.first!, prefix: "\(prefix)    ", depth: depth + 1, maxDepth: maxDepth)
        if array.count > 1 {
          print("\(prefix)  ... and \(array.count - 1) more items")
        }
      }
    } else {
      let valueStr = "\(object)"
      print("\(prefix)📄 Value: \(valueStr.count > 50 ? valueStr.prefix(50) + "..." : valueStr)")
    }
  }
}

// Helper for creating coding keys from strings
private struct _CustomCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init(_ string: String) {
    self.stringValue = string
    self.intValue = Int(string)
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = Int(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
