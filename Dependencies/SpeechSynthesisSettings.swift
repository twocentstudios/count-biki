import DependenciesAdditions
import Foundation

struct SpeechSynthesisSettingsClient {
    var get: @Sendable () throws -> (SpeechSynthesisSettings)
    var set: @Sendable (SpeechSynthesisSettings) throws -> Void
}

extension SpeechSynthesisSettingsClient {
    enum Error: Swift.Error {
        case settingsUnset
    }
}

extension SpeechSynthesisSettingsClient: DependencyKey {
    static let settingsKey = "SpeechSynthesisSettingsClient.Settings"
    static var liveValue: Self {
        @Dependency(\.userDefaults) var userDefaults
        @Dependency(\.encode) var encode
        @Dependency(\.decode) var decode
        return .init(
            get: {
                guard let data = userDefaults.data(forKey: settingsKey) else { throw Error.settingsUnset }
                let value = try decode(SpeechSynthesisSettings.self, from: data)
                return value
            },
            set: { newSettings in
                let data = try encode(newSettings)
                userDefaults.set(data, forKey: settingsKey)
            }
        )
    }
}

extension SpeechSynthesisSettingsClient: TestDependencyKey {
    private final class MockStorage {
        var value: SpeechSynthesisSettings = .mockNil
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
    var speechSynthesisSettingsClient: SpeechSynthesisSettingsClient {
        get { self[SpeechSynthesisSettingsClient.self] }
        set { self[SpeechSynthesisSettingsClient.self] = newValue }
    }
}
