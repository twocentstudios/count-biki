import ComposableArchitecture
import SwiftUI

@main
struct CountApp: App {
    var body: some Scene {
//        WindowGroup {
//            NavigationStack {
//                TopicsView()
//            }
//        }
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
                        guard let bestVoice else { XCTFail("No voice available"); return }
                        let settings = SpeechSynthesisSettings(voiceIdentifier: bestVoice.voiceIdentifier)
                        do {
                            try $0.speechSynthesisSettingsClient.set(settings)
                        } catch {
                            XCTFail("Error creating initial speech settings: \(error)")
                        }
                    } catch {
                        XCTFail("Unknown error: \(error)")
                    }

                    #if targetEnvironment(simulator)
                        $0.topicClient.generateQuestion = { _ in .init(topicID: Topic.id(for: 000), displayText: "1", answerPrefix: nil, answerPostfix: nil, acceptedAnswer: "1") }
                    #endif
                }
            )
            .fontDesign(.rounded)
        }
    }
}
