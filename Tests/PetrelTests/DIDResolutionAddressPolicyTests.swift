@testable import Petrel
import Testing

/// The address classification behind the identity transport's private-network guard. IPv6 is
/// parsed by one routine on every platform, so these cases hold on Linux as on Apple platforms.
@Suite("Identity transport address policy")
struct DIDResolutionAddressPolicyTests {
    @Test("Private, loopback, link-local and reserved addresses are refused in every spelling")
    func reservedAddresses() {
        let reserved = [
            // IPv4
            "0.0.0.0", "10.0.0.1", "100.64.0.1", "127.0.0.1", "127.255.255.254", "169.254.169.254",
            "172.16.0.1", "172.31.255.255", "192.0.0.1", "192.0.2.1", "192.168.1.1", "198.18.0.1",
            "198.51.100.1", "203.0.113.1", "224.0.0.1", "240.0.0.1", "255.255.255.255",
            // IPv6 loopback and unspecified, canonical and expanded
            "::", "::1", "0:0:0:0:0:0:0:1", "0000:0000:0000:0000:0000:0000:0000:0001", "::0001",
            // Link-local across the whole fe80::/10, with and without a zone
            "fe80::1", "FE80::1", "fe90::1", "fea0::1", "febf::1", "fe80::1%en0", "fec0::1",
            // Unique local, multicast, documentation, discard, Teredo
            "fc00::1", "fd12:3456:789a::1", "ff02::1", "2001:db8::1", "2001:0db8::1", "100::1", "2001:0:abcd::1",
            // IPv4 reached through IPv6: mapped, compatible, NAT64, 6to4
            "::ffff:127.0.0.1", "::ffff:7f00:1", "0:0:0:0:0:ffff:7f00:1", "::ffff:10.0.0.1", "::ffff:169.254.1.1",
            "::127.0.0.1", "::10.0.0.1", "::a00:1",
            "64:ff9b::7f00:1", "64:ff9b::10.0.0.1", "64:ff9b::a9fe:a9fe", "64:ff9b:1::1",
            "2002:7f00:1::1", "2002:a00:1::", "2002:c0a8:101::1",
            // Not parseable as an address at all
            "fe80::zz", "1::2::3", ":::",
        ]
        for address in reserved {
            #expect(IPAddress.isPrivateOrReservedAddress(address), "\(address)")
        }
    }

    @Test("Public addresses are allowed, including IPv4 reached through IPv6")
    func publicAddresses() {
        let allowed = [
            "93.184.216.34", "104.244.42.1", "8.8.8.8", "172.32.0.1", "100.128.0.1", "198.20.0.1",
            "2606:4700:4700::1111", "2a00:1450:4001:81b::200e", "2001:4860:4860::8888",
            "::ffff:93.184.216.34", "64:ff9b::5db8:d822", "2002:5db8:d822::1",
        ]
        for address in allowed {
            #expect(!IPAddress.isPrivateOrReservedAddress(address), "\(address)")
        }
    }

    @Test("An IPv6 address that embeds an IPv4 address is normalized to it")
    func normalization() {
        #expect(IPAddress.normalizeIPv4MappedIPv6("::ffff:7f00:1") == "127.0.0.1")
        #expect(IPAddress.normalizeIPv4MappedIPv6("0:0:0:0:0:ffff:7f00:1") == "127.0.0.1")
        #expect(IPAddress.normalizeIPv4MappedIPv6("::FFFF:192.0.2.1") == "192.0.2.1")
        #expect(IPAddress.normalizeIPv4MappedIPv6("64:ff9b::5db8:d822") == "93.184.216.34")
        #expect(IPAddress.normalizeIPv4MappedIPv6("2002:5db8:d822::1") == "93.184.216.34")
        #expect(IPAddress.normalizeIPv4MappedIPv6("::1") == "::1")
        #expect(IPAddress.normalizeIPv4MappedIPv6("2606:4700:4700::1111") == "2606:4700:4700::1111")
        #expect(IPAddress.normalizeIPv4MappedIPv6("93.184.216.34") == "93.184.216.34")
    }
}
