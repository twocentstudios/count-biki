import ComposableArchitecture
import SwiftUI

struct TopicCategory: Identifiable, Equatable {
    let id: String
    let topics: IdentifiedArrayOf<Topic>
    let title: String
    let description: String
    let symbolName: String
}

extension TopicCategory {
    static func filtered(_ allTopics: IdentifiedArrayOf<Topic>, skill: Topic.Skill, category: Topic.Category) -> Self {
        let id = skill.title + ":" + category.title
        let filteredTopics = allTopics.filter { $0.skill == skill && $0.category == category }
        return .init(id: id, topics: filteredTopics, title: category.title, description: category.description, symbolName: category.symbolName)
    }
}

struct TopicsFeature: Reducer {
    struct State: Equatable {
        @PresentationState var destination: Destination.State?
        let listeningCategories: IdentifiedArrayOf<TopicCategory>

        init() {
            @Dependency(\.topicClient.allTopics) var allTopics
            listeningCategories = [
                .filtered(allTopics(), skill: .listening, category: .number),
                .filtered(allTopics(), skill: .listening, category: .money),
                .filtered(allTopics(), skill: .listening, category: .duration),
                .filtered(allTopics(), skill: .listening, category: .dateTime),
            ]
            destination = .preSettings(.init())
        }
    }

    enum Action: Equatable, Sendable {
        case aboutButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case topicButtonTapped(UUID)
        case setDestination(Destination.State)
    }

    struct Destination: Reducer {
        enum State: Equatable, Sendable {
            case preSettings(PreSettingsFeature.State)
            case quiz(ListeningQuizNavigationFeature.State)
            case about(AboutFeature.State)
        }

        enum Action: Equatable, Sendable {
            case preSettings(PreSettingsFeature.Action)
            case quiz(ListeningQuizNavigationFeature.Action)
            case about(AboutFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.preSettings, action: /Action.preSettings) {
                PreSettingsFeature()
            }
            Scope(state: /State.quiz, action: /Action.quiz) {
                ListeningQuizNavigationFeature()
            }
            Scope(state: /State.about, action: /Action.about) {
                AboutFeature()
            }
        }
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.topicClient) var topicClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .aboutButtonTapped:
                state.destination = nil
                return .run { send in
                    await send(.setDestination(.about(.init())))
                }

            case .destination(.dismiss):
                // Re-present the preSettings half-modal when any other destination is dismissed
                return .run { send in
                    await send(.setDestination(.preSettings(.init())))
                }

            case .destination:
                return .none

            case let .setDestination(destination):
                state.destination = destination
                return .none

            case let .topicButtonTapped(topicID):
                state.destination = nil
                return .run { send in
                    await send(.setDestination(.quiz(.init(topicID: topicID))))
                }
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}

struct TopicsView: View {
    let store: StoreOf<TopicsFeature>
    let isFavoritesEnabled: Bool = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                List {
                    if isFavoritesEnabled {
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
                                                tapped: { viewStore.send(.topicButtonTapped(topic.id)) },
                                                toggleFavoriteTapped: nil // TODO: favorite support
                                            )
                                        }
                                    } footer: {
                                        if isFavoritesEnabled {
                                            Text("Tip: tap and hold a topic to add/remove a favorite")
                                        }
                                    }
                                }
                                .safeAreaInset(edge: .bottom) {
                                    // extra bottom padding for session settings sheet
                                    Spacer().frame(height: 100)
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
                                HStack(alignment: .center, spacing: 14) {
                                    Image(systemName: category.symbolName)
                                        .font(.body)
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color(.label))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category.title).font(.headline)
                                        Text(category.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
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
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.aboutButtonTapped)
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
            .fullScreenCover(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /TopicsFeature.Destination.State.quiz,
                action: TopicsFeature.Destination.Action.quiz
            ) { store in
                ListeningQuizNavigationView(store: store)
            }
            .sheet(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /TopicsFeature.Destination.State.about,
                action: TopicsFeature.Destination.Action.about
            ) { store in
                AboutView(store: store)
            }
            .sheet(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /TopicsFeature.Destination.State.preSettings,
                action: TopicsFeature.Destination.Action.preSettings
            ) { store in
                PreSettingsView(store: store)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.fraction(0.1), .medium, .large])
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(true)
            }
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
            if let toggleFavoriteTapped {
                Button {
                    toggleFavoriteTapped()
                }
                label: {
                    Label(isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: "star")
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
