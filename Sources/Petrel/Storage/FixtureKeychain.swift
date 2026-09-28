//
//  FixtureKeychain.swift
//  Petrel
//
//  DEBUG runtime-fixture launch configuration; on macOS, the fixture launch's keychain file.
//

#if DEBUG && canImport(Darwin)

    import Darwin
    import Foundation
    import Security
    import Synchronization

    /// The runtime-fixture launch configuration of this process, if any.
    ///
    /// A fixture launch names a private JSON config (environment or argument) whose `profile` is a
    /// directory owned by that run. On macOS the run's keychain items live in
    /// `fixture-keychain.json` there (mode 0600), never in the user's login keychain: separate
    /// runs cannot see each other's accounts, sessions or keys, and no login-keychain ACL prompt
    /// can block startup.
    public enum FixtureLaunch {
        public enum FileError: Error, Equatable {
            case unreadable(String)
            case tooLarge(String)
            case insecurePermissions(String)
            case invalidConfiguration(String)
        }

        /// Resolves the fixture config path from the environment, then the launch arguments
        /// (`--catbird-runtime-fixture-config <path>`, `--catbird-runtime-fixture-config=<path>`,
        /// `-CatbirdRuntimeFixtureConfig <path>`).
        public static func resolveConfigPath(
            arguments: [String] = ProcessInfo.processInfo.arguments,
            environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> String? {
            if let env = environment["CATBIRD_RUNTIME_FIXTURE_CONFIG"], !env.isEmpty {
                return env
            }
            if let env = environment["CATMOS_RUNTIME_FIXTURE_CONFIG"], !env.isEmpty {
                return env
            }
            for (index, arg) in arguments.enumerated() {
                if arg == "--catbird-runtime-fixture-config" || arg == "-CatbirdRuntimeFixtureConfig" {
                    if index + 1 < arguments.count {
                        return arguments[index + 1]
                    }
                } else if arg.hasPrefix("--catbird-runtime-fixture-config=") {
                    return String(arg.dropFirst("--catbird-runtime-fixture-config=".count))
                }
            }
            return nil
        }

        /// Reads a small owner-only regular file (no symlinks, no group/other permission bits).
        public static func readPrivateFile(at path: String, maxBytes: Int = 65536) throws -> Data {
            guard !path.isEmpty else {
                throw FileError.unreadable("Path is empty")
            }
            var statBuf = stat()
            guard lstat(path, &statBuf) == 0 else {
                throw FileError.unreadable("File not found or stat failed: \(path)")
            }
            guard statBuf.st_mode & S_IFMT == S_IFREG else {
                throw FileError.unreadable("File is not a regular file or is a symlink: \(path)")
            }
            guard statBuf.st_size <= maxBytes else {
                throw FileError.tooLarge("File size \(statBuf.st_size) exceeds \(maxBytes) bytes: \(path)")
            }
            let permissions = statBuf.st_mode & 0o777
            guard permissions & 0o077 == 0 else {
                throw FileError.insecurePermissions("Insecure file permissions \(String(permissions, radix: 8)) for: \(path)")
            }
            guard let file = fopen(path, "rb") else {
                throw FileError.unreadable("Cannot open file: \(path)")
            }
            defer { fclose(file) }
            var fstatBuf = stat()
            guard fstat(fileno(file), &fstatBuf) == 0,
                  fstatBuf.st_dev == statBuf.st_dev,
                  fstatBuf.st_ino == statBuf.st_ino,
                  fstatBuf.st_mode & 0o077 == 0
            else {
                throw FileError.insecurePermissions("File descriptor metadata verification failed: \(path)")
            }
            let count = Int(statBuf.st_size)
            guard count > 0 else { return Data() }
            var data = Data(count: count)
            let bytesRead = data.withUnsafeMutableBytes { fread($0.baseAddress, 1, count, file) }
            guard bytesRead == count else {
                throw FileError.unreadable("Partial read: expected \(count), got \(bytesRead)")
            }
            return data
        }
    }

    #if os(macOS)

    extension FixtureLaunch {
        public static let keychainFileName = "fixture-keychain.json"

        /// The keychain of this process: `nil` unless it was launched with a fixture config.
        public static var keychain: FixtureKeychain? {
            testKeychain.withLock { $0 } ?? launchKeychain
        }

        private static let launchKeychain: FixtureKeychain? = resolveConfigPath().map(FixtureKeychain.init(configPath:))
        private static let testKeychain = Mutex<FixtureKeychain?>(nil)

        /// Tests only: stand in for a fixture launch (nil restores this process's own launch).
        static func setTestKeychain(_ keychain: FixtureKeychain?) {
            testKeychain.withLock { $0 = keychain }
        }
    }

    /// Keychain items of one fixture launch, kept in `<profile>/fixture-keychain.json` (0600).
    ///
    /// Interprets the generic-password and key queries Catbird issues: items are matched by class,
    /// service, account and application tag; every other attribute (access group, accessibility,
    /// synchronizability, data-protection keychain) has no meaning here and is ignored. A config
    /// that cannot be used makes every operation fail with `errSecNotAvailable`; it never falls
    /// back to the login keychain.
    public final class FixtureKeychain: Sendable {
        struct Item: Codable, Equatable {
            enum Kind: String, Codable { case genericPassword, key }
            var kind: Kind
            var service: String?
            var account: String?
            var tag: Data?
            var value: Data
        }

        private enum State {
            case ready(file: URL, items: [Item])
            case unavailable(String)
        }

        private static let maxFileBytes = 16 * 1024 * 1024
        private let state: Mutex<State>

        /// The item file, or nil when this launch's config is unusable.
        public var fileURL: URL? {
            state.withLock {
                if case let .ready(file, _) = $0 { return file }
                return nil
            }
        }

        init(configPath: String) {
            let resolved: State
            do {
                resolved = try Self.open(configPath: configPath)
            } catch {
                resolved = .unavailable("\(error)")
                LogManager.logError("FixtureKeychain - fixture config unusable, keychain unavailable: \(error)")
            }
            state = Mutex(resolved)
        }

        private static func open(configPath: String) throws -> State {
            let config = try FixtureLaunch.readPrivateFile(at: configPath)
            guard let json = try JSONSerialization.jsonObject(with: config) as? [String: Any],
                  let profile = json["profile"] as? String, profile.hasPrefix("/")
            else {
                throw FixtureLaunch.FileError.invalidConfiguration("Fixture config needs an absolute profile path")
            }
            let directory = URL(fileURLWithPath: profile, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
            let file = directory.appendingPathComponent(FixtureLaunch.keychainFileName)
            guard FileManager.default.fileExists(atPath: file.path) else {
                return .ready(file: file, items: [])
            }
            let data = try FixtureLaunch.readPrivateFile(at: file.path, maxBytes: maxFileBytes)
            return .ready(file: file, items: data.isEmpty ? [] : try JSONDecoder().decode([Item].self, from: data))
        }

        // MARK: - SecItem semantics

        public func add(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            mutate { items in
                let q = query as NSDictionary as? [String: Any] ?? [:]
                guard let selector = Selector(q), selector.identifiesOneItem,
                      let value = q[kSecValueData as String] as? Data
                else { return errSecParam }
                if items.contains(where: selector.matches) { return errSecDuplicateItem }
                items.append(Item(kind: selector.kind, service: selector.service, account: selector.account,
                                  tag: selector.tag, value: value))
                result?.pointee = nil
                return errSecSuccess
            }
        }

        public func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
            state.withLock { state in
                guard case let .ready(_, items) = state else { return errSecNotAvailable }
                let q = query as NSDictionary as? [String: Any] ?? [:]
                guard let selector = Selector(q) else { return errSecParam }
                let found = items.filter(selector.matches)
                guard !found.isEmpty else { return errSecItemNotFound }
                let returnData = (q[kSecReturnData as String] as? Bool) == true
                let returnAttributes = (q[kSecReturnAttributes as String] as? Bool) == true
                let all = (q[kSecMatchLimit as String] as? String) == (kSecMatchLimitAll as String)
                let shaped: [Any] = (all ? found : [found[0]]).map { item -> Any in
                    guard returnAttributes else { return item.value }
                    var attributes: [String: Any] = [
                        kSecClass as String: item.kind == .key ? kSecClassKey : kSecClassGenericPassword
                    ]
                    if let service = item.service { attributes[kSecAttrService as String] = service }
                    if let account = item.account { attributes[kSecAttrAccount as String] = account }
                    if let tag = item.tag { attributes[kSecAttrApplicationTag as String] = tag }
                    if returnData { attributes[kSecValueData as String] = item.value }
                    return attributes
                }
                if returnData || returnAttributes {
                    result?.pointee = all ? (shaped as NSArray) as AnyObject : shaped[0] as AnyObject
                }
                return errSecSuccess
            }
        }

        public func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
            mutate { items in
                let q = query as NSDictionary as? [String: Any] ?? [:]
                guard let selector = Selector(q) else { return errSecParam }
                let a = attributes as NSDictionary as? [String: Any] ?? [:]
                var updated = false
                for index in items.indices where selector.matches(items[index]) {
                    if let value = a[kSecValueData as String] as? Data { items[index].value = value }
                    updated = true
                }
                return updated ? errSecSuccess : errSecItemNotFound
            }
        }

        public func delete(_ query: CFDictionary) -> OSStatus {
            mutate { items in
                let q = query as NSDictionary as? [String: Any] ?? [:]
                guard let selector = Selector(q) else { return errSecParam }
                let before = items.count
                items.removeAll(where: selector.matches)
                return items.count == before ? errSecItemNotFound : errSecSuccess
            }
        }

        /// Applies a change and persists it before returning; a failed write leaves memory unchanged.
        private func mutate(_ change: (inout [Item]) -> OSStatus) -> OSStatus {
            state.withLock { state in
                guard case let .ready(file, items) = state else { return errSecNotAvailable }
                var next = items
                let status = change(&next)
                guard status == errSecSuccess, next != items else { return status }
                do {
                    try Self.persist(next, to: file)
                } catch {
                    LogManager.logError("FixtureKeychain - failed to persist \(file.path): \(error)")
                    return errSecIO
                }
                state = .ready(file: file, items: next)
                return status
            }
        }

        private static func persist(_ items: [Item], to file: URL) throws {
            let data = try JSONEncoder().encode(items)
            let temp = file.deletingLastPathComponent()
                .appendingPathComponent(".\(FixtureLaunch.keychainFileName).\(UUID().uuidString)")
            guard FileManager.default.createFile(atPath: temp.path, contents: data, attributes: [.posixPermissions: 0o600])
            else {
                throw FixtureLaunch.FileError.unreadable("Cannot create \(temp.path)")
            }
            guard rename(temp.path, file.path) == 0 else {
                let code = errno
                unlink(temp.path)
                throw FixtureLaunch.FileError.unreadable("rename failed (\(code)) for \(file.path)")
            }
        }

        /// The identifying attributes of a query.
        private struct Selector {
            let kind: Item.Kind
            let service: String?
            let account: String?
            let tag: Data?

            init?(_ query: [String: Any]) {
                let itemClass = query[kSecClass as String] as? String
                if itemClass == kSecClassGenericPassword as String {
                    kind = .genericPassword
                } else if itemClass == kSecClassKey as String {
                    kind = .key
                } else {
                    return nil
                }
                service = query[kSecAttrService as String] as? String
                account = query[kSecAttrAccount as String] as? String
                switch query[kSecAttrApplicationTag as String] {
                case let data as Data: tag = data
                case let string as String: tag = Data(string.utf8)
                default: tag = nil
                }
            }

            /// An add must name the item it creates.
            var identifiesOneItem: Bool {
                kind == .key ? tag != nil : account != nil
            }

            func matches(_ item: Item) -> Bool {
                item.kind == kind
                    && (service == nil || item.service == service)
                    && (account == nil || item.account == account)
                    && (tag == nil || item.tag == tag)
            }
        }
    }

    #endif

#endif
