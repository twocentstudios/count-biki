import DependenciesAdditions
import Foundation

struct SpeechSynthesisSettingsClient {
    var get: @Sendable () -> (SpeechSynthesisSettings)
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
                guard let data = userDefaults.data(forKey: settingsKey) else { return SpeechSynthesisSettings() }
                do {
                    let value = try decode(SpeechSynthesisSettings.self, from: data)
                    return value
                } catch {
                    return SpeechSynthesisSettings()
                }
            },
            set: { newSettings in
                let data = try encode(newSettings)
                userDefaults.set(data, forKey: settingsKey)
            }
        )
    }
}

extension SpeechSynthesisSettingsClient: TestDependencyKey {
    static var previewValue: Self {
        let storage = LockIsolated(SpeechSynthesisSettings.mockNil)
        return .init(
            get: { storage.value },
            set: { storage.setValue($0) }
        )
    }

    static var testValue: Self {
        let storage = LockIsolated(SpeechSynthesisSettings.mockNil)
        return .init(
            get: { storage.value },
            set: { storage.setValue($0) }
        )
    }
}

extension DependencyValues {
    var speechSynthesisSettingsClient: SpeechSynthesisSettingsClient {
        get { self[SpeechSynthesisSettingsClient.self] }
        set { self[SpeechSynthesisSettingsClient.self] = newValue }
    }
}
