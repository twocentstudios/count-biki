import Dependencies
import UIKit

struct HapticsClient {
    var success: @Sendable @MainActor () -> Void
    var error: @Sendable @MainActor () -> Void
}
extension HapticsClient: DependencyKey {
    static var liveValue: Self {
        let generator = MainActorIsolated { UINotificationFeedbackGenerator() }
        return HapticsClient(
            success: { generator.value.notificationOccurred(.success) },
            error: { generator.value.notificationOccurred(.error) }
        )
    }
}

extension DependencyValues {
    var hapticsClient: HapticsClient {
        get { self[HapticsClient.self] }
        set { self[HapticsClient.self] = newValue }
    }
}

/// From: https://github.com/pointfreeco/swift-dependencies/discussions/22#discussioncomment-4681533
/// TODO: Revisit this in the swift-dependencies or swift-dependencies-additions libraries
@MainActor
public final class MainActorIsolated<Value>: Sendable {
  public lazy var value: Value = initialValue()
  private let initialValue: @MainActor () -> Value
  nonisolated public init(initialValue: @MainActor @escaping () -> Value) {
    self.initialValue = initialValue
  }
}
