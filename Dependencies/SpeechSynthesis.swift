@preconcurrency import AVFoundation
import Dependencies

struct SpeechSynthesisClient {
    var availableVoices: @Sendable () -> [SpeechSynthesisVoice]
    var speak: @Sendable (SpeechSynthesisUtterance) async throws -> Void
}

extension SpeechSynthesisClient {
    enum Error: Swift.Error {
        case noVoiceSet
        case voiceIdentifierNotAvailable
    }
}

extension DependencyValues {
    var speechSynthesisClient: SpeechSynthesisClient {
        get { self[SpeechSynthesisClient.self] }
        set { self[SpeechSynthesisClient.self] = newValue }
    }
}

extension SpeechSynthesisClient: TestDependencyKey {
    static var previewValue: Self {
        @Dependency(\.continuousClock) var clock
        return Self(
            availableVoices: { [.mock1, .mock2] },
            speak: { _ in
                try? await clock.sleep(for: .seconds(2))
            }
        )
    }

    static let testValue = Self(
        availableVoices: unimplemented(""),
        speak: unimplemented("")
    )
}

extension SpeechSynthesisClient: DependencyKey {
    #if !targetEnvironment(simulator)
        static var liveValue: Self {
            Self(
                availableVoices: {
                    AVSpeechSynthesisVoice.speechVoices().filter({ $0.language == "ja-JP" }).map(SpeechSynthesisVoice.init(_:))
                },
                speak: { utterance in
                    let synthesizer = AVSpeechSynthesizer()
                    try await withTaskCancellationHandler {
                        try await withCheckedThrowingContinuation { continuation in
                            do {
                                let avSpeechUtterance = try utterance.avSpeechUtterance()
                                let delegate = SpeechSynthesisDelegate(
                                    didStart: {
                                        // TODO: check didStart?
                                    }, didFinish: {
                                        continuation.resume()
                                    }, didCancel: {
                                        continuation.resume()
                                    }
                                )
                                synthesizer.delegate = delegate
                                synthesizer.speak(avSpeechUtterance)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } onCancel: {
                        synthesizer.stopSpeaking(at: .immediate)
                    }
                }
            )
        }
    #else
        static let liveValue = previewValue
    #endif
}

private final class SpeechSynthesisDelegate: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    let didStart: @Sendable () -> Void
    let didFinish: @Sendable () -> Void
    let didCancel: @Sendable () -> Void

    init(
        didStart: @escaping @Sendable () -> Void,
        didFinish: @escaping @Sendable () -> Void,
        didCancel: @escaping @Sendable () -> Void
    ) {
        self.didStart = didStart
        self.didFinish = didFinish
        self.didCancel = didCancel
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        didStart()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        didFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        didCancel()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        assertionFailure("Pausing is not supported")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        assertionFailure("Continuing is not supported")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {}

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {}
}

struct SpeechSynthesisUtterance {
    var speechString: String
    var settings: SpeechSynthesisSettings
}

extension SpeechSynthesisUtterance {
    func avSpeechUtterance() throws -> AVSpeechUtterance {
        guard let voiceIdentifier = settings.voiceIdentifier else { throw SpeechSynthesisClient.Error.noVoiceSet }
        guard let avSpeechSynthesisVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) else { throw SpeechSynthesisClient.Error.voiceIdentifierNotAvailable }

        let utterance = AVSpeechUtterance(string: speechString)
        utterance.voice = avSpeechSynthesisVoice

        if let pitchMultiplier = settings.pitchMultiplier {
            utterance.pitchMultiplier = pitchMultiplier
        }
        if let volume = settings.volume {
            utterance.volume = volume
        }
        if let rate = settings.rate {
            utterance.rate = rate
        }
        if let preUtteranceDelay = settings.preUtteranceDelay {
            utterance.preUtteranceDelay = preUtteranceDelay
        }
        if let postUtteranceDelay = settings.postUtteranceDelay {
            utterance.postUtteranceDelay = postUtteranceDelay
        }
        return utterance
    }
}

struct SpeechSynthesisSettings: Equatable, Codable {
    var voiceIdentifier: String?
    var pitchMultiplier: Float?
    var volume: Float?
    var rate: Float?
    var preUtteranceDelay: TimeInterval?
    var postUtteranceDelay: TimeInterval?
}

struct SpeechSynthesisVoice: Identifiable, Equatable {
    var id: String { voiceIdentifier }
    let voiceIdentifier: String
    let name: String
    let quality: AVSpeechSynthesisVoiceQuality
    let gender: AVSpeechSynthesisVoiceGender
    let languageCode: String
}

extension SpeechSynthesisVoice {
    init(_ voice: AVSpeechSynthesisVoice) {
        voiceIdentifier = voice.identifier
        name = voice.name
        quality = voice.quality
        gender = voice.gender
        languageCode = voice.language
    }
}

extension SpeechSynthesisVoice {
    static var mock1: Self {
        .init(voiceIdentifier: "com.twocentstudios.preview.spike", name: "Spike", quality: .default, gender: .male, languageCode: "ja-JP")
    }
    static var mock2: Self {
        .init(voiceIdentifier: "com.twocentstudios.preview.faye", name: "Faye", quality: .default, gender: .female, languageCode: "ja-JP")
    }
}

extension SpeechSynthesisSettings {
    static var mock: Self {
        .init(voiceIdentifier: SpeechSynthesisVoice.mock1.voiceIdentifier, pitchMultiplier: 0.5, volume: 0.5, rate: 0.8, preUtteranceDelay: 0.5, postUtteranceDelay: 1.0)
    }
}
