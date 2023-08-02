import AVFoundation
import SwiftUI

struct ContentView: View {
    @State var question: String = ""
    @State var text: String = ""
    @State var wrongText: String?
    @State var isCheating: Bool = false
    let synthesizer = AVSpeechSynthesizer() // must be retained
    @State var voice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: "ja-JP")!
    let japaneseVoices = AVSpeechSynthesisVoice.speechVoices().filter({ $0.language == "ja-JP" })

    var body: some View {
        VStack {
            Button {
                isCheating.toggle()
            } label: {
                Text(question)
                    .font(.caption)
                    .padding()
                    .redacted(reason: isCheating ? [] : .placeholder)
                    .onTapGesture {
                        isCheating.toggle()
                    }
            }
            .buttonStyle(.plain)
            Button {
                speak(string: question)
            } label: {
                Image(systemName: "speaker.fill") // TODO: playing state
                    .font(.title)
                    .padding(60)
            }
            .buttonStyle(.bordered)
            .disabled(false) // TODO: isPlaying
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Picker("Voice", selection: $voice) {
                ForEach(japaneseVoices, id: \.identifier) { voiceOption in
                    Text(voiceOption.name)
                        .tag(voiceOption)
                }
            }
        }
        .background {
            if isShowingIncorrect {
                Color(.red).saturation(0.9).brightness(0.6).ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                TextField("Answer", text: $text)
                    .foregroundStyle(Color.primary)
                    .font(.largeTitle)
                    .bold()
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .onChange(of: text) { _ in
                        wrongText = nil
                    }
                Button {
                    if question == text {
                        text = ""
                        generateQuestion()
                        speak(string: question)
                    } else {
                        wrongText = text
                    }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty)
            }
            .padding()
        }
        .onAppear {
            generateQuestion()
        }
    }

    var isShowingIncorrect: Bool {
        wrongText == text
    }

    func generateQuestion() {
        question = String(Int.random(in: 0 ... 1000))
    }

    func speak(string: String) {
        let utterance = AVSpeechUtterance(string: string)
        utterance.voice = voice
        #if !targetEnvironment(simulator) // iOS17b5 console has a meltdown on simulator
        synthesizer.speak(utterance)
        #endif
    }
}

#Preview {
    ContentView()
}
