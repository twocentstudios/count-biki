import SwiftUI

struct DeterminateProgressView: View {
    var percentage: Double = 0.0 // 0.0 ... 1.0
    var backgroundColor: Color = .white
    var foregroundColor: Color = .black
    var animation: Animation = .snappy(duration: 0.5)

    var body: some View {
        Capsule(style: .continuous)
            .fill(backgroundColor.shadow(.inner(color: .primary.opacity(0.15), radius: 1)))
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(foregroundColor)
                        .frame(width: proxy.size.width * percentage, height: proxy.size.height)
                        .animation(animation, value: percentage)
                }
            }
    }
}

#Preview {
    struct ContainerView: View {
        @State var percentage = 0.7

        var body: some View {
            DeterminateProgressView(percentage: percentage)
                .frame(height: 30)
                .padding()
                .background(Color(.secondarySystemBackground))
                .onTapGesture {
                    percentage -= 0.1
                }
        }
    }

    return ContainerView()
}
