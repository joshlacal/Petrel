//
//  URLStaticString.swift
//  Petrel
//
//  Safe construction of URLs from compile-time literals.
//

import Foundation

extension URL {
    /// Creates a URL from a compile-time constant string.
    ///
    /// Replaces scattered `URL(string: "…")!` force-unwraps for known-valid
    /// literals: a malformed literal is a programmer error caught the first
    /// time the constant is evaluated, with a clear message instead of a
    /// bare force-unwrap crash.
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("Invalid static URL literal: \(staticString)")
        }
        self = url
    }
}
