import SwiftUI

struct AboutView: View {
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
                    Label("Report a bug", systemImage: "ladybug")
                    Label("Report a content error", systemImage: "exclamationmark.bubble")
                    Label("Suggest a new Topic", systemImage: "lightbulb")
                    Label("Send me a nice message", systemImage: "face.smiling")
                    Label("Rate on the App Store", systemImage: "star")
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
                    Label("twocentstudios.com", systemImage: "globe")
                    Label("Mastodon", systemImage: "globe")
                    Label("Twitter", systemImage: "globe")
                } header: {
                    Text("About")
                }

                Section {
                    Label("Licenses", systemImage: "note.text")
                    Label("Privacy policy", systemImage: "note.text")
                    Label("Terms and conditions", systemImage: "note.text")
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
