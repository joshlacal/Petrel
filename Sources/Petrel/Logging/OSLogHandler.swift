//
//  OSLogHandler.swift
//  Petrel
//
//  Created by Claude on 11/27/24.
//

#if canImport(os)
    import Foundation
    import Logging
    import os.log

    /// A `LogHandler` implementation that forwards log messages to Apple's unified logging system (`os.Logger`).
    ///
    /// This handler provides near-zero overhead when logs are not being collected, making it ideal for
    /// production use on Apple platforms. It maps swift-log levels to appropriate `OSLogType` values
    /// and includes support for metadata.
    ///
    /// The handler uses the logger's label as the subsystem for `os.Logger`, allowing for fine-grained
    /// filtering in Console.app and other log viewing tools.
    public struct OSLogHandler: LogHandler {
        /// The underlying os.Logger instance
        private let osLogger: os.Logger

        /// The label identifying this logger
        private let label: String

        /// Current log level threshold
        public var logLevel: Logging.Logger.Level = .info

        /// Metadata storage
        public var metadata: Logging.Logger.Metadata = [:]

        /// Optional metadata provider for contextual metadata
        public var metadataProvider: Logging.Logger.MetadataProvider?

        /// Initialize a new OSLogHandler
        /// - Parameter label: The label for this logger, used as the subsystem for os.Logger
        public init(label: String) {
            self.label = label
            // Use the label as the subsystem and "default" as the category
            // The subsystem is typically a reverse-DNS string identifying the library/module
            osLogger = os.Logger(subsystem: label, category: "default")
        }

        /// Initialize with a custom category
        /// - Parameters:
        ///   - label: The label for this logger, used as the subsystem for os.Logger
        ///   - category: The category for os.Logger (defaults to "default")
        public init(label: String, category: String) {
            self.label = label
            osLogger = os.Logger(subsystem: label, category: category)
        }

        public func log(
            level: Logging.Logger.Level,
            message: Logging.Logger.Message,
            metadata: Logging.Logger.Metadata?,
            source: String,
            file: String,
            function: String,
            line: UInt
        ) {
            // Combine instance metadata with per-log metadata
            let effectiveMetadata = self.metadata.merging(metadata ?? [:]) { _, new in new }

            // Add metadata from provider if available
            let providerMetadata = metadataProvider?.get() ?? [:]
            let allMetadata = effectiveMetadata.merging(providerMetadata) { _, new in new }

            // Format the message with metadata if present
            let formattedMessage: String
            if allMetadata.isEmpty {
                formattedMessage = message.description
            } else {
                let metadataString = allMetadata
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: " ")
                formattedMessage = "\(message) [\(metadataString)]"
            }

            // Map swift-log level to OSLogType and emit the log
            let osLogType = mapLogLevel(level)
            osLogger.log(level: osLogType, "\(formattedMessage, privacy: .public)")
        }

        public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
            get {
                metadata[key]
            }
            set {
                metadata[key] = newValue
            }
        }

        /// Maps swift-log levels to OSLogType
        /// - Parameter level: The swift-log level
        /// - Returns: The corresponding OSLogType
        private func mapLogLevel(_ level: Logging.Logger.Level) -> OSLogType {
            switch level {
            case .trace, .debug:
                return .debug
            case .info, .notice:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .critical:
                return .fault
            }
        }
    }

#endif
