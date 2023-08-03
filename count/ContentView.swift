import AVFoundation
import SwiftUI

struct ContentView: View {
    @State var question: String = ""
    @State var text: String = ""
    @State var wrongText: String?
    @State var isCheating: Bool = false
    let synthesizer = AVSpeechSynthesizer() // must be retained
    @State var voice: AVSpeechSynthesisVoice = .init(language: "ja-JP")!
    let japaneseVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 16) {
                Button {
                    // TODO: settings
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
                            Color.clear.frame(height: 10)
                                .overlay {
                                    GeometryReader { proxy in
                                        let barPairCount: Int = 10
                                        let barWidth: CGFloat = proxy.size.width / Double(barPairCount * 2)
                                        HStack(spacing: 0) {
                                            ForEach(0..<barPairCount, id: \.self) { _ in
                                                Rectangle().fill(Color.white).frame(width: barWidth, height: proxy.size.width)
                                                Rectangle().fill(Color.blue).frame(width: barWidth, height: proxy.size.width)
                                            }
                                        }
                                        .rotationEffect(.degrees(50))
                                        .frame(height: 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .clipShape(Capsule(style: .continuous))
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
                    .frame(width: 100, height: 100)
            }
            Spacer()
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
                    .padding(70)
                    .overlay(alignment: .bottom) {
                        Text("Tap to replay")
                            .font(.caption)
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
            .disabled(false) // TODO: isPlaying
            Spacer()
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
                        speak(string: question)
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
