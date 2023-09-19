import ComposableArchitecture
import SwiftUI

let appStoreAppID = "6463796779"

@main
struct CountApp: App {
    var body: some Scene {
        WindowGroup {
            if !_XCTIsTesting {
                TopicsView(
                    store: Store(initialState: .init()) {
                        TopicsFeature()
                    } withDependencies: {
                        #if targetEnvironment(simulator)
                            $0.topicClient = .mock
                        #endif
                    }
                )
                .fontDesign(.rounded)
            }
        }
    }
}
