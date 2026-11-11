/// AT Protocol identifier syntax used by the scope grammar.
///
/// Every predicate here is a port of the validator the reference
/// implementation's `@atproto/oauth-scopes` calls for the same parameter, so a
/// scope string is accepted or rejected for the same reason on both sides. They
/// operate on UTF-8 bytes; each accepts ASCII only, so byte offsets and the
/// reference implementation's UTF-16 offsets coincide on every accepted value.
public enum AtprotoSyntax {
    // MARK: - DID

    /// Whether `value` is a DID under the AT Protocol DID syntax
    /// (`packages/syntax/src/did.ts:51`): at most 2048 bytes and
    /// `^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$`.
    ///
    /// This is the method-agnostic identifier grammar. It is not the predicate
    /// the scope grammar applies to an `aud` parameter; that one is
    /// ``isValidAtprotoDIDRefAbsolute(_:)``.
    public static func isValidDID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count <= 2048, bytes.count >= 7 else { return false }
        guard bytes.starts(with: didPrefix) else { return false }
        // method = 1*[a-z]
        var i = 4
        let methodStart = i
        while i < bytes.count, (0x61 ... 0x7A).contains(bytes[i]) {
            i += 1
        }
        guard i > methodStart else { return false }
        guard i < bytes.count, bytes[i] == 0x3A else { return false } // ":"
        i += 1
        let msidStart = i
        guard i < bytes.count else { return false }
        while i < bytes.count, isDIDSyntaxMSIDChar(bytes[i]) {
            i += 1
        }
        guard i == bytes.count, i > msidStart else { return false }
        // The final byte is `[a-zA-Z0-9._-]`: neither `:` nor `%`.
        guard let last = bytes.last, isDIDNameChar(last) else { return false }
        return true
    }

    private static let didPrefix: [UInt8] = Array("did:".utf8)

    /// `[a-zA-Z0-9._:%-]`
    private static func isDIDSyntaxMSIDChar(_ c: UInt8) -> Bool {
        isDIDNameChar(c) || c == 0x3A || c == 0x25
    }

    /// `[a-zA-Z0-9._-]`
    private static func isDIDNameChar(_ c: UInt8) -> Bool {
        (0x41 ... 0x5A).contains(c) || (0x61 ... 0x7A).contains(c) || (0x30 ... 0x39).contains(c)
            || c == 0x2E || c == 0x5F || c == 0x2D
    }

    /// `isDid` of `@atproto/did` (`packages/did/src/did.ts:210-245`), the W3C
    /// DID Core grammar that DID references are checked against.
    ///
    /// It differs from ``isValidDID(_:)`` in three ways: the method name is
    /// `[a-z0-9]+`, a `%` must introduce two UPPERCASE hexadecimal digits
    /// (`did.ts:173-199`), and the only constraint on the final byte is that it
    /// is not `:`.
    static func isDIDCoreDID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count <= 2048, bytes.starts(with: didPrefix) else { return false }
        guard let separator = bytes[4...].firstIndex(of: 0x3A) else { return false }
        let method = bytes[4 ..< separator]
        guard !method.isEmpty, method.allSatisfy({ (0x61 ... 0x7A).contains($0) || (0x30 ... 0x39).contains($0) })
        else { return false }
        return isDIDCoreMSID(bytes[(separator + 1)...])
    }

    /// `assertDidMsid`, `packages/did/src/did.ts:133-208`.
    private static func isDIDCoreMSID(_ bytes: ArraySlice<UInt8>) -> Bool {
        guard !bytes.isEmpty else { return false }
        var i = bytes.startIndex
        while i < bytes.endIndex {
            let c = bytes[i]
            if isDIDNameChar(c) {
                i += 1
            } else if c == 0x3A { // ":" — anywhere but last
                guard i != bytes.endIndex - 1 else { return false }
                i += 1
            } else if c == 0x25 { // "%" HEXDIG HEXDIG
                guard i + 2 < bytes.endIndex,
                      isUppercaseHexDigit(bytes[i + 1]), isUppercaseHexDigit(bytes[i + 2])
                else { return false }
                i += 3
            } else {
                return false
            }
        }
        return true
    }

    private static func isUppercaseHexDigit(_ c: UInt8) -> Bool {
        (0x30 ... 0x39).contains(c) || (0x41 ... 0x46).contains(c)
    }

    // MARK: - NSID

    /// Whether `value` is an NSID, as `isValidNsid` decides it
    /// (`packages/syntax/src/nsid.ts:164-180`): at most 317 bytes, at least
    /// three `.`-separated segments of 1 to 63 bytes, and
    ///
    ///  - the first segment starts with a letter;
    ///  - no segment but the last starts or ends with `-`;
    ///  - the last ("name") segment starts with a letter and contains letters
    ///    and digits only.
    ///
    /// Only the first and last segments may not start with a digit, so
    /// `com.9example.foo` is an NSID and `com.example.1foo` is not.
    public static func isValidNSID(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count <= 317, !bytes.isEmpty else { return false }
        let segments = bytes.split(separator: 0x2E, omittingEmptySubsequences: false)
        guard segments.count >= 3 else { return false }
        for (index, segment) in segments.enumerated() {
            guard let first = segment.first, let last = segment.last, segment.count <= 63 else {
                return false
            }
            let isNameSegment = index == segments.count - 1
            if index == 0 || isNameSegment {
                guard isASCIILetter(first) else { return false }
            } else {
                guard isASCIILetter(first) || isASCIIDigit(first) else { return false }
            }
            if isNameSegment {
                guard segment.allSatisfy({ isASCIILetter($0) || isASCIIDigit($0) }) else { return false }
            } else {
                guard segment.allSatisfy({ isASCIILetter($0) || isASCIIDigit($0) || $0 == 0x2D }),
                      last != 0x2D
                else { return false }
            }
        }
        return true
    }

    private static func isASCIILetter(_ c: UInt8) -> Bool {
        (0x41 ... 0x5A).contains(c) || (0x61 ... 0x7A).contains(c)
    }

    private static func isASCIIDigit(_ c: UInt8) -> Bool {
        (0x30 ... 0x39).contains(c)
    }

    // MARK: - Record key

    /// Whether `value` is a record key: 1 to 512 bytes of `[A-Za-z0-9._:~-]`,
    /// and neither `.` nor `..`.
    public static func isValidRecordKey(_ value: String) -> Bool {
        guard value != ".", value != ".." else { return false }
        let bytes = Array(value.utf8)
        guard bytes.count >= 1, bytes.count <= 512 else { return false }
        return bytes.allSatisfy { byte in
            isASCIILetter(byte) || isASCIIDigit(byte)
                || byte == 0x2D || byte == 0x2E || byte == 0x5F || byte == 0x3A || byte == 0x7E
        }
    }

    // MARK: - DID references

    /// Whether `value` is an absolute DID reference, `<did>#<fragment>`, for any
    /// DID method. Port of `isDidRefAbsolute`,
    /// `packages/did/src/did-ref.ts:11-18`:
    ///
    ///  1. exactly one `#` (`:14`, `:16`);
    ///  2. a non-empty fragment (`:15`);
    ///  3. the fragment is an RFC 3986 section 3.5 `fragment`
    ///     (`isFragment`, `packages/did/src/lib/uri.ts:5-59`);
    ///  4. the part before `#` is a DID Core DID (`isDid`,
    ///     `packages/did/src/did.ts:233-245`).
    public static func isValidDIDRefAbsolute(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard let hash = bytes.firstIndex(of: 0x23) else { return false }
        guard hash != bytes.count - 1 else { return false }
        guard !bytes[(hash + 1)...].contains(0x23) else { return false }
        guard isFragment(bytes, from: hash + 1, to: bytes.count) else { return false }
        return isDIDCoreDID(String(decoding: bytes[..<hash], as: UTF8.self))
    }

    /// Whether `value` is an absolute DID reference whose DID is one AT
    /// Protocol accepts: `did:plc` or `did:web`, followed by a mandatory
    /// non-empty fragment, as in `did:web:api.example.com#svc_appview`.
    ///
    /// This is the predicate the `aud` parameter of `rpc:` and `include:`
    /// scopes is validated with. Port of `isAtprotoDidRefAbsolute`,
    /// `packages/did/src/atproto.ts:230-235`, which is two independent checks:
    /// ``isValidDIDRefAbsolute(_:)`` on the whole value, then
    /// ``isValidAtprotoDID(_:)`` on the part before `#`.
    public static func isValidAtprotoDIDRefAbsolute(_ value: String) -> Bool {
        guard isValidDIDRefAbsolute(value) else { return false }
        let bytes = Array(value.utf8)
        guard let hash = bytes.firstIndex(of: 0x23) else { return false }
        return isValidAtprotoDID(String(decoding: bytes[..<hash], as: UTF8.self))
    }

    /// Whether `value` is a DID of a method AT Protocol accepts for identities:
    /// `did:plc`, or a `did:web` with no path and no port other than on
    /// `localhost`. Port of `isAtprotoDid`, `packages/did/src/atproto.ts:27-29`.
    public static func isValidAtprotoDID(_ value: String) -> Bool {
        isValidDIDPlc(value) || isValidAtprotoDIDWeb(value)
    }

    /// `isDidPlc`, `packages/did/src/methods/plc.ts:10-19`: exactly 32 bytes,
    /// `did:plc:` followed by 24 base32 characters (`[a-z2-7]`, `:53-54`).
    private static func isValidDIDPlc(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard bytes.count == 32, value.hasPrefix("did:plc:") else { return false }
        return bytes[8...].allSatisfy { (0x61 ... 0x7A).contains($0) || (0x32 ... 0x37).contains($0) }
    }

    /// `isAtprotoDidWeb`, `packages/did/src/atproto.ts:74-88`.
    private static func isValidAtprotoDIDWeb(_ value: String) -> Bool {
        guard isValidDIDWeb(value) else { return false }
        guard !didWebHasPath(value) else { return false }
        guard !didWebHasHTTPSPort(value) else { return false }
        return true
    }

    /// `isDidWeb`, `packages/did/src/methods/web.ts:10-23`: the prefix, no
    /// leading `:`, a DID Core method-specific id, and an identifier that
    /// rebuilds into a URL the WHATWG URL parser accepts.
    private static func isValidDIDWeb(_ value: String) -> Bool {
        guard value.hasPrefix("did:web:") else { return false }
        let msid = Array(value.utf8)[8...]
        guard msid.first != 0x3A, isDIDCoreMSID(msid) else { return false }
        return didWebURLCanParse(msid)
    }

    /// `isDidWebWithPath`, `packages/did/src/atproto.ts:90-92`: any `:` after
    /// the `did:web:` prefix starts a path.
    private static func didWebHasPath(_ did: String) -> Bool {
        did.utf8.dropFirst(8).contains(0x3A)
    }

    /// `isDidWebWithHttpsPort`, `packages/did/src/atproto.ts:94-117`. A port is
    /// allowed on `localhost` only, so a development server at
    /// `did:web:localhost%3A8080` stays valid.
    private static func didWebHasHTTPSPort(_ did: String) -> Bool {
        if did == "did:web:localhost"
            || did.hasPrefix("did:web:localhost:")
            || did.hasPrefix("did:web:localhost%3A") { return false }
        // Reached only for a DID without a path component, where an encoded
        // colon anywhere after the prefix is a port.
        return did.dropFirst(8).contains("%3A")
    }

    // MARK: - did:web URL

    /// Whether the URL `buildDidWebUrl` derives from a `did:web` identifier
    /// (`packages/did/src/methods/web.ts:68-83`) is one `URL.canParse` accepts.
    ///
    /// The reference implementation hands the rebuilt `https://<host><path>`
    /// string to the platform's WHATWG URL parser. Foundation's `URL` is not
    /// that parser and differs between Apple platforms and Linux, so the
    /// relevant part of the URL Standard is implemented here instead. The
    /// method-specific id is already restricted to `[A-Za-z0-9._-]`, `:` and
    /// `%XX`, which leaves only the authority able to fail:
    ///
    ///  - the host is everything up to the first `:`; `%3A` in it stands for
    ///    the port separator (`web.ts:74`);
    ///  - a port is ASCII digits, possibly none, with a value of at most 65535;
    ///  - the host is percent-decoded, must be non-empty and must not contain a
    ///    forbidden domain code point;
    ///  - a host whose last label is a number is an IPv4 address and must
    ///    parse as one.
    ///
    /// Two deliberate limits, both on hosts no deployed service uses. A host
    /// that percent-decodes to non-ASCII bytes is rejected, where the URL
    /// Standard would apply the IDNA mapping. An `xn--` label is required to be
    /// well-formed Punycode for at least one non-ASCII code point that is
    /// neither a control, a separator, unassigned nor private-use; the IDNA
    /// table is not consulted beyond that.
    private static func didWebURLCanParse(_ msid: ArraySlice<UInt8>) -> Bool {
        let hostEnd = msid.firstIndex(of: 0x3A) ?? msid.endIndex
        // `%3A` -> ":" splits the authority into host and port. A second
        // occurrence leaves a `:` inside the port, which is not a digit.
        var authority: [UInt8] = []
        var i = msid.startIndex
        while i < hostEnd {
            if msid[i] == 0x25, msid[i + 1] == 0x33, msid[i + 2] == 0x41 {
                authority.append(0x3A)
                i += 3
            } else {
                authority.append(msid[i])
                i += 1
            }
        }

        let encodedHost: ArraySlice<UInt8>
        if let colon = authority.firstIndex(of: 0x3A) {
            let port = authority[(colon + 1)...]
            guard port.allSatisfy(isASCIIDigit) else { return false }
            var value = 0
            for digit in port {
                value = value * 10 + Int(digit - 0x30)
                guard value <= 65535 else { return false }
            }
            encodedHost = authority[..<colon]
        } else {
            encodedHost = authority[...]
        }

        // Percent-decode. `isDIDCoreMSID` already established that every `%`
        // is followed by two hexadecimal digits.
        var host: [UInt8] = []
        var j = encodedHost.startIndex
        while j < encodedHost.endIndex {
            if encodedHost[j] == 0x25,
               let high = hexValue(encodedHost[j + 1]), let low = hexValue(encodedHost[j + 2]) {
                host.append(high << 4 | low)
                j += 3
            } else {
                host.append(encodedHost[j])
                j += 1
            }
        }

        guard !host.isEmpty, host.allSatisfy({ $0 < 0x80 && !isForbiddenDomainCodePoint($0) }) else {
            return false
        }
        let labels = host.map { (0x41 ... 0x5A).contains($0) ? $0 + 0x20 : $0 }
            .split(separator: 0x2E, omittingEmptySubsequences: false)
        guard labels.allSatisfy(isAcceptableDomainLabel) else { return false }
        if endsInANumber(labels) {
            return isIPv4Address(labels)
        }
        return true
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30 ... 0x39: byte - 0x30
        case 0x41 ... 0x46: byte - 0x41 + 10
        case 0x61 ... 0x66: byte - 0x61 + 10
        default: nil
        }
    }

    /// URL Standard, "forbidden domain code point", restricted to ASCII.
    private static func isForbiddenDomainCodePoint(_ c: UInt8) -> Bool {
        if c <= 0x20 || c == 0x7F { return true }
        switch c {
        case 0x23, 0x25, 0x2F, 0x3A, 0x3C, 0x3E, 0x3F, 0x40, 0x5B, 0x5C, 0x5D, 0x5E, 0x7C: return true
        default: return false
        }
    }

    /// A label is acceptable unless it claims to be Punycode and is not.
    private static func isAcceptableDomainLabel(_ label: ArraySlice<UInt8>) -> Bool {
        guard label.starts(with: Array("xn--".utf8)) else { return true }
        guard let scalars = decodePunycode(label.dropFirst(4)) else { return false }
        guard scalars.contains(where: { $0.value >= 0x80 }) else { return false }
        return scalars.allSatisfy { scalar in
            guard scalar.value >= 0x80 else { return true }
            switch scalar.properties.generalCategory {
            case .control, .unassigned, .privateUse, .surrogate,
                 .spaceSeparator, .lineSeparator, .paragraphSeparator:
                return false
            default:
                return true
            }
        }
    }

    /// RFC 3492 section 6.2. `nil` when the input is not well-formed Punycode.
    private static func decodePunycode(_ input: ArraySlice<UInt8>) -> [Unicode.Scalar]? {
        let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700
        var output: [UInt32] = []
        var rest = input
        if let delimiter = input.lastIndex(of: 0x2D) {
            output = input[..<delimiter].map(UInt32.init)
            rest = input[(delimiter + 1)...]
        }
        var n = 128, i = 0, bias = 72
        var position = rest.startIndex
        while position < rest.endIndex {
            let oldI = i
            var weight = 1
            var k = base
            while true {
                guard position < rest.endIndex else { return nil }
                let byte = rest[position]
                position += 1
                let digit: Int
                switch byte {
                case 0x61 ... 0x7A: digit = Int(byte - 0x61)
                case 0x30 ... 0x39: digit = Int(byte - 0x30) + 26
                default: return nil
                }
                guard digit <= (Int(Int32.max) - i) / weight else { return nil }
                i += digit * weight
                let threshold = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < threshold { break }
                guard weight <= Int(Int32.max) / (base - threshold) else { return nil }
                weight *= base - threshold
                k += base
            }
            let count = output.count + 1
            // Bias adaptation, RFC 3492 section 6.1.
            var delta = oldI == 0 ? (i - oldI) / damp : (i - oldI) / 2
            delta += delta / count
            var adapted = 0
            while delta > ((base - tMin) * tMax) / 2 {
                delta /= base - tMin
                adapted += base
            }
            bias = adapted + (base - tMin + 1) * delta / (delta + skew)

            guard i / count <= Int(Int32.max) - n else { return nil }
            n += i / count
            i %= count
            guard n <= 0x10FFFF else { return nil }
            output.insert(UInt32(n), at: i)
            i += 1
        }
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(output.count)
        for value in output {
            guard let scalar = Unicode.Scalar(value) else { return nil }
            scalars.append(scalar)
        }
        return scalars
    }

    /// URL Standard, "ends in a number".
    private static func endsInANumber(_ labels: [ArraySlice<UInt8>]) -> Bool {
        var parts = labels
        if parts.last?.isEmpty == true {
            guard parts.count > 1 else { return false }
            parts.removeLast()
        }
        guard let last = parts.last else { return false }
        if !last.isEmpty, last.allSatisfy(isASCIIDigit) { return true }
        return parseIPv4Number(last) != nil
    }

    /// URL Standard, "IPv4 parser", reduced to success or failure.
    private static func isIPv4Address(_ labels: [ArraySlice<UInt8>]) -> Bool {
        var parts = labels
        if parts.last?.isEmpty == true { parts.removeLast() }
        guard parts.count <= 4 else { return false }
        var numbers: [UInt64] = []
        for part in parts {
            guard let number = parseIPv4Number(part) else { return false }
            numbers.append(number)
        }
        guard let last = numbers.last, numbers.dropLast().allSatisfy({ $0 <= 255 }) else { return false }
        var limit: UInt64 = 1
        for _ in 0 ..< (5 - numbers.count) {
            limit *= 256
        }
        return last < limit
    }

    /// URL Standard, "IPv4 number parser". Values too large to matter saturate.
    private static func parseIPv4Number(_ input: ArraySlice<UInt8>) -> UInt64? {
        guard !input.isEmpty else { return nil }
        var digits = input
        var radix: UInt64 = 10
        if digits.count >= 2, digits.first == 0x30, digits.dropFirst().first == 0x78 || digits.dropFirst().first == 0x58 {
            digits = digits.dropFirst(2)
            radix = 16
        } else if digits.count >= 2, digits.first == 0x30 {
            digits = digits.dropFirst(1)
            radix = 8
        }
        var value: UInt64 = 0
        for byte in digits {
            guard let digit = hexValue(byte), UInt64(digit) < radix else { return nil }
            value = min(value * radix + UInt64(digit), 1 << 40)
        }
        return value
    }

    // MARK: - RFC 3986 fragment

    /// `isFragment`, `packages/did/src/lib/uri.ts:5-59`:
    /// `fragment = *( pchar / "/" / "?" )`. An empty range is a fragment here;
    /// a caller that requires a non-empty one checks that itself.
    static func isFragment(_ value: [UInt8], from start: Int, to end: Int) -> Bool {
        var i = start
        while i < end {
            switch value[i] {
            case 0x41 ... 0x5A, 0x61 ... 0x7A, 0x30 ... 0x39,
                 0x2D, 0x2E, 0x5F, 0x7E: // unreserved
                break
            case 0x21, 0x24, 0x26, 0x27, 0x28, 0x29,
                 0x2A, 0x2B, 0x2C, 0x3B, 0x3D: // sub-delims
                break
            case 0x3A, 0x40: // ":" "@"
                break
            case 0x2F, 0x3F: // "/" "?"
                break
            case 0x25: // "%" HEXDIG HEXDIG
                guard i + 2 < end, hexValue(value[i + 1]) != nil, hexValue(value[i + 2]) != nil else {
                    return false
                }
                i += 2
            default:
                return false
            }
            i += 1
        }
        return true
    }
}
