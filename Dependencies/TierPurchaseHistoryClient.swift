import DependenciesAdditions
import Foundation

struct TierPurchaseHistoryClient {
    var get: @Sendable () -> (TierPurchaseHistory)
    var set: @Sendable (TierPurchaseHistory) throws -> Void
}

extension TierPurchaseHistoryClient: DependencyKey {
    static let key = "TierPurchaseHistoryClient.purchaseHistory"
    static var liveValue: Self {
        @Dependency(\.userDefaults) var userDefaults
        @Dependency(\.encode) var encode
        @Dependency(\.decode) var decode
        return .init(
            get: {
                guard let data = userDefaults.data(forKey: key) else { return TierPurchaseHistory() }
                do {
                    let value = try decode(TierPurchaseHistory.self, from: data)
                    return value
                } catch {
                    XCTFail("Unexpected purchase history decoding failure.")
                    return TierPurchaseHistory()
                }
            },
            set: { newValue in
                let data = try encode(newValue)
                userDefaults.set(data, forKey: key)
            }
        )
    }
}

extension DependencyValues {
    var tierPurchaseHistoryClient: TierPurchaseHistoryClient {
        get { self[TierPurchaseHistoryClient.self] }
        set { self[TierPurchaseHistoryClient.self] = newValue }
    }
}
