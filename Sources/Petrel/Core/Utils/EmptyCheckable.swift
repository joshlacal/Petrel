import Foundation

/// A protocol for types that have custom logic for determining if they're empty
/// This is used by union types to determine whether they should be encoded
public protocol EmptyCheckable {
  /// Returns true if the value should be considered empty for encoding purposes
  var isEmpty: Bool { get }
}

// Make standard Swift collection types conform to EmptyCheckable
// This is redundant since we already check for Collection protocol,
// but it's included for clarity and future-proofing
extension Array: EmptyCheckable {}
extension Dictionary: EmptyCheckable {}
extension Set: EmptyCheckable {}
extension String: EmptyCheckable {}
