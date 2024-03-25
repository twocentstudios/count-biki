import ComposableArchitecture
import IdentifiedCollections
import SwiftUI

@Reducer struct AppIconFeature {
    @ObservableState struct State: Equatable {
        let appIcons: IdentifiedArrayOf<AppIcon>
        var selectedAppIcon: AppIcon?
        var isAppIconChangingAvailable: Bool

        init(isAppIconChangingAvailable: Bool) {
            @Dependency(\.appIconClient) var appIconClient
            appIcons = appIconClient.allIcons()
            selectedAppIcon = nil
            self.isAppIconChangingAvailable = isAppIconChangingAvailable
        }
    }

    enum Action: Equatable {
        case appIconTapped(AppIcon)
        case appIconSet(AppIcon)
        case onTask
    }

    @Dependency(\.appIconClient) var appIconClient
    @Dependency(\.continuousClock) var clock

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
                }
            }
        }
    }
}

struct AppIconView: View {
    let store: StoreOf<AppIconFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if store.isAppIconChangingAvailable {
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
                ForEach(store.appIcons) { appIcon in
                    Button {
                        store.send(.appIconTapped(appIcon))
                    }
                    label: {
                        Image(uiImage: UIImage(named: appIcon.iconName) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(6)
                            .shadow(color: Color.black.opacity(0.3), radius: 6)
                            .background {
                                if store.selectedAppIcon == appIcon {
                                    RoundedRectangle(cornerRadius: 26).strokeBorder(Color.accentColor, lineWidth: 6)
                                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                                }
                            }
                            .animation(.smooth(duration: 0.5), value: store.selectedAppIcon)
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isAppIconChangingAvailable)
                }
            }
            .padding()
        }
        .background { Color(.secondarySystemBackground).ignoresSafeArea() }
        .navigationTitle("App Icon")
        .task {
            store.send(.onTask)
        }
    }
}

#Preview {
    AppIconView(store: Store(initialState: .init(isAppIconChangingAvailable: true)) {
        AppIconFeature()
    })
    .fontDesign(.rounded)
}
