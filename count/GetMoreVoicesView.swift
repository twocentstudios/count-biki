import SwiftUI

struct GetMoreVoicesView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Text("Download voices individually from the iOS Settings app.")
                .font(.system(.headline, design: .rounded))

            Section {
                Button {
                    openURL(URL(string: "app-settings:root=General")!)
                } label: {
                    Text("Open Settings.app")
                        .font(.system(.body, design: .rounded))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowSeparator(.hidden)
                Image("get_more_voices_01")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "1.circle")) Tap this button to open Settings.app")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_02")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "2.circle")) Tap \"Accessibility\"")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_03")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "3.circle")) Tap \"Spoken Content\"")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_04")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "4.circle")) Tap \"Voices\"")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_05")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "5.circle")) Tap \"Japanese\"")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_06")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } header: {
                Text("\(Image(systemName: "6.circle")) Tap a name e.g. \"Kyoko\"")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Section {
                Image("get_more_voices_07")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Text("Tip: \"(Enhanced)\" voices are better and \"(Premium)\" voices are best.")
                    .font(.caption)
            } header: {
                Text("\(Image(systemName: "7.circle")) Tap the \(Image(systemName: "icloud.and.arrow.down")) button to download the voice")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.body, design: .rounded))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(EmptyView())
            .listRowSeparator(.hidden)
        }
        .listStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Get More Voices")
                    .font(.system(.headline, design: .rounded))
            }
        }
    }
}

#Preview {
    GetMoreVoicesView()
}
