import ComposableArchitecture
import StoreKit
import SwiftUI

@Reducer struct AboutFeature {
    @ObservableState struct State: Equatable, Sendable {
        var appIcon: AppIconFeature.State
        var transylvaniaTier: TransylvaniaTierFeature.State

        init() {
            @Dependency(TierProductsClient.self) var tierProductsClient
            let history = tierProductsClient.purchaseHistory()
            appIcon = .init(isAppIconChangingAvailable: history.status == .unlocked)
            transylvaniaTier = .init(tierHistory: history)
        }
    }

    enum Action: Equatable, ViewAction {
        case appIcon(AppIconFeature.Action)
        case onPurchaseHistoryUpdated(TierPurchaseHistory)
        case transylvaniaTier(TransylvaniaTierFeature.Action)
        case view(View)

        enum View {
            case doneButtonTapped
            case onTask
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(TierProductsClient.self) var tierProductsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.appIcon, action: \.appIcon) {
            AppIconFeature()
        }
        Scope(state: \.transylvaniaTier, action: \.transylvaniaTier) {
            TransylvaniaTierFeature()
        }
        Reduce { state, action in
            switch action {
            case .appIcon:
                return .none
            case .transylvaniaTier:
                return .none
            case let .onPurchaseHistoryUpdated(newHistory):
                state.appIcon.isAppIconChangingAvailable = newHistory.status == .unlocked
                state.transylvaniaTier.tierHistory = newHistory
                return .none
            case .view(.doneButtonTapped):
                return .run { _ in await dismiss() }
            case .view(.onTask):
                return .run { send in
                    for await newHistory in tierProductsClient.purchaseHistoryStream() {
                        await send(.onPurchaseHistoryUpdated(newHistory))
                    }
                }
            }
        }
    }
}

@ViewAction(for: AboutFeature.self)
struct AboutView: View {
    let store: StoreOf<AboutFeature>
    @Environment(\.requestReview) var requestReview

    var body: some View {
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

                Section {
                    NavigationLink {
                        TranslyvaniaTierView(store: store.scope(state: \.transylvaniaTier, action: \.transylvaniaTier))
                    } label: {
                        Label("Leave a tip", systemImage: "yensign.circle")
                    }
                    NavigationLink {
                        AppIconView(store: store.scope(state: \.appIcon, action: \.appIcon))
                    } label: {
                        Label("Choose app icon", systemImage: store.transylvaniaTier.hasTranslyvaniaTier ? "app.badge" : "lock")
                    }
                    if false { // TODO: choose Biki's outfit
                        Label("Choose Biki's outfit", systemImage: "tshirt")
                    }
                } header: {
                    Text("Transylvania Tier")
                } footer: {
                    if store.transylvaniaTier.hasTranslyvaniaTier {
                        Text("You've unlocked Translyvania Tier. Thanks for your support!")
                    } else {
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
                .tint(Color(.label))

                Section {
                    VStack {
                        Image("ct_avatar_about")
                            .resizable()
                            .clipShape(Circle())
                            .padding(2)
                            .background { Circle().fill(Color(.systemBackground), stroke: Color(.secondarySystemBackground)) }
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
                .tint(Color(.label))

                Section {
                    NavigationLink {
                        ScrollView {
                            Text(acknowledgements()).padding()
                        }
                        .navigationTitle("Licenses")
                    } label: {
                        Label("Licenses", systemImage: "note.text")
                    }
                    Link(destination: GlobalURL.privacyPolicy) {
                        Label("Privacy policy", systemImage: "note.text")
                    }
                } header: {
                    Text("Legal")
                }
                .tint(Color(.label))
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .principal) { Text("") }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        send(.doneButtonTapped)
                    } label: {
                        Label("Done", systemImage: "xmark.circle")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                send(.onTask)
            }
        }
    }
}

#Preview {
    AboutView(
        store: Store(initialState: .init()) {
            AboutFeature()
                ._printChanges()
        }
    )
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

enum GlobalURL {
    static let privacyPolicy = URL(string: "https://twocentstudios.com/apps/countbiki/privacy-policy")!
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
