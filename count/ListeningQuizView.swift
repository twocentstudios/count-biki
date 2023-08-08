import AVFoundation
import ComposableArchitecture
import SwiftUI

struct ListeningQuizFeature: Reducer {
    struct State: Equatable {
        var topicTitle: String = ""
        var topicSubtitle: String = ""
        var isSpeaking: Bool = false
        var questionNumber: Int = 0
        var question: String = ""
        @BindingState var answer: String = ""
        var lastSubmittedIncorrectAnswer: String?

        var isShowingIncorrect: Bool {
            lastSubmittedIncorrectAnswer == answer
        }
    }

    enum Action: BindableAction, Equatable {
        case answerSubmitButtonTapped
        case binding(BindingAction<State>)
        case playbackButtonTapped
        case onTask
        case titleButtonTapped
    }

    private enum CancelID {
        case speakAction
    }

    @Dependency(\.continuousClock) var clock
//    @Dependency(\.featureClient) var featureClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .answerSubmitButtonTapped:
                return .none

            case .binding:
                return .none

            case .onTask:
                return .none

            case .playbackButtonTapped:
                return .none

            case .titleButtonTapped:
                return .none
            }
        }
    }

    func generateQuestion(state: inout State) {
        state.question = String(Int.random(in: 0 ... 10000))
        state.questionNumber += 1
    }

//    func speak(string: String) {
//        let utterance = AVSpeechUtterance(string: string)
//        utterance.voice = voice
//        #if !targetEnvironment(simulator) // iOS17b5 console has a meltdown on simulator
//            synthesizer.speak(utterance)
//        #endif
//    }
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

    @State var isShowingDebug: Bool = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    Button {
                        isShowingDebug = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("Numbers")
                                    .font(.system(.title, design: .rounded, weight: .semibold))
                                Text("1-10k")
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
                        .padding(70)
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
                }
                .buttonStyle(.plain)
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
        }
    }
}

struct DebugView: View {
    let question: String
    @Binding var voice: AVSpeechSynthesisVoice
    let japaneseVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }

    var body: some View {
        VStack {
            Text(question)
                .font(.caption)
                .padding()

            Picker("Voice", selection: $voice) {
                ForEach(japaneseVoices, id: \.identifier) { voiceOption in
                    Text(voiceOption.name)
                        .tag(voiceOption)
                }
            }
        }
    }
}
