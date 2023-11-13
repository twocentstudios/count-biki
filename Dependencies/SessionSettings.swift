import AsyncExtensions
import DependenciesAdditions
import Foundation

struct SessionSettingsClient {
    var get: @Sendable () -> (SessionSettings)
    var set: @Sendable (SessionSettings) async throws -> Void
    var observe: @Sendable () -> AsyncStream<SessionSettings>
}

struct SessionSettings: Equatable, Codable {
    enum QuizMode: Equatable, Identifiable, Codable, CaseIterable {
        case infinite
        case questionLimit
        case timeLimit

        var id: Self { self }
        var title: String {
            switch self {
            case .infinite: "Infinite"
            case .questionLimit: "Question Limit"
            case .timeLimit: "Time Limit"
            }
        }
    }
    var quizMode: QuizMode
    var questionLimit: Int
    var timeLimit: Int // seconds

    var isShowingProgress: Bool
    var isShowingBiki: Bool
    var isShowingConfetti: Bool
}

extension SessionSettings {
    static let `default`: Self = .init(quizMode: .infinite, questionLimit: 10, timeLimit: 60, isShowingProgress: true, isShowingBiki: true, isShowingConfetti: true)

    static let questionLimitValues: [Int] = [5, 10, 20, 30, 50, 100]
    static let timeLimitValues: [Int] = [30, 1 * 60, 3 * 60, 5 * 60, 10 * 60, 20 * 60]
}

extension SessionSettingsClient: DependencyKey {
    static let settingsKey = "SessionSettingsClient_Settings"
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
            },
            observe: {
                userDefaults.dataValues(forKey: settingsKey)
                    .compactMap { maybeData in
                        guard let data = maybeData else { return nil }
                        guard let value = try? decode(SessionSettings.self, from: data) else { return nil }
                        return value
                    }
                    .eraseToStream()
            }
        )
    }
}

extension SessionSettingsClient: TestDependencyKey {
    static var previewValue: Self {
        let storage = AsyncCurrentValueSubject(SessionSettings.default)
        return .init(
            get: { storage.value },
            set: { storage.send($0) },
            observe: { storage.eraseToStream() }
        )
    }

    static var testValue: Self {
        let storage = AsyncCurrentValueSubject(SessionSettings.default)
        return .init(
            get: { storage.value },
            set: { storage.send($0) },
            observe: { storage.eraseToStream() }
        )
    }
}

extension DependencyValues {
    var sessionSettingsClient: SessionSettingsClient {
        get { self[SessionSettingsClient.self] }
        set { self[SessionSettingsClient.self] = newValue }
    }
}
