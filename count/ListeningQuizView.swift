import AVFoundation
import ComposableArchitecture
import SwiftUI

struct ListeningQuizFeature: Reducer {
    struct State: Equatable {
        @PresentationState var destination: Destination.State?
        var settings: SettingsFeature.State = .init()
        var isSpeaking: Bool = false
        var questionNumber: Int = 0
        var question: String = ""
        @BindingState var answer: String = ""
        var lastSubmittedIncorrectAnswer: String?
        var isShowingPlaybackError: Bool = false

        var isShowingIncorrect: Bool {
            lastSubmittedIncorrectAnswer == answer
        }
    }

    enum Action: BindableAction, Equatable {
        case answerSubmitButtonTapped
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case playbackButtonTapped
        case onTask
        case titleButtonTapped
        case onPlaybackFinished
        case onPlaybackError
        case onPlaybackErrorTimeout
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
    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.topicClient) var topicClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .answerSubmitButtonTapped:
                if state.question == state.answer {
                    state.answer = ""
                    generateQuestion(state: &state)
                    return playBackEffect(state: &state)
                } else {
                    state.lastSubmittedIncorrectAnswer = state.answer
                    return playBackEffect(state: &state)
                }

            case .binding:
                return .none

            case .destination(.presented(.settings(.binding))):
                guard case let .settings(action) = state.destination else { return .none }
                state.settings = action
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
        state.isSpeaking = true
        return .run { [question = state.question, settings = state.settings.speechSettings] send in
            await withTaskCancellation(id: CancelID.speakAction, cancelInFlight: true) {
                do {
                    let utterance = SpeechSynthesisUtterance(speechString: question, settings: settings)
                    try await speechClient.speak(utterance)
                    await send(.onPlaybackFinished)
                } catch {
                    await send(.onPlaybackError)
                }
            }
        }
    }
}

#Preview {
    ListeningQuizView(
        store: Store(initialState: ListeningQuizFeature.State()) {
            ListeningQuizFeature()
                ._printChanges()
        }
    )
}

struct ListeningQuizView: View {
    let store: StoreOf<ListeningQuizFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    Button {
                        viewStore.send(.titleButtonTapped)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(viewStore.settings.topic.title)
                                    .font(.system(.title, design: .rounded, weight: .semibold))
                                Text(viewStore.settings.topic.subtitle)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                Spacer()
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color(.secondaryLabel))
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
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    Circle() // TODO: avatar
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 100, height: 100)
                        .hidden()
                }
                Spacer()
                Button {
                    viewStore.send(.playbackButtonTapped)
                } label: {
                    Image(systemName: viewStore.isSpeaking ? "speaker.wave.3.fill" : "speaker.fill")
                        .font(.title)
                        .frame(width: 170, height: 170)
                        .overlay(alignment: .bottom) {
                            Text(viewStore.isSpeaking ? "Tap to stop" : "Tap to replay")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.secondary)
                                .padding(.vertical, 10)
                        }
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
                                .font(.system(.caption, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(.red))
                                .offset(x: 0, y: 40)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.bouncy, value: viewStore.isShowingPlaybackError)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {}
            .background {
                if viewStore.isShowingIncorrect {
                    Color(.red).saturation(0.9).brightness(0.6).ignoresSafeArea()
                } else {
                    Color(.systemBackground).ignoresSafeArea()
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    TextField("Answer", text: viewStore.$answer)
                        .foregroundStyle(Color.primary)
                        .font(.system(.largeTitle, design: .rounded))
                        .bold()
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                    Button {
                        viewStore.send(.answerSubmitButtonTapped)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewStore.answer.isEmpty) // TODO: where should this calculation go
                }
                .padding()
                .background {
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
                }
            }
            .task {
                await viewStore.send(.onTask).finish()
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
}
