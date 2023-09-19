@preconcurrency import AVFoundation
import Dependencies

struct SpeechSynthesisClient {
    var availableVoices: @Sendable () -> [SpeechSynthesisVoice]
    var defaultVoice: @Sendable () -> SpeechSynthesisVoice?
    var speak: @Sendable (SpeechSynthesisUtterance) async throws -> Void
    var speechRateAttributes: @Sendable () -> SpeechSynthesisVoiceRateAttributes
    var pitchMultiplierAttributes: @Sendable () -> SpeechSynthesisVoicePitchMultiplierAttributes
}

extension SpeechSynthesisClient {
    enum Error: Swift.Error {
        case noVoicesAvailable
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
            defaultVoice: { .mock1 },
            speak: { _ in
                try? await clock.sleep(for: .seconds(2))
            },
            speechRateAttributes: {
                .init(minimumRate: 0.0, maximumRate: 1.0, defaultRate: 0.5)
            },
            pitchMultiplierAttributes: {
                .init(minimumPitch: 0.5, maximumPitch: 2.0, defaultPitch: 1.0)
            }
        )
    }

    static let testValue = Self(
        availableVoices: unimplemented("SpeechSynthesisClient.availableVoices"),
        defaultVoice: unimplemented("SpeechSynthesisClient.defaultVoice"),
        speak: unimplemented("SpeechSynthesisClient.speak"),
        speechRateAttributes: {
            .init(minimumRate: 0.0, maximumRate: 1.0, defaultRate: 0.5)
        },
        pitchMultiplierAttributes: {
            .init(minimumPitch: 0.5, maximumPitch: 2.0, defaultPitch: 1.0)
        }
    )

    static var noVoices: Self {
        var value = Self.previewValue
        value.availableVoices = { [] }
        value.defaultVoice = { nil }
        return value
    }
}

extension SpeechSynthesisClient: DependencyKey {
    #if !targetEnvironment(simulator)
        static var liveValue: Self {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            var availableVoices: [SpeechSynthesisVoice] { AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }.map(SpeechSynthesisVoice.init(_:)) }
            var defaultVoice: SpeechSynthesisVoice? { availableVoices.sorted(by: { $0.quality.rawValue > $1.quality.rawValue }).first }
            let synthesizer = LockIsolated(AVSpeechSynthesizer())
            return Self(
                availableVoices: { availableVoices },
                defaultVoice: { defaultVoice },
                speak: { utterance in
                    var delegate: SpeechSynthesisDelegate?
                    try await withTaskCancellationHandler {
                        try await withCheckedThrowingContinuation { continuation in
                            do {
                                let avSpeechUtterance = try utterance.avSpeechUtterance(defaultVoiceIdentifier: defaultVoice?.voiceIdentifier)
                                delegate = SpeechSynthesisDelegate(
                                    didStart: {
                                        // TODO: check didStart?
                                    }, didFinish: {
                                        continuation.resume()
                                    }, didCancel: {
                                        continuation.resume()
                                    }
                                )
                                synthesizer.value.delegate = delegate
                                synthesizer.value.speak(avSpeechUtterance)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } onCancel: {
                        synthesizer.value.stopSpeaking(at: .immediate)
                    }
                    delegate = nil
                },
                speechRateAttributes: {
                    .init(minimumRate: AVSpeechUtteranceMinimumSpeechRate, maximumRate: AVSpeechUtteranceMaximumSpeechRate, defaultRate: AVSpeechUtteranceDefaultSpeechRate)
                },
                pitchMultiplierAttributes: {
                    // From AVSpeechUtterance.pitchMultiplier docs
                    .init(minimumPitch: 0.5, maximumPitch: 2.0, defaultPitch: 1.0)
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
        XCTFail("Pausing is not supported")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        XCTFail("Continuing is not supported")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {}

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {}
}

struct SpeechSynthesisUtterance {
    var speechString: String
    var settings: SpeechSynthesisSettings
}

extension SpeechSynthesisUtterance {
    func avSpeechUtterance(defaultVoiceIdentifier: String?) throws -> AVSpeechUtterance {
        let avSpeechSynthesisVoice: AVSpeechSynthesisVoice
        if let voiceIdentifierFromSettings = settings.voiceIdentifier,
           let voiceFromSettings = AVSpeechSynthesisVoice(identifier: voiceIdentifierFromSettings)
        {
            avSpeechSynthesisVoice = voiceFromSettings
        } else if let defaultVoiceIdentifier,
                  let defaultVoice = AVSpeechSynthesisVoice(identifier: defaultVoiceIdentifier)
        {
            avSpeechSynthesisVoice = defaultVoice
        } else {
            throw SpeechSynthesisClient.Error.noVoicesAvailable
        }

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

struct SpeechSynthesisVoiceRateAttributes: Equatable {
    let minimumRate: Float
    let maximumRate: Float
    let defaultRate: Float
}

struct SpeechSynthesisVoicePitchMultiplierAttributes: Equatable {
    let minimumPitch: Float
    let maximumPitch: Float
    let defaultPitch: Float
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

    static var mockNil: Self {
        .init(voiceIdentifier: nil, pitchMultiplier: nil, volume: nil, rate: nil, preUtteranceDelay: nil, postUtteranceDelay: nil)
    }
}
