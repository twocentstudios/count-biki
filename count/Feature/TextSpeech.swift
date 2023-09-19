import Collections
import ComposableArchitecture
import SwiftUI

struct TextSpeechFeature: Reducer {
    struct State: Equatable {
        @BindingState var textValue: String = ""
        var submissions: OrderedSet<String> = []
    }

    enum Action: BindableAction, Equatable {
        case submitButtonTapped
        case clearButtonTapped
        case appendStringButtonTapped(String)
        case submissionTapped(String)
        case playButtonTapped(String)
        case binding(BindingAction<State>)
        case onDelete(String)
    }

    @Dependency(\.speechSynthesisClient) var speechClient
    @Dependency(\.speechSynthesisSettingsClient) var speechSettingsClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .clearButtonTapped:
                state.textValue = ""
                return .none
            case let .appendStringButtonTapped(string):
                state.textValue += string
                return .none
            case let .submissionTapped(string):
                state.textValue = string
                return .none
            case let .playButtonTapped(string):
                return playBackEffect(text: string)
            case .submitButtonTapped:
                let playbackString = state.textValue
                state.submissions.insert(state.textValue, at: 0)
                state.textValue = ""
                return playBackEffect(text: playbackString)
            case let .onDelete(string):
                state.submissions.remove(string)
                return .none
            }
        }
    }

    private func playBackEffect(text: String) -> Effect<Self.Action> {
        .run { send in
            do {
                let utterance = SpeechSynthesisUtterance(speechString: text, settings: speechSettingsClient.get())
                try await speechClient.speak(utterance)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct TextSpeechView: View {
    let store: StoreOf<TextSpeechFeature>
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                List(viewStore.submissions, id: \.self) { submission in
                    Button {
                        viewStore.send(.submissionTapped(submission))
                    } label: {
                        HStack {
                            Image(systemName: "chevron.right")
                                .padding(.trailing)
                            Text(submission)
                                .font(.headline)
                        }
                    }
                    .contextMenu {
                        Button("Play") {
                            viewStore.send(.playButtonTapped(submission))
                        }
                        Button("Delete", role: .destructive) {
                            viewStore.send(.onDelete(submission))
                        }
                    }
                }
                .listStyle(.plain)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    HStack {
                        ForEach(["日", "月", "ヶ月", "年", "間"], id: \.self) { character in
                            Button(character) {
                                viewStore.send(.appendStringButtonTapped(character))
                            }
                        }
                        Button {
                            viewStore.send(.clearButtonTapped)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                    }
                    .padding(.horizontal)
                    .buttonStyle(.bordered)
                    HStack {
                        TextField("Text-to-speech", text: viewStore.$textValue)
                            .foregroundStyle(Color.primary)
                            .font(.largeTitle)
                            .bold()
                            .textFieldStyle(.plain)
                            .keyboardType(.default)
                            .padding(.horizontal, 4)
                            .focused($textFieldFocused)

                        Spacer().frame(width: 16)

                        Button {
                            viewStore.send(.submitButtonTapped)
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background {
                    Color(.secondarySystemBackground)
                        .ignoresSafeArea(.all, edges: .bottom)
                        .shadow(color: Color.primary.opacity(0.15), radius: 3, x: 0, y: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                textFieldFocused = true
            }
        }
    }
}

#Preview {
    TextSpeechView(
        store: Store(initialState: TextSpeechFeature.State()) {
            TextSpeechFeature()
                ._printChanges()
        }
    )
}
