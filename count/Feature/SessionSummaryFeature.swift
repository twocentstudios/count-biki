import ComposableArchitecture
import SwiftUI

struct SessionSummaryFeature: Reducer {
    struct State: Equatable {
        let topic: Topic
        let sessionChallenges: [Challenge]

        init(topicID: UUID, sessionChallenges: [Challenge]) {
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
            self.sessionChallenges = sessionChallenges
        }

        var challengesTotal: Int { sessionChallenges.count }
        var challengesCorrect: Int {
            sessionChallenges
                .filter { $0.submissions.allSatisfy { $0.kind == .correct } }
                .count
        }
        var challengesIncorrect: Int {
            sessionChallenges
                .filter { $0.submissions.contains(where: { $0.kind == .incorrect || $0.kind == .skip }) }
                .count
        }
    }

    enum Action: Equatable {
        case delegate(Delegate)

        enum Delegate: Equatable {
            case endSession
        }
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.hapticsClient) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .run { send in
                    await haptics.success()
                }
            }
        }
    }
}

struct SessionSummaryView: View {
    let store: StoreOf<SessionSummaryFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            List {
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
                    HStack {
                        Image(systemName: "tray.full")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17)
                        Text("Total Answers")
                        Spacer()
                        Text("\(viewStore.challengesTotal)")
                            .font(.headline)
                    }
                    .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17)
                            .foregroundStyle(Color.green)
                        Text("Correct")
                        Spacer()
                        Text("\(viewStore.challengesCorrect)")
                            .font(.headline)
                    }
                    .listRowInsets(.init(top: 0, leading: 40, bottom: 0, trailing: 20))
                    HStack {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17)
                            .foregroundStyle(Color.red)
                        Text("Incorrect & skipped")
                        Spacer()
                        Text("\(viewStore.challengesIncorrect)")
                            .font(.headline)
                    }
                    .listRowInsets(.init(top: 0, leading: 40, bottom: 0, trailing: 20))
                } header: {
                    Text("Results")
                        .font(.subheadline)
                }

                // TODO: more detailed results
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewStore.send(.delegate(.endSession))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "door.right.hand.open")
                        Text("Back to Topics")
                    }
                    .font(.headline)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 16.0)
                            .fill(Color(.tertiarySystemBackground).shadow(.drop(color: Color.black.opacity(0.05), radius: 6)))
                    }
                    .padding(.horizontal, 20)
                }
                // TODO: Button: retry session with same settings (if timed session was completed)
            }
            .navigationBarBackButtonHidden(false) // TODO: hide back button on certain conditions (timer out, questions out)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Session Summary")
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionSummaryView(
            store: Store(initialState: SessionSummaryFeature.State(topicID: Topic.mockID, sessionChallenges: [Topic.mockChallengeCorrect, Topic.mockChallengeSkipped, Topic.mockChallengeIncorrect])) {
                SessionSummaryFeature()
                    ._printChanges()
            }
        )
    }
    .fontDesign(.rounded)
}
