import ComposableArchitecture
import IdentifiedCollections
import SwiftUI

struct AppIconFeature: Reducer {
    struct State: Equatable {
        let appIcons: IdentifiedArrayOf<AppIcon>
        var selectedAppIcon: AppIcon?
        var isAppIconChangingAvailable: Bool

        init() {
            @Dependency(\.appIconClient) var appIconClient
            @Dependency(\.tierProductsClient.purchaseHistory) var purchaseHistory
            appIcons = appIconClient.allIcons()
            selectedAppIcon = nil
            isAppIconChangingAvailable = purchaseHistory().status == .unlocked
        }
    }

    enum Action: Equatable {
        case appIconTapped(AppIcon)
        case appIconSet(AppIcon)
        case onPurchaseHistoryUpdated(TierPurchaseHistory)
        case onTask
    }

    @Dependency(\.appIconClient) var appIconClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.tierProductsClient.purchaseHistoryStream) var purchaseHistoryStream

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .appIconTapped(tappedIcon):
                guard let currentIcon = state.selectedAppIcon else { return .none }
                return .run { send in
                    do {
                        await send(.appIconSet(tappedIcon))
                        try await clock.sleep(for: .milliseconds(500)) // wait for selection animation
                        try await appIconClient.setAppIcon(tappedIcon)
                    } catch {
                        await send(.appIconSet(currentIcon))
                        XCTFail("Unexpectedly couldn't update app icon.")
                    }
                }
            case let .appIconSet(tappedIcon):
                state.selectedAppIcon = tappedIcon
                return .none
            case .onTask:
                return .run { send in
                    let currentAppIcon = await appIconClient.appIcon()
                    await send(.appIconSet(currentAppIcon))
                    for await newHistory in purchaseHistoryStream() {
                        await send(.onPurchaseHistoryUpdated(newHistory))
                    }
                }
            case let .onPurchaseHistoryUpdated(newHistory):
                state.isAppIconChangingAvailable = newHistory.status == .unlocked
                return .none
            }
        }
    }
}

struct AppIconView: View {
    let store: StoreOf<AppIconFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 6) {
                    if viewStore.isAppIconChangingAvailable {
                        Text("You've unlocked Transylvania Tier 🥳")
                            .font(.headline)
                        Text("Select any app icon below")
                            .font(.subheadline)
                    } else {
                        Text("Unlock Transylvania Tier to change the app icon")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .center), count: 3)) {
                    ForEach(viewStore.appIcons) { appIcon in
                        Button {
                            viewStore.send(.appIconTapped(appIcon))
                        }
                        label: {
                            Image(uiImage: UIImage(named: appIcon.iconName) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(6)
                                .shadow(color: Color.black.opacity(0.3), radius: 6)
                                .background {
                                    if viewStore.selectedAppIcon == appIcon {
                                        RoundedRectangle(cornerRadius: 26).strokeBorder(Color.accentColor, lineWidth: 6)
                                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                                    }
                                }
                                .animation(.smooth(duration: 0.5), value: viewStore.selectedAppIcon)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewStore.isAppIconChangingAvailable)
                    }
                }
                .padding()
            }
            .background { Color(.secondarySystemBackground).ignoresSafeArea() }
            .navigationTitle("App Icon")
            .task {
                viewStore.send(.onTask)
            }
        }
    }
}

#Preview {
    AppIconView(store: Store(initialState: .init()) {
        AppIconFeature()
    } withDependencies: {
        $0.tierProductsClient.purchaseHistory = { TierPurchaseHistory(transactions: IdentifiedArrayOf(uniqueElements: [TierTransaction.mock])) }
    })
    .fontDesign(.rounded)
}
