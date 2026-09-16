import SwiftUI

// MARK: - Shuriken (four-blade star with a paw pad in the middle)

struct ShurikenShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        let inner = outer * 0.32
        for i in 0..<4 {
            let a = Double(i) * .pi / 2
            let tip = CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer)
            let l = CGPoint(x: c.x + cos(a - 0.55) * inner, y: c.y + sin(a - 0.55) * inner)
            let rr = CGPoint(x: c.x + cos(a + 0.55) * inner, y: c.y + sin(a + 0.55) * inner)
            if i == 0 { p.move(to: l) } else { p.addLine(to: l) }
            p.addQuadCurve(to: tip, control: CGPoint(x: c.x + cos(a - 0.18) * outer * 0.8, y: c.y + sin(a - 0.18) * outer * 0.8))
            p.addQuadCurve(to: rr, control: CGPoint(x: c.x + cos(a + 0.18) * outer * 0.8, y: c.y + sin(a + 0.18) * outer * 0.8))
        }
        p.closeSubpath()
        return p
    }
}

struct ShurikenView: View {
    var size: CGFloat = 52
    var body: some View {
        Paw.image("shuriken").resizable().scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Paw.roseDark.opacity(0.45), radius: 4, y: 2)
    }
}

/// One thrown shuriken. Flies from `from` to `to`, spinning; calls `onHit` when it lands.
struct ShotView: View {
    let from: CGPoint
    let to: CGPoint
    let onHit: () -> Void
    @State private var pos: CGPoint
    @State private var spin: Double = 0
    @State private var scale: CGFloat = 0.6

    init(from: CGPoint, to: CGPoint, onHit: @escaping () -> Void) {
        self.from = from; self.to = to; self.onHit = onHit
        _pos = State(initialValue: from)
    }

    var body: some View {
        ShurikenView()
            .rotationEffect(.degrees(spin))
            .scaleEffect(scale)
            .position(pos)
            .onAppear {
                withAnimation(.easeIn(duration: 0.32)) { pos = to; scale = 1 }
                withAnimation(.linear(duration: 0.32)) { spin = 720 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { onHit() }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Claw slash + shards on the hit tile

struct ClawSlash: View {
    @State private var trim: CGFloat = 0
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Path { p in
                    let x = 22 + CGFloat(i) * 16
                    p.move(to: CGPoint(x: x + 18, y: 6))
                    p.addQuadCurve(to: CGPoint(x: x - 10, y: 66), control: CGPoint(x: x - 2, y: 30))
                }
                .trim(from: 0, to: trim)
                .stroke(Paw.roseDark, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .shadow(color: .white, radius: 1)
            }
        }
        .frame(width: 84, height: 72)
        .onAppear { withAnimation(.easeOut(duration: 0.18)) { trim = 1 } }
    }
}

struct ShardBurst: View {
    let color: Color
    @State private var go = false
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                RoundedRectangle(cornerRadius: 3)
                    .fill(i % 2 == 0 ? color : Paw.pink)
                    .frame(width: 10 + CGFloat(i % 3) * 4, height: 8 + CGFloat(i % 2) * 5)
                    .rotationEffect(.degrees(go ? Double(i) * 97 : 0))
                    .offset(x: go ? cos(a) * 70 : 0, y: go ? sin(a) * 70 + 30 : 0)
                    .opacity(go ? 0 : 1)
            }
            Text("boop!")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Paw.rose)
                .shadow(color: .white, radius: 2)
                .offset(y: go ? -46 : -10)
                .opacity(go ? 0 : 1)
                .scaleEffect(go ? 1.3 : 0.6)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { go = true } }
        .allowsHitTesting(false)
    }
}

// MARK: - The cat that aims

struct AimingCat: View {
    /// -1…1, where the mouse is relative to the cat horizontally.
    var aim: CGFloat
    var throwing: Bool
    var body: some View {
        Paw.image("ninja").resizable().scaledToFit()
            .frame(width: 190)
            .rotationEffect(.degrees(Double(aim) * 12 + (throwing ? -14 : 0)), anchor: .bottom)
            .scaleEffect(x: throwing ? 1.06 : 1, y: throwing ? 0.94 : 1, anchor: .bottom)
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            .animation(.spring(duration: 0.25), value: aim)
            .animation(.spring(duration: 0.16, bounce: 0.5), value: throwing)
    }
}

// MARK: - Layout plumbing: tiles report their frames

struct TileFrameKey: PreferenceKey {
    static var defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
