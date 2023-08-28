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
                    description: "Integers between 1-999"
                ),
                generateQuestion: { rng in
                    let answer = rng { String(Int.random(in: 1 ... 999, using: &$0)) }
                    let question = Question(
                        displayText: answer,
                        answerPrefix: nil,
                        answerPostfix: nil,
                        acceptedAnswer: answer
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
                    let answer = rng { String(Int.random(in: 100 ... 1500, using: &$0)) }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer)"
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: answer
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
                    let answer = rng { String(Int.random(in: 80 ... 600, using: &$0) * 10) }
                    let prefix = "￥"
                    let displayText = "\(prefix)\(answer)"
                    let question = Question(
                        displayText: displayText,
                        answerPrefix: prefix,
                        answerPostfix: nil,
                        acceptedAnswer: answer
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
