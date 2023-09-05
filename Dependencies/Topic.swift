import Dependencies
import Foundation
import IdentifiedCollections

private struct TopicGenerator: Identifiable {
    var id: UUID { topic.id }
    let topic: Topic
    var generateQuestion: @Sendable (WithRandomNumberGenerator) throws -> (Question)
}

struct Topic: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
}

struct Question: Equatable {
    let displayText: String
    let answerPrefix: String?
    let answerPostfix: String?
    let acceptedAnswer: String
}

struct TopicClient {
    var allTopics: @Sendable () -> IdentifiedArrayOf<Topic>
    var generateQuestion: @Sendable (UUID) throws -> (Question)
}

extension TopicClient: DependencyKey {
    static var liveValue: TopicClient {
        @Dependency(\.withRandomNumberGenerator) var rng
        let uuidGenerator = UUIDGenerator.incrementing
        let allTopicGenerators: IdentifiedArrayOf<TopicGenerator> = [
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Numbers",
                    subtitle: "1-999",
                    description: "Whole numbers between 1-999"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 1 ... 999, using: &$0) }
                    let displayText = answer.formatted(.number.grouping(.automatic))
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: nil,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Numbers",
                    subtitle: "Extreme mode",
                    description: "Whole numbers between 0-100,000,000,000"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 0 ... 100_000_000_000, using: &$0) }
                    let displayText = answer.formatted(.number.grouping(.automatic))
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: nil,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Money",
                    subtitle: "Conbini",
                    description: "Yen amounts between 100-1500"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 100 ... 1500, using: &$0) }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer.formatted(.number.grouping(.automatic)))"
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Money",
                    subtitle: "Restaurant",
                    description: "Yen amounts between 800-6000 by 10s"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 80 ... 600, using: &$0) * 10 }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer.formatted(.number.grouping(.automatic)))"
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Money",
                    subtitle: "Monthly Rent",
                    description: "Yen amounts between 50,000-200,000 by 1,000s"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 50 ... 200, using: &$0) * 1_000 }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer.formatted(.number.grouping(.automatic)))"
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Money",
                    subtitle: "Annual Salary",
                    description: "Yen amounts between 2,000,000-15,000,000 by 100,000s"
                ),
                generateQuestion: { rng in
                    let answer = rng { Int.random(in: 20 ... 150, using: &$0) * 100_000 }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer.formatted(.number.grouping(.automatic)))"
                    let acceptedAnswer = String(answer)
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: acceptedAnswer
                    )
                    return question
                }
            ),
        ]
        return TopicClient(
            allTopics: {
                IdentifiedArray(uniqueElements: allTopicGenerators.map(\.topic))
            },
            generateQuestion: { topicID in
                struct NoTopicForIDError: Error {}
                guard let topicGenerator = allTopicGenerators[id: topicID] else { throw NoTopicForIDError() }
                return try topicGenerator.generateQuestion(rng)
            }
        )
    }
}

extension TopicClient: TestDependencyKey {
    static let previewValue: TopicClient = .liveValue

    static var testValue: TopicClient {
        Self(
            allTopics: unimplemented("allTopics"),
            generateQuestion: unimplemented("generateQuestion")
        )
    }
}

extension DependencyValues {
    var topicClient: TopicClient {
        get { self[TopicClient.self] }
        set { self[TopicClient.self] = newValue }
    }
}
