//
//  KeychainSecItem.swift
//  Petrel
//
//  The keychain item functions every Catbird keychain access goes through.
//

#if os(iOS) || os(macOS) || os(tvOS)

    import Foundation
    import Security
    #if DEBUG
        import Synchronization
    #endif

    /// Drop-in replacements for `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`.
    ///
    /// Release builds and every non-fixture launch call Security directly. A DEBUG macOS launch
    /// with a runtime-fixture config keeps its items in that fixture's profile instead
    /// (`FixtureLaunch.keychain`), so it never reads or writes the user's login keychain.
    public enum KeychainSecItem {
        public static func add(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            #if DEBUG && os(macOS)
                if let fixture = FixtureLaunch.keychain { return fixture.add(query, result) }
            #endif
            #if DEBUG
                if let system = systemForTesting.withLock({ $0 }) { return system.add(query, result) }
            #endif
            return SecItemAdd(query, result)
        }

        public static func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            #if DEBUG && os(macOS)
                if let fixture = FixtureLaunch.keychain { return fixture.copyMatching(query, result) }
            #endif
            #if DEBUG
                if let system = systemForTesting.withLock({ $0 }) { return system.copyMatching(query, result) }
            #endif
            return SecItemCopyMatching(query, result)
        }

        public static func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
            #if DEBUG && os(macOS)
                if let fixture = FixtureLaunch.keychain { return fixture.update(query, attributes) }
            #endif
            #if DEBUG
                if let system = systemForTesting.withLock({ $0 }) { return system.update(query, attributes) }
            #endif
            return SecItemUpdate(query, attributes)
        }

        public static func delete(_ query: CFDictionary) -> OSStatus {
            #if DEBUG && os(macOS)
                if let fixture = FixtureLaunch.keychain { return fixture.delete(query) }
            #endif
            #if DEBUG
                if let system = systemForTesting.withLock({ $0 }) { return system.delete(query) }
            #endif
            return SecItemDelete(query)
        }

        #if DEBUG
            /// Tests only: stands in for Security so a test can observe any call that reaches it.
            struct SystemFunctions: Sendable {
                let add: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
                let copyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
                let update: @Sendable (CFDictionary, CFDictionary) -> OSStatus
                let delete: @Sendable (CFDictionary) -> OSStatus
            }

            private static let systemForTesting = Mutex<SystemFunctions?>(nil)

            static func setSystemForTesting(_ functions: SystemFunctions?) {
                systemForTesting.withLock { $0 = functions }
            }
        #endif
    }

#endif
