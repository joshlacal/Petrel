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
    /// Normalizes IPv4-mapped IPv6 addresses (e.g. ::ffff:192.0.2.1 or ::ffff:7f00:1 -> 192.0.2.1 / 127.0.0.1)
    static func normalizeIPv4MappedIPv6(_ ip: String) -> String {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        #if canImport(Network)
            if let v6 = IPv6Address(trimmed) {
                let bytes = v6.rawValue
                // ::ffff:0:0/96 (IPv4-mapped IPv6)
                if bytes.prefix(10) == Data(repeating: 0, count: 10) && bytes[10] == 0xFF && bytes[11] == 0xFF {
                    let v4Bytes = bytes.suffix(4)
                    let octets = Array(v4Bytes)
                    return "\(octets[0]).\(octets[1]).\(octets[2]).\(octets[3])"
                }
                // 64:ff9b::/96 (Well-Known Prefix for IPv4/IPv6 translation)
                if bytes.prefix(12) == Data([0x00, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0]) {
                    let v4Bytes = bytes.suffix(4)
                    let octets = Array(v4Bytes)
                    return "\(octets[0]).\(octets[1]).\(octets[2]).\(octets[3])"
                }
                // 2002::/16 (6to4)
                if bytes[0] == 0x20 && bytes[1] == 0x02 {
                    return "\(bytes[2]).\(bytes[3]).\(bytes[4]).\(bytes[5])"
                }
            }
        #endif
        if trimmed.hasPrefix("::ffff:") {
            let suffix = String(trimmed.dropFirst(7))
            if Self.isValidIPv4(suffix) {
                return suffix
            }
        }
        return ip
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

            if let v6 = IPv6Address(normalized) {
                let bytes = v6.rawValue
                // ::/128 unspecified
                if bytes == Data(repeating: 0, count: 16) { return true }
                // ::1/128 loopback
                if bytes == Data(repeating: 0, count: 15) + Data([1]) { return true }
                // fe80::/10 link-local
                if (bytes[0] == 0xFE) && ((bytes[1] & 0xC0) == 0x80) { return true }
                // fc00::/7 unique local
                if (bytes[0] & 0xFE) == 0xFC { return true }
                // ff00::/8 multicast
                if bytes[0] == 0xFF { return true }
                // 2001:db8::/32 documentation
                if bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0D && bytes[3] == 0xB8 { return true }
                // 100::/64 discard prefix
                if bytes[0] == 0x01 && bytes[1] == 0x00 && bytes.subdata(in: 2..<8) == Data(repeating: 0, count: 6) { return true }
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

            if normalized.contains(":") {
                if normalized == "::1" || normalized == "0:0:0:0:0:0:0:1" || normalized == "::" { return true }
                if normalized.lowercased().hasPrefix("fe80:") { return true }
                if normalized.lowercased().hasPrefix("fc") || normalized.lowercased().hasPrefix("fd") { return true }
                if normalized.lowercased().hasPrefix("ff") { return true }
                if normalized.lowercased().hasPrefix("2001:db8:") || normalized.lowercased().hasPrefix("2001:0db8:") { return true }
                if normalized.lowercased().hasPrefix("100::") { return true }
            }
        #endif

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
