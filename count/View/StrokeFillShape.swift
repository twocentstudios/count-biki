import SwiftUI

/// From: https://wien.rocks/@noheger/111286009290721395
extension Shape {
    func fill(_ fillStyle: any ShapeStyle, stroke strokeStyle: any ShapeStyle, lineWidth: CGFloat = 1) -> some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .style(fillStyle))
            context.stroke(path(in: rect), with: .style(strokeStyle), lineWidth: 2 * lineWidth)
        }
        .clipShape(self)
    }
}
