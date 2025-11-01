import ComposableArchitecture
import Foundation
import Sharing
import SwiftUI
import UIKit

@Reducer struct SpeechSettingsFeature {
    @ObservableState struct State: Equatable {
        var availableVoices: [SpeechSynthesisVoice]
        var rawSpeechRate: Float
        var rawVoiceIdentifier: String?
        var rawPitchMultiplier: Float
        let pitchMultiplierRange: ClosedRange<Float>
        let speechRateRange: ClosedRange<Float>
        @Shared var speechSettings: SpeechSynthesisSettings

        init(speechSettings: Shared<SpeechSynthesisSettings>) {
            @Dependency(SpeechSynthesisClient.self) var speechClient
            _speechSettings = speechSettings

            availableVoices = speechClient.availableVoices()
            rawVoiceIdentifier = speechSettings.wrappedValue.voiceIdentifier ?? speechClient.defaultVoice()?.voiceIdentifier

            let speechRateAttributes = speechClient.speechRateAttributes()
            rawSpeechRate = speechSettings.wrappedValue.rate ?? speechRateAttributes.defaultRate
            speechRateRange = speechRateAttributes.minimumRate ... speechRateAttributes.maximumRate

            let pitchMultiplierAttributes = speechClient.pitchMultiplierAttributes()
            rawPitchMultiplier = speechSettings.wrappedValue.pitchMultiplier ?? pitchMultiplierAttributes.defaultPitch
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
        case foregroundNotifications
    }

    @Dependency(SpeechSynthesisClient.self) var speechClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.rawSpeechRate):
                state.$speechSettings.withLock { $0.rate = state.rawSpeechRate }
                return .none
            case .binding(\.rawVoiceIdentifier):
                state.$speechSettings.withLock { $0.voiceIdentifier = state.rawVoiceIdentifier }
                return .none
            case .binding(\.rawPitchMultiplier):
                state.$speechSettings.withLock { $0.pitchMultiplier = state.rawPitchMultiplier }
                return .none
            case .binding:
                return .none
            case .pitchLabelDoubleTapped:
                state.rawPitchMultiplier = speechClient.pitchMultiplierAttributes().defaultPitch
                state.$speechSettings.withLock { $0.pitchMultiplier = state.rawPitchMultiplier }
                return .none
            case .rateLabelDoubleTapped:
                state.rawSpeechRate = speechClient.speechRateAttributes().defaultRate
                state.$speechSettings.withLock { $0.rate = state.rawSpeechRate }
                return .none
            case .onSceneWillEnterForeground:
                state.availableVoices = speechClient.availableVoices()
                return .none
            case .onTask:
                return .run { send in
                    let notifications = NotificationCenter.default.notifications(
                        named: UIApplication.willEnterForegroundNotification
                    )
                    for await _ in notifications {
                        await send(.onSceneWillEnterForeground)
                    }
                }
                .cancellable(id: CancelID.foregroundNotifications, cancelInFlight: true)
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
    }
}

struct SpeechSettingsSection: View {
    @Bindable var store: StoreOf<SpeechSettingsFeature>

    var body: some View {
        Section {
            if let $unwrappedVoiceIdentifier = Binding($store.rawVoiceIdentifier) {
                Picker(selection: $unwrappedVoiceIdentifier) {
                    ForEach(store.availableVoices) { voice in
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
                            store.send(.rateLabelDoubleTapped)
                        }
                    Slider(value: $store.rawSpeechRate, in: store.speechRateRange, step: 0.05) {
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
                            store.send(.pitchLabelDoubleTapped)
                        }
                    Slider(value: $store.rawPitchMultiplier, in: store.pitchMultiplierRange, step: 0.05) {
                        Text("Pitch")
                    } minimumValueLabel: {
                        Image(systemName: "dial.low")
                    } maximumValueLabel: {
                        Image(systemName: "dial.high")
                    }
                }
                Button {
                    store.send(.testVoiceButtonTapped)
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
        .task {
            await store.send(.onTask).finish()
        }
    }
}
