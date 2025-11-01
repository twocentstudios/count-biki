import AVFoundation
import Dependencies
import DependenciesMacros

@DependencyClient
struct SpeechSynthesisClient {
    var availableVoices: @Sendable () -> [SpeechSynthesisVoice] = { [] }
    var defaultVoice: @Sendable () -> SpeechSynthesisVoice? = { nil }
    var speak: @Sendable (SpeechSynthesisUtterance) async throws -> Void = { _ in }
    var speechRateAttributes: @Sendable () -> SpeechSynthesisVoiceRateAttributes = {
        .init(minimumRate: 0, maximumRate: 1, defaultRate: 0.5)
    }
    var pitchMultiplierAttributes: @Sendable () -> SpeechSynthesisVoicePitchMultiplierAttributes = {
        .init(minimumPitch: 0.5, maximumPitch: 2, defaultPitch: 1)
    }
}

extension SpeechSynthesisClient {
    enum Error: Swift.Error {
        case noVoicesAvailable
    }
}

extension SpeechSynthesisClient: DependencyKey {
    #if !targetEnvironment(simulator)
        static var liveValue: Self {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])

            let voices: @Sendable () -> [SpeechSynthesisVoice] = {
                AVSpeechSynthesisVoice
                    .speechVoices()
                    .filter { $0.language == "ja-JP" }
                    .map(SpeechSynthesisVoice.init(_:))
            }

            let defaultVoice: @Sendable () -> SpeechSynthesisVoice? = {
                voices().max(by: { $0.quality.rawValue < $1.quality.rawValue })
            }

            let session = SpeechSynthesizerActor()
            return Self(
                availableVoices: voices,
                defaultVoice: defaultVoice,
                speak: { utterance in
                    let avUtterance = try utterance.avSpeechUtterance(
                        defaultVoiceIdentifier: defaultVoice()?.voiceIdentifier
                    )
                    try await session.speak(avUtterance)
                },
                speechRateAttributes: {
                    .init(
                        minimumRate: AVSpeechUtteranceMinimumSpeechRate,
                        maximumRate: AVSpeechUtteranceMaximumSpeechRate,
                        defaultRate: AVSpeechUtteranceDefaultSpeechRate
                    )
                },
                pitchMultiplierAttributes: {
                    .init(minimumPitch: 0.5, maximumPitch: 2.0, defaultPitch: 1.0)
                }
            )
        }
    #else
        static var liveValue: Self { previewValue }
    #endif

    static var previewValue: Self {
        let clock = ContinuousClock()
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
        availableVoices: unimplemented("SpeechSynthesisClient.availableVoices", placeholder: []),
        defaultVoice: unimplemented("SpeechSynthesisClient.defaultVoice", placeholder: nil),
        speak: unimplemented("SpeechSynthesisClient.speak", placeholder: ()),
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

private actor SpeechSynthesizerActor {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Swift.Error>?
    private let delegate: Delegate

    init() {
        let delegate = Delegate()
        self.delegate = delegate
        synthesizer.delegate = delegate
        delegate.configure(with: self)
    }

    func speak(_ utterance: AVSpeechUtterance) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
                Task { await self.beginSpeaking(utterance, continuation: continuation) }
            }
        } onCancel: {
            Task { await self.cancelSpeaking() }
        }
    }

    private func beginSpeaking(_ utterance: AVSpeechUtterance, continuation: CheckedContinuation<Void, Swift.Error>) async {
        guard self.continuation == nil else {
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        synthesizer.speak(utterance)
    }

    private func cancelSpeaking() async {
        synthesizer.stopSpeaking(at: .immediate)
        await finishThrowing(CancellationError())
    }

    private func finish() async {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume()
    }

    private func finishThrowing(_ error: Swift.Error) async {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }

    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        private var didFinish: (@Sendable () -> Void)?
        private var didCancel: (@Sendable () -> Void)?
        private var didPause: (@Sendable () -> Void)?
        private var didContinue: (@Sendable () -> Void)?

        func configure(with actor: SpeechSynthesizerActor) {
            didFinish = { Task { await actor.finish() } }
            didCancel = { Task { await actor.finishThrowing(CancellationError()) } }
            didPause = {
                assertionFailure("AVSpeechSynthesizer paused unexpectedly; pausing isn't supported.")
            }
            didContinue = {
                assertionFailure("AVSpeechSynthesizer continued unexpectedly; continuing isn't supported.")
            }
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            didFinish?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            didCancel?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
            didPause?()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
            didContinue?()
        }
    }
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
        .init(
            voiceIdentifier: "com.twocentstudios.preview.spike",
            name: "Spike",
            quality: .default,
            gender: .male,
            languageCode: "ja-JP"
        )
    }

    static var mock2: Self {
        .init(
            voiceIdentifier: "com.twocentstudios.preview.faye",
            name: "Faye",
            quality: .default,
            gender: .female,
            languageCode: "ja-JP"
        )
    }
}
