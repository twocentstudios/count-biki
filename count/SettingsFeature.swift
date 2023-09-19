import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        @BindingState var speechSettings: SpeechSynthesisSettings // TODO: nil is error
        let availableVoices: [SpeechSynthesisVoice]
        @BindingState var rawSpeechRate: Float
        let speechRateRange: ClosedRange<Float>

        let topic: Topic

        init(topicID: UUID) {
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            @Dependency(\.speechSynthesisClient) var speechClient
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
            let speechSettings = try! speechSettingsClient.get() // TODO: error handling
            self.speechSettings = speechSettings
            availableVoices = speechClient.availableVoices()
            let speechRateAttributes = speechClient.speechRateAttributes()
            rawSpeechRate = speechSettings.rate ?? speechRateAttributes.defaultRate
            speechRateRange = speechRateAttributes.minimumRate ... speechRateAttributes.maximumRate
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneButtonTapped
        case endSessionButtonTapped
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.$rawSpeechRate):
                state.speechSettings.rate = state.rawSpeechRate
                return .none
            case .binding:
                return .none
            case .doneButtonTapped:
                return .run { send in
                    await dismiss()
                }
            case .endSessionButtonTapped:
                return .none
            }
        }
        .onChange(of: \.speechSettings) { _, newValue in
            Reduce { state, action in
                try? speechSettingsClient.set(newValue) // TODO: handle error
                return .none
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

                        Button {
                            viewStore.send(.endSessionButtonTapped)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "door.right.hand.open")
                                Text("End Session")
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } header: {
                        Text("Topic")
                            .font(.subheadline)
                    }
                    Section {
                        Picker(selection: viewStore.$speechSettings.voiceIdentifier) {
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
                            Slider(value: viewStore.$rawSpeechRate, in: viewStore.speechRateRange) {
                                Text("Speech rate")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                            }
                        }
                        Button {
                            // TODO: play test
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.wave.2")
                                Text("Test Voice")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } header: {
                        Text("Voice")
                            .font(.subheadline)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
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
        }
    }
}

#Preview {
    SettingsView(
        store: Store(initialState: SettingsFeature.State(topicID: Topic.mockID)) {
            SettingsFeature()
                ._printChanges()
        }
    )
    .fontDesign(.rounded)
}
