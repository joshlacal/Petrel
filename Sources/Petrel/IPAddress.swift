//
//  IPAddress.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/16/24.
//

import Foundation
import Network

struct IPAddress {
    let address: String

    init?(_ address: String) {
        // Validate the IP address
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if IPv4Address(addr) != nil || IPv6Address(addr) != nil {
            self.address = addr
        } else {
            return nil
        }
    }

    func isInRange(_ cidr: String) -> Bool {
        // Supports only IPv4 for simplicity
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

        // Compare full bytes
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
    }
}
