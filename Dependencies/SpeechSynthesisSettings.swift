import Dependencies
import Foundation

struct SpeechSynthesisSettingsClient {
    var get: @Sendable () throws -> (SpeechSynthesisSettings)
    var set: @Sendable (SpeechSynthesisSettings) throws -> Void
}

extension SpeechSynthesisSettingsClient: DependencyKey {
    static var liveValue: Self {
        // TODO: store somewhere (user defaults?) (use dependency additions)
        .init(
            get: { .init() },
            set: { newSettings in
            }
        )
    }
}

extension SpeechSynthesisSettingsClient: TestDependencyKey {
    private final class MockStorage {
        var value: SpeechSynthesisSettings = .mock
    }
    static var previewValue: Self {
        let storage = MockStorage()
        return .init(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }

    static var testValue: Self {
        let storage = MockStorage()
        return .init(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }
}

extension DependencyValues {
    var speechSynthesisClientSettings: SpeechSynthesisSettingsClient {
        get { self[SpeechSynthesisSettingsClient.self] }
        set { self[SpeechSynthesisSettingsClient.self] = newValue }
    }
}
