import StoreKit
import SwiftUI

import ComposableArchitecture

struct AboutFeature: Reducer {
    struct State: Equatable {}

    enum Action: Equatable {
        case doneButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .doneButtonTapped:
                return .run { _ in await dismiss() }
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
                    if false {
                        Section {
                            Label("Leave a tip", systemImage: "yensign.circle")
                            Label("Choose app icon", systemImage: "app.badge")
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

                    // TODO: add legal stuff links
                    if false {
                        Section {
                            Link(destination: URL(string: "example.com")!) {
                                Label("Licenses", systemImage: "note.text")
                            } // TODO: licenses
                            Link(destination: URL(string: "example.com")!) {
                                Label("Privacy policy", systemImage: "note.text")
                            } // TODO: privacy policy
                            Link(destination: URL(string: "example.com")!) {
                                Label("Terms and conditions", systemImage: "note.text")
                            } // TODO: terms and conditions
                        } header: {
                            Text("Legal")
                        }
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