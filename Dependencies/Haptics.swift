import Dependencies
import UIKit

struct HapticsClient {
    var success: @Sendable @MainActor () -> Void
    var error: @Sendable @MainActor () -> Void
}
extension HapticsClient: DependencyKey {
    @MainActor static var liveValue: Self {
        let generator = UINotificationFeedbackGenerator()
        return HapticsClient(
            success: { generator.notificationOccurred(.success) },
            error: { generator.notificationOccurred(.error) }
        )
    }
}

extension DependencyValues {
    var hapticsClient: HapticsClient {
        get { self[HapticsClient.self] }
        set { self[HapticsClient.self] = newValue }
    }
}
