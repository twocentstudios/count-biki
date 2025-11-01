import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer struct PreSettingsFeature {
    @ObservableState struct State: Equatable {
        var rawQuizMode: SessionSettings.QuizMode
        var rawQuestionLimit: Int
        var rawTimeLimit: Int
        @Shared var sessionSettings: SessionSettings
        @Shared var speechSynthesisSettings: SpeechSynthesisSettings

        init(
            sessionSettings: Shared<SessionSettings>,
            speechSynthesisSettings: Shared<SpeechSynthesisSettings>
        ) {
            _sessionSettings = sessionSettings
            _speechSynthesisSettings = speechSynthesisSettings

            rawQuizMode = sessionSettings.wrappedValue.quizMode
            rawQuestionLimit = sessionSettings.wrappedValue.questionLimit // TODO: validate input
            rawTimeLimit = sessionSettings.wrappedValue.timeLimit // TODO: validate input
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case dismissButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.rawQuizMode):
                state.$sessionSettings.withLock { $0.quizMode = state.rawQuizMode }
                return .none
            case .binding(\.rawQuestionLimit):
                state.$sessionSettings.withLock { $0.questionLimit = state.rawQuestionLimit }
                return .none
            case .binding(\.rawTimeLimit):
                state.$sessionSettings.withLock { $0.timeLimit = state.rawTimeLimit }
                return .none
            case .binding:
                return .none
            case .dismissButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}

struct PreSettingsView: View {
    @Bindable var store: StoreOf<PreSettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $store.rawQuizMode) {
                        ForEach(SessionSettings.QuizMode.allCases) { quizMode in
                            Text(quizMode.title)
                                .tag(quizMode)
                        }
                    } label: {
                        Text("Quiz Mode")
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    switch store.sessionSettings.quizMode {
                    case .infinite:
                        EmptyView()
                    case .questionLimit:
                        Picker(selection: $store.rawQuestionLimit) {
                            ForEach(SessionSettings.questionLimitValues, id: \.self) { value in
                                Text("\(value)")
                                    .tag(value)
                            }
                        } label: {
                            Text("Question Limit")
                        }
                        .pickerStyle(.segmented)
                    case .timeLimit:
                        Picker(selection: $store.rawTimeLimit) {
                            ForEach(SessionSettings.timeLimitValues, id: \.self) { value in
                                Text("\(Duration.seconds(value).formatted(.units(width: .condensedAbbreviated)))")
                                    .tag(value)
                            }
                        } label: {
                            Text("Time Limit")
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Quiz Mode")
                        .font(.subheadline)
                }
                .listRowBackground(Color(.tertiarySystemBackground))

                SpeechSettingsSection(
                    store: Store(initialState: .init(speechSettings: store.$speechSynthesisSettings)) {
                        SpeechSettingsFeature()
                    })
                    .listRowBackground(Color(.systemGroupedBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color(.tertiarySystemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Session Settings")
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.send(.dismissButtonTapped)
                    }
                    .font(.headline)
                }
            }
        }
    }
}

#Preview {
    PreSettingsView(
        store: Store(
            initialState: PreSettingsFeature.State(
                sessionSettings: Shared(wrappedValue: .default, .appStorage(SessionSettings.storageKey)),
                speechSynthesisSettings: Shared(wrappedValue: .init(), .appStorage(SpeechSynthesisSettings.storageKey))
            )
        ) {
            PreSettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps[SpeechSynthesisClient.self] = .noVoices
        }
    )
    .fontDesign(.rounded)
}
