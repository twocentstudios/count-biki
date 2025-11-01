import ComposableArchitecture
import Sharing
import XCTest

@testable import count

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) {
        srand48(seed)
    }

    func next() -> UInt64 {
        withUnsafeBytes(of: drand48()) { bytes in
            bytes.load(as: UInt64.self)
        }
    }
}

final class ListeningQuizFeatureTests: XCTestCase {
    @MainActor
    func testOnAppear() async throws {
        let speechExpectation = expectation(description: "speaks")
        let store = TestStore(
            initialState: ListeningQuizFeature.State(
                topicID: Topic.mockID,
                quizMode: .infinite,
                sessionSettings: Shared(value: SessionSettings.default),
                speechSynthesisSettings: Shared(value: SpeechSynthesisSettings())
            )
        ) {
            ListeningQuizFeature()
        } withDependencies: {
            $0[TopicClient.self] = .mock
            $0.uuid = .incrementing
            $0.date.now = .init(timeIntervalSince1970: 0)
            $0[SpeechSynthesisClient.self].availableVoices = { [] }
            $0[SpeechSynthesisClient.self].defaultVoice = { nil }
            $0[SpeechSynthesisClient.self].speak = { _ in speechExpectation.fulfill() }
            $0.withRandomNumberGenerator = .init(RandomNumberGeneratorWithSeed(seed: 0))
        }

        await store.send(.onTask) {
            $0.isSpeaking = true
            $0.challenge = Challenge(
                id: .init(0),
                startDate: .init(timeIntervalSince1970: 0),
                question: Question(
                    topicID: Topic.mockID,
                    displayText: "1",
                    spokenText: "1",
                    answerPrefix: nil,
                    answerPostfix: nil,
                    acceptedAnswer: "1"
                ),
                submissions: []
            )
        }

        await store.receive(.onPlaybackFinished) {
            $0.isSpeaking = false
        }

        await fulfillment(of: [speechExpectation], timeout: 1)
        await store.finish()
    }
}
