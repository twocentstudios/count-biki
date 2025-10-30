import Combine
import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import StoreKit

typealias TierProductID = String
struct TierProduct: Equatable, Identifiable {
    let id: TierProductID
    let displayName: String
    let displayPrice: String
    let price: Decimal
}

extension TierProductID {
    static let tip001: Self = "countbiki_tip_001"
    static let tip002: Self = "countbiki_tip_002"
    static let tip003: Self = "countbiki_tip_003"
}

struct TierProductItem: Equatable {
    let title: String
    let description: String
    // let sceneName: String
}

extension TierProduct {
    static let localIDs: [TierProductID] = [.tip001, .tip002, .tip003]

    var item: TierProductItem? {
        switch id {
        case .tip001: .init(title: "Atomic Red Carrot", description: "A delicious, blood-red carrot preferred by vampiric rabbits.")
        case .tip002: .init(title: "Vampire Sunblock", description: "It's marketed as specially formulated for vampires, but its effectiveness has been questioned.")
        case .tip003: .init(title: "Ornate Mirror", description: "Not useful for reflecting oneself, but a great decorative piece for any room.")
        default: nil
        }
    }
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
        price = product.price
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
    static let storageKey = "TierPurchaseHistoryClient_PurchaseHistory"

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
    static let mock: Self = TierTransaction(id: 0, productID: .tip001, purchaseDate: .distantPast, originalPurchaseDate: .distantPast)
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
    var allowsPurchases: @Sendable () -> Bool
}

extension TierProductsClient: DependencyKey {
    static var liveValue: TierProductsClient {
        let storeKitProducts: @Sendable () async throws -> IdentifiedArrayOf<Product> = {
            try await IdentifiedArray(uniqueElements: Product.products(for: TierProduct.localIDs))
        }
        let availableProducts: @Sendable () async throws -> IdentifiedArrayOf<TierProduct> = {
            try await IdentifiedArray(uniqueElements: storeKitProducts().compactMap(TierProduct.init))
        }
        let sharedPurchaseHistory = Shared(
            wrappedValue: TierPurchaseHistory(),
            .appStorage(TierPurchaseHistory.storageKey)
        )
        func appendTransaction(_ transaction: Transaction) {
            sharedPurchaseHistory.withLock { history in
                history.transactions.append(TierTransaction(transaction))
            }
        }
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
                    appendTransaction(transaction)
                    await transaction.finish()
                    return .success
                case let .success(.unverified(transaction, error)):
                    XCTFail("Transaction was unverified(???): \(error.localizedDescription)")
                    appendTransaction(transaction)
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
                sharedPurchaseHistory.wrappedValue
            },
            purchaseHistoryStream: {
                let shared = sharedPurchaseHistory
                return AsyncStream { continuation in
                    let task = Task {
                        for await newValue in shared.publisher.values {
                            continuation.yield(newValue)
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            clearPurchaseHistory: {
                sharedPurchaseHistory.withLock { history in
                    history.transactions = []
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
                        appendTransaction(transaction)
                    }
                }
            },
            allowsPurchases: {
                AppStore.canMakePayments
            }
        )
    }
}

extension TierProductsClient: TestDependencyKey {
    static let mockProducts: IdentifiedArrayOf<TierProduct> = .init(uniqueElements: [
        TierProduct(
            id: "tier01",
            displayName: "Test Product 01",
            displayPrice: "$1.23",
            price: 123
        ),
        TierProduct(
            id: "tier02",
            displayName: "Test Product 02",
            displayPrice: "$4.56",
            price: 456
        ),
        TierProduct(
            id: "tier03",
            displayName: "Test Product 03",
            displayPrice: "$7.89",
            price: 789
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
            monitorPurchases: unimplemented("monitorPurchases"),
            allowsPurchases: unimplemented("allowsPurchases")
        )
    }
}

extension DependencyValues {
    var tierProductsClient: TierProductsClient {
        get { self[TierProductsClient.self] }
        set { self[TierProductsClient.self] = newValue }
    }
}
