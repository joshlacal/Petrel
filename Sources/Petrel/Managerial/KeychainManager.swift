//
//  KeychainManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import Foundation
import Security

enum KeychainError: Error {
    case itemStoreError
    case itemRetrievalError
    case dataFormatError
}

class KeychainManager {
    static func store(key: String, value: Data) throws {
        // Adjusted for storing Data
        let query =
            [
                kSecValueData: value,
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
            ] as [String: Any]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.itemStoreError }
    }

    static func retrieve(key: String) throws -> Data {
        // Adjusted to retrieve Data
        let query =
            [
                kSecReturnData: kCFBooleanTrue!,
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
            ] as [String: Any]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.itemRetrievalError
        }
        return data
    }

    static func delete(key: String) throws {
        let query =
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
            ] as [String: Any]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.itemStoreError
        }
    }
}
