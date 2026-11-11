import Foundation

/// An ordered, case-insensitive list of HTTP header fields.
public struct OAuthHTTPHeaders: Sendable, Equatable {
    /// One header field.
    public struct Field: Sendable, Equatable {
        /// The field name, in the case it was given.
        public let name: String
        /// The field value.
        public let value: String

        /// Creates a field.
        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    /// The fields in order.
    public private(set) var fields: [Field]

    /// Creates a header list.
    public init(_ fields: [(String, String)] = []) {
        self.fields = fields.map { Field(name: $0.0, value: $0.1) }
    }

    /// Every value of `name`, in order. Names compare case-insensitively.
    public func values(for name: String) -> [String] {
        let wanted = name.lowercased()
        return fields.filter { $0.name.lowercased() == wanted }.map(\.value)
    }

    /// The value of `name` when it appears exactly once.
    public func single(_ name: String) -> String? {
        let found = values(for: name)
        return found.count == 1 ? found[0] : nil
    }

    /// The first value of `name`.
    public subscript(name: String) -> String? {
        values(for: name).first
    }

    /// Appends a field without replacing existing ones of the same name.
    public mutating func add(_ name: String, _ value: String) {
        fields.append(Field(name: name, value: value))
    }

    /// Replaces every field named `name` with one value.
    public mutating func set(_ name: String, _ value: String) {
        let wanted = name.lowercased()
        fields.removeAll { $0.name.lowercased() == wanted }
        fields.append(Field(name: name, value: value))
    }
}

/// An HTTP request as the authorization server sees it: a plain value, so the
/// core depends on no web framework.
public struct OAuthHTTPRequest: Sendable, Equatable {
    /// The request method, for example `POST`.
    public let method: String
    /// The request path, starting with `/`, without the query.
    public let path: String
    /// The raw query string without the leading `?`, or `nil`.
    public let query: String?
    /// The request headers.
    public let headers: OAuthHTTPHeaders
    /// The request body.
    public let body: Data
    /// The client's network address, when the host knows it. Passed to the
    /// account authenticator for rate limiting; never used for authorization.
    public let remoteAddress: String?

    /// Creates a request.
    public init(
        method: String,
        path: String,
        query: String? = nil,
        headers: OAuthHTTPHeaders = .init(),
        body: Data = Data(),
        remoteAddress: String? = nil
    ) {
        self.method = method.uppercased()
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.remoteAddress = remoteAddress
    }
}

/// An HTTP response produced by the authorization server.
public struct OAuthHTTPResponse: Sendable, Equatable {
    /// The status code.
    public var status: Int
    /// The response headers.
    public var headers: OAuthHTTPHeaders
    /// The response body.
    public var body: Data

    /// Creates a response.
    public init(status: Int, headers: OAuthHTTPHeaders = .init(), body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// One endpoint the authorization server answers, for registering routes with
/// a web framework.
public struct OAuthRoute: Sendable, Equatable, Hashable {
    /// The HTTP method.
    public let method: String
    /// The exact path.
    public let path: String

    /// Creates a route.
    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
}

/// Strict `application/x-www-form-urlencoded` parsing for OAuth endpoints.
///
/// OAuth request parameters must not be repeated (RFC 6749 §3.1, §3.2), so a
/// repeated name is an error and never "last one wins". Percent-escapes must
/// be well formed and decode to valid UTF-8.
enum OAuthForm {
    enum Failure: Error {
        case malformed
        case tooLarge
    }

    static func isFormContentType(_ headers: OAuthHTTPHeaders) -> Bool {
        guard let value = headers.single("Content-Type") else { return false }
        let mediaType = value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .trimmingCharacters(in: .whitespaces).lowercased()
        return mediaType == "application/x-www-form-urlencoded"
    }

    static func parse(_ data: Data, maximumBytes: Int) throws(Failure) -> [String: String] {
        guard data.count <= maximumBytes else { throw .tooLarge }
        return try parse(Array(data))
    }

    static func parseQuery(_ query: String?, maximumBytes: Int = 8192) throws(Failure) -> [String: String] {
        guard let query, !query.isEmpty else { return [:] }
        guard query.utf8.count <= maximumBytes else { throw .tooLarge }
        return try parse(Array(query.utf8))
    }

    private static func parse(_ bytes: [UInt8]) throws(Failure) -> [String: String] {
        var fields: [String: String] = [:]
        guard !bytes.isEmpty else { return fields }
        for pair in bytes.split(separator: 0x26, omittingEmptySubsequences: false) {
            guard !pair.isEmpty else { throw .malformed }
            let parts = pair.split(separator: 0x3D, maxSplits: 1, omittingEmptySubsequences: false)
            let name = try decode(parts[0])
            let value = parts.count > 1 ? try decode(parts[1]) : ""
            guard !name.isEmpty, fields.updateValue(value, forKey: name) == nil else { throw .malformed }
        }
        return fields
    }

    private static func decode(_ encoded: some Collection<UInt8>) throws(Failure) -> String {
        var output: [UInt8] = []
        output.reserveCapacity(encoded.count)
        var iterator = encoded.makeIterator()
        while let byte = iterator.next() {
            switch byte {
            case 0x2B:
                output.append(0x20)
            case 0x25:
                guard let high = iterator.next().flatMap(hex), let low = iterator.next().flatMap(hex) else {
                    throw .malformed
                }
                output.append(high << 4 | low)
            default:
                output.append(byte)
            }
        }
        guard let text = String(validatingUTF8: output), !text.utf8.contains(0) else { throw .malformed }
        return text
    }

    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30 ... 0x39: byte - 0x30
        case 0x41 ... 0x46: byte - 0x41 + 10
        case 0x61 ... 0x66: byte - 0x61 + 10
        default: nil
        }
    }

    /// Encodes one query component, leaving only RFC 3986 unreserved
    /// characters unescaped.
    static func encodeComponent(_ value: String) -> String {
        var output = ""
        for byte in value.utf8 {
            switch byte {
            case 0x30 ... 0x39, 0x41 ... 0x5A, 0x61 ... 0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
                output.unicodeScalars.append(UnicodeScalar(byte))
            default:
                output += "%" + String(byte, radix: 16, uppercase: true).leftPadded(to: 2)
            }
        }
        return output
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }

    init?(validatingUTF8 bytes: [UInt8]) {
        guard let text = String(bytes: bytes, encoding: .utf8) else { return nil }
        self = text
    }
}
