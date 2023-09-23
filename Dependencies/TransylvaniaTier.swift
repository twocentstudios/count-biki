@preconcurrency import Combine
import Dependencies
import IdentifiedCollections

struct TransylvaniaTierClient {
    var tierStatus: @Sendable () -> (TierStatus)
    var tierStatusStream: @Sendable () -> AsyncStream<TierStatus>
    var monitor: @Sendable () async -> Void
}

extension TransylvaniaTierClient: DependencyKey {
    static var liveValue: TransylvaniaTierClient {
        let tierStatusSubject: CurrentValueSubject<TierStatus, Never> = .init(.unknown) // TODO: this is probably not @Sendable
        return Self(
            tierStatus: { tierStatusSubject.value },
            tierStatusStream: { tierStatusSubject.values.eraseToStream() },
            monitor: {
                @Dependency(\.tierProductsClient) var tierProductsClient
                let initialStatus = await tierProductsClient.currentStatus()
                tierStatusSubject.send(initialStatus)
                for await _ in tierProductsClient.monitorPurchases() {
                    let updatedStatus = await tierProductsClient.currentStatus()
                    tierStatusSubject.send(updatedStatus)
                }
            }
        )
    }
}

extension TransylvaniaTierClient: TestDependencyKey {
    static let previewValue: TransylvaniaTierClient = .liveValue

    static var testValue: TransylvaniaTierClient {
        Self(
            tierStatus: unimplemented("tierStatus"),
            tierStatusStream: unimplemented("tierStatusStream"),
            monitor: unimplemented("monitor")
        )
    }
}

extension DependencyValues {
    var transylvaniaTierClient: TransylvaniaTierClient {
        get { self[TransylvaniaTierClient.self] }
        set { self[TransylvaniaTierClient.self] = newValue }
    }
}
