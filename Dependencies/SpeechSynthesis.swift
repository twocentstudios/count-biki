import AVFoundation
import Dependencies

struct SpeechSynthesisClient {
    var availableVoices: @Sendable () -> [SpeechSynthesisVoice]
    var speak: @Sendable (SpeechSynthesisUtterance) async throws -> Void
}

enum SpeechSynthesisClientError: Error {
    case noVoiceSet
    case voiceIdentifierNotAvailable
}

extension SpeechSynthesisClient: DependencyKey {
    static var liveValue: Self {
        Self(
            availableVoices: {
                AVSpeechSynthesisVoice.speechVoices().map(SpeechSynthesisVoice.init(_:))
            },
            speak: { utterance in
                let synthesizer = AVSpeechSynthesizer()
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
            }
        )
    }
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
        guard let voice = settings.voice else { throw SpeechSynthesisClientError.noVoiceSet }
        guard let avSpeechSynthesisVoice = AVSpeechSynthesisVoice(identifier: voice.voiceIdentifier) else { throw SpeechSynthesisClientError.voiceIdentifierNotAvailable }

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

struct SpeechSynthesisSettings {
    var voice: SpeechSynthesisVoice?
    var pitchMultiplier: Float?
    var volume: Float?
    var rate: Float?
    var preUtteranceDelay: TimeInterval?
    var postUtteranceDelay: TimeInterval?
}

struct SpeechSynthesisVoice: Identifiable {
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
