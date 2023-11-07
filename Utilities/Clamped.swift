// https://stackoverflow.com/a/40868784
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension BinaryFloatingPoint {
    func clampedPercentage() -> Self {
        clamped(to: 0.0 ... 1.0)
    }
}
