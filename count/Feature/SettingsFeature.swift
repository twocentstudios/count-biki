import _NotificationDependency
import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        var availableVoices: [SpeechSynthesisVoice]
        @BindingState var rawSpeechRate: Float
        @BindingState var rawVoiceIdentifier: String?
        @BindingState var rawPitchMultiplier: Float
        let pitchMultiplierRange: ClosedRange<Float>
        let speechRateRange: ClosedRange<Float>
        var speechSettings: SpeechSynthesisSettings

        let topic: Topic

        init(topicID: UUID, speechSettings: SpeechSynthesisSettings) {
            @Dependency(\.speechSynthesisClient) var speechClient
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
            self.speechSettings = speechSettings

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
        case delegate(Delegate)
        case doneButtonTapped
        case onSceneWillEnterForeground
        case onTask
        case pitchLabelDoubleTapped
        case rateLabelDoubleTapped
        case testVoiceButtonTapped

        enum Delegate: Equatable {
            case speechSettingsUpdated(SpeechSynthesisSettings)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency.Notification(\.sceneWillEnterForeground) var sceneWillEnterForeground
    @Dependency(\.speechSynthesisClient) var speechClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
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
            case .delegate:
                return .none
            case .doneButtonTapped:
                return .run { send in
                    await dismiss()
                }
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
                .send(.delegate(.speechSettingsUpdated(newValue)))
            }
        }
    }
}

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewStore.topic.skill.title): \(viewStore.topic.category.title)")
                                .font(.headline)
                            Text(viewStore.topic.title)
                                .font(.subheadline)
                            Text(viewStore.topic.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 2)
                    } header: {
                        Text("Topic")
                            .font(.subheadline)
                    }

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
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Session")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Session")
                            .font(.headline)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.doneButtonTapped)
                        } label: {
                            Text("Done")
                                .font(.headline)
                        }
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
    SettingsView(
        store: Store(initialState: SettingsFeature.State(topicID: Topic.mockID, speechSettings: .mock)) {
            SettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps.speechSynthesisClient = .noVoices
        }
    )
    .fontDesign(.rounded)
}
