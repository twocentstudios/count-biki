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
        @PresentationState var quiz: ListeningQuizFeature.State?
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
        case quiz(PresentationAction<ListeningQuizFeature.Action>)
        case selectTopic(UUID)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.topicClient) var topicClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .quiz:
                return .none

            case let .selectTopic(topicID):
                state.quiz = .init(topicID: topicID)
                return .none
            }
        }
        .ifLet(\.$quiz, action: /Action.quiz) {
            ListeningQuizFeature()
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
                                        TopicCell(
                                            title: topic.title,
                                            subtitle: topic.description,
                                            isFavorite: false,
                                            tapped: { viewStore.send(.selectTopic(topic.id)) },
                                            toggleFavoriteTapped: {}
                                        )
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
        .fullScreenCover(
            store: store.scope(state: \.$quiz, action: { .quiz($0) })
        ) { store in
            ListeningQuizView(store: store)
        }
    }
}

struct TopicCell: View {
    let title: String
    let subtitle: String
    var isFavorite: Bool = false
    var tapped: (() -> Void)?
    var toggleFavoriteTapped: (() -> Void)?

    var body: some View {
        Button {
            tapped?()
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleFavoriteTapped?()
            }
            label: {
                Label(isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: "star")
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
