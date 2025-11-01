import ComposableArchitecture
import Sharing
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

@Reducer struct TopicsFeature {
    @ObservableState struct State: Equatable {
        @Presents var destination: Destination.State?
        let listeningCategories: IdentifiedArrayOf<TopicCategory>
        @Shared var sessionSettings: SessionSettings
        @Shared var speechSynthesisSettings: SpeechSynthesisSettings

        init() {
            @Dependency(TopicClient.self) var topicClient
            let topics = topicClient.allTopics()
            listeningCategories = [
                .filtered(topics, skill: .listening, category: .number),
                .filtered(topics, skill: .listening, category: .money),
                .filtered(topics, skill: .listening, category: .duration),
                .filtered(topics, skill: .listening, category: .dateTime),
            ]
            _sessionSettings = Shared(
                wrappedValue: SessionSettings.default,
                .appStorage(SessionSettings.storageKey)
            )
            _speechSynthesisSettings = Shared(
                wrappedValue: SpeechSynthesisSettings(),
                .appStorage(SpeechSynthesisSettings.storageKey)
            )
        }
    }

    enum Action: Equatable, Sendable {
        case aboutButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case preSettingsButtonTapped
        case topicButtonTapped(UUID)
    }

    @Reducer enum Destination {
        case preSettings(PreSettingsFeature)
        case quiz(ListeningQuizNavigationFeature)
        case about(AboutFeature)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(TopicClient.self) var topicClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .aboutButtonTapped:
                state.destination = .about(.init())
                return .none

            case .destination:
                return .none

            case .preSettingsButtonTapped:
                state.destination = .preSettings(.init(
                    sessionSettings: state.$sessionSettings,
                    speechSynthesisSettings: state.$speechSynthesisSettings
                ))
                return .none

            case let .topicButtonTapped(topicID):
                state.destination = .quiz(.init(
                    topicID: topicID,
                    sessionSettings: state.$sessionSettings,
                    speechSynthesisSettings: state.$speechSynthesisSettings
                ))
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension TopicsFeature.Destination.State: Equatable {}
extension TopicsFeature.Destination.Action: Equatable {}

struct TopicsView: View {
    @Bindable var store: StoreOf<TopicsFeature>
    let isFavoritesEnabled: Bool = false

    var body: some View {
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
                    ForEach(store.listeningCategories) { category in
                        NavigationLink {
                            List {
                                Section {
                                    ForEach(category.topics) { topic in
                                        TopicCell(
                                            title: topic.title,
                                            subtitle: topic.description,
                                            isFavorite: false,
                                            tapped: { store.send(.topicButtonTapped(topic.id)) },
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
                                ToolbarItem(placement: .bottomBar) {
                                    SessionSettingsButton {
                                        store.send(.preSettingsButtonTapped)
                                    }
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
                        store.send(.aboutButtonTapped)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    SessionSettingsButton {
                        store.send(.preSettingsButtonTapped)
                    }
                }
            }
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.quiz, action: \.destination.quiz)) { store in
            ListeningQuizNavigationView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.about, action: \.destination.about)) { store in
            AboutView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.preSettings, action: \.destination.preSettings)) { store in
            PreSettingsView(store: store)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
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

struct SessionSettingsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                Text("Session Settings")
            }
            .font(.headline)
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
