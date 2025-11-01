import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer struct SettingsFeature {
    @ObservableState struct State: Equatable {
        @Shared var sessionSettings: SessionSettings
        @Shared var speechSynthesisSettings: SpeechSynthesisSettings
        let topic: Topic

        init(
            topicID: UUID,
            sessionSettings: Shared<SessionSettings>,
            speechSynthesisSettings: Shared<SpeechSynthesisSettings>
        ) {
            @Dependency(TopicClient.self) var topicClient
            _sessionSettings = sessionSettings
            _speechSynthesisSettings = speechSynthesisSettings

            topic = topicClient.allTopics()[id: topicID]!
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                .none
            case .doneButtonTapped:
                .run { send in
                    await dismiss()
                }
            }
        }
    }
}

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.topic.skill.title): \(store.topic.category.title)")
                            .font(.headline)
                        Text(store.topic.title)
                            .font(.subheadline)
                        Text(store.topic.description)
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
                    Toggle(isOn: $store.sessionSettings.isShowingProgress, label: {
                        Text("Show progress")
                    })
                    Toggle(isOn: $store.sessionSettings.isShowingBiki, label: {
                        Text("Show Biki")
                    })
                    Toggle(isOn: $store.sessionSettings.isShowingConfetti, label: {
                        Text("Show confetti")
                    })
                } header: {
                    Text("Display Settings")
                        .font(.subheadline)
                }

                SpeechSettingsSection(
                    store: Store(initialState: .init(speechSettings: store.$speechSynthesisSettings)) {
                        SpeechSettingsFeature()
                    })
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
                        store.send(.doneButtonTapped)
                    } label: {
                        Text("Done")
                            .font(.headline)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(
                topicID: Topic.mockID,
                sessionSettings: Shared(wrappedValue: .default, .appStorage(SessionSettings.storageKey)),
                speechSynthesisSettings: Shared(wrappedValue: .init(), .appStorage(SpeechSynthesisSettings.storageKey))
            )
        ) {
            SettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps[SpeechSynthesisClient.self] = .noVoices
        }
    )
    .fontDesign(.rounded)
}
