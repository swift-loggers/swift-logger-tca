import ComposableArchitecture
import Foundation
import LoggerLibraryTCA
import Testing

extension LoggerDomain {
    fileprivate static let auth: LoggerDomain = "Auth"
}

@Reducer
private struct AuthFeature {
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

    init() {}

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appeared:
                logger.info(.auth, "Sign-in screen appeared")
                return .none

            case let .usernameChanged(username):
                state.username = username
                logger.debug(
                    .auth,
                    "Username input changed for \(username, privacy: .private)"
                )
                return .none

            case let .signInTapped(username, _):
                logger.info(
                    .auth,
                    "Sign-in submitted",
                    attributes: [
                        LogAttribute("auth.method", "password"),
                        LogAttribute("auth.username", username, privacy: .private)
                    ]
                )
                return .none
            }
        }
    }
}

private final class RecordingLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        // periphery:ignore - read via synthesized Equatable
        let level: LoggerLevel
        // periphery:ignore - read via synthesized Equatable
        let domain: LoggerDomain
        let renderedMessage: String
        let attributes: [LogAttribute]
    }

    private let lock = NSLock()
    private var storedEntries: [Entry] = []

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storedEntries
    }

    func log(
        _ level: LoggerLevel,
        _ domain: LoggerDomain,
        _ message: @autoclosure @escaping @Sendable () -> LogMessage,
        attributes: @autoclosure @escaping @Sendable () -> [LogAttribute]
    ) {
        guard level != .disabled else { return }
        let entry = Entry(
            level: level,
            domain: domain,
            renderedMessage: message().redactedDescription,
            attributes: attributes()
        )
        lock.lock()
        defer { lock.unlock() }
        storedEntries.append(entry)
    }
}

@Test
func authLogsScreenAppearedAsPlainString() async {
    let logger = RecordingLogger()
    let store = await TestStore(initialState: AuthFeature.State()) {
        AuthFeature()
    } withDependencies: {
        $0.logger = logger
    }

    await store.send(.appeared)

    #expect(logger.entries == [
        RecordingLogger.Entry(
            level: .info,
            domain: "Auth",
            renderedMessage: "Sign-in screen appeared",
            attributes: []
        )
    ])
}

@Test
func authLogsUsernameChangeWithPrivacyInterpolation() async {
    let logger = RecordingLogger()
    let store = await TestStore(initialState: AuthFeature.State()) {
        AuthFeature()
    } withDependencies: {
        $0.logger = logger
    }

    await store.send(.usernameChanged("alice")) {
        $0.username = "alice"
    }

    #expect(logger.entries == [
        RecordingLogger.Entry(
            level: .debug,
            domain: "Auth",
            renderedMessage: "Username input changed for <private>",
            attributes: []
        )
    ])
}

@Test
func authLogsSignInTappedWithStructuredAttributesAndNoPasswordLeak() async {
    let logger = RecordingLogger()
    let store = await TestStore(initialState: AuthFeature.State()) {
        AuthFeature()
    } withDependencies: {
        $0.logger = logger
    }

    await store.send(.signInTapped(username: "alice", password: "hunter2"))

    let recorded = logger.entries
    #expect(recorded == [
        RecordingLogger.Entry(
            level: .info,
            domain: "Auth",
            renderedMessage: "Sign-in submitted",
            attributes: [
                LogAttribute("auth.method", "password"),
                LogAttribute("auth.username", "alice", privacy: .private)
            ]
        )
    ])
    // Sanity: password must never appear in any captured field.
    let allText = recorded.map(\.renderedMessage).joined()
        + recorded.flatMap(\.attributes).map(\.redactedDescription).joined()
    #expect(!allText.contains("hunter2"))
}
