import _NotificationDependency
import ComposableArchitecture
import SwiftUI

struct PreSettingsFeature: Reducer {
    struct State: Equatable {
        @BindingState var rawQuizMode: SessionSettings.QuizMode
        @BindingState var rawQuestionLimit: Int
        @BindingState var rawTimeLimit: Int
        var sessionSettings: SessionSettings

        init() {
            @Dependency(\.sessionSettingsClient) var sessionSettingsClient
            @Dependency(\.topicClient.allTopics) var allTopics

            sessionSettings = sessionSettingsClient.get()
            rawQuizMode = sessionSettings.quizMode
            rawQuestionLimit = sessionSettings.questionLimit // TODO: validate input
            rawTimeLimit = sessionSettings.timeLimit // TODO: validate input
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.sessionSettingsClient.set) var setSessionSettings

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.$rawQuizMode):
                state.sessionSettings.quizMode = state.rawQuizMode
                return .none
            case .binding(\.$rawQuestionLimit):
                state.sessionSettings.questionLimit = state.rawQuestionLimit
                return .none
            case .binding(\.$rawTimeLimit):
                state.sessionSettings.timeLimit = state.rawTimeLimit
                return .none
            case .binding:
                return .none
            }
        }
        .onChange(of: \.sessionSettings) { _, newValue in
            Reduce { _, _ in
                .run { _ in
                    do {
                        try await setSessionSettings(newValue)
                    } catch {
                        XCTFail("SessionSettingsClient unexpectedly failed to write")
                    }
                }
            }
        }
    }
}

struct PreSettingsView: View {
    let store: StoreOf<PreSettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        Picker(selection: viewStore.$rawQuizMode) {
                            ForEach(SessionSettings.QuizMode.allCases) { quizMode in
                                Text(quizMode.title)
                                    .tag(quizMode)
                            }
                        } label: {
                            Text("Quiz Mode")
                        }
                        .pickerStyle(.segmented)
                        .listRowSeparator(.hidden)
                        switch viewStore.sessionSettings.quizMode {
                        case .infinite:
                            EmptyView()
                        case .questionLimit:
                            Picker(selection: viewStore.$rawQuestionLimit) {
                                ForEach(SessionSettings.questionLimitValues, id: \.self) { value in
                                    Text("\(value)")
                                        .tag(value)
                                }
                            } label: {
                                Text("Question Limit")
                            }
                            .pickerStyle(.segmented)
                        case .timeLimit:
                            Picker(selection: viewStore.$rawTimeLimit) {
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
