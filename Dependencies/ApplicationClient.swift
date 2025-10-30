import Dependencies
import UIKit

struct ApplicationClient: Sendable {
    var applicationState: @Sendable () -> UIApplication.State
}

extension ApplicationClient {
    static let live = ApplicationClient {
        UIApplication.shared.applicationState
    }
}

private enum ApplicationClientDependencyKey: DependencyKey {
    static let liveValue: ApplicationClient = .live
    static let previewValue: ApplicationClient = .init { .active }
    static let testValue: ApplicationClient = .init { .active }
}

extension DependencyValues {
    var application: ApplicationClient {
        get { self[ApplicationClientDependencyKey.self] }
        set { self[ApplicationClientDependencyKey.self] = newValue }
    }
}
