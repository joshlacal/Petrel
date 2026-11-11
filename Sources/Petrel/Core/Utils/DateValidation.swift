import Foundation

/// The Lexicon `datetime` string format: a timestamp that keeps the exact string
/// it was decoded from.
///
/// Validation follows https://atproto.com/specs/lexicon#datetime — the
/// intersection of RFC 3339, ISO 8601 and WHATWG HTML datetimes:
///
/// - `YYYY-MM-DDTHH:MM:SS` with an upper-case `T`, exactly four year digits and
///   two digits in every other field; whole seconds are required
/// - optional fractional seconds of any length
/// - a mandatory timezone: upper-case `Z` or `±HH:MM`; `-00:00` is not allowed
/// - no surrounding whitespace, at most 64 characters
/// - the fields must name a real instant (no month 13, no 30 February, no hour
///   24, no second 60), and the instant must fall in years 0000–9999 once
///   converted to UTC
///
/// Parsing does not use Foundation's ISO 8601 parser, so results are identical on
/// every platform.
///
/// ```swift
/// let created = try ATProtocolDate(datetimeString: "1985-04-12T23:20:50.123Z")
/// created.iso8601String                     // "1985-04-12T23:20:50.123Z", verbatim
/// ATProtocolDate.isValidDatetime("1985-04-12T23:20:50.123")   // false: no timezone
/// try ATProtocolDate.normalizeDatetime("1985-04-12 23:20:50") // "1985-04-12T23:20:50.000Z"
/// ```
public struct ATProtocolDate: Codable, Hashable, Equatable, Sendable, ATProtocolValue {
    public func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let otherDate = other as? ATProtocolDate else {
            return false
        }
        return date == otherDate.date
    }

    public func toCBORValue() throws -> Any {
        try checkedString()
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

    /// Wraps a `Date`. Any `Date` is accepted here; one outside years 0000–9999
    /// cannot be written as an atproto datetime and throws when it is encoded.
    /// Use ``init(validating:)`` to find out at the point of construction.
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

        switch DatetimeSyntax.parse(dateString) {
        case let .success(date):
            self.date = date
            rawString = dateString
        case let .failure(failure):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid AT Protocol datetime \(syntaxExcerpt(dateString)): \(failure.reason)",
                    underlyingError: ATProtocolError.invalidDatetime(
                        "Invalid datetime \(syntaxExcerpt(dateString)): \(failure.reason)"
                    )
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(checkedString())
    }

    public static func == (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date == rhs.date
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }

    /// The string to write: the wire string when there is one, otherwise the
    /// formatted date — refusing a date that has no valid datetime form.
    private func checkedString() throws -> String {
        if let rawString {
            return rawString
        }
        return try normalizedString()
    }
}

// MARK: - Validation, parsing and formatting

public extension ATProtocolDate {
    /// Parses a datetime string, returning `nil` if it is not a valid atproto
    /// datetime. The string is kept verbatim for re-encoding.
    init?(iso8601String: String) {
        guard case let .success(date) = DatetimeSyntax.parse(iso8601String) else {
            return nil
        }
        self.init(date: date, rawString: iso8601String)
    }

    /// Parses a datetime string, throwing ``ATProtocolError/invalidDatetime(_:)``
    /// with the reason when it is not a valid atproto datetime. The string is kept
    /// verbatim for re-encoding.
    init(datetimeString: String) throws {
        switch DatetimeSyntax.parse(datetimeString) {
        case let .success(date):
            self.init(date: date, rawString: datetimeString)
        case let .failure(failure):
            throw ATProtocolError.invalidDatetime(
                "Invalid datetime \(syntaxExcerpt(datetimeString)): \(failure.reason)"
            )
        }
    }

    /// Wraps a `Date`, throwing ``ATProtocolError/invalidDatetime(_:)`` if it
    /// falls outside years 0000–9999 and so has no atproto datetime form.
    init(validating date: Date) throws {
        _ = try DatetimeSyntax.format(date).get()
        self.init(date: date)
    }

    /// Whether `string` is a valid atproto datetime: correct syntax, a real
    /// calendar instant, and a UTC year in 0000–9999.
    static func isValidDatetime(_ string: String) -> Bool {
        if case .success = DatetimeSyntax.parse(string) { return true }
        return false
    }

    /// The datetime string: the exact wire string for a decoded value, otherwise
    /// the date at millisecond precision in UTC (`YYYY-MM-DDTHH:MM:SS.sssZ`).
    ///
    /// For a value created from a `Date` outside years 0000–9999 this is an
    /// ISO 8601 expanded-year string, which is not a valid atproto datetime;
    /// encoding such a value throws. See ``isRepresentable``.
    var iso8601String: String {
        rawString ?? DatetimeSyntax.formatUnchecked(date)
    }

    /// Whether this value can be written as an atproto datetime. `false` only for
    /// a value created from a `Date` outside years 0000–9999.
    var isRepresentable: Bool {
        if rawString != nil { return true }
        if case .success = DatetimeSyntax.format(date) { return true }
        return false
    }

    /// The canonical form: millisecond precision, UTC, `Z` suffix
    /// (`YYYY-MM-DDTHH:MM:SS.sssZ`), rounded to the nearest millisecond. Unlike
    /// ``iso8601String`` this never returns the wire string, so two values for the
    /// same instant give the same result. Throws
    /// ``ATProtocolError/invalidDatetime(_:)`` outside years 0000–9999.
    func normalizedString() throws -> String {
        try DatetimeSyntax.format(date).get()
    }

    /// Converts a loosely formatted timestamp into the canonical atproto form
    /// (`YYYY-MM-DDTHH:MM:SS.sssZ`).
    ///
    /// Besides every valid datetime, this accepts the near-misses that occur in
    /// older records: a missing timezone (read as UTC), lower-case `t` / `z`, a
    /// space or underscore between date and time, offsets written `+HHMM` or
    /// `+HH`, `-00:00`, a missing seconds field, a date with no time, and
    /// surrounding whitespace. Field ranges are still enforced. Throws
    /// ``ATProtocolError/invalidDatetime(_:)`` when the input cannot be read.
    static func normalizeDatetime(_ string: String) throws -> String {
        switch DatetimeSyntax.parse(string, lenient: true) {
        case let .success(date):
            return try DatetimeSyntax.format(date).get()
        case let .failure(failure):
            throw ATProtocolError.invalidDatetime(
                "Cannot normalize datetime \(syntaxExcerpt(string)): \(failure.reason)"
            )
        }
    }

    /// As ``normalizeDatetime(_:)``, but returns the UNIX epoch
    /// (`1970-01-01T00:00:00.000Z`) for input that cannot be read, matching
    /// `normalizeDatetimeAlways` in `@atproto/syntax`. Only for display or sort
    /// keys where a placeholder is acceptable; never for data that is written back.
    static func normalizeDatetimeAlways(_ string: String) -> String {
        (try? normalizeDatetime(string)) ?? "1970-01-01T00:00:00.000Z"
    }
}

// MARK: - Comparable Conformance

extension ATProtocolDate: Comparable {
    public static func < (lhs: ATProtocolDate, rhs: ATProtocolDate) -> Bool {
        lhs.date < rhs.date
    }
}

// MARK: - Scanner

/// Hand-written datetime scanner and formatter using proleptic Gregorian
/// arithmetic, so behaviour does not depend on Foundation's parser or the host
/// platform.
enum DatetimeSyntax {
    private struct Cursor {
        let bytes: UnsafeBufferPointer<UInt8>
        var index = 0

        var atEnd: Bool {
            index >= bytes.count
        }

        var peek: UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        /// Consumes exactly `count` ASCII digits and returns their value.
        mutating func digits(_ count: Int) -> Int? {
            guard index + count <= bytes.count else { return nil }
            var value = 0
            for offset in 0 ..< count {
                let byte = bytes[index + offset]
                guard SyntaxByte.isDigit(byte) else { return nil }
                value = value * 10 + Int(byte - 0x30)
            }
            index += count
            return value
        }

        mutating func eat(_ byte: UInt8) -> Bool {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
            return true
        }

        mutating func eat(anyOf candidates: [UInt8]) -> UInt8? {
            guard index < bytes.count, candidates.contains(bytes[index]) else { return nil }
            index += 1
            return bytes[index - 1]
        }

        /// Consumes a run of digits (possibly empty) as a decimal fraction.
        mutating func fraction() -> (value: Double, digitCount: Int) {
            var value = 0.0
            var scale = 0.1
            var count = 0
            while index < bytes.count, SyntaxByte.isDigit(bytes[index]) {
                // Seventeen significant digits exhaust a Double; later digits are
                // validated but cannot change the value.
                if count < 17 {
                    value += Double(bytes[index] - 0x30) * scale
                    scale /= 10
                }
                count += 1
                index += 1
            }
            return (value, count)
        }
    }

    private static let letterT: UInt8 = 0x54
    private static let letterZ: UInt8 = 0x5A
    private static let minus: UInt8 = 0x2D
    private static let plus: UInt8 = 0x2B
    private static let colon: UInt8 = 0x3A
    private static let dot: UInt8 = 0x2E

    /// Parses a datetime. `lenient` is the tolerant grammar used only by
    /// `normalizeDatetime`; validation always uses the strict one.
    static func parse(_ string: String, lenient: Bool = false) -> Result<Date, SyntaxFailure> {
        let input = lenient ? string.trimmingCharacters(in: .whitespacesAndNewlines) : string
        return withSyntaxBytes(input) { bytes -> Result<Date, SyntaxFailure> in
            guard bytes.count <= 64 else { return .failure("longer than 64 characters") }
            var cursor = Cursor(bytes: bytes)
            return lenient ? scanLenient(&cursor) : scanStrict(&cursor)
        }
    }

    private static func scanStrict(_ cursor: inout Cursor) -> Result<Date, SyntaxFailure> {
        guard let year = cursor.digits(4), cursor.eat(minus),
              let month = cursor.digits(2), cursor.eat(minus),
              let day = cursor.digits(2)
        else {
            return .failure("date must be YYYY-MM-DD")
        }
        guard cursor.eat(letterT) else {
            return .failure("date and time must be separated by an upper-case \"T\"")
        }
        guard let hour = cursor.digits(2), cursor.eat(colon),
              let minute = cursor.digits(2), cursor.eat(colon),
              let second = cursor.digits(2)
        else {
            return .failure("time must be HH:MM:SS with whole seconds")
        }

        var fraction = 0.0
        if cursor.eat(dot) {
            let parsed = cursor.fraction()
            guard parsed.digitCount > 0 else {
                return .failure("fractional seconds need at least one digit")
            }
            fraction = parsed.value
        }

        var offsetSeconds = 0
        if cursor.eat(letterZ) {
            offsetSeconds = 0
        } else if let sign = cursor.eat(anyOf: [plus, minus]) {
            guard let offsetHour = cursor.digits(2), cursor.eat(colon), let offsetMinute = cursor.digits(2) else {
                return .failure("timezone offset must be ±HH:MM")
            }
            guard offsetHour <= 23, offsetMinute <= 59 else {
                return .failure("timezone offset is out of range")
            }
            guard !(sign == minus && offsetHour == 0 && offsetMinute == 0) else {
                return .failure("\"-00:00\" is not allowed; use \"Z\" or \"+00:00\"")
            }
            offsetSeconds = (offsetHour * 3600 + offsetMinute * 60) * (sign == minus ? -1 : 1)
        } else {
            return .failure("timezone is required: upper-case \"Z\" or ±HH:MM")
        }

        guard cursor.atEnd else { return .failure("unexpected characters after the timezone") }

        return instant(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second,
            fraction: fraction, offsetSeconds: offsetSeconds
        )
    }

    private static func scanLenient(_ cursor: inout Cursor) -> Result<Date, SyntaxFailure> {
        guard let year = cursor.digits(4), cursor.eat(minus),
              let month = cursor.digits(2), cursor.eat(minus),
              let day = cursor.digits(2)
        else {
            return .failure("date must be YYYY-MM-DD")
        }

        var hour = 0
        var minute = 0
        var second = 0
        var fraction = 0.0
        var offsetSeconds = 0

        if !cursor.atEnd {
            // "T", "t", space or underscore between date and time.
            guard cursor.eat(anyOf: [letterT, 0x74, 0x20, 0x5F]) != nil else {
                return .failure("unexpected characters after the date")
            }
            guard let parsedHour = cursor.digits(2), cursor.eat(colon), let parsedMinute = cursor.digits(2) else {
                return .failure("time must be HH:MM or HH:MM:SS")
            }
            hour = parsedHour
            minute = parsedMinute
            if cursor.eat(colon) {
                guard let parsedSecond = cursor.digits(2) else {
                    return .failure("seconds must be two digits")
                }
                second = parsedSecond
                if cursor.eat(dot) {
                    fraction = cursor.fraction().value
                }
            }

            if cursor.eat(anyOf: [letterZ, 0x7A]) != nil {
                offsetSeconds = 0
            } else if let sign = cursor.eat(anyOf: [plus, minus]) {
                guard let offsetHour = cursor.digits(2) else {
                    return .failure("timezone offset must be ±HH:MM, ±HHMM or ±HH")
                }
                var offsetMinute = 0
                if !cursor.atEnd {
                    _ = cursor.eat(colon)
                    guard let parsedMinute = cursor.digits(2) else {
                        return .failure("timezone offset must be ±HH:MM, ±HHMM or ±HH")
                    }
                    offsetMinute = parsedMinute
                }
                guard offsetHour <= 23, offsetMinute <= 59 else {
                    return .failure("timezone offset is out of range")
                }
                offsetSeconds = (offsetHour * 3600 + offsetMinute * 60) * (sign == minus ? -1 : 1)
            }
            guard cursor.atEnd else { return .failure("unexpected trailing characters") }
        }

        return instant(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second,
            fraction: fraction, offsetSeconds: offsetSeconds
        )
    }

    /// Range-checks the fields and converts them to an instant.
    private static func instant(
        year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int,
        fraction: Double, offsetSeconds: Int
    ) -> Result<Date, SyntaxFailure> {
        guard (1 ... 12).contains(month) else { return .failure("month must be 01 to 12") }
        guard day >= 1, day <= daysInMonth(year: year, month: month) else {
            return .failure("day is not valid for the month")
        }
        guard hour <= 23 else { return .failure("hour must be 00 to 23") }
        guard minute <= 59 else { return .failure("minute must be 00 to 59") }
        // RFC 3339 permits a leap second (":60"), but neither reference
        // implementation accepts one and `Date` cannot represent it.
        guard second <= 59 else { return .failure("second must be 00 to 59") }

        let days = daysFromCivil(year: year, month: month, day: day)
        let seconds = days * 86400 + Int64(hour * 3600 + minute * 60 + second) - Int64(offsetSeconds)
        let utcYear = civilFromDays(floorDivide(seconds, 86400)).year
        guard utcYear >= 0 else { return .failure("normalizes to a year before 0000 in UTC") }
        guard utcYear <= 9999 else { return .failure("normalizes to a year after 9999 in UTC") }

        return .success(Date(timeIntervalSince1970: Double(seconds) + fraction))
    }

    // MARK: Formatting

    /// `YYYY-MM-DDTHH:MM:SS.sssZ`, or a failure outside years 0000–9999.
    static func format(_ date: Date) -> Result<String, ATProtocolError> {
        guard let fields = utcFields(date), (0 ... 9999).contains(fields.year) else {
            return .failure(
                .invalidDatetime("Date \(date.timeIntervalSince1970) is outside years 0000-9999 and has no atproto datetime form")
            )
        }
        return .success(render(fields, year: pad(fields.year, 4)))
    }

    /// As `format`, but falls back to the ISO 8601 expanded-year form
    /// (`+YYYYYY-…` / `-YYYYYY-…`) outside years 0000–9999. Not a valid atproto
    /// datetime in that case; used only for display of an unencodable value.
    static func formatUnchecked(_ date: Date) -> String {
        guard let fields = utcFields(date) else {
            return String(describing: date.timeIntervalSince1970)
        }
        if (0 ... 9999).contains(fields.year) {
            return render(fields, year: pad(fields.year, 4))
        }
        return render(fields, year: (fields.year < 0 ? "-" : "+") + pad(abs(fields.year), 6))
    }

    private struct Fields {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
        let second: Int
        let millisecond: Int
    }

    private static func utcFields(_ date: Date) -> Fields? {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded()
        // Keep well inside Int64 so the arithmetic below cannot overflow.
        guard milliseconds.isFinite, abs(milliseconds) < 8.0e18 else { return nil }
        let total = Int64(milliseconds)
        let seconds = floorDivide(total, 1000)
        let millisecond = Int(total - seconds * 1000)
        let days = floorDivide(seconds, 86400)
        let secondOfDay = Int(seconds - days * 86400)
        let civil = civilFromDays(days)
        return Fields(
            year: civil.year, month: civil.month, day: civil.day,
            hour: secondOfDay / 3600, minute: secondOfDay % 3600 / 60, second: secondOfDay % 60,
            millisecond: millisecond
        )
    }

    private static func render(_ fields: Fields, year: String) -> String {
        "\(year)-\(pad(fields.month, 2))-\(pad(fields.day, 2))T\(pad(fields.hour, 2)):\(pad(fields.minute, 2)):\(pad(fields.second, 2)).\(pad(fields.millisecond, 3))Z"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return digits.count >= width ? digits : String(repeating: "0", count: width - digits.count) + digits
    }

    // MARK: Proleptic Gregorian calendar arithmetic

    private static func floorDivide(_ value: Int64, _ divisor: Int64) -> Int64 {
        let quotient = value / divisor
        return (value % divisor != 0 && (value < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int64 {
        let adjustedYear = Int64(month <= 2 ? year - 1 : year)
        let era = floorDivide(adjustedYear, 400)
        let yearOfEra = adjustedYear - era * 400
        let dayOfYear = Int64((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1)
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The proleptic Gregorian date for a count of days since 1970-01-01.
    private static func civilFromDays(_ days: Int64) -> (year: Int, month: Int, day: Int) {
        let shifted = days + 719_468
        let era = floorDivide(shifted, 146_097)
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = Int(dayOfYear - (153 * monthIndex + 2) / 5 + 1)
        let month = Int(monthIndex < 10 ? monthIndex + 3 : monthIndex - 9)
        let year = Int(yearOfEra + era * 400) + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}
