import Dependencies
import DependenciesMacros
import UIKit

@DependencyClient
struct ApplicationClient: Sendable {
    var applicationState: @Sendable () -> UIApplication.State = { .active }
}

extension ApplicationClient {
    static let live = ApplicationClient {
        MainActor.assumeIsolated {
            UIApplication.shared.applicationState
        }
    }
}

extension ApplicationClient: DependencyKey {
    static let liveValue: ApplicationClient = .live
    static let previewValue: ApplicationClient = .init { .active }
    static let testValue: ApplicationClient = .init { .active }
}
