import SwiftUI
import Shared

// MARK: - Belt Arc Picker (Android-parity)
struct BeltArcPicker: View {
    let belts: [Belt]
    @Binding var selectedBelt: Belt

    private let big: CGFloat = 126
    private let small: CGFloat = 70
    private let stepGap: CGFloat = 18
    private var step: CGFloat { small + stepGap }

    private let arcDepth: CGFloat = 58
    private var pickerHeight: CGFloat { small + arcDepth + 24 }

    @State private var centerValue: CGFloat = 0
    @State private var dragStartCenter: CGFloat? = nil
    @State private var activeCircleDragIndex: Int? = nil

    private var currentIndex: Int {
        belts.firstIndex(of: selectedBelt) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let centerX = width / 2

            ZStack(alignment: .top) {
                ForEach(Array(belts.enumerated()), id: \.offset) { index, belt in
                    let rel = CGFloat(index) - centerValue
                    let dist = abs(rel)

                    // מציגים את המרכזי ועוד חצי מהעיגולים הקרובים
                    let hide = dist > 1.10

                    let t = Swift.min(CGFloat(1), dist / 1.0)
                    let drop = arcDepth * (1 - cos(t * .pi / 2))
                    let grow = Swift.max(CGFloat(0), 1 - Swift.min(CGFloat(1), dist))
                    let targetSize = small + (big - small) * grow

                    let targetAlpha: CGFloat = {
                        if hide { return 0 }
                        if dist < 0.20 { return 1.0 }
                        return 0.60
                    }()

                    let x = centerX + step * rel

                    let sideBoost = small * 0.42
                    let boostFactor = min(1, dist)
                    let yDrop = drop + sideBoost * boostFactor
                    let y = yDrop + 2

                    let isCenter = dist < 0.20

                    BeltCircle(belt: belt, isCenter: isCenter)
                        .frame(width: targetSize, height: targetSize)
                        .scaleEffect(isCenter ? 1.0 : 0.82)
                        .opacity(targetAlpha)
                        .position(x: x, y: y + targetSize / 2)
                        .zIndex(isCenter ? 3 : 1)
                        .shadow(radius: isCenter ? 6 : 2, y: isCenter ? 4 : 1)
                        .overlay {
                            if isCenter {
                                Circle()
                                    .stroke(BeltPalette.color(for: belt).opacity(0.55), lineWidth: 6)
                                    .blur(radius: 6)
                                    .scaleEffect(1.10)
                            }
                        }
                        .contentShape(Circle())
                        .allowsHitTesting(!hide)
                        .highPriorityGesture(circleDragGesture(for: index))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                snapToIndex(index)
                            }
                        }
                }
            }
            .frame(width: min(width, 330), height: pickerHeight, alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture())
            .onAppear {
                centerValue = CGFloat(currentIndex)
            }
            .onChange(of: selectedBelt) { _, new in
                let idx = belts.firstIndex(of: new) ?? 0
                withAnimation(.easeInOut(duration: 0.22)) {
                    centerValue = CGFloat(idx)
                }
            }
        }
        .frame(height: pickerHeight)
        .padding(.bottom, 6)
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                if activeCircleDragIndex != nil { return }

                if dragStartCenter == nil {
                    dragStartCenter = centerValue
                }
                let start = dragStartCenter ?? centerValue
                let delta = v.translation.width / step
                let next = (start - delta).clamped(to: 0...CGFloat(Swift.max(0, belts.count - 1)))
                centerValue = next
            }
            .onEnded { _ in
                if activeCircleDragIndex != nil { return }

                let prevIndex = currentIndex
                let snap = Int(round(centerValue)).clamped(to: 0...Swift.max(0, belts.count - 1))
                dragStartCenter = nil

                withAnimation(.easeInOut(duration: 0.18)) {
                    centerValue = CGFloat(snap)
                }

                if belts.indices.contains(snap) {
                    selectedBelt = belts[snap]
                }

                if snap != prevIndex {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    private func circleDragGesture(for index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                activeCircleDragIndex = index

                let delta = v.translation.width / step

                // ✅ היפוך כיוון:
                // גרירה ימינה => העיגול שמשמאל מתקדם למרכז
                // גרירה שמאלה => העיגול שמימין מתקדם למרכז
                let nextCenter = (CGFloat(index) - delta)
                    .clamped(to: 0...CGFloat(Swift.max(0, belts.count - 1)))

                centerValue = nextCenter
            }
            .onEnded { _ in
                let prevIndex = currentIndex
                let snap = Int(round(centerValue)).clamped(to: 0...Swift.max(0, belts.count - 1))

                activeCircleDragIndex = nil
                dragStartCenter = nil

                withAnimation(.easeInOut(duration: 0.18)) {
                    centerValue = CGFloat(snap)
                }

                if belts.indices.contains(snap) {
                    selectedBelt = belts[snap]
                }

                if snap != prevIndex {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    private func snapToIndex(_ index: Int) {
        let snap = index.clamped(to: 0...max(0, belts.count - 1))
        centerValue = CGFloat(snap)
        if belts.indices.contains(snap) {
            selectedBelt = belts[snap]
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private struct BeltCircle: View {
        let belt: Belt
        let isCenter: Bool

        var body: some View {
            let fill = BeltPalette.color(for: belt).opacity(0.96)
            let outline = outlineColor(for: belt)

            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(
                        Circle().stroke(outline, lineWidth: 3)
                    )

                if isCenter {
                    Text("חגורה\n\(cleanHeb(belt.heb))")
                        .font(.system(size: 13, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(textColor(for: belt))
                        .padding(8)
                }
            }
        }

        private func outlineColor(for belt: Belt) -> Color {
            if belt == .black || belt == .brown { return .white }
            let lum = BeltPalette.color(for: belt).luminanceLike
            return (lum < 0.5) ? .white : .black
        }

        private func textColor(for belt: Belt) -> Color {
            let lum = BeltPalette.color(for: belt).luminanceLike
            return (lum < 0.5) ? .white : .black
        }

        private func cleanHeb(_ s: String) -> String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("חגורה") {
                return t.replacingOccurrences(of: "חגורה", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return t
        }
    }
}

// MARK: - helpers

private extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, r.lowerBound), r.upperBound)
    }
}

private extension Int {
    func clamped(to r: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, r.lowerBound), r.upperBound)
    }
}

private extension Color {
    var luminanceLike: Double {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double(0.2126 * r + 0.7152 * g + 0.0722 * b)
    }
}
