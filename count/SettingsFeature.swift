import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        @BindingState var speechSettings: SpeechSynthesisSettings // TODO: nil is error
        let availableVoices: [SpeechSynthesisVoice]

        @BindingState var topicID: UUID
        var topic: Topic { availableTopics[id: topicID]! }
        let availableTopics: IdentifiedArrayOf<Topic>

        init() {
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            @Dependency(\.speechSynthesisClient) var speechClient
            @Dependency(\.topicSettingsClient) var topicSettingsClient
            @Dependency(\.topicClient) var topicClient

            speechSettings = try! speechSettingsClient.get() // TODO: error handling
            availableVoices = speechClient.availableVoices()

            availableTopics = topicClient.allTopics()

            if let loadedID = try? topicSettingsClient.get(),
               availableTopics[id: loadedID] != nil
            {
                topicID = loadedID
            } else {
                topicID = availableTopics.first!.id
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
    @Dependency(\.topicSettingsClient) var topicSettingsClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                // TODO: should persistence happen in child or parent reducer?
                try? speechSettingsClient.set(state.speechSettings) // TODO: handle error
                try? topicSettingsClient.set(state.topicID) // TODO: handle error
                return .none
            case .doneButtonTapped:
                return .run { send in
                    await dismiss()
                }
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
                        Picker(selection: viewStore.$speechSettings.voiceIdentifier) {
                            ForEach(viewStore.availableVoices) { voice in
                                Text(voice.name)
                                    .tag(Optional(voice.voiceIdentifier))
                            }
                        } label: {
                            Text("Voice Name")
                        }
                        .pickerStyle(.navigationLink)
                        NavigationLink {
                            GetMoreVoicesView()
                        } label: {
                            Text("Get more voices")
                        }
                    } header: {
                        Text("Voice")
                            .font(.subheadline)
                    }

                    Section {
                        Picker(selection: viewStore.$topicID) {
                            ForEach(viewStore.availableTopics) { topic in
                                VStack(alignment: .leading) {
                                    Text(topic.title).font(.headline) + Text(": ") + Text(topic.subtitle).font(.subheadline)
                                    Text(topic.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                                .tag(topic.id)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.inline)
                    } header: {
                        Text("Topics")
                            .font(.subheadline)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
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
        store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
                ._printChanges()
        }
    )
    .fontDesign(.rounded)
}
