import SwiftUI

struct ContentView: View {
    @State var text: String = "123"

    var body: some View {
        VStack {
            Button {
                // TODO: play
            } label: {
                Image(systemName: "speaker.fill") // TODO: playing state
                    .font(.title)
                    .padding(60)
            }
            .buttonStyle(.bordered)
            .disabled(false) // TODO: isPlaying
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                TextField("", text: $text)
                    .foregroundStyle(Color.primary) // TODO: change to red on incorrect
                    .font(.largeTitle)
                    .bold()
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button {
                    // TODO: check answer
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                }
                .buttonStyle(.borderedProminent)
                .disabled(false) // TODO: isTextEmpty
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
