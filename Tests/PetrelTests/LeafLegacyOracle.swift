// Verbatim behavioural copies of the leaf validators/parsers as they were before
// the byte-scanner fast paths (Petrel main 397a3097:
// Sources/Petrel/Core/Utils/ATProtoTypes.swift, DateValidation.swift,
// Languages.swift and Sources/PetrelCore/CID.swift). Only the enclosing type names
// changed. They are the oracles for LeafScannerEquivalenceTests and must never be
// "fixed": a difference between these and production is a behaviour change.
import Foundation

enum LeafLegacyOracle {
    // MARK: DID

    static let didPattern = "^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$"
    nonisolated(unsafe) static let didRegex: NSRegularExpression? = try? NSRegularExpression(pattern: didPattern, options: [])

    static func isValidDID(_ did: String) -> Bool {
        guard !did.isEmpty, did.utf8.count <= 2048, did.allSatisfy({ $0.isASCII }) else {
            return false
        }
        guard let regex = didRegex else {
            return did.hasPrefix("did:") && did.count > 4
        }
        let range = NSRange(location: 0, length: did.utf16.count)
        return regex.firstMatch(in: did, options: [], range: range) != nil
    }

    struct DIDParts: Equatable {
        let method: String
        let authority: String
        let segments: [String]
    }

    /// `DID(didString:)`: nil when it throws.
    static func parseDID(_ didString: String) -> DIDParts? {
        guard didString.utf8.count <= 2048, isValidDID(didString) else { return nil }
        let components = didString.dropFirst(4).split(separator: ":", omittingEmptySubsequences: false)
        let method = String(components[0])
        let authority = components.count > 1 ? String(components[1]) : ""
        let segments = components.count > 2 ? components.dropFirst(2).map { String($0) } : []
        return DIDParts(method: method, authority: authority, segments: segments)
    }

    /// `DID.didString()` as it was: rebuilt from the components.
    static func didString(_ p: DIDParts) -> String {
        var didString = "did:\(p.method):\(p.authority)"
        if !p.segments.isEmpty {
            didString += ":" + p.segments.joined(separator: ":")
        }
        return didString
    }

    // MARK: Handle

    static let handlePattern =
        "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"
    nonisolated(unsafe) static let handleRegex: NSRegularExpression? = try? NSRegularExpression(pattern: handlePattern, options: [])

    static func isValidHandle(_ handle: String) -> Bool {
        guard !handle.isEmpty, handle.utf8.count <= 253 else {
            return false
        }
        let lower = handle.lowercased()
        let labels = lower.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else {
            return false
        }
        guard labels.allSatisfy({ label in
            !label.isEmpty
                && label.utf8.count <= 63
                && label.first != "-"
                && label.last != "-"
                && label.utf8.allSatisfy({ ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 45 })
        }) else {
            return false
        }
        guard let tld = labels.last.map(String.init) else {
            return false
        }
        guard let firstByte = tld.utf8.first, firstByte >= 97 && firstByte <= 122 else {
            return false
        }
        guard let regex = handleRegex else {
            return true
        }
        let range = NSRange(location: 0, length: handle.utf16.count)
        return regex.firstMatch(in: handle, options: [], range: range) != nil
    }

    /// `Handle(handleString:).value`: nil when it throws.
    static func handleValue(_ handle: String) -> String? {
        guard isValidHandle(handle) else { return nil }
        return handle.lowercased()
    }

    // MARK: NSID

    static let nsidPattern =
        "^([a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))+\\.[a-zA-Z][a-zA-Z0-9]{0,62}$"
    nonisolated(unsafe) static let nsidRegex: NSRegularExpression? = try? NSRegularExpression(pattern: nsidPattern, options: [])

    static func isValidNSID(_ nsid: String) -> Bool {
        guard !nsid.isEmpty, nsid.utf8.count <= 317, nsid.allSatisfy({ $0.isASCII }) else {
            return false
        }
        guard let regex = nsidRegex else { return false }
        let range = NSRange(location: 0, length: nsid.utf16.count)
        return regex.firstMatch(in: nsid, options: [], range: range) != nil
    }

    // MARK: RecordKey

    static let recordKeyPattern = "^[a-zA-Z0-9._:~-]+$"
    nonisolated(unsafe) static let recordKeyRegex: NSRegularExpression? = try? NSRegularExpression(pattern: recordKeyPattern, options: [])

    static func isValidRecordKey(_ key: String) -> Bool {
        guard !key.isEmpty, key.utf8.count <= 512, key != ".", key != "..", key.allSatisfy({ $0.isASCII }) else {
            return false
        }
        guard let regex = recordKeyRegex else { return false }
        let range = NSRange(location: 0, length: key.utf16.count)
        return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    // MARK: ATProtocolURI

    struct ATURIParts: Equatable {
        var authority: String
        var collection: String?
        var recordKey: String?
        var isSpace: Bool
        var spaceDID: String?
        var spaceType: String?
        var skey: String?
        var authorDID: String?
    }

    struct URIError: Error, Equatable {
        let message: String
    }

    static func parseATURI(_ uriString: String) throws -> ATURIParts {
        guard uriString.hasPrefix("at://"), uriString.utf8.count <= 8192 else {
            throw URIError(message: "Invalid AT URI format or length")
        }
        guard uriString.count > 5 else {
            throw URIError(message: "Invalid AT URI: too short")
        }
        let trimmedString = String(uriString.dropFirst(5))
        let components = trimmedString.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty, !components[0].isEmpty else {
            throw URIError(message: "Invalid AT URI: missing or empty authority")
        }
        let authorityStr = String(components[0])
        guard isValidDID(authorityStr) || isValidHandle(authorityStr) else {
            throw URIError(message: "Invalid authority in AT URI: \(authorityStr)")
        }
        let segments = components
        let authority = String(segments[0])
        let path = segments.dropFirst().map(String.init)
        guard path.first == "space" else {
            guard path.count <= 2 else {
                throw URIError(message: "Too many path segments in public AT URI")
            }
            let collectionName: String?
            if path.count > 0 && !path[0].isEmpty {
                guard isValidNSID(path[0]) else {
                    throw URIError(message: "Invalid collection NSID: \(path[0])")
                }
                collectionName = path[0]
            } else {
                collectionName = nil
            }
            let rkey: String?
            if path.count > 1 && !path[1].isEmpty {
                guard isValidRecordKey(path[1]) else {
                    throw URIError(message: "Invalid record key: \(path[1])")
                }
                rkey = path[1]
            } else {
                rkey = nil
            }
            return ATURIParts(authority: authority, collection: collectionName, recordKey: rkey, isSpace: false,
                              spaceDID: nil, spaceType: nil, skey: nil,
                              authorDID: isValidDID(authority) ? authority : nil)
        }
        let space = path.filter { !$0.isEmpty }
        func segment(_ index: Int) -> String? { index < space.count ? space[index] : nil }
        let author = segment(3)
        return ATURIParts(authority: authority, collection: segment(4), recordKey: segment(5), isSpace: true,
                          spaceDID: isValidDID(authority) ? authority : nil,
                          spaceType: segment(1).flatMap { isValidNSID($0) ? $0 : nil },
                          skey: segment(2), authorDID: author.flatMap { isValidDID($0) ? $0 : nil })
    }

    // MARK: CID / base32

    struct CIDParts: Equatable {
        var codec: UInt8
        var algorithm: UInt8
        var length: UInt8
        var digest: Data
    }

    enum CIDParseError: Error, Equatable {
        case invalidPrefix(String)
        case invalidBase32Encoding
        case insufficientLength
        case invalidVersion(UInt8)
        case unsupportedCodec(UInt8)
    }

    static let validCodecs: Set<UInt8> = [0x55, 0x70, 0x71, 0x78, 0x00]
    static let base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"
    static let base32Lookup: [UInt8: UInt8] = {
        var lookup = [UInt8: UInt8]()
        for (i, char) in base32Alphabet.utf8.enumerated() { lookup[char] = UInt8(i) }
        return lookup
    }()

    static func parseCID(_ cidString: String) throws -> CIDParts {
        guard !cidString.isEmpty else { throw CIDParseError.invalidPrefix("CID string cannot be empty") }
        guard cidString.hasPrefix("b") else { throw CIDParseError.invalidPrefix("Requires 'b' prefix") }
        guard cidString.count >= 10 && cidString.count <= 100 else {
            throw CIDParseError.invalidPrefix("CID string length out of valid range")
        }
        let base32Part = String(cidString.dropFirst())
        guard let cidBytes = base32Decode(base32Part.uppercased()) else { throw CIDParseError.invalidBase32Encoding }
        return try cidFromBytes(cidBytes)
    }

    static func cidFromBytes(_ cidBytes: Data) throws -> CIDParts {
        guard cidBytes.count >= 4 else { throw CIDParseError.insufficientLength }
        guard cidBytes[0] == 0x01 else { throw CIDParseError.invalidVersion(cidBytes[0]) }
        let codec = cidBytes[1]
        guard validCodecs.contains(codec) else { throw CIDParseError.unsupportedCodec(codec) }
        let hashAlgorithm = cidBytes[2]
        let hashLength = cidBytes[3]
        guard hashLength > 0, hashLength <= 64 else { throw CIDParseError.insufficientLength }
        guard cidBytes.count == 4 + Int(hashLength) else { throw CIDParseError.insufficientLength }
        let digest = Data(cidBytes[4...])
        return CIDParts(codec: codec, algorithm: hashAlgorithm, length: hashLength, digest: digest)
    }

    static func base32Decode(_ string: String) -> Data? {
        guard !string.isEmpty else { return nil }
        guard string.count <= 200 else { return nil }
        let lowercasedString = string.lowercased()
        var result = Data()
        var bits = 0
        var value: UInt32 = 0
        for charCode in lowercasedString.utf8 {
            guard let charValue = base32Lookup[charCode] else { return nil }
            value = (value << 5) | UInt32(charValue)
            bits += 5
            if bits >= 8 {
                bits -= 8
                result.append(UInt8((value >> bits) & 0xFF))
            }
        }
        return result
    }

    static func base32Encode(_ data: Data) -> String {
        var result = ""
        var bits = 0
        var value: UInt32 = 0
        for byte in data {
            value = (value << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                let index = Int((value >> bits) & 0x1F)
                result.append(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
            }
        }
        if bits > 0 {
            let index = Int((value << (5 - bits)) & 0x1F)
            result.append(base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: index)])
        }
        return result
    }

    static func cidString(_ p: CIDParts) -> String {
        let bytes = Data([0x01, p.codec]) + (Data([p.algorithm, p.length]) + p.digest)
        return "b" + base32Encode(bytes).lowercased()
    }

    // MARK: ATProtocolDate

    nonisolated(unsafe) static let longFractionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})\\.([0-9]{7,})(Z|[+-][0-9]{2}:[0-9]{2})$",
        options: []
    )

    static func parseDate(_ dateString: String) -> Date? {
        if let date = parseWithFoundation(dateString) { return date }
        if let truncated = truncatingLongFractionalSeconds(dateString) { return parseWithFoundation(truncated) }
        return nil
    }

    static func truncatingLongFractionalSeconds(_ dateString: String) -> String? {
        guard let regex = longFractionRegex else { return nil }
        let range = NSRange(location: 0, length: dateString.utf16.count)
        guard let match = regex.firstMatch(in: dateString, options: [], range: range),
              let prefixRange = Range(match.range(at: 1), in: dateString),
              let fractionRange = Range(match.range(at: 2), in: dateString),
              let zoneRange = Range(match.range(at: 3), in: dateString)
        else { return nil }
        let fraction = dateString[fractionRange].prefix(6)
        return "\(dateString[prefixRange]).\(fraction)\(dateString[zoneRange])"
    }

    static func parseWithFoundation(_ dateString: String) -> Date? {
        let strategy = Date.ISO8601FormatStyle(
            dateSeparator: .dash, dateTimeSeparator: .standard, timeSeparator: .colon,
            timeZoneSeparator: .omitted, includingFractionalSeconds: true, timeZone: .gmt
        )
        do {
            return try strategy.parse(dateString)
        } catch {
            let fallbackStrategy = Date.ISO8601FormatStyle()
            do {
                return try fallbackStrategy.parse(dateString)
            } catch {
                if dateString == "1970-01-01T00:00:00.000Z" { return Date(timeIntervalSince1970: 0) }
                return nil
            }
        }
    }

    /// `ATProtocolDate.formattedDate` (the encode path for non-wire dates).
    static func formattedDate(_ date: Date) -> String {
        let formatStyle = Date.ISO8601FormatStyle(
            dateSeparator: .dash, dateTimeSeparator: .standard, timeSeparator: .colon,
            timeZoneSeparator: .omitted, includingFractionalSeconds: true, timeZone: .gmt
        )
        var result = formatStyle.format(date)
        if let dotIndex = result.firstIndex(of: ".") {
            let fractionalPart = result[result.index(after: dotIndex)...]
            if let zIndex = fractionalPart.firstIndex(of: "Z") {
                let digits = fractionalPart.distance(from: fractionalPart.startIndex, to: zIndex)
                if digits < 3 {
                    let zerosToAdd = 3 - digits
                    let insertIndex = result.index(dotIndex, offsetBy: digits + 1)
                    result.insert(contentsOf: String(repeating: "0", count: zerosToAdd), at: insertIndex)
                } else if digits > 3 {
                    let endIndex = result.index(dotIndex, offsetBy: 4)
                    let zIndex = result.lastIndex(of: "Z")!
                    result.replaceSubrange(endIndex ..< zIndex, with: "")
                }
            }
        } else if result.hasSuffix("Z") {
            let insertIndex = result.index(before: result.endIndex)
            result.insert(contentsOf: ".000", at: insertIndex)
        }
        return result
    }
}

/// Deterministic SplitMix64 so every fuzz failure is reproducible.
struct LeafSplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
