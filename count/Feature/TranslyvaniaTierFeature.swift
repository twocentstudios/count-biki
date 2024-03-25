import ComposableArchitecture
import SwiftUI

@Reducer struct TransylvaniaTierFeature {
    struct State: Equatable, Sendable {
        @PresentationState var alert: AlertState<Never>?
        var tierHistory: TierPurchaseHistory
        var availableProducts: DataState<IdentifiedArrayOf<TierProduct>> = .initialized
        var confettiAnimation: Int = 0
        var isPurchasingProductId: TierProduct.ID?

        var hasTranslyvaniaTier: Bool {
            if case .unlocked = tierHistory.status { return true }
            return false
        }
    }

    enum Action: Equatable {
        case alert(PresentationAction<Never>)
        case availableProductsUpdated(DataState<IdentifiedArrayOf<TierProduct>>)
        case clearPurchaseHistory
        case onPurchaseFailure(EquatableError)
        case onPurchaseSuccess
        case onPurchaseCancelled
        case onTask
        case purchaseButtonTapped(TierProduct)
        case retryLoadProductsTapped
        case restorePurchasesTapped
    }

    @Dependency(\.tierProductsClient) var tierProductsClient
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert:
                return .none
            case let .availableProductsUpdated(products):
                state.availableProducts = products
                return .none
            case .clearPurchaseHistory:
                #if DEBUG
                    tierProductsClient.clearPurchaseHistory()
                #endif
                return .none
            case let .onPurchaseFailure(error):
                state.alert = .init(title: { TextState("Error") }, message: { TextState(error.localizedDescription) })
                state.isPurchasingProductId = nil
                return .none
            case .onPurchaseCancelled:
                state.isPurchasingProductId = nil
                return .none
            case .onPurchaseSuccess:
                state.confettiAnimation += 1
                state.isPurchasingProductId = nil
                return .none
            case .onTask:
                return .run { send in
                    await loadProducts(send: send)
                }
            case let .purchaseButtonTapped(product):
                guard state.isPurchasingProductId == nil else {
                    XCTFail("A purchase is already in progress")
                    return .none
                }
                state.isPurchasingProductId = product.id
                return .run { send in
                    let result = try await tierProductsClient.purchase(product)
                    switch result {
                    case .success:
                        await send(.onPurchaseSuccess)
                    case .userCancelled:
                        // Do nothing
                        await send(.onPurchaseCancelled)
                    case .pending:
                        // TODO: show message about pending status?
                        await send(.onPurchaseCancelled)
                    }
                } catch: { error, send in
                    await send(.onPurchaseFailure(error.toEquatableError()))
                }
            case .retryLoadProductsTapped:
                return .run { await loadProducts(send: $0) }
            case .restorePurchasesTapped:
                return .run { _ in
                    await tierProductsClient.restorePurchases()
                }
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func loadProducts(send: Send<TransylvaniaTierFeature.Action>) async {
        do {
            guard tierProductsClient.allowsPurchases() else {
                struct PurchasesNotAllowedError: LocalizedError {
                    var errorDescription: String? { "Purchases are not allowed on this device." }
                }
                throw PurchasesNotAllowedError()
            }
            let products = try await tierProductsClient.availableProducts()
            let sortedProducts = IdentifiedArrayOf(uniqueElements: products.sorted(by: { $0.price < $1.price }))
            guard !products.isEmpty else {
                struct NoProductsError: LocalizedError {
                    var errorDescription: String? { "No items are currently available for purchase." }
                }
                throw NoProductsError()
            }
            await send(.availableProductsUpdated(.loaded(sortedProducts)))
        } catch {
            await send(.availableProductsUpdated(.loadingFailed(error.toEquatableError())))
        }
    }
}

struct TranslyvaniaTierView: View {
    let store: StoreOf<TransylvaniaTierFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Text(viewStore.hasTranslyvaniaTier ? "You've unlocked..." : "Leave any size tip to unlock...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Translyvania Tier")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundStyle(LinearGradient(colors: [Color.red, Color.orange, Color.yellow], startPoint: .bottomLeading, endPoint: .topTrailing))
                            .confettiCannon(counter: .constant(viewStore.confettiAnimation), num: 85, confettiSize: 7, rainHeight: 1000, fadesOut: false, opacity: 1.0, openingAngle: .degrees(20), closingAngle: .degrees(160), radius: 180, repetitions: 0, repetitionInterval: 2.0)
                        if viewStore.hasTranslyvaniaTier {
                            Text("Thanks for supporting development")
                                .fontDesign(.default)
                                .italic()
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(Image(systemName: "1.circle"))  Choose your favorite app icon")
                            Text("\(Image(systemName: "2.circle"))  Support ongoing development")
                        }
                        .font(.headline)
                        .padding(.trailing, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .animation(.default, value: viewStore.hasTranslyvaniaTier)
                    if viewStore.availableProducts.isLoading {
                        ProgressView().padding()
                    }
                    if let error = viewStore.availableProducts.errorMessage {
                        GroupBox {
                            Text(error)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                            Button("Try Again") {
                                viewStore.send(.retryLoadProductsTapped)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if let availableProducts = viewStore.availableProducts.value {
                        let productCounts = viewStore.tierHistory.productCounts
                        VStack(spacing: 16) {
                            ForEach(availableProducts) { product in
                                let count = productCounts[product.id] ?? 0
                                TipButton(
                                    imageName: nil,
                                    title: product.item?.title,
                                    subtitle: product.displayName,
                                    description: product.item?.description,
                                    price: product.displayPrice,
                                    purchaseCount: (count > 0) ? "\(count)" : nil,
                                    isBeingPurchased: product.id == viewStore.isPurchasingProductId,
                                    action: {
                                        viewStore.send(.purchaseButtonTapped(product))
                                    }
                                )
                                .disabled(viewStore.isPurchasingProductId != nil)
                            }
                            .alert(store: store.scope(state: \.$alert, action: \.alert))
                            HStack(spacing: 20) {
                                Button {
                                    viewStore.send(.restorePurchasesTapped)
                                } label: {
                                    Text("Restore Purchases")
                                        .font(.callout)
                                }
                                Link("Privacy Policy", destination: GlobalURL.privacyPolicy)
                                    .font(.callout)
                            }
                            .padding(.vertical, 0)
                            #if DEBUG
                                Button {
                                    viewStore.send(.clearPurchaseHistory)
                                } label: {
                                    Text("[DEBUG] Clear Purchase History")
                                        .font(.callout)
                                }
                            #endif
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Translyvania Tier")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                await viewStore.send(.onTask).finish()
            }
        }
    }
}

struct TipButton: View {
    let imageName: String?
    let title: String?
    let subtitle: String
    let description: String?
    let price: String
    let purchaseCount: String?
    let isBeingPurchased: Bool
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading) {
            Button {
                action?()
            } label: {
                HStack(spacing: 0) {
                    if let imageName {
                        Image(imageName)
                            .padding(.trailing, 10)
                    }
                    VStack(alignment: .leading) {
                        if let title {
                            Text(title)
                                .font(.title3)
                                .fontWeight(.black)
                                .multilineTextAlignment(.leading)
                        }
                        Text(subtitle)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 16)
                    if isBeingPurchased {
                        ProgressView()
                            .padding(.horizontal, 6)
                    }
                    Text(price)
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2)
                        }
                        .background(Material.ultraThick)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
                .overlay(alignment: .bottom) {
                    if let purchaseCount {
                        Text("Purchased: \(purchaseCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                    }
                }
                .background { RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemFill)) }
            }
            .buttonStyle(.plain)
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    TranslyvaniaTierView(
        store: Store(initialState: TransylvaniaTierFeature.State(tierHistory: .init(transactions: IdentifiedArray(uniqueElements: [.mock])))) {
            TransylvaniaTierFeature()
                ._printChanges()
        }
    )
    .fontDesign(.rounded)
}
