//
//  KestrelLogger.swift
//  KestrelTransitions
//
//  Created by Kamil Buczel on 26/07/2025.
//

import os.log
import Foundation

// MARK: - Logging Configuration

/// Configuration for KestrelTransitions logging
public struct KestrelLoggingConfig {
    public let isEnabled: Bool
    public let level: KestrelLogLevel
    public let subsystem: String
    public let category: String
    
    public init(
        isEnabled: Bool = true,
        level: KestrelLogLevel = .info,
        subsystem: String = "com.kestrel.transitions",
        category: String = "KestrelTransitions"
    ) {
        self.isEnabled = isEnabled
        self.level = level
        self.subsystem = subsystem
        self.category = category
    }
    
    /// Default configuration with logging disabled for production
    public static let `default` = KestrelLoggingConfig(isEnabled: false, level: .error)
    
    /// Debug configuration with verbose logging
    public static let debug = KestrelLoggingConfig(isEnabled: true, level: .debug)
    
    /// Production configuration with minimal logging
    public static let production = KestrelLoggingConfig(isEnabled: true, level: .error)
}

/// Log levels for KestrelTransitions
public enum KestrelLogLevel: Int, CaseIterable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public static func < (lhs: KestrelLogLevel, rhs: KestrelLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🐛"
        case .info: return "📋"
        case .warning: return "⚠️"
        case .error: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

// MARK: - KestrelLogger

/// Centralized logger for KestrelTransitions with configurable levels and output
public final class KestrelLogger {
    
    // MARK: - Singleton
    
    public static let shared = KestrelLogger()
    
    // MARK: - Properties
    
    private var config: KestrelLoggingConfig = .default
    private lazy var osLogger: Logger = {
        Logger(subsystem: config.subsystem, category: config.category)
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure the logger with custom settings
    /// - Parameter config: The logging configuration to use
    public func configure(with config: KestrelLoggingConfig) {
        self.config = config
        // Recreate logger with new config
        self.osLogger = Logger(subsystem: config.subsystem, category: config.category)
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - context: Additional context (e.g., function name, transition ID)
    ///   - file: Source file (automatically filled)
    ///   - function: Source function (automatically filled)
    ///   - line: Source line (automatically filled)
    public func debug(
        _ message: String,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, context: context, file: file, function: function, line: line)
    }
    
    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - context: Additional context (e.g., function name, transition ID)
    ///   - file: Source file (automatically filled)
    ///   - function: Source function (automatically filled)
    ///   - line: Source line (automatically filled)
    public func info(
        _ message: String,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, context: context, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - context: Additional context (e.g., function name, transition ID)
    ///   - file: Source file (automatically filled)
    ///   - function: Source function (automatically filled)
    ///   - line: Source line (automatically filled)
    public func warning(
        _ message: String,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, context: context, file: file, function: function, line: line)
    }
    
    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - context: Additional context (e.g., function name, transition ID)
    ///   - file: Source file (automatically filled)
    ///   - function: Source function (automatically filled)
    ///   - line: Source line (automatically filled)
    public func error(
        _ message: String,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, context: context, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(
        level: KestrelLogLevel,
        message: String,
        context: String?,
        file: String,
        function: String,
        line: Int
    ) {
        guard config.isEnabled && level >= config.level else { return }
        
        let contextString = context.map { " [\($0.suffix(4))]" } ?? ""
        let logMessage = "\(level.emoji) \(message)\(contextString)"

        osLogger.log(level: level.osLogType, "\(logMessage)")
    }
}

// MARK: - Convenient Global Functions

/// Global logging function for easier usage throughout the codebase
public func kestrelLog(
    _ message: String,
    level: KestrelLogLevel = .info,
    context: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    switch level {
    case .debug:
        KestrelLogger.shared.debug(message, context: context, file: file, function: function, line: line)
    case .info:
        KestrelLogger.shared.info(message, context: context, file: file, function: function, line: line)
    case .warning:
        KestrelLogger.shared.warning(message, context: context, file: file, function: function, line: line)
    case .error:
        KestrelLogger.shared.error(message, context: context, file: file, function: function, line: line)
    }
}
