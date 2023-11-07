import _NotificationDependency
import ComposableArchitecture
import SwiftUI

struct SpeechSettingsFeature: Reducer {
    struct State: Equatable {
        var availableVoices: [SpeechSynthesisVoice]
        @BindingState var rawSpeechRate: Float
        @BindingState var rawVoiceIdentifier: String?
        @BindingState var rawPitchMultiplier: Float
        let pitchMultiplierRange: ClosedRange<Float>
        let speechRateRange: ClosedRange<Float>
        var speechSettings: SpeechSynthesisSettings

        init() {
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            @Dependency(\.speechSynthesisClient) var speechClient

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

    private enum CancelID {
        case saveDebounce
    }

    @Dependency(\.continuousClock) var clock
    @Dependency.Notification(\.sceneWillEnterForeground) var sceneWillEnterForeground
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
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
            Reduce { state, _ in
                .run { _ in
                    try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
                        try await clock.sleep(for: .seconds(0.25))
                        try speechSettingsClient.set(newValue)
                    }
                } catch: { _, _ in
                    XCTFail("SpeechSettingsClient unexpectedly failed to write")
                }
            }
        }
    }
}

struct SpeechSettingsSection: View {
    let store: StoreOf<SpeechSettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
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
    }
}
