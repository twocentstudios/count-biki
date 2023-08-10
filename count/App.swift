import ComposableArchitecture
import SwiftUI

@main
struct CountApp: App {
    var body: some Scene {
        WindowGroup {
            ListeningQuizView(
                store: Store(initialState: ListeningQuizFeature.State()) {
                    ListeningQuizFeature()
                } withDependencies: {
                    // TODO: perhaps move this into SpeechSynthesisClient due to performance warning in `transformDependency` docs.
                    //       see: https://github.com/pointfreeco/swift-composable-architecture/discussions/1713#discussioncomment-6681618
                    do {
                        _ = try $0.speechSynthesisSettingsClient.get()
                    } catch SpeechSynthesisSettingsClient.Error.settingsUnset {
                        let voices = $0.speechSynthesisClient.availableVoices()
                        let bestVoice = voices
                            .filter { $0.languageCode == "ja-JP" }
                            .sorted(by: { $0.quality.rawValue > $1.quality.rawValue })
                            .first
                        guard let bestVoice else { assertionFailure("No voice available"); return }
                        let settings = SpeechSynthesisSettings(voiceIdentifier: bestVoice.voiceIdentifier)
                        do {
                            try $0.speechSynthesisSettingsClient.set(settings)
                        } catch {
                            assertionFailure("Error creating initial speech settings: \(error)")
                        }
                    } catch {
                        assertionFailure("Unknown error: \(error)")
                    }
                }
            )
        }
    }
}
