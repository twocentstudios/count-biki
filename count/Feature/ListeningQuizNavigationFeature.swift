import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer struct ListeningQuizNavigationFeature {
    @ObservableState struct State: Equatable {
        var listeningQuiz: ListeningQuizFeature.State
        var path = StackState<Path.State>()
        @Presents var settings: SettingsFeature.State?

        init(topicID: UUID) {
            let sessionSettings = Shared(
                wrappedValue: SessionSettings.default,
                .appStorage(SessionSettings.storageKey)
            ).wrappedValue
            listeningQuiz = .init(topicID: topicID, quizMode: .init(sessionSettings))
        }
    }

    enum Action: Equatable {
        case listeningQuiz(ListeningQuizFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
        case settings(PresentationAction<SettingsFeature.Action>)
    }

    @Reducer
    enum Path {
        case summary(SessionSummaryFeature)
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Scope(state: \.listeningQuiz, action: \.listeningQuiz) {
            ListeningQuizFeature()
        }
        Reduce { state, action in
            switch action {
            case .listeningQuiz(.endSessionButtonTapped):
                if state.listeningQuiz.completedChallenges.isEmpty,
                   state.listeningQuiz.challenge.submissions.isEmpty
                {
                    return .run { _ in await dismiss() }
                } else {
                    state.path.append(.summary(.init(
                        topicID: state.listeningQuiz.topicID,
                        sessionChallenges: state.listeningQuiz.completedChallenges,
                        quizMode: state.listeningQuiz.quizMode,
                        isSessionComplete: state.listeningQuiz.isSessionComplete
                    )))
                    return .none
                }

            case .listeningQuiz(.settingsButtonTapped):
                state.settings = .init(topicID: state.listeningQuiz.topicID)
                return .none

            case .listeningQuiz(.answerSubmitButtonTapped):
                if state.listeningQuiz.isSessionComplete {
                    state.path.append(.summary(.init(
                        topicID: state.listeningQuiz.topicID,
                        sessionChallenges: state.listeningQuiz.completedChallenges,
                        quizMode: state.listeningQuiz.quizMode,
                        isSessionComplete: state.listeningQuiz.isSessionComplete
                    )))
                }
                return .none

            case .listeningQuiz:
                return .none

            case .path(.element(_, .summary(.endSessionButtonTapped))):
                return .run { _ in await dismiss() }

            case .path:
                return .none

            case .settings:
                return .none
            }
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
        .forEach(\.path, action: \.path)
        Reduce { state, action in
            state.listeningQuiz.isViewFrontmost = state.path.isEmpty && state.settings == nil
            return .none
        }
    }
}

extension ListeningQuizNavigationFeature.Path.State: Equatable {}
extension ListeningQuizNavigationFeature.Path.Action: Equatable {}

struct ListeningQuizNavigationView: View {
    @Bindable var store: StoreOf<ListeningQuizNavigationFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ListeningQuizView(store: store.scope(state: \.listeningQuiz, action: \.listeningQuiz))
        } destination: { store in
            switch store.case {
            case let .summary(store):
                SessionSummaryView(store: store)
            }
        }
        .sheet(item: $store.scope(state: \.settings, action: \.settings)) { store in
            SettingsView(store: store)
        }
    }
}

#Preview {
    ListeningQuizNavigationView(
        store: Store(initialState: ListeningQuizNavigationFeature.State(topicID: Topic.mockID)) {
            ListeningQuizNavigationFeature()
                ._printChanges()
        }
    )
}
