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

        // Try parsing with explicit ISO8601 parsing strategy
        if let date = Self.parseDate(from: dateString) {
            self.date = date
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid AT Protocol datetime format: \(dateString)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso8601String)
    }

    // MARK: - Parsing and Formatting

    private static func parseDate(from dateString: String) -> Date? {
        // Create a more flexible ISO8601 parsing strategy
        let strategy = Date.ISO8601FormatStyle(
            dateSeparator: .dash,
            dateTimeSeparator: .standard,
            timeSeparator: .colon,
            timeZoneSeparator: .omitted,
            includingFractionalSeconds: true,
            timeZone: .gmt
        )

        // Try parsing with our format style
        do {
            return try strategy.parse(dateString)
        } catch {
            // Fall back to a direct raw parse for known edge cases
            let fallbackStrategy = Date.ISO8601FormatStyle() // Default is usually more permissive
            do {
                return try fallbackStrategy.parse(dateString)
            } catch {
                // Last resort: manual string parsing for epoch time
                if dateString == "1970-01-01T00:00:00.000Z" {
                    return Date(timeIntervalSince1970: 0)
                }
                return nil
            }
        }
    }

    private var formattedDate: String {
        // Configure an ISO8601 format style that guarantees millisecond precision
        let formatStyle = Date.ISO8601FormatStyle(
            dateSeparator: .dash,
            dateTimeSeparator: .standard,
            timeSeparator: .colon,
            timeZoneSeparator: .omitted,
            includingFractionalSeconds: true,
            timeZone: .gmt
        )

        // Format date to ISO8601 string with fractional seconds
        var result = formatStyle.format(date)

        // Ensure exactly 3 decimal places for milliseconds
        if let dotIndex = result.firstIndex(of: ".") {
            let fractionalPart = result[result.index(after: dotIndex)...]

            if let zIndex = fractionalPart.firstIndex(of: "Z") {
                let digits = fractionalPart.distance(from: fractionalPart.startIndex, to: zIndex)
                if digits < 3 {
                    // Add zeros to ensure millisecond precision
                    let zerosToAdd = 3 - digits
                    let insertIndex = result.index(dotIndex, offsetBy: digits + 1)
                    result.insert(contentsOf: String(repeating: "0", count: zerosToAdd), at: insertIndex)
                } else if digits > 3 {
                    // Truncate to millisecond precision
                    let endIndex = result.index(dotIndex, offsetBy: 4) // dot + 3 digits
                    let zIndex = result.lastIndex(of: "Z")!
                    result.replaceSubrange(endIndex ..< zIndex, with: "")
                }
            }
        } else if result.hasSuffix("Z") {
            // No fractional seconds, add .000
            let insertIndex = result.index(before: result.endIndex)
            result.insert(contentsOf: ".000", at: insertIndex)
        }

        return result
    }
}

// MARK: - Convenience Initializers and Methods

public extension ATProtocolDate {
    init?(iso8601String: String) {
        guard let date = Self.parseDate(from: iso8601String) else {
            return nil
        }
        self.init(date: date)
    }

    var iso8601String: String {
        formattedDate
    }
}

// MARK: - Comparable Conformance

extension ATProtocolDate: Comparable {
    public static func < (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date < rhs.date
    }
}
