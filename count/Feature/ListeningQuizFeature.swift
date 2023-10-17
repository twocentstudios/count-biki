import AVFoundation
import ComposableArchitecture
import ConfettiSwiftUI
import SwiftUI

struct BikiAnimation: Equatable {
    enum Kind {
        case correct
        case incorrect
    }

    let id: UUID
    let kind: Kind
}

struct ListeningQuizFeature: Reducer {
    struct State: Equatable {
        var bikiAnimation: BikiAnimation?
        var confettiAnimation: Int = 0
        @PresentationState var destination: Destination.State?
        var isShowingPlaybackError: Bool = false
        var isSpeaking: Bool = false
        @BindingState var pendingSubmissionValue: String = ""
        var speechSettings: SpeechSynthesisSettings
        let topic: Topic
        let topicID: UUID

        var completedChallenges: [Challenge] = []
        var challenge: Challenge

        var challengeCount: Int { completedChallenges.count }
        var lastSubmittedIncorrectValue: String? {
            challenge.submissions.last(where: { $0.kind == .incorrect })?.value
        }
        var isShowingAnswer: Bool {
            challenge.submissions.last?.kind == .skip
        }
        var question: Question {
            challenge.question
        }
        var totalIncorrect: Int {
            completedChallenges
                .filter { $0.submissions.contains(where: { $0.kind == .incorrect || $0.kind == .skip }) }
                .count
        }
        var totalCorrect: Int {
            completedChallenges
                .filter { $0.submissions.allSatisfy { $0.kind == .correct } }
                .count
        }

        init(topicID: UUID) {
            @Dependency(\.topicClient.allTopics) var allTopics
            topic = allTopics()[id: topicID]!
            self.topicID = topicID

            @Dependency(\.topicClient.generateQuestion) var generateQuestion
            @Dependency(\.uuid) var uuid
            @Dependency(\.date.now) var now
            let question = try! generateQuestion(topicID) // TODO: handle error
            let challenge = Challenge(id: uuid(), startDate: now, question: question, submissions: [])
            self.challenge = challenge

            @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
            let speechSettings = speechSettingsClient.get()
            self.speechSettings = speechSettings
        }
    }

    enum Action: BindableAction, Equatable {
        case answerSubmitButtonTapped
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case endSessionButtonTapped
        case onPlaybackError
        case onPlaybackErrorTimeout
        case onPlaybackFinished
        case onTask
        case playbackButtonTapped
        case showAnswerButtonTapped
        case titleButtonTapped
    }

    struct Destination: Reducer {
        enum State: Equatable {
            case settings(SettingsFeature.State)
        }

        enum Action: Equatable {
            case settings(SettingsFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.settings, action: /Action.settings) {
                SettingsFeature()
            }
        }
    }

    private enum CancelID {
        case speakAction
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.hapticsClient) var haptics
    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient
    @Dependency(\.topicClient) var topicClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .answerSubmitButtonTapped:
                if state.isShowingAnswer {
                    state.pendingSubmissionValue = ""
                    state.completedChallenges.append(state.challenge)
                    generateChallenge(state: &state)
                    return .run { _ in await haptics.error() }
                        .merge(with: playBackEffect(state: &state))
                } else if state.question.acceptedAnswer == state.pendingSubmissionValue {
                    let submission = Submission(id: uuid(), date: now, kind: .correct, value: state.pendingSubmissionValue)
                    state.challenge.submissions.append(submission)
                    state.completedChallenges.append(state.challenge)
                    state.pendingSubmissionValue = ""
                    state.bikiAnimation = .init(id: uuid(), kind: .correct)
                    state.confettiAnimation += 1
                    generateChallenge(state: &state)
                    return .run { _ in await haptics.success() }
                        .merge(with: playBackEffect(state: &state))
                } else {
                    let submission = Submission(id: uuid(), date: now, kind: .incorrect, value: state.pendingSubmissionValue)
                    state.challenge.submissions.append(submission)
                    state.bikiAnimation = .init(id: uuid(), kind: .incorrect)
                    return .run { _ in await haptics.error() }
                        .merge(with: playBackEffect(state: &state))
                }

            case .binding:
                return .none

            case let .destination(.presented(.settings(.delegate(.speechSettingsUpdated(newSpeechSettings))))):
                state.speechSettings = newSpeechSettings
                do {
                    try speechSettingsClient.set(newSpeechSettings)
                } catch {
                    XCTFail("SpeechSettingsClient unexpectedly failed to write")
                }
                return .none

            case .destination:
                return .none

            case .endSessionButtonTapped:
                return .run { _ in
                    await dismiss()
                }

            case .onPlaybackFinished:
                guard state.isSpeaking else { return .none }
                state.isSpeaking = false
                return .none

            case .onPlaybackError:
                state.isSpeaking = false
                guard !state.isShowingPlaybackError else { return .none }
                state.isShowingPlaybackError = true
                return .run { send in
                    try? await clock.sleep(for: .seconds(2))
                    await send(.onPlaybackErrorTimeout)
                }

            case .onPlaybackErrorTimeout:
                guard state.isShowingPlaybackError else { return .none }
                state.isShowingPlaybackError = false
                return .none

            case .onTask:
                return playBackEffect(state: &state)

            case .playbackButtonTapped:
                if state.isSpeaking {
                    state.isSpeaking = false
                    return .cancel(id: CancelID.speakAction)
                } else {
                    return playBackEffect(state: &state)
                }

            case .showAnswerButtonTapped:
                let submission = Submission(id: uuid(), date: now, kind: .skip, value: nil)
                state.challenge.submissions.append(submission)
                return .none

            case .titleButtonTapped:
                state.destination = .settings(.init(
                    topicID: state.topicID,
                    speechSettings: state.speechSettings,
                    sessionChallenges: state.completedChallenges
                ))
                return .none
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }

    func generateChallenge(state: inout State) {
        let question = try! topicClient.generateQuestion(state.topicID) // TODO: handle error
        let challenge = Challenge(id: uuid(), startDate: now, question: question, submissions: [])
        state.challenge = challenge
    }

    private func playBackEffect(state: inout State) -> Effect<Self.Action> {
        state.isSpeaking = true
        return .run { [settings = state.speechSettings, spokenText = state.question.spokenText] send in
            await withTaskCancellation(id: CancelID.speakAction, cancelInFlight: true) {
                do {
                    let utterance = SpeechSynthesisUtterance(speechString: spokenText, settings: settings)
                    try await speechClient.speak(utterance)
                    await send(.onPlaybackFinished)
                } catch {
                    await send(.onPlaybackError)
                }
            }
        }
    }
}

extension ListeningQuizFeature.State {
    var isShowingIncorrect: Bool {
        lastSubmittedIncorrectValue == pendingSubmissionValue
    }

    var isSubmitButtonDisabled: Bool {
        if isShowingAnswer {
            return false
        } else {
            return pendingSubmissionValue.isEmpty
        }
    }

    var answerText: String {
        if isShowingAnswer {
            return question.displayText
        } else {
            return "00000"
        }
    }

    enum AnswerButton: String {
        case checkmark = "checkmark.circle"
        case arrow = "arrow.right.circle"
    }
    var answerButtonKind: AnswerButton {
        if isShowingAnswer {
            return .arrow
        } else {
            return .checkmark
        }
    }

    var formattedPendingSubmissionValue: String? {
        guard topic.shouldShowFormattedPendingSubmission else {
            return nil
        }
        guard let formatted = Int(pendingSubmissionValue)?.formatted(.number.grouping(.automatic)) else {
            return nil
        }
        if formatted.count < 4 {
            return nil
        }
        return formatted
    }
}

#Preview {
    ListeningQuizView(
        store: Store(initialState: ListeningQuizFeature.State(topicID: Topic.mockID)) {
            ListeningQuizFeature()
                ._printChanges()
        } withDependencies: {
            $0.topicClient.generateQuestion = { _ in .init(topicID: Topic.mockID, displayText: "1", spokenText: "1", answerPrefix: nil, answerPostfix: nil, acceptedAnswer: "1") }
        }
    )
}

struct ListeningQuizView: View {
    let store: StoreOf<ListeningQuizFeature>
    @FocusState private var answerFieldFocused: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                header(viewStore: viewStore)

                Spacer()

                answer(viewStore: viewStore)

                Spacer()

                playButton(viewStore: viewStore)

                Spacer()

                progressBar(viewStore: viewStore)
            }
            .padding(.top, 16)
            .padding(.bottom, 6)
            .padding(.horizontal, 16)
            .safeAreaInset(edge: .bottom) {
                submissionTextField(viewStore: viewStore)
            }
            .task {
                await viewStore.send(.onTask).finish()
            }
            .onAppear {
                answerFieldFocused = true
            }
            .sheet(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /ListeningQuizFeature.Destination.State.settings,
                action: ListeningQuizFeature.Destination.Action.settings
            ) { store in
                SettingsView(store: store)
            }
        }
    }

    @ViewBuilder func header(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(viewStore.topic.category.title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(viewStore.topic.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(viewStore.topic.category.title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(viewStore.topic.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    Button {
                        viewStore.send(.endSessionButtonTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "door.right.hand.open")
                            ViewThatFits(in: .horizontal) {
                                Text("End Session")
                                Text("End")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                                .stroke(Color(.secondarySystemBackground))
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        viewStore.send(.titleButtonTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            ViewThatFits(in: .horizontal) {
                                Text("Settings")
                                Text("")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                        .background {
                            RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                                .stroke(Color(.secondarySystemBackground))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CountBikiView(bikiAnimation: viewStore.bikiAnimation)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 90)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder func answer(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        Text(viewStore.answerText)
            .font(.system(size: 80, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(viewStore.isShowingAnswer ? Color.primary : Color.secondary)
            .blur(radius: viewStore.isShowingAnswer ? 0 : 18)
            .overlay {
                if !viewStore.isShowingAnswer {
                    Button {
                        viewStore.send(.showAnswerButtonTapped)
                    } label: {
                        Text("Show Answer")
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.easeOut(duration: viewStore.isShowingAnswer ? 0.15 : 0.0), value: viewStore.isShowingAnswer)
    }

    @ViewBuilder func playButton(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        Button {
            viewStore.send(.playbackButtonTapped)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "speaker.wave.3.fill") // same height for different symbols
                    .font(.title)
                    .hidden()
                    .overlay {
                        Image(systemName: viewStore.isSpeaking ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.title)
                    }
                Text(viewStore.isSpeaking ? "Stop" : "Play Question")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding()
            .frame(maxWidth: 260)
            .background {
                RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
            }
            .animation(.bouncy, value: viewStore.isSpeaking)
        }
        .buttonStyle(.plain)
        .background(alignment: .bottom) {
            ZStack {
                if viewStore.isShowingPlaybackError {
                    Text("There was an error playing your question")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(.red))
                        .offset(x: 0, y: 40)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.bouncy, value: viewStore.isShowingPlaybackError)
        }
    }

    @ViewBuilder func progressBar(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        HStack(spacing: 0) {
            IndeterminateProgressView(
                animationCount: viewStore.challengeCount,
                color1: Color(.tintColor),
                color2: Color(.systemBackground),
                barCount: 20,
                rotation: .degrees(50),
                animation: .snappy()
            )
            .clipShape(Capsule(style: .continuous))
            .frame(height: 10)
            .padding(.trailing, 6)
            Image(systemName: "infinity")
                .font(.caption)
                .bold()
                .foregroundColor(Color(.label))
                .padding(.trailing, 10)

            HStack(spacing: 0) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.green)
                Spacer().frame(width: 2)
                Text(String(viewStore.totalCorrect))
                    .contentTransition(.numericText())
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.green)
                    .animation(.default, value: viewStore.totalCorrect)
                Spacer().frame(width: 8)
                Image(systemName: "xmark.circle")
                    .foregroundColor(Color.red)
                Spacer().frame(width: 2)
                Text(String(viewStore.totalIncorrect))
                    .contentTransition(.numericText())
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.red)
                    .animation(.default, value: viewStore.totalIncorrect)
            }
            .bold()
            .font(.caption)
            .saturation(0.9)
        }
    }

    @MainActor @ViewBuilder func submissionTextField(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        HStack(spacing: 0) {
            if let prefix = viewStore.question.answerPrefix {
                Text(prefix)
                    .font(.title)
                    .foregroundStyle(Color.secondary)
            }

            TextField("Answer", text: viewStore.$pendingSubmissionValue)
                .foregroundStyle(Color.primary)
                .font(.largeTitle)
                .bold()
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .padding(.horizontal, 4)
                .focused($answerFieldFocused)

            if let postfix = viewStore.question.answerPostfix {
                Text(postfix)
                    .font(.title)
                    .foregroundStyle(Color.secondary)
            }

            Spacer().frame(width: 16)

            Button {
                viewStore.send(.answerSubmitButtonTapped)
            } label: {
                Image(systemName: viewStore.answerButtonKind.rawValue)
                    .font(.title)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewStore.isSubmitButtonDisabled)
        }
        .padding()
        .overlay(alignment: .top) {
            Text(viewStore.formattedPendingSubmissionValue ?? "")
                .font(.caption)
        }
        .padding(.top, 4)
        .background {
            Color(.secondarySystemBackground)
                .ignoresSafeArea(.all, edges: .bottom)
                .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
        }
        .background(alignment: .top) {
            ZStack {
                if viewStore.isShowingIncorrect {
                    Color(hue: 0.0, saturation: 0.88, brightness: 0.96).frame(height: 10)
                        .offset(y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.1), value: viewStore.isShowingIncorrect)
            .confettiCannon(counter: .constant(viewStore.confettiAnimation), num: 25, confettiSize: 7, rainHeight: 300, fadesOut: true, opacity: 1.0, openingAngle: .degrees(50), closingAngle: .degrees(130), radius: 120, repetitions: 0, repetitionInterval: 1.0)
        }
    }
}
