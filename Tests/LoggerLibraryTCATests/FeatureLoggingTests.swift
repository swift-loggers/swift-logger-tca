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
