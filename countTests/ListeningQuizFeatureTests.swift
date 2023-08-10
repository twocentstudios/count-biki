import ComposableArchitecture
import XCTest

@testable import count

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) {
        srand48(seed)
    }
    
    func next() -> UInt64 {
        return withUnsafeBytes(of: drand48()) { bytes in
            bytes.load(as: UInt64.self)
        }
    }
}

@MainActor final class ListeningQuizFeatureTests: XCTestCase {
    func testOnAppear() async throws {
        let speechExpectation = expectation(description: "speaks")
        let store = TestStore(initialState: ListeningQuizFeature.State()) {
            ListeningQuizFeature()
        } withDependencies: {
            $0.speechSynthesisClient.speak = { _ in speechExpectation.fulfill() }
            $0.withRandomNumberGenerator = .init(RandomNumberGeneratorWithSeed(seed: 0))
        }

        await store.send(.onTask) {
            $0.question = "2491"
            $0.isSpeaking = true
            $0.questionNumber = 1
        }
        
        await store.receive(.onPlaybackFinished) {
            $0.isSpeaking = false
        }
        
        await fulfillment(of: [speechExpectation], timeout: 1)
    }
}
