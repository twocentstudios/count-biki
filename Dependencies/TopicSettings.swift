import DependenciesAdditions
import Foundation

struct TopicSettingsClient {
    var get: @Sendable () throws -> (UUID)
    var set: @Sendable (UUID) throws -> Void
}

extension TopicSettingsClient {
    enum Error: Swift.Error {
        case settingsUnset
    }
}

extension TopicSettingsClient: DependencyKey {
    static let selectedTopicKey = "TopicSettingsClient.selectedTopic"
    static var liveValue: Self {
        @Dependency(\.userDefaults) var userDefaults
        @Dependency(\.encode) var encode
        @Dependency(\.decode) var decode
        return .init(
            get: {
                guard let data = userDefaults.data(forKey: selectedTopicKey) else { throw Error.settingsUnset }
                let value = try decode(UUID.self, from: data)
                return value
            },
            set: { newValue in
                let data = try encode(newValue)
                userDefaults.set(data, forKey: selectedTopicKey)
            }
        )
    }
}

extension TopicSettingsClient: TestDependencyKey {
    private final class MockStorage {
        var value: UUID = UUID(0)
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
    var topicSettingsClient: TopicSettingsClient {
        get { self[TopicSettingsClient.self] }
        set { self[TopicSettingsClient.self] = newValue }
    }
}
