import SwiftUI
import Shared

// MARK: - Belt Arc Picker (Android-parity)
struct BeltArcPicker: View {
    let belts: [Belt]
    @Binding var selectedBelt: Belt
    let isEnglish: Bool

    private let big: CGFloat = 112
    private let small: CGFloat = 58
    private let stepGap: CGFloat = 46
    private var step: CGFloat { small + stepGap }

    private let arcDepth: CGFloat = 74
    private var pickerHeight: CGFloat { big + arcDepth - 34 }
    
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

                    // Android parity:
                    // מציגים את המרכזי ועוד עיגולים צדדיים שנחתכים בתחתית.
                    let hide = dist > 2.55

                    let t = Swift.min(CGFloat(1), dist / 2.0)
                    let drop = arcDepth * (1 - cos(t * .pi / 2))
                    let grow: CGFloat = {
                        if dist >= 0.58 { return 0 }
                        let normalized = (0.58 - dist) / 0.58
                        return Swift.max(CGFloat(0), Swift.min(CGFloat(1), normalized))
                    }()
                    let targetSize = small + (big - small) * grow

                    let targetAlpha: CGFloat = {
                        if hide { return 0 }
                        if dist < 0.25 { return 1.0 }
                        return 0.78
                    }()

                    let x = centerX + step * rel

                    let sideBoost = small * 1.32
                    let boostFactor = min(1, dist)
                    let yDrop = drop + sideBoost * boostFactor
                    let y = yDrop + 22
                    let isCenter = dist < 0.25

                    ZStack {
                        if isCenter {
                            Circle()
                                .fill(BeltPalette.color(for: belt).opacity(0.26))
                                .frame(width: targetSize + 22, height: targetSize + 22)
                                .blur(radius: 12)

                            RotatingOrbitRing(
                                base: BeltPalette.color(for: belt)
                            )
                            .frame(width: targetSize + 14, height: targetSize + 14)
                        }

                        BeltCircle(
                            belt: belt,
                            isCenter: isCenter,
                            isEnglish: isEnglish
                        )
                        .padding(isCenter ? 6 : 0)
                    }
                    .frame(
                        width: isCenter ? targetSize + 24 : targetSize,
                        height: isCenter ? targetSize + 24 : targetSize
                    )
                    .scaleEffect(1.0)
                    .opacity(targetAlpha)
                    .position(x: x, y: y + targetSize / 2)
                    .zIndex(isCenter ? 3 : 1)
                    .shadow(
                        color: isCenter ? Color.black.opacity(0.30) : Color.black.opacity(0.20),
                        radius: isCenter ? 9 : 4,
                        x: 0,
                        y: isCenter ? 5 : 2
                    )
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
            .frame(width: min(width, 360), height: pickerHeight, alignment: .top)
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
        .padding(.top, 18)
        .padding(.bottom, -12)
        .zIndex(30)
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                if activeCircleDragIndex != nil { return }

                if dragStartCenter == nil {
                    dragStartCenter = centerValue
                }
                let start = dragStartCenter ?? centerValue
                let delta = -(v.translation.width / step)
                let next = (start + delta).clamped(to: 0...CGFloat(Swift.max(0, belts.count - 1)))
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

                let nextCenter = (CGFloat(index) + delta)
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
        let isEnglish: Bool

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
                    Text(centerText(for: belt))
                        .font(.system(size: isEnglish ? 12 : 13, weight: .bold))
                        .lineSpacing(isEnglish ? 1 : 0)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(textColor(for: belt))
                        .minimumScaleFactor(0.78)
                        .lineLimit(2)
                        .padding(8)
                }
            }
        }

        private func centerText(for belt: Belt) -> String {
            if isEnglish {
                return "Belt\n\(englishBeltName(belt))"
            }

            return "חגורה\n\(cleanHeb(belt.heb))"
        }

        private func englishBeltName(_ belt: Belt) -> String {
            switch belt {
            case .white:
                return "White"
            case .yellow:
                return "Yellow"
            case .orange:
                return "Orange"
            case .green:
                return "Green"
            case .blue:
                return "Blue"
            case .brown:
                return "Brown"
            case .black:
                return "Black"
            default:
                return "Belt"
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

private struct RotatingOrbitRing: View {
    let base: Color

    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(base.opacity(0.22), lineWidth: 6)

            Circle()
                .trim(from: 0.0, to: 0.84)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.13, green: 0.83, blue: 0.93),
                            Color(red: 0.65, green: 0.47, blue: 0.98),
                            Color(red: 0.96, green: 0.45, blue: 0.70),
                            Color(red: 0.98, green: 0.75, blue: 0.18),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.9)
                        .repeatForever(autoreverses: false)
                    ) {
                        angle = 360
                    }
                }
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
