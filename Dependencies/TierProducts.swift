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
    case unknown
    case locked
    case unlocked([TierProduct])
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
                    }
                }
                guard let products = try? await availableProducts() else { return .unknown }
                let purchasedProducts = purchaseIds.compactMap { products[id: $0] }
                if purchasedProducts.isEmpty {
                    return .locked
                } else {
                    return .unlocked(purchasedProducts)
                }
            },
            monitorPurchases: {
                Transaction.updates.map { _ in () }.eraseToStream()
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
            restorePurchases: unimplemented("restorePurchases"),
            currentStatus: unimplemented("currentStatus"),
            monitorPurchases: unimplemented("monitorPurchases")
        )
    }

    static var mock: TierProductsClient {
        let products: LockIsolated<[TierProduct]> = .init([])
        return Self(
            availableProducts: { mockProducts },
            purchase: { product in
                products.withValue { value in
                    value.append(product)
                }
                print("count", products.value.count)
                return .success
            },
            restorePurchases: {},
            currentStatus: {
                if products.value.isEmpty {
                    return .locked
                } else {
                    return .unlocked(products.value)
                }
            },
            monitorPurchases: {
                print("addddadadasdfa")
                let streamPair = AsyncStream.makeStream(of: Void.self)
                let handle = Task {
                    @Dependency(\.continuousClock) var clock
                    while true {
                        try! await clock.sleep(for: .seconds(1))
                        streamPair.continuation.yield()
                    }
                }
                streamPair.continuation.onTermination = { _ in
                    handle.cancel()
                }
                return streamPair.stream
            }
        )
    }

    static var unlocked: TierProductsClient {
        Self(
            availableProducts: { mockProducts },
            purchase: { _ in .success },
            restorePurchases: {},
            currentStatus: { .unlocked(mockProducts.elements) },
            monitorPurchases: { AsyncStream { _ in }}
        )
    }

    static var locked: TierProductsClient {
        Self(
            availableProducts: { mockProducts },
            purchase: { _ in .success },
            restorePurchases: {},
            currentStatus: { .locked },
            monitorPurchases: { AsyncStream { _ in }}
        )
    }

    static var unknown: TierProductsClient {
        Self(
            availableProducts: { mockProducts },
            purchase: { _ in .success },
            restorePurchases: {},
            currentStatus: { .unknown },
            monitorPurchases: { AsyncStream { _ in }}
        )
    }
}

extension DependencyValues {
    var tierProductsClient: TierProductsClient {
        get { self[TierProductsClient.self] }
        set { self[TierProductsClient.self] = newValue }
    }
}
