use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

pub(super) fn is_private_or_reserved(address: IpAddr) -> bool {
    match address {
        IpAddr::V4(address) => is_private_v4(address),
        IpAddr::V6(address) => {
            if let Some(embedded) = embedded_ipv4(address) {
                return is_private_v4(embedded);
            }
            match address.segments() {
                [0, 0, 0, 0, 0, 0, ..]             // Deprecated IPv4-compatible addresses
                | [0x64, 0xff9b, 1, ..]               // Local-use NAT64
                | [0x100, 0, 0, 0, ..]                // Discard
                | [0x2001, 0 | 0xdb8, ..]             // Teredo and documentation
                | [0xfc00..=0xfdff | 0xfe80..=0xffff, ..] => true, // Local and multicast
                _ => false,
            }
        }
    }
}

fn is_private_v4(address: Ipv4Addr) -> bool {
    matches!(
        address.octets(),
        [0 | 10 | 127 | 224..=255, ..]
            | [100, 64..=127, ..]
            | [169, 254, ..]
            | [172, 16..=31, ..]
            | [192, 0, 0 | 2, _]
            | [192, 168, ..]
            | [198, 18 | 19, ..]
            | [198, 51, 100, _]
            | [203, 0, 113, _]
    )
}

fn embedded_ipv4(address: Ipv6Addr) -> Option<Ipv4Addr> {
    let bytes = address.octets();
    match address.segments() {
        [0, 0, 0, 0, 0, 0xffff, ..]            // IPv4-mapped
        | [0x64, 0xff9b, 0, 0, 0, 0, ..] =>  // Well-known NAT64
            Some(Ipv4Addr::new(bytes[12], bytes[13], bytes[14], bytes[15])),
        [0x2002, ..] =>                       // 6to4
            Some(Ipv4Addr::new(bytes[2], bytes[3], bytes[4], bytes[5])),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_addresses_pass_and_private_or_reserved_addresses_fail() {
        let cases = [
            ("0.255.255.255", true),
            ("1.0.0.0", false),
            ("9.255.255.255", false),
            ("10.0.0.0", true),
            ("10.255.255.255", true),
            ("11.0.0.0", false),
            ("100.63.255.255", false),
            ("100.64.0.0", true),
            ("100.127.255.255", true),
            ("100.128.0.0", false),
            ("127.0.0.1", true),
            ("169.253.255.255", false),
            ("169.254.0.0", true),
            ("169.254.255.255", true),
            ("169.255.0.0", false),
            ("172.15.255.255", false),
            ("172.16.0.0", true),
            ("172.31.255.255", true),
            ("172.32.0.0", false),
            ("192.0.0.255", true),
            ("192.0.1.0", false),
            ("192.0.2.255", true),
            ("192.0.3.0", false),
            ("192.167.255.255", false),
            ("192.168.0.0", true),
            ("192.168.255.255", true),
            ("192.169.0.0", false),
            ("198.17.255.255", false),
            ("198.18.0.0", true),
            ("198.19.255.255", true),
            ("198.20.0.0", false),
            ("198.51.100.255", true),
            ("198.51.101.0", false),
            ("203.0.113.255", true),
            ("203.0.114.0", false),
            ("223.255.255.255", false),
            ("224.0.0.0", true),
            ("239.255.255.255", true),
            ("240.0.0.0", true),
            ("255.255.255.255", true),
            ("::", true),
            ("::1", true),
            ("::192.0.2.1", true),
            ("::ffff:127.0.0.1", true),
            ("::ffff:1.1.1.1", false),
            ("64:ff9b::a00:1", true),
            ("64:ff9b::101:101", false),
            ("64:ff9b:1::", true),
            ("64:ff9b:1:ffff:ffff:ffff:ffff:ffff", true),
            ("64:ff9b:2::", false),
            ("100::ffff:ffff:ffff:ffff", true),
            ("100:0:0:1::", false),
            ("2001:0:ffff:ffff:ffff:ffff:ffff:ffff", true),
            ("2001:1::", false),
            ("2001:db7:ffff:ffff:ffff:ffff:ffff:ffff", false),
            ("2001:db8::", true),
            ("2001:db9::", false),
            ("2002:a00:1::", true),
            ("2002:101:101::", false),
            ("2003::", false),
            ("fc00::", true),
            ("fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", true),
            ("fe00::", false),
            ("fe80::1", true),
            ("febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff", true),
            ("fec0::", true),
            ("feff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", true),
            ("ff00::", true),
        ];

        for (address, expected) in cases {
            assert_eq!(
                is_private_or_reserved(address.parse().unwrap()),
                expected,
                "{address}",
            );
        }
    }
}
