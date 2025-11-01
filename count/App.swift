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
                            ._printChanges()
                    } withDependencies: {
                        #if targetEnvironment(simulator)
                            // $0[TopicClient.self] = .mock
                            $0[TopicClient.self] = .liveValue
                        #endif
                    }
                )
                .fontDesign(.rounded)
                .task {
                    // TODO: move this to AppReducer
                    @Dependency(TierProductsClient.self) var tierProductsClient
                    await tierProductsClient.monitorPurchases()
                }
            }
        }
    }
}
