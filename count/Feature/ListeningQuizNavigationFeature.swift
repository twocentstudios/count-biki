import ComposableArchitecture
import SwiftUI

struct ListeningQuizNavigationFeature: Reducer {
    struct State: Equatable {
        var listeningQuiz: ListeningQuizFeature.State
        var path = StackState<Path.State>()
        @PresentationState var settings: SettingsFeature.State?

        init(topicID: UUID, quizMode: QuizMode) {
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            let speechSettings = speechSettingsClient.get()

            listeningQuiz = .init(topicID: topicID, quizMode: quizMode, speechSettings: speechSettings)
        }
    }

    enum Action: Equatable {
        case listeningQuiz(ListeningQuizFeature.Action)
        case path(StackAction<Path.State, Path.Action>)
        case settings(PresentationAction<SettingsFeature.Action>)
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
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient

    var body: some ReducerOf<Self> {
        CombineReducers {
            Scope(state: \.listeningQuiz, action: /Action.listeningQuiz) {
                ListeningQuizFeature()
            }
            Reduce { state, action in
                switch action {
                case .listeningQuiz(.endSessionButtonTapped):
                    if state.listeningQuiz.completedChallenges.isEmpty, state.listeningQuiz.challenge.submissions.isEmpty {
                        return .run { _ in await dismiss() }
                    } else {
                        state.path.append(.summary(.init(topicID: state.listeningQuiz.topicID, sessionChallenges: state.listeningQuiz.completedChallenges)))
                        return .none
                    }

                case .listeningQuiz(.settingsButtonTapped):
                    state.settings = .init(topicID: state.listeningQuiz.topicID, speechSettings: state.listeningQuiz.speechSettings)
                    return .none

                case .listeningQuiz:
                    return .none

                case .path(.element(_, .summary(.delegate(.endSession)))):
                    return .run { _ in await dismiss() }

                case .path:
                    return .none

                case .settings:
                    return .none
                }
            }
            .ifLet(\.$settings, action: /Action.settings) {
                SettingsFeature()
            }
            .forEach(\.path, action: /Action.path) {
                Path()
            }
        }
        .onChange(of: \.settings?.speechSettings) { _, newValue in
            // Play back speechSettings changes to listeningQuiz and client.
            Reduce { state, _ in
                guard let newValue else { return .none }
                state.listeningQuiz.speechSettings = newValue
                do {
                    try speechSettingsClient.set(newValue)
                } catch {
                    XCTFail("SpeechSettingsClient unexpectedly failed to write")
                }
                return .none
            }
        }
    }
}

struct ListeningQuizNavigationView: View {
    let store: StoreOf<ListeningQuizNavigationFeature>

    var body: some View {
        NavigationStackStore(store.scope(state: \.path, action: { .path($0) })) {
            ListeningQuizView(store: store.scope(state: \.listeningQuiz, action: { .listeningQuiz($0) }))
        } destination: {
            switch $0 {
            case .summary:
                CaseLet(
                    /ListeningQuizNavigationFeature.Path.State.summary,
                    action: ListeningQuizNavigationFeature.Path.Action.summary,
                    then: SessionSummaryView.init(store:)
                )
            }
        }
        .sheet(store: store.scope(state: \.$settings, action: { .settings($0) })) { store in
            SettingsView(store: store)
        }
    }
}

#Preview {
    ListeningQuizNavigationView(
        store: Store(initialState: ListeningQuizNavigationFeature.State(topicID: Topic.mockID, quizMode: .infinite)) {
            ListeningQuizNavigationFeature()
                ._printChanges()
        }
    )
}
