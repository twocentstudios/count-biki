import AVFoundation
import ComposableArchitecture
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
        @BindingState var answer: String = ""
        var bikiAnimation: BikiAnimation?
        @PresentationState var destination: Destination.State?
        var isShowingPlaybackError: Bool = false
        var isShowingAnswer: Bool = false
        var isSpeaking: Bool = false
        var lastSubmittedIncorrectAnswer: String?
        var questionNumber: Int = 0
        var question: Question?
        var settings: SettingsFeature.State = .init()
    }

    enum Action: BindableAction, Equatable {
        case answerSubmitButtonTapped
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
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
    @Dependency(\.topicClient) var topicClient
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .answerSubmitButtonTapped:
                if state.isShowingAnswer {
                    state.lastSubmittedIncorrectAnswer = nil
                    state.answer = ""
                    state.isShowingAnswer = false
                    generateQuestion(state: &state)
                    return playBackEffect(state: &state)
                } else if state.question?.acceptedAnswer == state.answer {
                    state.bikiAnimation = .init(id: uuid(), kind: .correct)
                    state.lastSubmittedIncorrectAnswer = nil
                    state.answer = ""
                    generateQuestion(state: &state)
                    return .run { _ in await haptics.success() }
                        .merge(with: playBackEffect(state: &state))
                } else {
                    state.bikiAnimation = .init(id: uuid(), kind: .incorrect)
                    state.lastSubmittedIncorrectAnswer = state.answer
                    return .run { _ in await haptics.error() }
                        .merge(with: playBackEffect(state: &state))
                }

            case .binding:
                return .none

            case .destination(.presented(.settings(.binding))):
                guard case let .settings(newValue) = state.destination else { return .none }
                let oldValue = state.settings
                state.settings = newValue
                if oldValue.topicID != newValue.topicID {
                    state.lastSubmittedIncorrectAnswer = nil
                    state.answer = ""
                    state.isShowingAnswer = false
                    generateQuestion(state: &state)
                }
                return .none

            case .destination:
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
                generateQuestion(state: &state)
                return playBackEffect(state: &state)

            case .playbackButtonTapped:
                if state.isSpeaking {
                    state.isSpeaking = false
                    return .cancel(id: CancelID.speakAction)
                } else {
                    return playBackEffect(state: &state)
                }

            case .showAnswerButtonTapped:
                state.isShowingAnswer = true
                return .none

            case .titleButtonTapped:
                state.destination = .settings(state.settings)
                return .none
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }

    func generateQuestion(state: inout State) {
        state.question = try! topicClient.generateQuestion(state.settings.topic.id) // TODO: handle error
        state.questionNumber += 1
    }

    private func playBackEffect(state: inout State) -> Effect<Self.Action> {
        guard let displayText = state.question?.displayText else {
            assertionFailure("Tried to play before question set")
            return .none
        }

        state.isSpeaking = true
        return .run { [settings = state.settings.speechSettings] send in
            await withTaskCancellation(id: CancelID.speakAction, cancelInFlight: true) {
                do {
                    let utterance = SpeechSynthesisUtterance(speechString: displayText, settings: settings)
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
        lastSubmittedIncorrectAnswer == answer
    }

    var isSubmitButtonDisabled: Bool {
        if isShowingAnswer {
            return false
        } else {
            return answer.isEmpty
        }
    }

    var answerText: String {
        if isShowingAnswer {
            return question?.acceptedAnswer ?? ""
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
}

#Preview {
    ListeningQuizView(
        store: Store(initialState: ListeningQuizFeature.State()) {
            ListeningQuizFeature()
                ._printChanges()
        } withDependencies: {
            $0.topicClient.generateQuestion = { _ in .init(displayText: "1", answerPrefix: nil, answerPostfix: nil, acceptedAnswer: "1") }
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
                    .padding(.bottom, 16)
                playButton(viewStore: viewStore)

                Spacer()
            }
            .padding()
            .safeAreaInset(edge: .bottom) {
                answerTextField(viewStore: viewStore)
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
            Button {
                viewStore.send(.titleButtonTapped)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(viewStore.settings.topic.title)
                                .font(.title)
                                .fontWeight(.semibold)
                            Text(viewStore.settings.topic.subtitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(viewStore.settings.topic.title)
                                .font(.title)
                                .fontWeight(.semibold)
                            Text(viewStore.settings.topic.subtitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    HStack(spacing: 6) {
                        IndeterminateProgressView(
                            animationCount: viewStore.questionNumber,
                            color1: Color(.tintColor),
                            color2: Color(.systemBackground),
                            barCount: 20,
                            rotation: .degrees(50),
                            animation: .snappy()
                        )
                        .clipShape(Capsule(style: .continuous))
                        .frame(height: 10)
                        Image(systemName: "infinity")
                            .font(.caption)
                            .bold()
                            .foregroundColor(Color(.label))
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background {
                    RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
                }
            }
            .buttonStyle(.plain)

            CountBikiView(bikiAnimation: viewStore.bikiAnimation)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 100)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder func answer(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        Text(viewStore.answerText)
            .font(.system(size: 80, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .foregroundStyle(viewStore.isShowingAnswer ? Color.primary : Color.secondary)
            .blur(radius: viewStore.isShowingAnswer ? 0 : 18)
            .overlay {
                if !viewStore.isShowingAnswer {
                    Button {
                        viewStore.send(.showAnswerButtonTapped)
                    } label: {
                        VStack(spacing: 10) {
                            Text("Show Answer")
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 24)
                        .animation(.bouncy, value: viewStore.isSpeaking)
                    }
                    .buttonStyle(.plain)
                }
            }
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

    @MainActor @ViewBuilder func answerTextField(viewStore: ViewStoreOf<ListeningQuizFeature>) -> some View {
        HStack(spacing: 0) {
            if let prefix = viewStore.question?.answerPrefix {
                Text(prefix)
                    .font(.title)
                    .foregroundStyle(Color.secondary)
            }
            TextField("Answer", text: viewStore.$answer)
                .foregroundStyle(Color.primary)
                .font(.largeTitle)
                .bold()
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .padding(.horizontal, 4)
                .focused($answerFieldFocused)

            if let postfix = viewStore.question?.answerPostfix {
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
        }
    }
}
