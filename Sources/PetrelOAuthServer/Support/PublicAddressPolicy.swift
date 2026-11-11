import Foundation

/// Decides whether an authorization server may open an outbound connection
/// to an IP address.
///
/// Client metadata and JWKS retrieval, `did:web` and PLC document fetches,
/// handle verification and Lexicon resolution all resolve hostnames chosen by
/// a remote party. Each must check the addresses a hostname resolved to before
/// connecting, so that a request cannot be steered at the server's own network
/// (server-side request forgery). Every such check goes through this one type,
/// so that a range refused on one path is refused on all of them.
public enum OAuthPublicAddressPolicy {
    /// Network-order IPv4. The deny list is the special-purpose registry, not
    /// merely RFC 1918: loopback, "this network", CGNAT, link-local,
    /// benchmarking, documentation, 6to4 relay anycast, multicast, and
    /// reserved ranges are all non-destinations.
    public static func isPublicInternetAddress(ipv4 value: UInt32) -> Bool {
        let first = UInt8((value >> 24) & 0xFF)
        let second = UInt8((value >> 16) & 0xFF)
        let third = UInt8((value >> 8) & 0xFF)
        if first == 0 || first == 10 || first == 127 || first >= 224 { return false }
        if first == 100, (64 ... 127).contains(second) { return false }
        if first == 169, second == 254 { return false }
        if first == 172, (16 ... 31).contains(second) { return false }
        if first == 192, second == 0, third == 0 { return false }
        if first == 192, second == 0, third == 2 { return false }
        if first == 192, second == 88, third == 99 { return false }
        if first == 192, second == 168 { return false }
        if first == 198, second == 18 || second == 19 { return false }
        if first == 198, second == 51, third == 100 { return false }
        if first == 203, second == 0, third == 113 { return false }
        return true
    }

    /// Sixteen network-order IPv6 bytes. Any other length is not an address
    /// and is refused rather than defaulted.
    public static func isPublicInternetAddress(ipv6 bytes: Data) -> Bool {
        guard bytes.count == 16 else { return false }
        // Re-base the octets: `Data` keeps the slice's original indices, and
        // this classifier is reached with values built by several different
        // callers.
        let octets = [UInt8](bytes)
        // An IPv4-mapped address inherits the IPv4 decision instead of
        // becoming an alternate spelling for an unsafe peer.
        if octets.prefix(10).allSatisfy({ $0 == 0 }), octets[10] == 0xFF, octets[11] == 0xFF {
            let mapped = (UInt32(octets[12]) << 24) | (UInt32(octets[13]) << 16)
                | (UInt32(octets[14]) << 8) | UInt32(octets[15])
            return isPublicInternetAddress(ipv4: mapped)
        }
        // Global unicast is 2000::/3. Everything outside it is unspecified,
        // loopback, ULA, link-local, multicast, or reserved.
        guard octets[0] & 0xE0 == 0x20 else { return false }
        // IANA IPv6 Special-Purpose Address Registry, last updated
        // 2025-10-09. The whole 2001::/23 protocol-assignment block is
        // refused, rather than keeping exceptions for
        // protocol anycast/tunneling ranges as fetch destinations. 2002::/16
        // matters twice over: a 6to4 address embeds an IPv4 destination in
        // bytes 2...5, so accepting it would be a second spelling for every
        // IPv4 address this policy already refuses.
        let deniedSpecialPurposePrefixes: [([UInt8], Int)] = [
            ([0x20, 0x01, 0x00], 23), // IETF assignments
            ([0x20, 0x01, 0x0D, 0xB8], 32), // documentation
            ([0x20, 0x02], 16), // 6to4
            ([0x3F, 0xFF, 0x00], 20), // documentation
        ]
        return !deniedSpecialPurposePrefixes.contains {
            hasPrefix(octets, prefix: $0.0, bitCount: $0.1)
        }
    }

    /// True when the whole 16-byte address is loopback (`::1`).
    public static func isLoopback(ipv6 bytes: Data) -> Bool {
        bytes.count == 16 && [UInt8](bytes) == [UInt8](repeating: 0, count: 15) + [1]
    }

    /// True when the network-order IPv4 value is in 127.0.0.0/8.
    public static func isLoopback(ipv4 value: UInt32) -> Bool {
        (value >> 24) == 127
    }

    private static func hasPrefix(
        _ address: [UInt8],
        prefix: [UInt8],
        bitCount: Int
    ) -> Bool {
        guard address.count == 16, bitCount >= 0,
              bitCount <= prefix.count * 8 else {
            return false
        }
        let wholeBytes = bitCount / 8
        guard Array(address.prefix(wholeBytes)) == Array(prefix.prefix(wholeBytes)) else {
            return false
        }
        let remainingBits = bitCount % 8
        guard remainingBits > 0 else { return true }
        let mask = UInt8.max << (8 - remainingBits)
        return address[wholeBytes] & mask == prefix[wholeBytes] & mask
    }
}
