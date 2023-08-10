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
                    Section("Voice") {
                        Picker("Voice Name", selection: viewStore.$speechSettings.voiceIdentifier) {
                            ForEach(viewStore.availableVoices) { voice in
                                Text(voice.name)
                                    .tag(Optional(voice.voiceIdentifier))
                            }
                        }
                        .pickerStyle(.navigationLink)
                        NavigationLink("Get more voices") {
                            Text("TODO")
                        }
                    }
                }
                .navigationBarTitle("Settings")
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
