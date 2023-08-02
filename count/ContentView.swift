import AVFoundation
import SwiftUI

struct ContentView: View {
    @State var question: String = ""
    @State var text: String = ""
    @State var wrongText: String?
    @State var isCheating: Bool = false
    let synthesizer = AVSpeechSynthesizer() // must be retained

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
        var bestVoice = AVSpeechSynthesisVoice(language: "ja-JP")
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            if voice.language == "ja-JP" {
                if voice.quality == .premium {
                    bestVoice = voice
                    break
                } else if voice.quality == .enhanced {
                    bestVoice = voice
                    break
                } else {
                    bestVoice = voice
                }
            }
        }

        print(bestVoice.debugDescription)
        utterance.voice = bestVoice
        synthesizer.speak(utterance)
    }
}

#Preview {
    ContentView()
}
