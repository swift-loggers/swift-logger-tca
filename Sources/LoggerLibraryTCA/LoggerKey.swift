import Dependencies
@_exported import LoggerNoOp
@_exported import LoggerPrint
@_exported import Loggers

/// A `DependencyKey` that exposes a `Logger` to
/// [pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies).
///
/// Use this key with `@Dependency(\.logger)` in TCA reducers, or override
/// it in `withDependencies` blocks to inject a fixed logger for tests
/// and previews.
///
/// ## Default values
///
/// - ``liveValue`` is a `PrintLogger` at `.info` severity. It writes
///   each message to standard output and is suitable for development
///   and production builds where logs go to the system console.
/// - ``testValue`` is a `NoOpLogger`. It silences logging in tests so
///   suite output stays focused on assertion failures.
/// - ``previewValue`` is a `PrintLogger` at `.debug` severity, giving
///   verbose output in Xcode previews.
///
/// Override the default for a single scope:
///
/// ```swift
/// withDependencies {
///     $0.logger = MyLogger()
/// } operation: {
///     // ...
/// }
/// ```
public enum LoggerKey: DependencyKey {
    /// The default `Logger` used in app-launched dependency contexts.
    /// Returns a `PrintLogger` at `.info` severity.
    public static var liveValue: any Logger {
        PrintLogger(minimumLevel: .info)
    }

    /// The default `Logger` used inside test runs. Returns a
    /// `NoOpLogger` so tests do not pollute output with log lines.
    public static var testValue: any Logger {
        NoOpLogger()
    }

    /// The default `Logger` used in Xcode previews. Returns a
    /// `PrintLogger` at `.debug` severity for verbose preview output.
    public static var previewValue: any Logger {
        PrintLogger(minimumLevel: .debug)
    }
}

extension DependencyValues {
    /// The `Logger` injected via swift-dependencies.
    ///
    /// Read with `@Dependency(\.logger)` and override per-scope with
    /// `withDependencies { $0.logger = ... }`.
    public var logger: any Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }
}
