import ComposableArchitecture
import SwiftUI

struct TopicCategory: Identifiable, Equatable {
    let id: String
    let topics: IdentifiedArrayOf<Topic>
    let title: String
    let description: String
}

extension TopicCategory {
    static func filtered(_ allTopics: IdentifiedArrayOf<Topic>, skill: Topic.Skill, category: Topic.Category) -> Self {
        let id = skill.title + ":" + category.title
        let filteredTopics = allTopics.filter { $0.skill == skill && $0.category == category }
        return .init(id: id, topics: filteredTopics, title: category.title, description: category.description)
    }
}

struct TopicsFeature: Reducer {
    struct State: Equatable {
        let listeningCategories: IdentifiedArrayOf<TopicCategory>

        init() {
            @Dependency(\.topicClient.allTopics) var allTopics
            listeningCategories = [
                .filtered(allTopics(), skill: .listening, category: .number),
                .filtered(allTopics(), skill: .listening, category: .money),
            ]
        }
    }

    enum Action: Equatable {
        case selectTopic(UUID)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.topicClient) var topicClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectTopic(topicID):
                print(topicID)
                return .none
            }
        }
    }
}

struct TopicsView: View {
    let store: StoreOf<TopicsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            List {
                Section {
                    Text("No favorites yet")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } header: {
                    Text("Favorites \(Image(systemName: "star"))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                Section {
                    ForEach(viewStore.listeningCategories) { category in
                        NavigationLink {
                            List {
                                Section {
                                    ForEach(category.topics) { topic in
                                        Button {
                                            viewStore.send(.selectTopic(topic.id))
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(topic.title).font(.headline)
                                                Text(topic.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 2)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Add Favorite") {}
                                        }
                                    }
                                } footer: {
                                    Text("Tip: tap and hold a topic to add/remove a favorite")
                                }
                            }
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle(category.title)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    Text(category.title)
                                        .font(.headline)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title).font(.headline)
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Listening \(Image(systemName: "ear"))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                } footer: {
                    Text("Listen to a clip and transcribe the number")
                }
            }
            .listStyle(.automatic)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Topics")
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TopicsView(
            store: Store(initialState: TopicsFeature.State()) {
                TopicsFeature()
                    ._printChanges()
            }
        )
    }
}
