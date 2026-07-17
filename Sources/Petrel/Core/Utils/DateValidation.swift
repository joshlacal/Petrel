import Foundation

public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable, ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherDate = other as? ATProtocolDate else {
            return false
        }
        return date == otherDate.date
    }

    public func toCBORValue() throws -> Any {
        // Convert to a string representation for CBOR
        return iso8601String
    }

    public let date: Date

    /// The exact datetime string received on the wire, when this value was decoded.
    /// `Date` is a binary floating-point offset and cannot represent every wire
    /// timestamp exactly (e.g. ".301" re-formats as ".300"), so re-encoding must
    /// emit this string verbatim or strict lossless round-trip checks fail.
    private let rawString: String?

    public var toDate: Date {
        date
    }

    public init(date: Date) {
        self.date = date
        rawString = nil
    }

    init(date: Date, rawString: String) {
        self.date = date
        self.rawString = rawString
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        // Try parsing with explicit ISO8601 parsing strategy
        if let date = Self.parseDate(from: dateString) {
            self.date = date
            rawString = dateString
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

    public static func == (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date == rhs.date
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }

    // MARK: - Parsing and Formatting

    private static func parseDate(from dateString: String) -> Date? {
        if let date = parseWithFoundation(dateString) {
            return date
        }

        // Foundation cannot parse very high-precision fractional seconds, but the
        // atproto datetime spec allows arbitrary precision. Validate the string shape,
        // truncate the fraction, and retry.
        if let truncated = truncatingLongFractionalSeconds(dateString) {
            return parseWithFoundation(truncated)
        }

        return nil
    }

    /// Matches a full ISO 8601 datetime with seven or more fractional second digits,
    /// capturing the date-time prefix, the fraction, and the timezone suffix.
    private static let longFractionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})\\.([0-9]{7,})(Z|[+-][0-9]{2}:[0-9]{2})$",
        options: []
    )

    /// Truncates fractional seconds to microsecond precision so Foundation can parse them,
    /// while still validating the overall datetime shape. Returns nil if the string does not
    /// match a datetime with an overlong fraction.
    private static func truncatingLongFractionalSeconds(_ dateString: String) -> String? {
        guard let regex = longFractionRegex else {
            return nil
        }

        let range = NSRange(location: 0, length: dateString.utf16.count)
        guard let match = regex.firstMatch(in: dateString, options: [], range: range),
              let prefixRange = Range(match.range(at: 1), in: dateString),
              let fractionRange = Range(match.range(at: 2), in: dateString),
              let zoneRange = Range(match.range(at: 3), in: dateString)
        else {
            return nil
        }

        let fraction = dateString[fractionRange].prefix(6)
        return "\(dateString[prefixRange]).\(fraction)\(dateString[zoneRange])"
    }

    private static func parseWithFoundation(_ dateString: String) -> Date? {
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
        self.init(date: date, rawString: iso8601String)
    }

    var iso8601String: String {
        rawString ?? formattedDate
    }
}

// MARK: - Comparable Conformance

extension ATProtocolDate: Comparable {
    public static func < (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date < rhs.date
    }
}
