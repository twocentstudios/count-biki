import StoreKit
import SwiftUI

import ComposableArchitecture

struct AppIconFeature: Reducer {
    struct State: Equatable {
        let appIcons: IdentifiedArrayOf<AppIcon>
        var selectedAppIcon: AppIcon?
        var isAppIconChangingAvailable: Bool

        init() {
            @Dependency(\.appIconClient) var appIconClient
            appIcons = appIconClient.allIcons()
            selectedAppIcon = nil
            isAppIconChangingAvailable = false // TODO: paywall
        }
    }

    enum Action: Equatable {
        case appIconTapped(AppIcon)
        case appIconSet(AppIcon)
        case onTask
    }

    @Dependency(\.appIconClient) var appIconClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    let currentAppIcon = await appIconClient.appIcon()
                    await send(.appIconSet(currentAppIcon))
                }
            case let .appIconTapped(tappedIcon):
                return .run { send in
                    do {
                        try await appIconClient.setAppIcon(tappedIcon)
                        await send(.appIconSet(tappedIcon))
                    } catch {
                        XCTFail("Unexpectedly couldn't update app icon.")
                    }
                }
            case let .appIconSet(tappedIcon):
                state.selectedAppIcon = tappedIcon
                return .none
            }
        }
    }
}

struct AboutFeature: Reducer {
    struct State: Equatable {
        var appIcon: AppIconFeature.State

        init(appIcon: AppIconFeature.State = .init()) {
            self.appIcon = appIcon
        }
    }

    enum Action: Equatable {
        case doneButtonTapped
        case appIcon(AppIconFeature.Action)
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Scope(state: \.appIcon, action: /Action.appIcon) {
            AppIconFeature()
        }
        Reduce { state, action in
            switch action {
            case .doneButtonTapped:
                return .run { _ in await dismiss() }
            case .appIcon:
                return .none
            }
        }
    }
}

struct AboutView: View {
    let store: StoreOf<AboutFeature>
    @Environment(\.requestReview) var requestReview

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                List {
                    Section {
                        VStack(spacing: 0) {
                            CountBikiView()
                                .frame(width: 100, height: 100)
                            Text("Count Biki")
                                .font(.largeTitle)
                                .bold()
                            Text("Master Japanese numbers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fontDesign(.default)
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // TODO: implement IAP
                    if true {
                        Section {
                            Label("Leave a tip", systemImage: "yensign.circle")
                            NavigationLink {
                                WithViewStore(store.scope(state: \.appIcon, action: { .appIcon($0) }), observe: { $0 }) { viewStore in
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
                                                        .shadow(color: Color.primary.opacity(0.3), radius: 6)
                                                        .background {
                                                            ZStack {
                                                                if viewStore.selectedAppIcon == appIcon {
                                                                    RoundedRectangle(cornerRadius: 26).strokeBorder(Color.accentColor, lineWidth: 6)
                                                                        .transition(AnyTransition.scale(scale: 0.1).combined(with: .opacity))
                                                                }
                                                            }
                                                            .animation(.smooth(duration: 0.7), value: viewStore.selectedAppIcon)
                                                        }
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
                            } label: {
                                Label("Choose app icon", systemImage: "app.badge")
                            }

                            Label("Choose Biki's outfit", systemImage: "tshirt")
                        } header: {
                            Text("Transylvania Tier")
                        } footer: {
                            Text("Leave any size tip to join Transylvania Tier. Unlock whimsical benefits and support the app's development.")
                        }
                    }

                    Section {
                        Link(destination: MailTo.reportBug) {
                            Label("Report a bug", systemImage: "ladybug")
                        }
                        Link(destination: MailTo.reportContentError) {
                            Label("Report a content error", systemImage: "exclamationmark.bubble")
                        }
                        Link(destination: MailTo.suggestTopic) {
                            Label("Suggest a new Topic", systemImage: "lightbulb")
                        }
                        Link(destination: MailTo.sendNiceMessage) {
                            Label("Send the developer a nice message", systemImage: "face.smiling")
                        }
                        Button {
                            requestReview()
                        } label: {
                            Label("Rate on the App Store", systemImage: "star")
                        }
                        Link(destination: URL(string: "https://apps.apple.com/app/id\(appStoreAppID)?action=write-review")!) {
                            Label("Review on the App Store", systemImage: "square.and.pencil")
                        }
                    } header: {
                        Text("Support")
                    }

                    Section {
                        VStack {
                            Image("ct_avatar_about")
                                .resizable()
                                .clipShape(Circle())
                                .padding(2)
                                .background {
                                    Circle().fill(Color(.systemBackground))
                                    Circle().stroke(Color(.secondarySystemBackground))
                                }
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("Hi, I'm Chris.")
                                .font(.title3)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("My independent development shop is called twocentstudios. I hope you enjoy the app.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        Link(destination: URL(string: "https://twocentstudios.com")!) {
                            Label("twocentstudios.com", systemImage: "globe")
                        }
                        Link(destination: URL(string: "https://hachyderm.io/@twocentstudios")!) {
                            Label("Mastodon", systemImage: "globe")
                        }
                        Link(destination: URL(string: "https://twitter.com/twocentstudios")!) {
                            Label("Twitter", systemImage: "globe")
                        }
                    } header: {
                        Text("About")
                    }

                    Section {
                        NavigationLink {
                            ScrollView {
                                Text(acknowledgements()).padding()
                            }
                            .navigationTitle("Licenses")
                        } label: {
                            Label("Licenses", systemImage: "note.text")
                        }
                        Link(destination: URL(string: "https://twocentstudios.com/apps/countbiki/privacy-policy")!) {
                            Label("Privacy policy", systemImage: "note.text")
                        }
                    } header: {
                        Text("Legal")
                    }
                }
                .listStyle(.insetGrouped)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("About")
                .toolbar {
                    ToolbarItem(placement: .principal) { Text("") }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewStore.send(.doneButtonTapped)
                        } label: {
                            Label("Done", systemImage: "xmark.circle")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }
}

#Preview {
    AboutView(
        store: Store(initialState: .init()) {
            AboutFeature()
        })
        .fontDesign(.rounded)
}

// $ brew install licenseplist
// $ cd ~/code/count
// $ license-plist --markdown-path count/acknowledgements.md --single-page --force --output-path /tmp --suppress-opening-directory
private func acknowledgements() -> String {
    guard let path = Bundle.main.path(forResource: "acknowledgements", ofType: "md"),
          let string = try? String(contentsOfFile: path)
    else {
        XCTFail("acknowledgements file is missing")
        return ""
    }
    return string
}

@MainActor private enum MailTo {
    static let supportAddress = "support@twocentstudios.com"
    static let reportBug = mailToURL(
        to: supportAddress,
        subject: "Count Biki: Report bug",
        body: debugInfoBody()
    )
    static let reportContentError = mailToURL(
        to: supportAddress,
        subject: "Count Biki: Report content error",
        body: debugInfoBody()
    )
    static let suggestTopic = mailToURL(
        to: supportAddress,
        subject: "Count Biki: Suggest a topic",
        body: debugInfoBody()
    )
    static let sendNiceMessage = mailToURL(
        to: supportAddress,
        subject: "Count Biki: A nice message",
        body: ""
    )

    private static func mailToURL(to: String, subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url!
    }

    @MainActor private static func debugInfoBody() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "(unknown)"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "(unknown)"
        let model = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        return "\n\n\n\n-------------------\nDEBUG INFO:\nApp Version: \(version)\nApp Build: \(build)\nDevice: \(model)\nOS Version: \(systemVersion)"
    }
}
