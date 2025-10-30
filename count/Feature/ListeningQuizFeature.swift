import AVFoundation
import Combine
import ComposableArchitecture
import ConfettiSwiftUI
import Sharing
import SwiftUI
import UIKit

struct BikiAnimation: Equatable {
    enum Kind {
        case correct
        case incorrect
    }

    let id: UUID
    let kind: Kind
}

enum QuizMode: Equatable {
    case infinite
    case questionLimit(Int) // > 0
    case timeLimit(Int) // > 0
}

extension QuizMode {
    var shouldStartTimer: Bool {
        switch self {
        case .infinite: false
        case .questionLimit: false
        case .timeLimit: true
        }
    }

    init(_ sessionSettings: SessionSettings) {
        switch sessionSettings.quizMode {
        case .infinite:
            self = .infinite
        case .questionLimit:
            self = .questionLimit(sessionSettings.questionLimit)
        case .timeLimit:
            self = .timeLimit(sessionSettings.timeLimit)
        }
    }
}

@Reducer struct ListeningQuizFeature {
    @ObservableState struct State: Equatable {
        var bikiAnimation: BikiAnimation?
        var confettiAnimation: Int = 0
        var isViewFrontmost: Bool = true
        var isShowingPlaybackError: Bool = false
        var isSpeaking: Bool = false
        var pendingSubmissionValue: String = ""
        let quizMode: QuizMode
        var secondsElapsed: Int = 0
        var speechSettings: SpeechSynthesisSettings
        var sessionSettings: SessionSettings
        let topic: Topic
        let topicID: UUID

        var completedChallenges: [Challenge] = []
        var challenge: Challenge

        init(topicID: UUID, quizMode: QuizMode) {
            @Dependency(\.topicClient.allTopics) var allTopics
            topic = allTopics()[id: topicID]!
            self.topicID = topicID
            self.quizMode = quizMode

            @Dependency(\.topicClient.generateQuestion) var generateQuestion
            @Dependency(\.uuid) var uuid
            @Dependency(\.date.now) var now
            let question = try! generateQuestion(topicID) // TODO: handle error
            let challenge = Challenge(id: uuid(), startDate: now, question: question, submissions: [])
            self.challenge = challenge
            let speechSettingsShared = Shared(
                wrappedValue: SpeechSynthesisSettings(),
                .appStorage(SpeechSynthesisSettings.storageKey)
            )
            speechSettings = speechSettingsShared.wrappedValue
            let sessionSettingsShared = Shared(
                wrappedValue: SessionSettings.default,
                .appStorage(SessionSettings.storageKey)
            )
            sessionSettings = sessionSettingsShared.wrappedValue
        }

        var isSessionComplete: Bool {
            switch quizMode {
            case let .questionLimit(limit) where completedChallenges.count >= limit:
                true
            case let .timeLimit(limit) where secondsElapsed >= limit:
                true
            default:
                false
            }
        }
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

        var determiniteProgressPercentage: Double {
            switch quizMode {
            case .infinite:
                1.0
            case let .questionLimit(limit):
                (Double(limit - completedChallenges.count) / Double(limit)).clampedPercentage()
            case let .timeLimit(limit):
                (Double(limit - secondsElapsed) / Double(limit)).clampedPercentage()
            }
        }
        var determiniteIconName: String {
            switch quizMode {
            case .infinite: ""
            case .questionLimit: "tray.fill"
            case .timeLimit: "stopwatch"
            }
        }
        var determiniteRemainingTitle: String {
            switch quizMode {
            case .infinite:
                ""
            case let .questionLimit(limit):
                "\(limit - completedChallenges.count)"
            case let .timeLimit(limit):
                Duration.seconds((limit - secondsElapsed).clamped(to: 0 ... limit)).formatted(.time(pattern: .minuteSecond))
            }
        }
        var isShowingIncorrect: Bool {
            lastSubmittedIncorrectValue == pendingSubmissionValue
        }
        var isSubmitButtonDisabled: Bool {
            if isShowingAnswer {
                false
            } else {
                pendingSubmissionValue.isEmpty
            }
        }
        var answerText: String {
            if isShowingAnswer {
                question.displayText
            } else {
                "00000"
            }
        }
        enum AnswerButton: String {
            case checkmark = "checkmark.circle"
            case arrow = "arrow.right.circle"
        }
        var answerButtonKind: AnswerButton {
            if isShowingAnswer {
                .arrow
            } else {
                .checkmark
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

    enum Action: BindableAction, Equatable {
        case answerSubmitButtonTapped
        case binding(BindingAction<State>)
        case endSessionButtonTapped
        case onSessionSettingsUpdated(SessionSettings)
        case onSpeechSettingsUpdated(SpeechSynthesisSettings)
        case onPlaybackError
        case onPlaybackErrorTimeout
        case onPlaybackFinished
        case onTask
        case onTimerTick
        case playbackButtonTapped
        case showAnswerButtonTapped
        case settingsButtonTapped
    }

    private enum CancelID {
        case speakAction
        case timer
        case speechSettingsStream
        case sessionSettingsStream
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.hapticsClient) var haptics
    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.topicClient) var topicClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now
    @Dependency(\.application) var application
    @Shared(.appStorage(SpeechSynthesisSettings.storageKey)) var sharedSpeechSettings = SpeechSynthesisSettings()
    @Shared(.appStorage(SessionSettings.storageKey)) var sharedSessionSettings = SessionSettings.default

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .answerSubmitButtonTapped:
                if state.isShowingAnswer {
                    state.pendingSubmissionValue = ""
                    state.completedChallenges.append(state.challenge)
                    if state.isSessionComplete {
                        return .run { _ in await haptics.error() }
                    } else {
                        generateChallenge(state: &state)
                        return .run { _ in await haptics.error() }
                            .merge(with: playBackEffect(state: &state))
                    }
                } else if state.question.acceptedAnswer == state.pendingSubmissionValue {
                    let submission = Submission(id: uuid(), date: now, kind: .correct, value: state.pendingSubmissionValue)
                    state.challenge.submissions.append(submission)
                    state.completedChallenges.append(state.challenge)
                    state.pendingSubmissionValue = ""
                    state.bikiAnimation = .init(id: uuid(), kind: .correct)
                    if state.sessionSettings.isShowingConfetti {
                        state.confettiAnimation += 1
                    }
                    if state.isSessionComplete {
                        return .run { _ in await haptics.success() }
                    } else {
                        generateChallenge(state: &state)
                        return .run { _ in await haptics.success() }
                            .merge(with: playBackEffect(state: &state))
                    }
                } else {
                    let submission = Submission(id: uuid(), date: now, kind: .incorrect, value: state.pendingSubmissionValue)
                    state.challenge.submissions.append(submission)
                    state.bikiAnimation = .init(id: uuid(), kind: .incorrect)
                    return .run { _ in await haptics.error() }
                        .merge(with: playBackEffect(state: &state))
                }

            case .binding:
                return .none

            case .endSessionButtonTapped:
                return .none

            case let .onSessionSettingsUpdated(newValue):
                state.sessionSettings = newValue
                return .none

            case let .onSpeechSettingsUpdated(newValue):
                state.speechSettings = newValue
                return .none

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
                let shouldStartTimer = state.quizMode.shouldStartTimer
                return playBackEffect(state: &state)
                    .merge(with:
                        .run { send in
                            if shouldStartTimer {
                                for await _ in clock.timer(interval: .seconds(1)) {
                                    await send(.onTimerTick)
                                }
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    .merge(with:
                        .run { [sharedSpeechSettings = $sharedSpeechSettings] send in
                            var isFirst = true
                            for await newValue in sharedSpeechSettings.publisher.values {
                                if isFirst {
                                    isFirst = false
                                    continue
                                }
                                await send(.onSpeechSettingsUpdated(newValue))
                            }
                        }
                        .cancellable(id: CancelID.speechSettingsStream, cancelInFlight: true)
                    )
                    .merge(with:
                        .run { [sharedSessionSettings = $sharedSessionSettings] send in
                            var isFirst = true
                            for await newValue in sharedSessionSettings.publisher.values {
                                if isFirst {
                                    isFirst = false
                                    continue
                                }
                                await send(.onSessionSettingsUpdated(newValue))
                            }
                        }
                        .cancellable(id: CancelID.sessionSettingsStream, cancelInFlight: true)
                    )

            case .onTimerTick:
                if state.isViewFrontmost, application.applicationState() == .active {
                    state.secondsElapsed += 1
                }
                return .none

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

            case .settingsButtonTapped:
                return .none
            }
        }
    }

    private func generateChallenge(state: inout State) {
        let question = try! topicClient.generateQuestion(state.topicID) // TODO: handle error
        let challenge = Challenge(id: uuid(), startDate: now, question: question, submissions: [])
        state.challenge = challenge
    }

    private func playBackEffect(state: inout State) -> Effect<Action> {
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

#Preview("Infinite") {
    ListeningQuizView(
        store: Store(initialState: ListeningQuizFeature.State(topicID: Topic.mockID, quizMode: .infinite)) {
            ListeningQuizFeature()
                ._printChanges()
        })
}
#Preview("Time Limit") {
    ListeningQuizView(
        store: Store(initialState: ListeningQuizFeature.State(topicID: Topic.mockID, quizMode: .timeLimit(60))) {
            ListeningQuizFeature()
                ._printChanges()
        })
}

struct ListeningQuizView: View {
    @Bindable var store: StoreOf<ListeningQuizFeature>
    @FocusState private var answerFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header(store: store)

            Spacer()

            answer(store: store)

            Spacer().frame(maxHeight: 16).layoutPriority(-1)

            playButton(store: store)

            Spacer()

            if store.sessionSettings.isShowingProgress {
                progressBar(store: store)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
        .padding(.horizontal, 16)
        .safeAreaInset(edge: .bottom) {
            submissionTextField
        }
        .navigationTitle("Quiz")
        .toolbar(.hidden, for: .navigationBar)
        .dynamicTypeSize(.xSmall ... .accessibility2) // TODO: fix layout for accessibility sizes
        .task {
            await store.send(.onTask).finish()
        }
        .onAppear {
            answerFieldFocused = true
        }
    }

    @ViewBuilder func header(store: StoreOf<ListeningQuizFeature>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.topic.category.title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(store.topic.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(store.topic.category.title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(store.topic.title)
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
                        store.send(.endSessionButtonTapped)
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
                        store.send(.settingsButtonTapped)
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

            if store.sessionSettings.isShowingBiki {
                CountBikiView(bikiAnimation: store.bikiAnimation)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 90)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder func answer(store: StoreOf<ListeningQuizFeature>) -> some View {
        Text(store.answerText)
            .font(.system(size: 80, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(store.isShowingAnswer ? Color.primary : Color.secondary)
            .blur(radius: store.isShowingAnswer ? 0 : 18)
            .overlay {
                if !store.isShowingAnswer {
                    Button {
                        store.send(.showAnswerButtonTapped)
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
            .animation(.easeOut(duration: store.isShowingAnswer ? 0.15 : 0.0), value: store.isShowingAnswer)
    }

    @ViewBuilder func playButton(store: StoreOf<ListeningQuizFeature>) -> some View {
        Button {
            store.send(.playbackButtonTapped)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "speaker.wave.3.fill") // same height for different symbols
                    .font(.title)
                    .hidden()
                    .overlay {
                        Image(systemName: store.isSpeaking ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.title)
                    }
                Text(store.isSpeaking ? "Stop" : "Play Question")
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
            .animation(.bouncy, value: store.isSpeaking)
        }
        .buttonStyle(.plain)
        .background(alignment: .bottom) {
            ZStack {
                if store.isShowingPlaybackError {
                    Text("There was an error playing your question")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(.red))
                        .offset(x: 0, y: 40)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.bouncy, value: store.isShowingPlaybackError)
        }
    }

    @ViewBuilder func progressBar(store: StoreOf<ListeningQuizFeature>) -> some View {
        HStack(spacing: 0) {
            switch store.quizMode {
            case .infinite:
                IndeterminateProgressView(
                    animationCount: store.challengeCount,
                    color1: Color(.systemFill),
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
                    .foregroundColor(Color(.secondaryLabel))
                    .padding(.trailing, 10)
            case .questionLimit, .timeLimit:
                DeterminateProgressView(
                    percentage: store.determiniteProgressPercentage,
                    backgroundColor: Color(.systemBackground),
                    foregroundColor: Color(.systemFill),
                    animation: .snappy
                )
                .frame(height: 10)
                .padding(.trailing, 6)
                HStack(spacing: 3) {
                    Image(systemName: store.determiniteIconName)
                    Text(store.determiniteRemainingTitle)
                        .contentTransition(.numericText())
                        .bold()
                        .fontDesign(.monospaced)
                        .animation(.default, value: store.determiniteRemainingTitle)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.trailing, 10)
            }

            HStack(spacing: 0) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(Color.green)
                Spacer().frame(width: 2)
                Text(String(store.totalCorrect))
                    .contentTransition(.numericText())
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.green)
                    .animation(.default, value: store.totalCorrect)
                Spacer().frame(width: 8)
                Image(systemName: "xmark.circle")
                    .foregroundColor(Color.red)
                Spacer().frame(width: 2)
                Text(String(store.totalIncorrect))
                    .contentTransition(.numericText())
                    .fontDesign(.monospaced)
                    .foregroundColor(Color.red)
                    .animation(.default, value: store.totalIncorrect)
            }
            .bold()
            .font(.caption)
            .saturation(0.9)
        }
    }

    @MainActor @ViewBuilder var submissionTextField: some View {
        HStack(spacing: 0) {
            if let prefix = store.question.answerPrefix {
                Text(prefix)
                    .font(.title)
                    .foregroundStyle(Color.secondary)
            }

            TextField("Answer", text: $store.pendingSubmissionValue)
                .foregroundStyle(Color.primary)
                .font(.largeTitle)
                .bold()
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .padding(.horizontal, 4)
                .focused($answerFieldFocused)

            if let postfix = store.question.answerPostfix {
                Text(postfix)
                    .font(.title)
                    .foregroundStyle(Color.secondary)
            }

            Spacer().frame(width: 16)

            Button {
                store.send(.answerSubmitButtonTapped)
            } label: {
                Image(systemName: store.answerButtonKind.rawValue)
                    .font(.title)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSubmitButtonDisabled)
        }
        .padding()
        .overlay(alignment: .top) {
            Text(store.formattedPendingSubmissionValue ?? "")
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
                if store.isShowingIncorrect {
                    Color(hue: 0.0, saturation: 0.88, brightness: 0.96).frame(height: 10)
                        .offset(y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.1), value: store.isShowingIncorrect)
            .confettiCannon(counter: .constant(store.confettiAnimation), num: 25, confettiSize: 7, rainHeight: 300, fadesOut: true, opacity: 1.0, openingAngle: .degrees(50), closingAngle: .degrees(130), radius: 120, repetitions: 0, repetitionInterval: 1.0)
        }
    }
}
