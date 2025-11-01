import ComposableArchitecture
import Sharing
import SwiftUI

@Reducer struct SettingsFeature {
    @ObservableState struct State: Equatable {
        var sessionSettings: SessionSettings
        let topic: Topic

        init(topicID: UUID) {
            @Dependency(TopicClient.self) var topicClient
            let sharedSessionSettings = Shared(
                wrappedValue: SessionSettings.default,
                .appStorage(SessionSettings.storageKey)
            )

            topic = topicClient.allTopics()[id: topicID]!
            sessionSettings = sharedSessionSettings.wrappedValue
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case doneButtonTapped
    }

    private enum CancelID {
        case saveDebounce
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss
    /// TODO: does this work with TCA???
    @Shared(.appStorage(SessionSettings.storageKey)) var sharedSessionSettings = SessionSettings.default

    var body: some ReducerOf<Self> {
        CombineReducers {
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
        .onChange(of: \.sessionSettings) { _, newValue in
            Reduce { state, _ in
                .run { _ in
                    try await withTaskCancellation(id: CancelID.saveDebounce, cancelInFlight: true) {
                        try await clock.sleep(for: .seconds(0.25))
                        $sharedSessionSettings.withLock { $0 = newValue }
                    }
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
                    store: Store(initialState: .init()) {
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
        store: Store(initialState: SettingsFeature.State(topicID: Topic.mockID)) {
            SettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps[SpeechSynthesisClient.self] = .noVoices
        }
    )
    .fontDesign(.rounded)
}
