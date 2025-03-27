import Foundation

/// Protocol for types that can contain pending data that needs to be loaded
public protocol PendingDataLoadable {
    /// Indicates if this object contains any pending data that needs loading
    var hasPendingData: Bool { get }

    /// Attempts to load any pending data in this object
    mutating func loadPendingData() async
}

// Default implementation for non-recursive types
public extension PendingDataLoadable {
    /// Default implementation for types that don't have pending data
    var hasPendingData: Bool {
        return false
    }

    /// Default empty implementation for types that don't have pending data
    mutating func loadPendingData() async {
        // No pending data to load
    }
}

// MARK: - Basic types conformance

// These types never have pending data, but might be contained in unions

extension String: PendingDataLoadable {}
extension Int: PendingDataLoadable {}
extension Bool: PendingDataLoadable {}
extension Double: PendingDataLoadable {}
extension Date: PendingDataLoadable {}
extension URL: PendingDataLoadable {}
extension Data: PendingDataLoadable {}
extension UUID: PendingDataLoadable {}

// MARK: - Collection conformance

extension Array: PendingDataLoadable where Element: PendingDataLoadable {
    public var hasPendingData: Bool {
        return contains { $0.hasPendingData }
    }

    public mutating func loadPendingData() async {
        for i in indices where self[i].hasPendingData {
            var element = self[i]
            await element.loadPendingData()
            self[i] = element
        }
    }
}

extension Dictionary: PendingDataLoadable where Value: PendingDataLoadable {
    public var hasPendingData: Bool {
        return values.contains { $0.hasPendingData }
    }

    public mutating func loadPendingData() async {
        for key in keys where self[key]?.hasPendingData == true {
            if var value = self[key] {
                await value.loadPendingData()
                self[key] = value
            }
        }
    }
}

extension Optional: PendingDataLoadable where Wrapped: PendingDataLoadable {
    public var hasPendingData: Bool {
        switch self {
        case let .some(value):
            return value.hasPendingData
        case .none:
            return false
        }
    }

    public mutating func loadPendingData() async {
        switch self {
        case var .some(value) where value.hasPendingData:
            await value.loadPendingData()
            self = .some(value)
        default:
            break
        }
    }
}
