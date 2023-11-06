import _NotificationDependency
import ComposableArchitecture
import SwiftUI

struct PreSettingsFeature: Reducer {
    struct State: Equatable {
        var availableVoices: [SpeechSynthesisVoice]
        @BindingState var rawQuizMode: SessionSettings.QuizMode
        @BindingState var rawQuestionLimit: Int
        @BindingState var rawTimeLimit: Int
        @BindingState var rawSpeechRate: Float
        @BindingState var rawVoiceIdentifier: String?
        @BindingState var rawPitchMultiplier: Float
        let pitchMultiplierRange: ClosedRange<Float>
        let speechRateRange: ClosedRange<Float>
        var speechSettings: SpeechSynthesisSettings
        var sessionSettings: SessionSettings

        init() {
            @Dependency(\.sessionSettingsClient) var sessionSettingsClient
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            @Dependency(\.speechSynthesisClient) var speechClient
            @Dependency(\.topicClient.allTopics) var allTopics

            sessionSettings = sessionSettingsClient.get()
            rawQuizMode = sessionSettings.quizMode
            rawQuestionLimit = sessionSettings.questionLimit // TODO: validate input
            rawTimeLimit = sessionSettings.timeLimit // TODO: validate input

            speechSettings = speechSettingsClient.get()

            availableVoices = speechClient.availableVoices()
            rawVoiceIdentifier = speechSettings.voiceIdentifier ?? speechClient.defaultVoice()?.voiceIdentifier

            let speechRateAttributes = speechClient.speechRateAttributes()
            rawSpeechRate = speechSettings.rate ?? speechRateAttributes.defaultRate
            speechRateRange = speechRateAttributes.minimumRate ... speechRateAttributes.maximumRate

            let pitchMultiplierAttributes = speechClient.pitchMultiplierAttributes()
            rawPitchMultiplier = speechSettings.pitchMultiplier ?? pitchMultiplierAttributes.defaultPitch
            pitchMultiplierRange = pitchMultiplierAttributes.minimumPitch ... pitchMultiplierAttributes.maximumPitch
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onSceneWillEnterForeground
        case onTask
        case pitchLabelDoubleTapped
        case rateLabelDoubleTapped
        case testVoiceButtonTapped
    }

    @Dependency.Notification(\.sceneWillEnterForeground) var sceneWillEnterForeground
    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.sessionSettingsClient) var sessionSettingsClient
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient

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
            case .binding(\.$rawQuizMode):
                state.sessionSettings.timeLimit = state.rawTimeLimit
                return .none
            case .binding(\.$rawSpeechRate):
                state.speechSettings.rate = state.rawSpeechRate
                return .none
            case .binding(\.$rawVoiceIdentifier):
                state.speechSettings.voiceIdentifier = state.rawVoiceIdentifier
                return .none
            case .binding(\.$rawPitchMultiplier):
                state.speechSettings.pitchMultiplier = state.rawPitchMultiplier
                return .none
            case .binding:
                return .none
            case .pitchLabelDoubleTapped:
                state.rawPitchMultiplier = speechClient.pitchMultiplierAttributes().defaultPitch
                state.speechSettings.pitchMultiplier = state.rawPitchMultiplier
                return .none
            case .rateLabelDoubleTapped:
                state.rawSpeechRate = speechClient.speechRateAttributes().defaultRate
                state.speechSettings.rate = state.rawSpeechRate
                return .none
            case .onSceneWillEnterForeground:
                state.availableVoices = speechClient.availableVoices()
                return .none
            case .onTask:
                return .run { send in
                    for await _ in sceneWillEnterForeground {
                        await send(.onSceneWillEnterForeground)
                    }
                }
            case .testVoiceButtonTapped:
                let spokenText = "1234"
                enum CancelID { case speakAction }
                return .run { [settings = state.speechSettings] send in
                    await withTaskCancellation(id: CancelID.speakAction, cancelInFlight: true) {
                        do {
                            let utterance = SpeechSynthesisUtterance(speechString: spokenText, settings: settings)
                            try await speechClient.speak(utterance)
                        } catch {
                            assertionFailure(error.localizedDescription)
                        }
                    }
                }
            }
        }
        .onChange(of: \.speechSettings) { _, newValue in
            Reduce { _, _ in
                do {
                    try speechSettingsClient.set(newValue)
                } catch {
                    XCTFail("SpeechSettingsClient unexpectedly failed to write")
                }
                return .none
            }
        }
        .onChange(of: \.sessionSettings) { _, newValue in
            Reduce { _, _ in
                do {
                    try sessionSettingsClient.set(newValue)
                } catch {
                    XCTFail("SessionSettingsClient unexpectedly failed to write")
                }
                return .none
            }
        }
    }
}

struct PreSettingsView: View {
    let store: StoreOf<PreSettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                List {
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

                    Section {
                        if let $unwrappedVoiceIdentifier = Binding(viewStore.$rawVoiceIdentifier) {
                            Picker(selection: $unwrappedVoiceIdentifier) {
                                ForEach(viewStore.availableVoices) { voice in
                                    Text(voice.name)
                                        .tag(Optional(voice.voiceIdentifier))
                                }
                            } label: {
                                Text("Voice name")
                            }
                            .pickerStyle(.navigationLink)
                            NavigationLink {
                                GetMoreVoicesView()
                            } label: {
                                Text("Get more voices")
                            }
                            HStack {
                                Text("Rate")
                                    .onTapGesture(count: 2) {
                                        viewStore.send(.rateLabelDoubleTapped)
                                    }
                                Slider(value: viewStore.$rawSpeechRate, in: viewStore.speechRateRange, step: 0.05) {
                                    Text("Speech rate")
                                } minimumValueLabel: {
                                    Image(systemName: "tortoise")
                                } maximumValueLabel: {
                                    Image(systemName: "hare")
                                }
                            }
                            HStack {
                                Text("Pitch")
                                    .onTapGesture(count: 2) {
                                        viewStore.send(.pitchLabelDoubleTapped)
                                    }
                                Slider(value: viewStore.$rawPitchMultiplier, in: viewStore.pitchMultiplierRange, step: 0.05) {
                                    Text("Pitch")
                                } minimumValueLabel: {
                                    Image(systemName: "dial.low")
                                } maximumValueLabel: {
                                    Image(systemName: "dial.high")
                                }
                            }
                            Button {
                                viewStore.send(.testVoiceButtonTapped)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.wave.2")
                                    Text("Test Voice")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        } else {
                            NavigationLink {
                                GetMoreVoicesView()
                            } label: {
                                HStack {
                                    Text("Error: no voices found on device")
                                        .foregroundStyle(Color.red)
                                }
                            }
                        }
                    } header: {
                        Text("Voice Settings")
                            .font(.subheadline)
                    }
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
            .task {
                await viewStore.send(.onTask).finish()
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
