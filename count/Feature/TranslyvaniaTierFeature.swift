import ComposableArchitecture
import SwiftUI

struct TransylvaniaTierFeature: Reducer {
    struct State: Equatable {
        var tierStatus: TierStatus
        var availableProducts: IdentifiedArrayOf<TierProduct> = []
        let canMakePayments: Bool = true // TODO: AppStore.canMakePayments

        var hasTranslyvaniaTier: Bool {
            if case .unlocked = tierStatus { return true }
            return false
        }

        init() {
            @Dependency(\.transylvaniaTierClient) var transylvaniaTierClient
            tierStatus = transylvaniaTierClient.tierStatus()
        }
    }

    enum Action: Equatable {
        case availableProductsUpdated(IdentifiedArrayOf<TierProduct>)
        case onTask
        case restorePurchasesTapped
        case tierStatusUpdated(TierStatus)
    }

    @Dependency(\.transylvaniaTierClient) var transylvaniaTierClient
    @Dependency(\.tierProductsClient) var tierProductsClient
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .availableProductsUpdated(let products):
                state.availableProducts = products
                return .none
            case .onTask:
                return .run { send in
                    if let products = try? await tierProductsClient.availableProducts() {
                        // TODO: handle error
                        await send(.availableProductsUpdated(products))
                    }
                    for await newStatus in transylvaniaTierClient.tierStatusStream() {
                        await send(.tierStatusUpdated(newStatus))
                    }
                }
            case .restorePurchasesTapped:
                return .run { _ in
                    await tierProductsClient.restorePurchases()
                }
            case let .tierStatusUpdated(tierStatus):
                state.tierStatus = tierStatus
                return .none
            }
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
                        if viewStore.hasTranslyvaniaTier {
                            Text("You've unlocked...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Translyvania Tier")
                                .font(.largeTitle)
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(colors: [Color.red, Color.orange, Color.yellow], startPoint: .bottomLeading, endPoint: .topTrailing))
                            Text("Thanks for supporting development")
                                .fontDesign(.default)
                                .italic()
                            Text("If you find Count Biki useful, you're welcome to leave another tip :)")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Leave any size tip to unlock...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Translyvania Tier")
                                .font(.largeTitle)
                                .fontWeight(.black)
                                .foregroundStyle(LinearGradient(colors: [Color.red, Color.orange, Color.yellow], startPoint: .bottomLeading, endPoint: .topTrailing))
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(Image(systemName: "1.circle"))  Choose your favorite app icon")
                                Text("\(Image(systemName: "2.circle"))  Support ongoing development")
                            }
                            .font(.headline)
                            .padding(.trailing, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    VStack(spacing: 16) {
                        ForEach(viewStore.availableProducts) { product in
                            TipButton(imageName: nil, title: product.displayName, price: product.displayPrice, action: nil)
                        }
//                        TipButton(imageName: nil, title: "Atomic red carrot tip", price: "$0.99")
//                        TipButton(imageName: nil, title: "Sunblock tip", price: "$4.99")
//                        TipButton(imageName: nil, title: "Coffin polish tip", price: "$19.99")
                        Button {
                            viewStore.send(.restorePurchasesTapped)
                        } label: {
                            Text("Restore Purchases")
                                .font(.callout)
                        }
                        .padding(.vertical, 0)
                        HStack(spacing: 20) {
                            Button {} label: {
                                Text("Terms of Service")
                                    .font(.callout)
                            }
                            .buttonStyle(.borderless)
                            Button {} label: {
                                Text("Privacy Policy")
                                    .font(.callout)
                            }
                            .buttonStyle(.borderless)
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
    let title: String
    let price: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 0) {
                if let imageName {
                    Image(imageName)
                        .padding(.trailing, 10)
                }
                Text(title)
                    .font(.title3)
                    .fontWeight(.black)
                    .multilineTextAlignment(.leading)
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
