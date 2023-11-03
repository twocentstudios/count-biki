import ComposableArchitecture
import SwiftUI

struct ListeningQuizWrapperFeature: Reducer {
    struct State: Equatable {
        var listeningQuiz: ListeningQuizFeature.State
        var path = StackState<Path.State>()
    }

    enum Action: Equatable {
        case listeningQuiz(ListeningQuizFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
    }

    struct Path: Reducer {
        enum State: Equatable {
            case summary(SessionSummaryFeature.State)
        }

        enum Action: Equatable {
            case summary(SessionSummaryFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.summary, action: /Action.summary) {
                SessionSummaryFeature()
            }
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Scope(state: \.listeningQuiz, action: /Action.listeningQuiz) {
            ListeningQuizFeature()
        }
        Reduce { state, action in
            switch action {
            case let .listeningQuiz(.delegate(.wantsToShowSummary(summaryState))):
                state.path.append(.summary(summaryState))
                return .none
            case .listeningQuiz:
                return .none
            case .path(.element(_, .summary(.delegate(.endSession)))):
                return .run { _ in
                    await dismiss()
                }

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
}

struct ListeningQuizWrapperView: View {
    let store: StoreOf<ListeningQuizWrapperFeature>

    var body: some View {
        NavigationStackStore(store.scope(state: \.path, action: { .path($0) })) {
            ListeningQuizView(store: store.scope(state: \.listeningQuiz, action: { .listeningQuiz($0) }))
        } destination: {
            switch $0 {
            case .summary:
                CaseLet(
                    /ListeningQuizWrapperFeature.Path.State.summary,
                    action: ListeningQuizWrapperFeature.Path.Action.summary,
                    then: SessionSummaryView.init(store:)
                )
            }
        }
    }
}

#Preview {
    ListeningQuizWrapperView(
        store: Store(initialState: ListeningQuizWrapperFeature.State(listeningQuiz: .init(topicID: Topic.mockID))) {
            ListeningQuizWrapperFeature()
                ._printChanges()
        }
    )
}
