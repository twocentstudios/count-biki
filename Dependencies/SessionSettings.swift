import DependenciesAdditions
import Foundation

struct SessionSettingsClient {
    var get: @Sendable () -> (SessionSettings)
    var set: @Sendable (SessionSettings) throws -> Void
}

struct SessionSettings: Equatable, Codable {
    enum QuizMode: Equatable, Identifiable, Codable, CaseIterable {
        case infinite
        case questionAttack
        case timeAttack

        var id: Self { self }
        var title: String {
            switch self {
            case .infinite: "Infinite"
            case .questionAttack: "Question Limit"
            case .timeAttack: "Time Limit"
            }
        }
    }
    var quizMode: QuizMode
    var questionLimit: Int
    var timeLimit: Int // seconds

    var showProgress: Bool
    var showBiki: Bool
    var showConfetti: Bool
    var playHaptics: Bool
}

extension SessionSettings {
    static let `default`: Self = .init(quizMode: .infinite, questionLimit: 10, timeLimit: 60, showProgress: true, showBiki: true, showConfetti: true, playHaptics: true)
    
    static let questionLimitValues: [Int] = [5, 10, 20, 30, 50, 100]
    static let timeLimitValues: [Int] = [1, 3, 5, 10, 20, 60].map { $0 * 60 }
}

extension SessionSettingsClient: DependencyKey {
    static let settingsKey = "SessionSettingsClient.settings"
    static var liveValue: Self {
        @Dependency(\.userDefaults) var userDefaults
        @Dependency(\.encode) var encode
        @Dependency(\.decode) var decode
        return .init(
            get: {
                let data = userDefaults.data(forKey: settingsKey)
                let value: SessionSettings
                if let data {
                    value = (try? decode(SessionSettings.self, from: data)) ?? SessionSettings.default
                } else {
                    value = SessionSettings.default
                }
                return value
            },
            set: { newValue in
                let data = try encode(newValue)
                userDefaults.set(data, forKey: settingsKey)
            }
        )
    }
}

extension SessionSettingsClient: TestDependencyKey {
    static var previewValue: Self {
        let storage = LockIsolated(SessionSettings.default)
        return .init(
            get: { storage.value },
            set: { storage.setValue($0) }
        )
    }

    static var testValue: Self {
        let storage = LockIsolated(SessionSettings.default)
        return .init(
            get: { storage.value },
            set: { storage.setValue($0) }
        )
    }
}

extension DependencyValues {
    var sessionSettingsClient: SessionSettingsClient {
        get { self[SessionSettingsClient.self] }
        set { self[SessionSettingsClient.self] = newValue }
    }
}
