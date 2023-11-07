import SwiftUI

struct IndeterminateProgressView: View {
    var animationCount: Int = 0
    var color1: Color = .white
    var color2: Color = .black
    var barCount: Int = 40
    var rotation: Angle = .degrees(50)
    var animation: Animation = .snappy(duration: 0.5)

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { proxy in
                    let barWidth: CGFloat = proxy.size.width / Double(barCount)
                    let range = Range(uncheckedBounds: (lower: 0 + animationCount, upper: barCount + animationCount))
                    HStack(spacing: 0) {
                        ForEach(range, id: \.self) { index in
                            Rectangle().fill(index % 2 == 0 ? color1 : color2).frame(width: barWidth, height: proxy.size.width)
                        }
                    }
                    .animation(animation, value: animationCount)
                    .rotationEffect(rotation)
                    .frame(height: proxy.size.height)
                }
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .primary.opacity(0.1), location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.9),
                        .init(color: .primary.opacity(0.1), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .contentShape(Capsule(style: .continuous))
            .clipShape(Capsule(style: .continuous))
    }
}

#Preview {
    struct ContainerView: View {
        @State var animationCount = 0

        var body: some View {
            IndeterminateProgressView(animationCount: animationCount, barCount: 24)
                .frame(height: 30)
                .padding()
                .background(Color(.secondarySystemBackground))
                .onTapGesture {
                    animationCount += 1
                }
        }
    }

    return ContainerView()
}
