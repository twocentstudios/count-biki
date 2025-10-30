import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer struct PreSettingsFeature {
    @ObservableState struct State: Equatable {
        var rawQuizMode: SessionSettings.QuizMode
        var rawQuestionLimit: Int
        var rawTimeLimit: Int
        var sessionSettings: SessionSettings

        init() {
            let sharedSessionSettings = Shared(
                wrappedValue: SessionSettings.default,
                .appStorage(SessionSettings.storageKey)
            )
            let sessionSettings = sharedSessionSettings.wrappedValue
            self.sessionSettings = sessionSettings

            rawQuizMode = sessionSettings.quizMode
            rawQuestionLimit = sessionSettings.questionLimit // TODO: validate input
            rawTimeLimit = sessionSettings.timeLimit // TODO: validate input
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    @Shared(.appStorage(SessionSettings.storageKey)) var sharedSessionSettings = SessionSettings.default

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.rawQuizMode):
                state.sessionSettings.quizMode = state.rawQuizMode
                return .none
            case .binding(\.rawQuestionLimit):
                state.sessionSettings.questionLimit = state.rawQuestionLimit
                return .none
            case .binding(\.rawTimeLimit):
                state.sessionSettings.timeLimit = state.rawTimeLimit
                return .none
            case .binding:
                return .none
            }
        }
        .onChange(of: \.sessionSettings) { _, newValue in
            Reduce { _, _ in
                .run { _ in
                    $sharedSessionSettings.withLock { $0 = newValue }
                }
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
                    store: Store(initialState: .init()) {
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
            }
        }
    }
}

#Preview {
    PreSettingsView(
        store: Store(initialState: PreSettingsFeature.State()) {
            PreSettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps.speechSynthesisClient = .noVoices
        }
    )
    .fontDesign(.rounded)
}
