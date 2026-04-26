# swift-logger-tca

TCA / swift-dependencies integration for [swift-loggers](https://github.com/swift-loggers).
Built on top of [swift-loggers/swift-logger](https://github.com/swift-loggers/swift-logger).

Exposes a `Logger` instance to
[pointfreeco/swift-dependencies](https://github.com/pointfreeco/swift-dependencies)
through a `LoggerKey` and a `DependencyValues.logger` extension, so
TCA reducers and any other code using `@Dependency` can read and
override the logger.

Requires Swift 6.0+. MIT licensed.

Pre-release. The first tagged version will be `0.1.0`.

> This package is **not** an adapter for
> [`apple/swift-log`](https://github.com/apple/swift-log). It integrates
> the `swift-loggers` family with
> [`pointfreeco/swift-dependencies`](https://github.com/pointfreeco/swift-dependencies).
> A `swift-log` adapter is planned in a separate companion package.

## Installation

```swift
// In your Package.swift:
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/swift-loggers/swift-logger-tca.git", branch: "main")
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
`LoggerNoOp`, so the protocol, `LoggerLevel`, `LoggerDomain`,
`PrintLogger`, and `NoOpLogger` are all available without additional
imports. `ComposableArchitecture` is **not** a runtime dependency of
this package; consumers using TCA add it to their own `Package.swift`
and `import ComposableArchitecture` alongside `import LoggerLibraryTCA`.

## Usage

Read the logger from a TCA reducer via `@Dependency(\.logger)`. This
example is the same code exercised in
`Tests/LoggerLibraryTCATests/FeatureLoggingTests.swift`:

```swift
import ComposableArchitecture
import LoggerLibraryTCA

extension LoggerDomain {
    static let app: LoggerDomain = "App"
}

@Reducer
struct Feature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case appeared
    }

    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .appeared:
                logger.info(.app, "Feature appeared")
                return .none
            }
        }
    }
}
```

## Defaults

`LoggerKey` provides three scope-specific defaults:

| Scope | Default | Severity |
|-------|---------|----------|
| `liveValue` | `PrintLogger` | `.info` |
| `testValue` | `NoOpLogger` | n/a |
| `previewValue` | `PrintLogger` | `.debug` |

`testValue` is `NoOpLogger` so suite output stays focused on assertion
failures. `previewValue` is verbose so Xcode previews surface
diagnostic logs while iterating on UI.

## Testing a reducer with a fixture logger

Override the logger for a single scope by injecting a fixture through
`TestStore.withDependencies`. The fixture below records every emitted
line so the test can assert the exact output. This snippet lives
verbatim in `Tests/LoggerLibraryTCATests/FeatureLoggingTests.swift`:

```swift
import ComposableArchitecture
import Foundation
import LoggerLibraryTCA
import Testing

extension LoggerDomain {
    fileprivate static let app: LoggerDomain = "App"
}

@Reducer
private struct Feature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case appeared
    }

    @Dependency(\.logger) var logger

    init() {}

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .appeared:
                logger.info(.app, "Feature appeared")
                return .none
            }
        }
    }
}

private final class RecordingLogger: Logger, @unchecked Sendable {
    private let lock = NSLock()
    private var storedLines: [String] = []

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedLines
    }

    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> String
    ) {
        guard level != .disabled else { return }
        let rendered = "\(level) [\(domain)] \(message())"
        lock.lock()
        defer { lock.unlock() }
        storedLines.append(rendered)
    }
}

@Test
func featureLogsOnAppear() async {
    let logger = RecordingLogger()
    let store = await TestStore(initialState: Feature.State()) {
        Feature()
    } withDependencies: {
        $0.logger = logger
    }

    await store.send(.appeared)

    #expect(logger.lines == ["info [App] Feature appeared"])
}
```

## Companion packages

- [`swift-loggers/swift-logger`](https://github.com/swift-loggers/swift-logger)
  — protocol-only core plus `PrintLogger`, `DomainFilteredLogger`,
  `NoOpLogger`. Zero dependencies. Use it directly when you do not need
  the TCA / swift-dependencies integration.
