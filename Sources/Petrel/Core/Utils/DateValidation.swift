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
        if let date = fastParse(dateString) {
            return date
        }

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

    /// The primary parse strategy. `Date.ISO8601FormatStyle` is a `Sendable` value
    /// whose `parse` is non-mutating, and constructing one builds a Gregorian
    /// calendar, so it is built once instead of per call.
    private static let fractionalSecondsStyle = Date.ISO8601FormatStyle(
        dateSeparator: .dash,
        dateTimeSeparator: .standard,
        timeSeparator: .colon,
        timeZoneSeparator: .omitted,
        includingFractionalSeconds: true,
        timeZone: .gmt
    )

    /// The permissive fallback strategy (the default style: no fractional seconds).
    private static let defaultStyle = Date.ISO8601FormatStyle()

    private static func parseWithFoundation(_ dateString: String) -> Date? {
        // Try parsing with our format style
        do {
            return try fractionalSecondsStyle.parse(dateString)
        } catch {
            // Fall back to a direct raw parse for known edge cases
            do {
                return try defaultStyle.parse(dateString)
            } catch {
                // Last resort: manual string parsing for epoch time
                if dateString == "1970-01-01T00:00:00.000Z" {
                    return Date(timeIntervalSince1970: 0)
                }
                return nil
            }
        }
    }

    // MARK: - Byte fast path

    /// Parses the canonical atproto shape `YYYY-MM-DDTHH:MM:SS[.f{1,9}]Z` (years
    /// 1970...2199, real calendar dates, hours 0...23, minutes and seconds 0...59)
    /// directly from the bytes. Returns `nil` for anything else (offsets, lowercase
    /// separators, more than nine fraction digits, leap seconds, out-of-range or
    /// normalizable components), and the caller then runs the unchanged Foundation
    /// path.
    ///
    /// The result is bit-identical to Foundation's: for this shape
    /// `Date.ISO8601FormatStyle.parse` resolves the components through
    /// `_CalendarGregorian.date(from:inTimeZone:)`, which computes
    /// `(Date(julianDay:) - 43200) + secondsInDay` with
    /// `secondsInDay = Double(h) * 3600 + Double(m) * 60 + Double(s) + Double(ns) / 1e9`.
    /// The day start and the integer part of `secondsInDay` are exact integers in a
    /// `Double`, so the only roundings are the nanosecond division and the two final
    /// additions, reproduced here in the same order. The arithmetic is unchanged in
    /// swift-foundation release/6.0 (the iOS 18 / macOS 15 floor) through main; it is
    /// also swept exhaustively in the unit tests (every day 1970...2199).
    static func fastParse(_ dateString: String) -> Date? {
        LeafScan.withBytes(dateString) { u -> Date? in
            let n = u.count
            guard n >= 20, n <= 30, u[n - 1] == 0x5A,
                  u[4] == 0x2D, u[7] == 0x2D, u[10] == 0x54, u[13] == 0x3A, u[16] == 0x3A
            else { return nil }
            guard let y1 = twoDigits(u, 0), let y2 = twoDigits(u, 2), let month = twoDigits(u, 5),
                  let day = twoDigits(u, 8), let hour = twoDigits(u, 11), let minute = twoDigits(u, 14),
                  let second = twoDigits(u, 17)
            else { return nil }
            let year = y1 * 100 + y2
            guard year >= 1970, year <= 2199, month >= 1, month <= 12, day >= 1,
                  day <= daysInMonth(year, month), hour <= 23, minute <= 59, second <= 59
            else { return nil }

            var nanoseconds = 0
            if n > 20 {
                guard u[19] == 0x2E else { return nil }
                let digits = n - 21
                guard digits >= 1, digits <= 9 else { return nil }
                var i = 20
                while i < n - 1 {
                    let digit = u[i] &- 0x30
                    guard digit < 10 else { return nil }
                    nanoseconds = nanoseconds * 10 + Int(digit)
                    i += 1
                }
                var scale = digits
                while scale < 9 {
                    nanoseconds *= 10
                    scale += 1
                }
            }

            // Days since 2001-01-01 (the reference date); exact in Double.
            let dayStart = Double((daysSinceUnixEpoch(year, month, day) - 11323) * 86400)
            let secondsInDay = Double(hour * 3600 + minute * 60 + second)
                + Double(nanoseconds) / 1_000_000_000
            return Date(timeIntervalSinceReferenceDate: dayStart + secondsInDay)
        }
    }

    @inline(__always)
    private static func twoDigits(_ u: LeafBytes, _ i: Int) -> Int? {
        let high = u[i] &- 0x30
        let low = u[i + 1] &- 0x30
        guard high < 10, low < 10 else { return nil }
        return Int(high) * 10 + Int(low)
    }

    @inline(__always)
    private static func daysInMonth(_ year: Int, _ month: Int) -> Int {
        switch month {
        case 2:
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }

    /// Days from 1970-01-01 in the proleptic Gregorian calendar (H. Hinnant's
    /// days_from_civil), for years >= 1970.
    @inline(__always)
    private static func daysSinceUnixEpoch(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = y / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private var formattedDate: String {
        // Format date to ISO8601 string with fractional seconds (same configuration as
        // the primary parse style).
        var result = Self.fractionalSecondsStyle.format(date)

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
