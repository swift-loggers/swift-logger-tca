import Dependencies
import LoggerLibraryTCA
import Testing

@Suite("LoggerKey")
struct LoggerKeyTests {
    @Test("liveValue is a PrintLogger")
    func liveValueIsPrintLogger() {
        #expect(LoggerKey.liveValue is PrintLogger)
    }

    @Test("testValue is a NoOpLogger")
    func testValueIsNoOpLogger() {
        #expect(LoggerKey.testValue is NoOpLogger)
    }

    @Test("previewValue is a PrintLogger")
    func previewValueIsPrintLogger() {
        #expect(LoggerKey.previewValue is PrintLogger)
    }

    @Test("DependencyValues.logger reads LoggerKey default in test context")
    func dependencyValuesLoggerReadsTestDefault() {
        withDependencies { _ in
            // No override; test context should use LoggerKey.testValue.
        } operation: {
            @Dependency(\.logger) var logger
            #expect(logger is NoOpLogger)
        }
    }

    @Test("DependencyValues.logger honors per-scope override")
    func dependencyValuesLoggerHonorsOverride() {
        let override = OverrideLogger()
        withDependencies {
            $0.logger = override
        } operation: {
            @Dependency(\.logger) var logger
            #expect(logger is OverrideLogger)
        }
    }
}

private struct OverrideLogger: Logger {
    func log(
        _: LoggerLevel,
        _: LoggerDomain,
        _: @autoclosure @escaping @Sendable () -> String
    ) {}
}
