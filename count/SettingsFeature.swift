import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        @BindingState var speechSettings: SpeechSynthesisSettings // TODO: nil is error
        let availableVoices: [SpeechSynthesisVoice]

        init() {
            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            @Dependency(\.speechSynthesisClient) var speechClient
            speechSettings = try! speechSettingsClient.get() // TODO: error handling
            availableVoices = speechClient.availableVoices()
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                try? speechSettingsClient.set(state.speechSettings) // TODO: handle error
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
                                    .font(.system(.body, design: .rounded))
                                    .tag(Optional(voice.voiceIdentifier))
                            }
                        } label: {
                            Text("Voice Name")
                                .font(.system(.body, design: .rounded))
                        }
                        .pickerStyle(.navigationLink)
                        NavigationLink {
                            Text("TODO")
                                .font(.system(.body, design: .rounded))
                        } label: {
                            Text("Get more voices")
                                .font(.system(.body, design: .rounded))
                        }
                    } header: {
                        Text("Voice")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .font(.system(.headline, design: .rounded))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.doneButtonTapped)
                        } label: {
                            Text("Done")
                                .font(.system(.headline, design: .rounded))
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
}
