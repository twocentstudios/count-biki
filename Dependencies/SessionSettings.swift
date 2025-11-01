import Foundation

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
    static let storageKey = "SessionSettingsClient_Settings"
}
