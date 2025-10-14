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

struct IPAddress {
    let address: String

    init?(_ address: String) {
        // Validate the IP address
        let addr = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        #if canImport(Network)
        if IPv4Address(addr) != nil || IPv6Address(addr) != nil {
            self.address = addr
        } else {
            return nil
        }
        #else
        // On Linux, use regex-based validation
        if Self.isValidIPv4(addr) || Self.isValidIPv6(addr) {
            self.address = addr
        } else {
            return nil
        }
        #endif
    }

    func isInRange(_ cidr: String) -> Bool {
        #if canImport(Network)
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
        #else
        // Linux fallback - basic IPv4 CIDR checking
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
        
        // Compare full bytes
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
    
    #if !canImport(Network)
    // Linux-only IP validation helpers
    private static func isValidIPv4(_ string: String) -> Bool {
        let octets = string.split(separator: ".")
        guard octets.count == 4 else { return false }
        
        for octet in octets {
            guard let value = UInt8(octet), value <= 255 else {
                return false
            }
        }
        return true
    }
    
    private static func isValidIPv6(_ string: String) -> Bool {
        // Simple IPv6 validation - contains colons and valid hex characters
        let validChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        let stringChars = CharacterSet(charactersIn: string)
        
        guard stringChars.isSubset(of: validChars),
              string.contains(":"),
              !string.hasPrefix(":"),
              !string.hasSuffix(":") || string.hasSuffix("::") else {
            return false
        }
        
        // Very basic check - a proper IPv6 validator would be more complex
        let groups = string.split(separator: ":")
        return groups.count >= 3 && groups.count <= 8
    }
    #endif
}
