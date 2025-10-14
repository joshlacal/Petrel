//
//  SecurityCompat.swift
//  Petrel
//
//  Cross-platform Security framework compatibility
//

import Foundation

#if os(iOS) || os(macOS)
    import Security
#else
    // Define Security framework constants for cross-platform compatibility
    let errSecSuccess: Int = 0
    let errSecItemNotFound: Int = -25300
    let errSecDuplicateItem: Int = -25299
    let errSecAuthFailed: Int = -25293
#endif
