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
    static let localIDs: [TierProductID] = ["tip01", "tip02", "tip03"]
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
    case unknown
    case locked
    case unlocked(IdentifiedArrayOf<TierProduct>)
}

enum TierProductUpdate: Equatable {
    case added(TierProduct)
    case removed(TierProduct)
}

struct TierProductsClient {
    var availableProducts: @Sendable () async throws -> IdentifiedArrayOf<TierProduct>
    var purchase: @Sendable (TierProduct) async throws -> TierPurchaseResult
    var restorePurchases: @Sendable () async -> Void
    var currentStatus: @Sendable () async -> TierStatus
    var monitorPurchases: @Sendable () -> AsyncStream<Void>
}

extension TierProductsClient: DependencyKey {
    static var liveValue: TierProductsClient {
        let storeKitProducts: @Sendable () async throws -> IdentifiedArrayOf<Product> = {
            try await IdentifiedArray(uniqueElements: Product.products(for: TierProduct.localIDs))
        }
        let availableProducts: @Sendable () async throws -> IdentifiedArrayOf<TierProduct> = {
            try await IdentifiedArray(uniqueElements: storeKitProducts().compactMap(TierProduct.init))
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
                    await transaction.finish()
                    return .success
                case let .success(.unverified(transaction, error)):
                    XCTFail("Transaction was unverified(???): \(error.localizedDescription)")
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
            restorePurchases: {
                try? await AppStore.sync()
            },
            currentStatus: {
                var purchaseIds: Set<TierProductID> = []
                for await result in Transaction.currentEntitlements {
                    guard case let .verified(transaction) = result else { continue }

                    if transaction.revocationDate == nil {
                        purchaseIds.insert(transaction.productID)
                    } else {
                        // TODO: does this make sense?
                        purchaseIds.remove(transaction.productID)
                    }
                }
                guard let products = try? await availableProducts() else { return .unknown }
                let purchasedProducts = purchaseIds.compactMap { products[id: $0] }
                if purchasedProducts.isEmpty {
                    return .locked
                } else {
                    return .unlocked(.init(uniqueElements: purchasedProducts))
                }
            },
            monitorPurchases: {
                Transaction.updates.map { _ in () }.eraseToStream()
            }
        )
    }
}
extension DependencyValues {
    var tierProductsClient: TierProductsClient {
        get { self[TierProductsClient.self] }
        set { self[TierProductsClient.self] = newValue }
    }
}
