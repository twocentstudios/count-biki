import AsyncExtensions
import DependenciesAdditions
import Foundation

struct SpeechSynthesisSettingsClient {
    var get: @Sendable () -> (SpeechSynthesisSettings)
    var set: @Sendable (SpeechSynthesisSettings) throws -> Void
    var observe: @Sendable () -> AsyncStream<SpeechSynthesisSettings>
}

extension SpeechSynthesisSettingsClient: DependencyKey {
    static let deprecatedSettingsKey = "SpeechSynthesisSettingsClient.Settings"
    static let settingsKey = "SpeechSynthesisSettingsClient_Settings"
    static var liveValue: Self {
        @Dependency(\.userDefaults) var userDefaults
        @Dependency(\.encode) var encode
        @Dependency(\.decode) var decode
        return .init(
            get: {
                guard
                    let data = userDefaults.data(forKey: settingsKey) ?? userDefaults.data(forKey: deprecatedSettingsKey)
                else {
                    return SpeechSynthesisSettings()
                }
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
            },
            observe: {
                userDefaults.dataValues(forKey: settingsKey)
                    .compactMap { maybeData in
                        guard let data = maybeData else { return nil }
                        guard let value = try? decode(SpeechSynthesisSettings.self, from: data) else { return nil }
                        return value
                    }
                    .eraseToStream()
            }
        )
    }
}

extension SpeechSynthesisSettingsClient: TestDependencyKey {
    static var previewValue: Self {
        let storage = AsyncCurrentValueSubject(SpeechSynthesisSettings.mockNil)
        return .init(
            get: { storage.value },
            set: { storage.send($0) },
            observe: { storage.eraseToStream() }
        )
    }

    static var testValue: Self {
        let storage = AsyncCurrentValueSubject(SpeechSynthesisSettings.mockNil)
        return .init(
            get: { storage.value },
            set: { storage.send($0) },
            observe: { storage.eraseToStream() }
        )
    }
}

extension DependencyValues {
    var speechSynthesisSettingsClient: SpeechSynthesisSettingsClient {
        get { self[SpeechSynthesisSettingsClient.self] }
        set { self[SpeechSynthesisSettingsClient.self] = newValue }
    }
}
