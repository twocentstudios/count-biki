import ComposableArchitecture
import SwiftUI

struct SettingsFeature: Reducer {
    struct State: Equatable {
        let topic: Topic

        init(topicID: UUID) {
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
        }
    }

    enum Action: Equatable {
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
