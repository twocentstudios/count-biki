import ComposableArchitecture
import SwiftUI

struct TransylvaniaTierFeature: Reducer {
    struct State: Equatable {
        var tierHistory: TierPurchaseHistory
        var availableProducts: DataState<IdentifiedArrayOf<TierProduct>> = .initialized
        let canMakePayments: Bool = true // TODO: AppStore.canMakePayments

        var hasTranslyvaniaTier: Bool {
            if case .unlocked = tierHistory.status { return true }
            return false
        }

        init() {
            @Dependency(\.tierProductsClient) var tierProductsClient
            tierHistory = tierProductsClient.purchaseHistory()
        }
    }

    enum Action: Equatable {
        case availableProductsUpdated(DataState<IdentifiedArrayOf<TierProduct>>)
        case clearPurchaseHistory
        case onTask
        case purchaseButtonTapped(TierProduct)
        case retryLoadProductsTapped
        case restorePurchasesTapped
        case tierHistoryUpdated(TierPurchaseHistory)
    }

    @Dependency(\.tierProductsClient) var tierProductsClient
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .availableProductsUpdated(products):
                state.availableProducts = products
                return .none
            case .clearPurchaseHistory:
                #if DEBUG
                    tierProductsClient.clearPurchaseHistory()
                #endif
                return .none
            case .onTask:
                return .run { send in
                    await loadProducts(send: send)
                    for await newHistory in tierProductsClient.purchaseHistoryStream() {
                        await send(.tierHistoryUpdated(newHistory))
                    }
                }
            case let .purchaseButtonTapped(product):
                return .run { send in
                    let result = try await tierProductsClient.purchase(product)
                    switch result {
                    case .success:
                        break
                    // TODO: confetti?
                    case .userCancelled:
                        break // Do nothing
                    case .pending:
                        break
                        // TODO: show message about pending status?
                    }
                }
            case .retryLoadProductsTapped:
                return .run { await loadProducts(send: $0) }
            case .restorePurchasesTapped:
                return .run { _ in
                    await tierProductsClient.restorePurchases()
                }
            case let .tierHistoryUpdated(tierHistory):
                state.tierHistory = tierHistory
                return .none
            }
        }
    }

    private func loadProducts(send: Send<TransylvaniaTierFeature.Action>) async {
        do {
            let products = try await tierProductsClient.availableProducts()
            let sortedProducts = IdentifiedArrayOf(uniqueElements: products.sorted(by: { $0.price < $1.price }))
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
                    if viewStore.availableProducts.errorMessage != nil {
                        GroupBox {
                            Text("There was a problem loading the available tips.")
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
                        VStack(spacing: 16) {
                            ForEach(availableProducts) { product in
                                TipButton(
                                    imageName: nil,
                                    title: product.item?.title,
                                    subtitle: product.displayName,
                                    description: product.item?.description,
                                    price: product.displayPrice,
                                    action: {
                                        viewStore.send(.purchaseButtonTapped(product))
                                    }
                                )
                            }
                            Button {
                                viewStore.send(.restorePurchasesTapped)
                            } label: {
                                Text("Restore Purchases")
                                    .font(.callout)
                            }
                            .padding(.vertical, 0)
                            HStack(spacing: 20) {
                                Button {
                                    // TODO: TOS
                                } label: {
                                    Text("Terms of Service")
                                        .font(.callout)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    // TODO: Privacy Policy
                                } label: {
                                    Text("Privacy Policy")
                                        .font(.callout)
                                }
                                .buttonStyle(.borderless)
                            }
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
        store: Store(initialState: TransylvaniaTierFeature.State()) {
            TransylvaniaTierFeature()
                ._printChanges()
        }
    )
    .fontDesign(.rounded)
}
