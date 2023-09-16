import StoreKit
import SwiftUI

struct AboutView: View {
    @Environment(\.requestReview) var requestReview

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack {
                        Image(systemName: "circle")
                            .resizable()
                            .foregroundColor(Color(.label))
                            .frame(width: 80, height: 80)
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
                    Label("Leave a tip", systemImage: "yensign.circle")
                    Label("Choose app icon", systemImage: "app.badge")
                    Label("Choose Biki's outfit", systemImage: "tshirt")
                } header: {
                    Text("Transylvania Tier")
                } footer: {
                    Text("Leave any size tip to join Transylvania Tier. Unlock whimsical benefits and support the app's development.")
                }

                Section {
                    Link(destination: URL(string: "example.com")!) {
                        Label("Report a bug", systemImage: "ladybug")
                    }
                    Link(destination: URL(string: "example.com")!) {
                        Label("Report a content error", systemImage: "exclamationmark.bubble")
                    }
                    Link(destination: URL(string: "example.com")!) {
                        Label("Suggest a new Topic", systemImage: "lightbulb")
                    }
                    Link(destination: URL(string: "example.com")!) {
                        Label("Send me a nice message", systemImage: "face.smiling")
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
                        Image(systemName: "circle")
                            .resizable()
                            .foregroundColor(Color(.label))
                            .frame(width: 80, height: 80)
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
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .principal) { Text("") }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // TODO:
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

#Preview {
    AboutView()
        .fontDesign(.rounded)
}