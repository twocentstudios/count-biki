import Dependencies
import IdentifiedCollections
import StoreKit

typealias TierProductID = String
struct TierProduct: Equatable, Identifiable {
    let id: TierProductID
    let displayName: String
    let displayPrice: String
}

extension TierProduct {
    static let localIDs: [TierProductID] = ["countbiki_tip_001"]
}

extension TierProduct {
    init?(_ product: Product) {
        guard product.type == .consumable else {
            XCTFail("Unexpected non-consumable StoreKit.Product")
            return nil
        }
        id = product.id
        displayName = product.displayName
        displayPrice = product.displayPrice
    }
}

enum TierPurchaseResult: Equatable {
    case success
    case userCancelled
    case pending
}

enum TierStatus: Equatable {
    case locked
    case unlocked
}

struct TierPurchaseHistory: Equatable, Codable {
    var transactions: IdentifiedArrayOf<TierTransaction> = []
}

extension TierPurchaseHistory {
    var productCounts: [TierProductID: Int] {
        var counts: [TierProductID: Int] = [:]
        for transaction in transactions {
            counts[transaction.productID, default: 0] += 1
        }
        return counts
    }

    var status: TierStatus {
        transactions.isEmpty ? .locked : .unlocked
    }
}

typealias TierTransactionID = UInt64 // Transaction.ID
struct TierTransaction: Equatable, Identifiable, Codable {
    let id: TierTransactionID
    let productID: TierProductID
    let purchaseDate: Date
    let originalPurchaseDate: Date
}

extension TierTransaction {
    init(_ transaction: Transaction) {
        id = transaction.id
        productID = transaction.productID
        purchaseDate = transaction.purchaseDate
        originalPurchaseDate = transaction.originalPurchaseDate
    }
}

struct TierProductsClient {
    var availableProducts: @Sendable () async throws -> IdentifiedArrayOf<TierProduct>
    var purchase: @Sendable (TierProduct) async throws -> TierPurchaseResult
    var purchaseHistory: @Sendable () -> TierPurchaseHistory
    var purchaseHistoryStream: @Sendable () -> AsyncStream<TierPurchaseHistory>
    var clearPurchaseHistory: @Sendable () -> Void
    var restorePurchases: @Sendable () async -> Void
    var monitorPurchases: @Sendable () async -> Void
}

extension TierProductsClient: DependencyKey {
    static var liveValue: TierProductsClient {
        let storeKitProducts: @Sendable () async throws -> IdentifiedArrayOf<Product> = {
            try await IdentifiedArray(uniqueElements: Product.products(for: TierProduct.localIDs))
        }
        let availableProducts: @Sendable () async throws -> IdentifiedArrayOf<TierProduct> = {
            try await IdentifiedArray(uniqueElements: storeKitProducts().compactMap(TierProduct.init))
        }
        @Dependency(\.tierPurchaseHistoryClient) var purchaseHistoryClient
        let loadedHistory = purchaseHistoryClient.get()
        let purchaseHistory: LockIsolated<TierPurchaseHistory> = .init(loadedHistory)
        let purchaseHistoryStream = AsyncStream.makeStream(of: TierPurchaseHistory.self)
        return TierProductsClient(
            availableProducts: availableProducts,
            purchase: { tierProduct in
                struct NoProductFoundError: Error {} // TODO: merge into errors
                guard let storeKitProduct = try await storeKitProducts()[id: tierProduct.id] else {
                    throw NoProductFoundError()
                }
                let result = try await storeKitProduct.purchase()
                switch result {
                case let .success(.verified(transaction)):
                    purchaseHistory.withValue {
                        $0.transactions.append(TierTransaction(transaction))
                        purchaseHistoryStream.continuation.yield($0)
                        try? purchaseHistoryClient.set($0)
                    }
                    await transaction.finish()
                    return .success
                case let .success(.unverified(transaction, error)):
                    XCTFail("Transaction was unverified(???): \(error.localizedDescription)")
                    purchaseHistory.withValue {
                        $0.transactions.append(TierTransaction(transaction))
                        purchaseHistoryStream.continuation.yield($0)
                        try? purchaseHistoryClient.set($0)
                    }
                    await transaction.finish()
                    return .success
                case .pending:
                    // Transaction waiting on SCA (Strong Customer Authentication) or approval from Ask to Buy
                    return .pending
                case .userCancelled:
                    return .userCancelled
                @unknown default:
                    return .userCancelled
                }
            },
            purchaseHistory: {
                purchaseHistory.value
            },
            purchaseHistoryStream: {
                purchaseHistoryStream.stream.eraseToStream()
            },
            clearPurchaseHistory: {
                purchaseHistory.withValue {
                    $0.transactions = []
                    purchaseHistoryStream.continuation.yield($0)
                    try? purchaseHistoryClient.set($0)
                }
            },
            restorePurchases: {
                try? await AppStore.sync()
            },
            monitorPurchases: {
                for await result in Transaction.updates {
                    switch result {
                    case let .unverified(transaction, _),
                         let .verified(transaction):
                        purchaseHistory.withValue {
                            $0.transactions.append(TierTransaction(transaction))
                            purchaseHistoryStream.continuation.yield($0)
                            try? purchaseHistoryClient.set($0)
                        }
                    }
                }
            }
        )
    }
}

extension TierProductsClient: TestDependencyKey {
    static let mockProducts: IdentifiedArrayOf<TierProduct> = .init(uniqueElements: [
        TierProduct(
            id: "tier01",
            displayName: "Test Product 01",
            displayPrice: "$1.23"
        ),
        TierProduct(
            id: "tier02",
            displayName: "Test Product 02",
            displayPrice: "$4.56"
        ),
        TierProduct(
            id: "tier03",
            displayName: "Test Product 03",
            displayPrice: "$7.89"
        ),
    ])

    static let previewValue: TierProductsClient = .liveValue

    static var testValue: TierProductsClient {
        Self(
            availableProducts: unimplemented("availableProducts"),
            purchase: unimplemented("purchase"),
            purchaseHistory: unimplemented("purchaseHistory"),
            purchaseHistoryStream: unimplemented("purchaseHistoryStream"),
            clearPurchaseHistory: unimplemented("clearPurchaseHistory"),
            restorePurchases: unimplemented("restorePurchases"),
            monitorPurchases: unimplemented("monitorPurchases")
        )
    }
}

extension DependencyValues {
    var tierProductsClient: TierProductsClient {
        get { self[TierProductsClient.self] }
        set { self[TierProductsClient.self] = newValue }
    }
}
