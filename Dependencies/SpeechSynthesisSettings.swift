import Dependencies
import Foundation

struct SpeechSynthesisSettingsClient {
    var get: @Sendable () throws -> (SpeechSynthesisSettings)
    var set: @Sendable (SpeechSynthesisSettings) throws -> Void
}

extension SpeechSynthesisSettingsClient: DependencyKey {
    static var liveValue: Self {
        .init(
            get: { .init() },
            set: { newSettings in
            }
        )
    }
}

extension SpeechSynthesisSettingsClient: TestDependencyKey {
    static var previewValue: Self {
        .init(
            get: { .init() },
            set: { newSettings in
            }
        )
    }

    static let testValue = Self(
        get: { .init() },
        set: { newSettings in
        }
    )
}

extension DependencyValues {
    var feature: SpeechSynthesisSettingsClient {
        get { self[SpeechSynthesisSettingsClient.self] }
        set { self[SpeechSynthesisSettingsClient.self] = newValue }
    }
}
