import ComposableArchitecture
import SwiftUI

struct SessionSummaryFeature: Reducer {
    struct State: Equatable {
        let topic: Topic
        let sessionChallenges: [Challenge]
        let quizMode: QuizMode
        let isSessionComplete: Bool

        init(topicID: UUID, sessionChallenges: [Challenge], quizMode: QuizMode, isSessionComplete: Bool) {
            @Dependency(\.topicClient.allTopics) var allTopics

            topic = allTopics()[id: topicID]!
            self.sessionChallenges = sessionChallenges

            self.quizMode = quizMode
            self.isSessionComplete = isSessionComplete
        }
    }

    enum Action: Equatable {
        case endSessionButtonTapped
    }

    @Dependency(\.hapticsClient) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .endSessionButtonTapped:
                return .run { send in
                    await haptics.success()
                }
            }
        }
    }
}

extension SessionSummaryFeature.State {
    var challengesTotalCount: Int { sessionChallenges.count }
    var challengesCorrectCount: Int { challengesCorrect.count }
    var challengesIncorrectSkippedCount: Int {
        sessionChallenges
            .filter { $0.submissions.contains(where: { $0.kind == .incorrect || $0.kind == .skip }) }
            .count
    }

    var challengesCorrect: [Challenge] {
        sessionChallenges.filter { $0.submissions.allSatisfy { $0.kind == .correct } }
    }
    var challengesSkipped: [Challenge] {
        sessionChallenges.filter { $0.submissions.contains(where: { $0.kind == .skip }) }
    }
    var challengesIncorrect: [Challenge] {
        sessionChallenges.filter { !$0.submissions.contains(where: { $0.kind == .skip }) && $0.submissions.contains(where: { $0.kind == .incorrect }) }
    }
    var quizModeTitle: String {
        switch quizMode {
        case .infinite:
            "Infinite"
        case let .questionAttack(limit):
            "\(limit) question limit"
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
                    HStack {
                        Text("Quiz Mode:")
                            .foregroundStyle(Color(.secondaryLabel))
                        Text(viewStore.quizModeTitle)
                    }
                    .font(.subheadline)
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
                        Text("\(viewStore.challengesTotalCount)")
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
                        Text("\(viewStore.challengesCorrectCount)")
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
                        Text("\(viewStore.challengesIncorrectSkippedCount)")
                            .font(.headline)
                    }
                    .listRowInsets(.init(top: 0, leading: 40, bottom: 0, trailing: 20))
                } header: {
                    Text("Results")
                        .font(.subheadline)
                }

                let skipped = viewStore.state.challengesSkipped
                if !skipped.isEmpty {
                    Section {
                        ForEach(skipped) { challenge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.question.acceptedAnswer)
                                if !challenge.submissions.filter({ $0.kind != .correct }).isEmpty {
                                    ViewThatFits {
                                        HStack {
                                            ForEach(challenge.submissions) { submission in
                                                if let value = submission.value {
                                                    Text(value)
                                                }
                                            }
                                        }
                                        .strikethrough()
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                        Text("\(challenge.submissions.count) attempts")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Skipped Questions")
                            .font(.subheadline)
                    }
                }

                let incorrect = viewStore.state.challengesIncorrect
                if !incorrect.isEmpty {
                    Section {
                        ForEach(incorrect) { challenge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.question.acceptedAnswer)
                                if !challenge.submissions.filter({ $0.kind != .correct }).isEmpty {
                                    ViewThatFits {
                                        HStack {
                                            ForEach(challenge.submissions) { submission in
                                                if let value = submission.value, submission.kind != .correct {
                                                    Text(value)
                                                }
                                            }
                                        }
                                        .strikethrough()
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                        Text("\(challenge.submissions.count) attempts")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Incorrect Questions")
                            .font(.subheadline)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewStore.send(.endSessionButtonTapped)
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
            .navigationBarBackButtonHidden(viewStore.isSessionComplete)
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
            store: Store(
                initialState: SessionSummaryFeature.State(
                    topicID: Topic.mockID,
                    sessionChallenges: [Topic.mockChallengeCorrect, Topic.mockChallengeSkipped, Topic.mockChallengeIncorrect],
                    quizMode: .infinite,
                    isSessionComplete: true
                )
            ) {
                SessionSummaryFeature()
                    ._printChanges()
            }
        )
    }
    .fontDesign(.rounded)
}
