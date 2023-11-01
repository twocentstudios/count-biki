import ComposableArchitecture
import SwiftUI

struct SessionSummaryFeature: Reducer {
    struct State: Equatable {}

    enum Action: Equatable {}

    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {}
        }
    }
}

struct SessionSummaryView: View {
    let store: StoreOf<SessionSummaryFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Text("hello")
        }
    }
}

#Preview {
    SessionSummaryView(
        store: Store(initialState: SessionSummaryFeature.State()) {
            SessionSummaryFeature()
                ._printChanges()
        }
    )
}
