import _NotificationDependency
import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        var speechSettings: SpeechSettingsFeature.State

        let topic: Topic

        init(topicID: UUID, speechSettings: SpeechSettingsFeature.State = .init()) {
            @Dependency(\.speechSynthesisClient) var speechClient
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
            self.speechSettings = speechSettings
        }
    }

    enum Action: Equatable {
        case doneButtonTapped
        case onTask
        case speechSettings(SpeechSettingsFeature.Action)
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Scope(state: \.speechSettings, action: /Action.speechSettings) {
            SpeechSettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .doneButtonTapped:
                return .run { send in
                    await dismiss()
                }
            case .onTask:
                return .send(.speechSettings(.onTask))
            case .speechSettings:
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
                    } header: {
                        Text("Topic")
                            .font(.subheadline)
                    }

                    SpeechSettingsSection(
                        store: store.scope(state: \.speechSettings, action: { .speechSettings($0) })
                    )
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
        store: Store(initialState: SettingsFeature.State(topicID: Topic.mockID)) {
            SettingsFeature()
                ._printChanges()
        } withDependencies: { deps in
            // deps.speechSynthesisClient = .noVoices
        }
    )
    .fontDesign(.rounded)
}
