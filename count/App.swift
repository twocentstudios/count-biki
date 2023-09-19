import ComposableArchitecture
import SwiftUI

let appStoreAppID = "6463796779"

@main
struct CountApp: App {
    var body: some Scene {
        WindowGroup {
            TopicsView(
                store: Store(initialState: .init()) {
                    TopicsFeature()
                } withDependencies: {
                    #if targetEnvironment(simulator)
                        $0.topicClient.generateQuestion = { _ in .init(topicID: Topic.id(for: 000), displayText: "1", spokenText: "1", answerPrefix: nil, answerPostfix: nil, acceptedAnswer: "1") }
                    #endif
                }
            )
            .fontDesign(.rounded)
        }
    }
}
