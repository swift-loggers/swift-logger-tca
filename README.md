# swift-logger-tca

TCA / swift-dependencies integration for [swift-loggers](https://github.com/swift-loggers).
Built on top of [swift-loggers/swift-logger](https://github.com/swift-loggers/swift-logger).

Exposes a `Logger` instance to
[pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies)
through a `LoggerKey` and a `DependencyValues.logger` extension, so
TCA reducers and any other code using `@Dependency` can read and
override the logger.

Requires Swift 6.0+. iOS 16+, tvOS 16+, macOS 13+, watchOS 9+, visionOS 1+.
MIT licensed.

API reference (DocC):
[swift-loggers.github.io/swift-logger-tca](https://swift-loggers.github.io/swift-logger-tca/documentation/loggerlibrarytca/).

> This package is **not** an adapter for
> [`apple/swift-log`](https://github.com/apple/swift-log). It integrates
> the `swift-loggers` family with
> [`pointfreeco/swift-dependencies`](https://github.com/pointfreeco/swift-dependencies).
> A `swift-log` adapter is planned in a separate companion package.

## Installation

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(
            url: "https://github.com/swift-loggers/swift-logger-tca.git",
            .upToNextMinor(from: "0.1.0")
        )
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "LoggerLibraryTCA", package: "swift-logger-tca")
            ]
        )
    ]
)
```

`import LoggerLibraryTCA` re-exports `Loggers`, `LoggerPrint`, and
`LoggerNoOp`. `ComposableArchitecture` is **not** a runtime dependency
of this package; consumers add it to their own `Package.swift`.

## Usage

Read the logger from a TCA reducer via `@Dependency(\.logger)`. A
single reducer can log both plain lifecycle events and structured
operational events; both shapes go through the same `logger`
instance resolved from `DependencyValues`:

```swift
import ComposableArchitecture
import LoggerLibraryTCA

extension LoggerDomain {
    static let auth: LoggerDomain = "Auth"
}

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var username: String = ""
    }

    enum Action {
        case appeared
        case usernameChanged(String)
        case signInTapped(username: String, password: String)
    }

    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                logger.info(.auth, "Sign-in screen appeared")
                return .none

            case .usernameChanged(let username):
                state.username = username
                logger.debug(
                    .auth,
                    "Username input changed for \(username, privacy: .private)"
                )
                return .none

            case .signInTapped(let username, _):
                logger.info(
                    .auth,
                    "Sign-in submitted",
                    attributes: [
                        LogAttribute("auth.method", "password"),
                        LogAttribute("auth.username", username, privacy: .private)
                    ]
                )
                // Password is bound to `_` so the reducer never even names
                // it; an effect would forward (username, password) to an
                // auth client, which owns the network call and any
                // HTTP-level logging.
                return .none
            }
        }
    }
}
```

The full `Logger` API (privacy-aware string interpolation,
structured `attributes`, severity levels, custom domains) is
documented in
[swift-loggers/swift-logger](https://github.com/swift-loggers/swift-logger);
this package does not re-define it. One TCA-specific note: `state`
is `inout` inside `Reduce`, so a value referenced by the message or
attributes autoclosures must be copied to a local constant first --
the autoclosures are `@Sendable` and cannot capture the `inout`
parameter directly.

## Defaults

`LoggerKey` provides three scope-specific defaults:

| Scope | Default | Severity |
|-------|---------|----------|
| `liveValue` | `PrintLogger` | `.info` |
| `testValue` | `NoOpLogger` | n/a |
| `previewValue` | `PrintLogger` | `.debug` |

`testValue` is `NoOpLogger` so suite output stays focused on assertion
failures. `previewValue` is verbose by default so previews surface
diagnostic logs while iterating on UI.

## Testing

Override the logger for a single scope through
`TestStore.withDependencies` and assert against a recording fixture
without changing the reducer under test. The reducer + test pair,
including both a plain-string `.appeared` case and a structured
`.signInTapped` case, lives verbatim in
[`Tests/LoggerLibraryTCATests/FeatureLoggingTests.swift`](Tests/LoggerLibraryTCATests/FeatureLoggingTests.swift).

## Companion packages

- [`swift-loggers/swift-logger`](https://github.com/swift-loggers/swift-logger)
  -- protocol-only core plus `PrintLogger`, `DomainFilteredLogger`,
  `NoOpLogger`. No third-party dependencies; uses Foundation for
  `Date`-backed payloads. Use it directly when you do not need the
  TCA / swift-dependencies integration.
