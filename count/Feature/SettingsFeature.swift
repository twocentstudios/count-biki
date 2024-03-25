import ComposableArchitecture
import SwiftUI

@Reducer struct SettingsFeature {
    struct State: Equatable {
        @BindingState var sessionSettings: SessionSettings
        let topic: Topic

        init(topicID: UUID) {
            @Dependency(\.topicClient.allTopics) var allTopics
            @Dependency(\.sessionSettingsClient) var sessionSettingsClient

            topic = allTopics()[id: topicID]!
            sessionSettings = sessionSettingsClient.get()
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
    @Dependency(\.sessionSettingsClient.set) var setSessionSettings

    var body: some ReducerOf<Self> {
        CombineReducers {
            BindingReducer()
            Reduce { state, action in
                switch action {
                case .binding:
                    return .none
                case .doneButtonTapped:
                    return .run { send in
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
                        do {
                            try await setSessionSettings(newValue)
                        } catch {
                            XCTFail("SpeechSettingsClient unexpectedly failed to write: \(error)")
                        }
                    }
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
                        Toggle(isOn: viewStore.$sessionSettings.isShowingProgress, label: {
                            Text("Show progress")
                        })
                        Toggle(isOn: viewStore.$sessionSettings.isShowingBiki, label: {
                            Text("Show Biki")
                        })
                        Toggle(isOn: viewStore.$sessionSettings.isShowingConfetti, label: {
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
        } withDependencies: { deps in
            // deps.speechSynthesisClient = .noVoices
        }
    )
    .fontDesign(.rounded)
}
