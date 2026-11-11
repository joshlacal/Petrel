//
//  IPAddress.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/16/24.
//

import Foundation
#if canImport(Network)
    import Network
#endif

struct IPAddress: Sendable {
    let address: String

    init?(_ address: String) {
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(Network)
            if IPv4Address(addr) != nil || IPv6Address(addr) != nil {
                self.address = addr
            } else {
                return nil
            }
        #else
            if Self.isValidIPv4(addr) || Self.isValidIPv6(addr) {
                self.address = addr
            } else {
                return nil
            }
        #endif
    }
    /// The 16 bytes of an IPv6 address in any textual form, or `nil` when the string is not an
    /// IPv6 address. A zone suffix (`%en0`) is ignored. One parser serves every platform, so a
    /// non-canonical spelling such as `0:0:0:0:0:ffff:7f00:1` is classified the same everywhere.
    static func ipv6Bytes(_ string: String) -> [UInt8]? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = trimmed.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
        guard host.contains(":") else { return nil }
        var address = in6_addr()
        guard inet_pton(AF_INET6, host, &address) == 1 else { return nil }
        return withUnsafeBytes(of: &address) { Array($0) }
    }

    /// The IPv4 address embedded in an IPv6 address that only exists to reach an IPv4 host:
    /// IPv4-mapped (`::ffff:0:0/96`), the NAT64 well-known prefix (`64:ff9b::/96`) and 6to4
    /// (`2002::/16`).
    private static func embeddedIPv4(in bytes: [UInt8]) -> String? {
        func dotted(_ slice: ArraySlice<UInt8>) -> String {
            slice.map(String.init).joined(separator: ".")
        }
        if bytes[0 ..< 10].allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            return dotted(bytes[12 ..< 16])
        }
        if Array(bytes[0 ..< 12]) == [0x00, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0] {
            return dotted(bytes[12 ..< 16])
        }
        if bytes[0] == 0x20, bytes[1] == 0x02 {
            return dotted(bytes[2 ..< 6])
        }
        return nil
    }

    /// Replaces an IPv6 address that embeds an IPv4 address (IPv4-mapped, NAT64, 6to4) with that
    /// IPv4 address, e.g. `::ffff:7f00:1` -> `127.0.0.1`. Other strings are returned unchanged.
    static func normalizeIPv4MappedIPv6(_ ip: String) -> String {
        guard let bytes = ipv6Bytes(ip), let embedded = embeddedIPv4(in: bytes) else {
            return ip
        }
        return embedded
    }

    static func isPrivateOrReservedAddress(_ ip: String) -> Bool {
        let normalized = normalizeIPv4MappedIPv6(ip)
        #if canImport(Network)
            if let v4 = IPv4Address(normalized) {
                let octets = v4.rawValue
                let a = Int(octets[0])
                let b = Int(octets[1])

                // 0.0.0.0/8
                if a == 0 { return true }
                // 10.0.0.0/8
                if a == 10 { return true }
                // 100.64.0.0/10 (CGNAT: 100.64.0.0 – 100.127.255.255)
                if a == 100 && (64 ... 127).contains(b) { return true }
                // 127.0.0.0/8 loopback
                if a == 127 { return true }
                // 169.254.0.0/16 link-local
                if a == 169 && b == 254 { return true }
                // 172.16.0.0/12
                if a == 172 && (16 ... 31).contains(b) { return true }
                // 192.0.0.0/24 (IETF Protocol Assignments)
                if a == 192 && b == 0 && octets[2] == 0 { return true }
                // 192.0.2.0/24 (TEST-NET-1)
                if a == 192 && b == 0 && octets[2] == 2 { return true }
                // 192.168.0.0/16
                if a == 192 && b == 168 { return true }
                // 198.18.0.0/15 (Benchmarking)
                if a == 198 && (18 ... 19).contains(b) { return true }
                // 198.51.100.0/24 (TEST-NET-2)
                if a == 198 && b == 51 && octets[2] == 100 { return true }
                // 203.0.113.0/24 (TEST-NET-3)
                if a == 203 && b == 0 && octets[2] == 113 { return true }
                // 224.0.0.0/4 (Multicast: 224.0.0.0 - 239.255.255.255)
                if (224 ... 239).contains(a) { return true }
                // 240.0.0.0/4 (Reserved / Future Use) and 255.255.255.255
                if a >= 240 { return true }
            }

        #else
            let components = normalized.split(separator: ".").compactMap { Int($0) }
            if components.count == 4 {
                let a = components[0]
                let b = components[1]
                let c = components[2]

                if a == 0 { return true }
                if a == 10 { return true }
                if a == 100 && (64 ... 127).contains(b) { return true }
                if a == 127 { return true }
                if a == 169 && b == 254 { return true }
                if a == 172 && (16 ... 31).contains(b) { return true }
                if a == 192 && b == 0 && c == 0 { return true }
                if a == 192 && b == 0 && c == 2 { return true }
                if a == 192 && b == 168 { return true }
                if a == 198 && (18 ... 19).contains(b) { return true }
                if a == 198 && b == 51 && c == 100 { return true }
                if a == 203 && b == 0 && c == 113 { return true }
                if (224 ... 239).contains(a) { return true }
                if a >= 240 { return true }
            }

        #endif

        if normalized.contains(":") {
            // An IPv6 literal that does not parse cannot be shown to be public.
            guard let bytes = ipv6Bytes(normalized) else { return true }
            return isPrivateOrReservedIPv6(bytes)
        }

        return false
    }

    private static func isPrivateOrReservedIPv6(_ bytes: [UInt8]) -> Bool {
        // ::/96: unspecified (::), loopback (::1) and the deprecated IPv4-compatible addresses.
        if bytes[0 ..< 12].allSatisfy({ $0 == 0 }) { return true }
        // An embedded IPv4 address is judged as that IPv4 address.
        if let embedded = embeddedIPv4(in: bytes) { return isPrivateOrReservedAddress(embedded) }
        // 64:ff9b:1::/48 local-use IPv4/IPv6 translation
        if Array(bytes[0 ..< 6]) == [0x00, 0x64, 0xFF, 0x9B, 0x00, 0x01] { return true }
        // fe80::/10 link-local and fec0::/10 site-local (deprecated)
        if bytes[0] == 0xFE, (bytes[1] & 0xC0) == 0x80 || (bytes[1] & 0xC0) == 0xC0 { return true }
        // fc00::/7 unique local
        if (bytes[0] & 0xFE) == 0xFC { return true }
        // ff00::/8 multicast
        if bytes[0] == 0xFF { return true }
        // 2001::/32 Teredo and 2001:db8::/32 documentation
        if bytes[0] == 0x20, bytes[1] == 0x01, bytes[2] == 0x00, bytes[3] == 0x00 { return true }
        if bytes[0] == 0x20, bytes[1] == 0x01, bytes[2] == 0x0D, bytes[3] == 0xB8 { return true }
        // 100::/64 discard prefix
        if bytes[0] == 0x01, bytes[1] == 0x00, bytes[2 ..< 8].allSatisfy({ $0 == 0 }) { return true }
        return false
    }

    func isInRange(_ cidr: String) -> Bool {
        #if canImport(Network)
            let parts = cidr.split(separator: "/")
            guard parts.count == 2,
                  let cidrAddress = IPv4Address(String(parts[0])),
                  let prefixLength = UInt8(String(parts[1])),
                  let ip = IPv4Address(address)
            else {
                return false
            }

            var cidrOctets = cidrAddress.rawValue
            var ipOctets = ip.rawValue

            let fullBytes = Int(prefixLength) / 8
            let remainingBits = Int(prefixLength) % 8

            for i in 0 ..< fullBytes {
                if cidrOctets[i] != ipOctets[i] {
                    return false
                }
            }

            if remainingBits > 0 {
                let mask = UInt8.max << (8 - remainingBits)
                if (cidrOctets[fullBytes] & mask) != (ipOctets[fullBytes] & mask) {
                    return false
                }
            }

            return true
        #else
            let parts = cidr.split(separator: "/")
            guard parts.count == 2,
                  Self.isValidIPv4(String(parts[0])),
                  let prefixLength = UInt8(String(parts[1])),
                  Self.isValidIPv4(address)
            else {
                return false
            }

            let cidrOctets = String(parts[0]).split(separator: ".").compactMap { UInt8($0) }
            let ipOctets = address.split(separator: ".").compactMap { UInt8($0) }

            guard cidrOctets.count == 4 && ipOctets.count == 4 else {
                return false
            }

            let fullBytes = Int(prefixLength) / 8
            let remainingBits = Int(prefixLength) % 8

            for i in 0 ..< fullBytes {
                if cidrOctets[i] != ipOctets[i] {
                    return false
                }
            }

            if remainingBits > 0 && fullBytes < 4 {
                let mask = UInt8.max << (8 - remainingBits)
                if (cidrOctets[fullBytes] & mask) != (ipOctets[fullBytes] & mask) {
                    return false
                }
            }

            return true
        #endif
    }

    static func isValidIPv4(_ string: String) -> Bool {
        let octets = string.split(separator: ".")
        guard octets.count == 4 else { return false }

        for octet in octets {
            guard let value = UInt8(octet), value <= 255 else {
                return false
            }
        }
        return true
    }

    static func isValidIPv6(_ string: String) -> Bool {
        let validChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        let stringChars = CharacterSet(charactersIn: string)

        guard stringChars.isSubset(of: validChars),
              string.contains(":"),
              !string.hasPrefix(":"),
              !string.hasSuffix(":") || string.hasSuffix("::")
        else {
            return false
        }

        let groups = string.split(separator: ":")
        return groups.count >= 3 && groups.count <= 8
    }
}
