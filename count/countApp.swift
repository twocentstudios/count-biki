import SwiftUI
import ComposableArchitecture

@main
struct countApp: App {
    var body: some Scene {
        WindowGroup {
            ListeningQuizView(
                store: Store(initialState: ListeningQuizFeature.State()) {
                    ListeningQuizFeature()
                }
            )
        }
    }
}
