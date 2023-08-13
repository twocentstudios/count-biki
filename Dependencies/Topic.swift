import Dependencies
import Foundation
import IdentifiedCollections

private struct TopicGenerator: Identifiable {
    var id: UUID { topic.id }
    let topic: Topic
    var generateQuestion: @Sendable (WithRandomNumberGenerator) throws -> (String)
}

struct Topic: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
}

struct TopicClient {
    var allTopics: @Sendable () -> IdentifiedArrayOf<Topic>
    var generateQuestion: @Sendable (UUID) throws -> (String)
}

extension TopicClient: DependencyKey {
    static var liveValue: TopicClient {
        @Dependency(\.withRandomNumberGenerator) var rng
        var uuidGenerator = UUIDGenerator.incrementing
        let allTopicGenerators: IdentifiedArrayOf<TopicGenerator> = [
            TopicGenerator(
                topic: Topic(
                    id: uuidGenerator(),
                    title: "Numbers",
                    subtitle: "1-999",
                    description: "Integers between 1-999"
                ),
                generateQuestion: { rng in
                    rng { String(Int.random(in: 1 ... 999, using: &$0)) }
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
                    rng { "￥\(Int.random(in: 100 ... 1500, using: &$0))" }
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
                    rng { "￥\(Int.random(in: 80 ... 600, using: &$0) * 10)" }
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
    var feature: TopicClient {
        get { self[TopicClient.self] }
        set { self[TopicClient.self] = newValue }
    }
}
