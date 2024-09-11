import Foundation

public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable {
    public let date: Date

    public var toDate: Date { date }

    public init(date: Date) {
        self.date = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        guard let date = Self.parse(dateString) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid AT Protocol datetime format: \(dateString)"
            )
        }

        self.date = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.format(date))
    }

    // MARK: - Parsing and Formatting

    // no concurrent modifications
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parse(_ dateString: String) -> Date? {
        // Try parsing with ISO8601DateFormatter first
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // If that fails, try with DateFormatter
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ", // Millisecond precision with Z
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ", // Microsecond precision with Z
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", // Millisecond precision with timezone offset
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", // Microsecond precision with timezone offset
            "yyyy-MM-dd'T'HH:mm:ssZ", // Whole seconds with Z
            "yyyy-MM-dd'T'HH:mm:ssXXXXX", // Whole seconds with timezone offset
            "yyyy-MM-dd'T'HH:mm:ss.SZ", // Single fractional second digit with Z
            "yyyy-MM-dd'T'HH:mm:ss.SXXXXX", // Single fractional second digit with timezone offset
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSSSSSZ", // Extended precision with Z
            "yyyy-MM-dd'T'HH:mm:ss.SSS", // Millisecond precision without timezone
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", // Microsecond precision without timezone
            "yyyy-MM-dd'T'HH:mm:ss", // Whole seconds without timezone
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private static func format(_ date: Date) -> String {
        var formatted = iso8601Formatter.string(from: date)

        // Ensure at least millisecond precision and pad with zeros
        if let dotIndex = formatted.firstIndex(of: ".") {
            let fractionalPart = formatted[dotIndex...].dropLast() // Drop the 'Z'
            let padLength = max(3, fractionalPart.count)
            formatted =
                String(formatted[..<dotIndex])
                    + fractionalPart.padding(toLength: padLength, withPad: "0", startingAt: 0) + "Z"
        } else {
            // If no fractional seconds, add .000
            formatted = String(formatted.dropLast()) + ".000Z"
        }

        return formatted
    }
}

// MARK: - Convenience Initializers and Methods

public extension ATProtocolDate {
    init?(iso8601String: String) {
        guard let date = Self.parse(iso8601String) else { return nil }
        self.init(date: date)
    }

    var iso8601String: String {
        Self.format(date)
    }
}

// MARK: - Comparable Conformance

extension ATProtocolDate: Comparable {
    public static func < (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date < rhs.date
    }
}

// import Foundation
// import RegexBuilder
//
// public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable {
//    public let date: Date
//
//    public var toDate: Date { date }
//
//    public init(date: Date) {
//        self.date = date
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let dateString = try container.decode(String.self)
//
//        guard let date = Self.parse(dateString) else {
//            throw DecodingError.dataCorruptedError(in: container,
//                debugDescription: "Invalid AT Protocol datetime format: \(dateString)")
//        }
//
//        self.date = date
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(Self.format(date))
//    }
//
//    // MARK: - Parsing and Formatting
//
//    private static let regex = try! Regex(#"^(\d{4})-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.(\d+))?(?:Z|([+-])(?:0\d|1[0-4]):([0-5]\d))$"#)
//
//    private static let formatter: ISO8601DateFormatter = {
//        let formatter = ISO8601DateFormatter()
//        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//        return formatter
//    }()
//
//    private static func parse(_ dateString: String) -> Date? {
//        guard dateString.wholeMatch(of: regex) != nil else { return nil }
//        return formatter.date(from: dateString)
//    }
//
//    private static func format(_ date: Date) -> String {
//        var formatted = formatter.string(from: date)
//
//        // Ensure at least millisecond precision and pad with zeros
//        if let dotIndex = formatted.firstIndex(of: ".") {
//            let fractionalPart = formatted[dotIndex...].dropLast() // Drop the 'Z'
//            let padLength = max(3, fractionalPart.count)
//            formatted = String(formatted[..<dotIndex]) +
//                        fractionalPart.padding(toLength: padLength, withPad: "0", startingAt: 0) +
//                        "Z"
//        } else {
//            // If no fractional seconds, add .000
//            formatted = String(formatted.dropLast()) + ".000Z"
//        }
//
//        return formatted
//    }
// }
//
//// MARK: - Convenience Initializers and Methods
//
// extension ATProtocolDate {
//    public init?(iso8601String: String) {
//        guard let date = Self.parse(iso8601String) else { return nil }
//        self.init(date: date)
//    }
//
//    public var iso8601String: String {
//        Self.format(date)
//    }
// }
//
//// MARK: - Comparable Conformance
//
// extension ATProtocolDate: Comparable {
//    public static func < (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
//        lhs.date < rhs.date
//    }
// }

// public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable {
//
//    public let date: Date
//
//    public var toDate: Date {
//        // Conversion logic here
//        // ATProtocolDate is a wrapper around Date:
//        return self.date
//    }
//
//    public init(date: Date) {
//        self.date = date
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let dateString = try container.decode(String.self)
//
//        let formatter = DateFormatter()
//        formatter.calendar = Calendar(identifier: .iso8601)
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.timeZone = TimeZone(secondsFromGMT: 0)
//
//        // List of possible date formats
//        let dateFormats = [
//            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",            // Millisecond precision with Z
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",         // Microsecond precision with Z
//            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",        // Millisecond precision with timezone offset
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",     // Microsecond precision with timezone offset
//            "yyyy-MM-dd'T'HH:mm:ssZ",                // Whole seconds with Z
//            "yyyy-MM-dd'T'HH:mm:ssXXXXX",            // Whole seconds with timezone offset
//            "yyyy-MM-dd'T'HH:mm:ss.SZ",              // Single fractional second digit with Z
//            "yyyy-MM-dd'T'HH:mm:ss.SXXXXX",          // Single fractional second digit with timezone offset
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSSSSSZ",  // Extended precision with Z
//            "yyyy-MM-dd'T'HH:mm:ss.SSS",             // Millisecond precision without timezone
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",          // Microsecond precision without timezone
//            "yyyy-MM-dd'T'HH:mm:ss"                 // Whole seconds without timezone
//        ]
//
//        var date: Date?
//        for dateFormat in dateFormats {
//            formatter.dateFormat = dateFormat
//            if let parsedDate = formatter.date(from: dateString) {
//                date = parsedDate
//                break
//            }
//        }
//
//        guard let validDate = date else {
//            throw DecodingError.dataCorruptedError(in: container,
//                debugDescription: "Date string does not match any expected format.")
//        }
//
//        self.date = validDate
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        let formatter = DateFormatter()
//        formatter.calendar = Calendar(identifier: .iso8601)
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.timeZone = TimeZone(secondsFromGMT: 0)
//        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
//        let dateString = formatter.string(from: self.date)
//        try container.encode(dateString)
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(date)
//    }
//
//
// }

//
// import Foundation
//
// public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable {
//
//    public let date: Date
//
//    public var toDate: Date {
//        // Directly return the wrapped date
//        return self.date
//    }
//
//    public init(date: Date) {
//        self.date = date
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let dateString = try container.decode(String.self)
//
//        // Use the cached DateFormatter instances
//        if let date = ATProtocolDate.parseDate(from: dateString) {
//            self.date = date
//        } else {
//            throw DecodingError.dataCorruptedError(in: container,
//                debugDescription: "Date string does not match any expected format.")
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        let formatter = ATProtocolDate.cachedFormatter(withFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")
//        let dateString = formatter.string(from: self.date)
//        try container.encode(dateString)
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(date)
//    }
//
//    // Static cache for DateFormatter instances
//    private static var formatterCache: [String: DateFormatter] = [:]
//    private static let cacheQueue = DispatchQueue(label: "formatterCacheQueue", attributes: .concurrent)
//
//    // Get a cached DateFormatter instance
//    private static func cachedFormatter(withFormat format: String) -> DateFormatter {
//        var formatter: DateFormatter?
//        cacheQueue.sync {
//            formatter = formatterCache[format]
//        }
//
//        if formatter == nil {
//            let newFormatter = DateFormatter()
//            newFormatter.calendar = Calendar(identifier: .iso8601)
//            newFormatter.locale = Locale(identifier: "en_US_POSIX")
//            newFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//            newFormatter.dateFormat = format
//
//            cacheQueue.async(flags: .barrier) {
//                formatterCache[format] = newFormatter
//            }
//            formatter = newFormatter
//        }
//
//        return formatter!
//    }
//
//    // Parse the date string using the list of formats
//    private static func parseDate(from dateString: String) -> Date? {
//        let dateFormats = [
//            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ssZ",
//            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ss.SZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SXXXXX"
//        ]
//
//        for format in dateFormats {
//            let formatter = cachedFormatter(withFormat: format)
//            if let date = formatter.date(from: dateString) {
//                return date
//            }
//        }
//        return nil
//    }
// }

// import Foundation
//
// actor DateFormatterCache {
//    private var formatterCache: [String: DateFormatter] = [:]
//
//    func cachedFormatter(withFormat format: String) -> DateFormatter {
//        if let formatter = formatterCache[format] {
//            return formatter
//        } else {
//            let newFormatter = DateFormatter()
//            newFormatter.calendar = Calendar(identifier: .iso8601)
//            newFormatter.locale = Locale(identifier: "en_US_POSIX")
//            newFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//            newFormatter.dateFormat = format
//
//            formatterCache[format] = newFormatter
//            return newFormatter
//        }
//    }
// }
//
// let dateFormatterCache = DateFormatterCache()
//
// public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable {
//
//    public let date: Date
//
//    public var toDate: Date {
//        return self.date
//    }
//
//    public init(date: Date) {
//        self.date = date
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.singleValueContainer()
//        let dateString = try container.decode(String.self)
//
//        if let date = try await ATProtocolDate.parseDate(from: dateString) {
//            self.date = date
//        } else {
//            throw DecodingError.dataCorruptedError(in: container,
//                debugDescription: "Date string does not match any expected format.")
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        let formatter = await dateFormatterCache.cachedFormatter(withFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")
//        let dateString = formatter.string(from: self.date)
//        try container.encode(dateString)
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(date)
//    }
//
//    // Parse the date string using the list of formats
//    private static func parseDate(from dateString: String) async throws -> Date? {
//        let dateFormats = [
//            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ssZ",
//            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
//            "yyyy-MM-dd'T'HH:mm:ss.SZ",
//            "yyyy-MM-dd'T'HH:mm:ss.SXXXXX"
//        ]
//
//        for format in dateFormats {
//            let formatter = await dateFormatterCache.cachedFormatter(withFormat: format)
//            if let date = formatter.date(from: dateString) {
//                return date
//            }
//        }
//        return nil
//    }
// }
