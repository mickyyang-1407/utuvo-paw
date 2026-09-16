import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var model: PawModel

    var body: some View {
        ZStack {
            AmbientBackground()
            switch model.phase {
            case .idle: DropZone()
            case .scanning: ScanningView()
            case .results: ResultsView()
            case .done: DoneView()
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { model.load(url) }
            }
            return true
        }
        .animation(.spring(duration: 0.35), value: model.phase)
    }
}

// MARK: - Idle

struct DropZone: View {
    @EnvironmentObject var model: PawModel
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                    .pawGlass(RoundedRectangle(cornerRadius: 22), tint: model.isDropTargeted ? Paw.pinkSoft.opacity(0.8) : nil, fallback: Paw.cream.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                        .foregroundStyle(model.isDropTargeted ? Paw.rose : Paw.dash))
                VStack(spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Paw.rose)
                        .scaleEffect(breathe ? 1.08 : 0.94)
                    Text("Drop apps here")
                        .font(Paw.font(22, .bold))
                        .foregroundStyle(Paw.ink)
                    Text("The cat will find every leftover file.")
                        .font(Paw.font(13, .semibold))
                        .foregroundStyle(Paw.inkSoft)
                }
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Paw.image("loaf")
                    .resizable().scaledToFit()
                    .frame(width: 150)
                    .padding(.trailing, 14)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
            }
            .padding(24)

            HStack(spacing: 12) {
                Button("Choose app…") { model.chooseApp() }.buttonStyle(GhostButtonStyle())
                if !Trasher.hasFullDiskAccess {
                    Button {
                        Trasher.openFullDiskAccessSettings()
                    } label: { Label("Full Disk Access is off — needed for Containers", systemImage: "lock.shield") }
                        .buttonStyle(GhostButtonStyle())
                        .help("Without it the cat can list but not remove ~/Library/Containers and similar protected folders.")
                }
                if let e = model.errorText {
                    Text(e).font(Paw.font(12, .semibold)).foregroundStyle(Paw.roseDark)
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true } }
    }
}

// MARK: - Scanning

struct ScanningView: View {
    @State private var wiggle = false
    var body: some View {
        VStack(spacing: 14) {
            Paw.image("peek").resizable().scaledToFit().frame(width: 220)
                .rotationEffect(.degrees(wiggle ? 3 : -3))
            Text("Sniffing…").font(Paw.font(22, .bold)).foregroundStyle(Paw.ink)
            ProgressView().controlSize(.small)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { wiggle = true } }
    }
}

// MARK: - Results: the desk. Aim with the mouse, click a thing to throw a shuriken at it.

struct ResultsView: View {
    @EnvironmentObject var model: PawModel
    @State private var frames: [URL: CGRect] = [:]
    @State private var mouse: CGPoint = .zero
    @State private var shots: [Shot] = []
    @State private var hits: Set<URL> = []
    @State private var throwPhase: ThrowPhase = .idle
    @State private var catTurn: Double = 0
    @State private var aimOverride: CGFloat?
    @State private var deskSize: CGSize = .zero
    @State private var lastError: String?

    struct Shot: Identifiable { let id = UUID(); let target: URL; let from: CGPoint; let to: CGPoint }

    let columns = [GridItem(.adaptive(minimum: 104, maximum: 124), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Paw.dash)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.items) { item in
                                Tile(item: item, hit: hits.contains(item.url))
                                    .background(GeometryReader { g in
                                        Color.clear.preference(key: TileFrameKey.self, value: [item.url: g.frame(in: .named("desk"))])
                                    })
                                    .onTapGesture { shoot(item) }
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 170)
                    }
                    AimingCat(aim: aimOverride ?? aimValue(in: geo.size), phase: throwPhase, turn: catTurn)
                        .offset(y: 24)
                        .allowsHitTesting(false)
                    ForEach(shots) { shot in
                        ShotView(from: shot.from, to: shot.to) { land(shot) }
                    }
                }
                .coordinateSpace(name: "desk")
                .onPreferenceChange(TileFrameKey.self) { frames = $0 }
                .onAppear { deskSize = geo.size }
                .onChange(of: geo.size) { _, new in deskSize = new }
                .onContinuousHover { phase in
                    if case .active(let p) = phase { mouse = p }
                }
            }
            if model.needsFullDiskAccess {
                FullDiskAccessBanner()
            } else if let e = lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Paw.orange)
                    Text(e).font(Paw.font(12, .semibold)).foregroundStyle(Paw.roseDark).lineLimit(2)
                    Spacer()
                    Button("OK") { withAnimation { lastError = nil } }.buttonStyle(GhostButtonStyle())
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .pawGlass(Rectangle(), tint: Paw.pinkSoft.opacity(0.7), fallback: Paw.pinkSoft)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Divider().overlay(Paw.dash)
            footer
        }
    }

    // MARK: aiming & throwing

    func aimValue(in size: CGSize) -> CGFloat {
        guard size.width > 0 else { return 0 }
        return max(-1, min(1, (mouse.x - size.width / 2) / (size.width / 2)))
    }

    func shoot(_ item: Leftover) {
        guard !item.needsAdmin, !hits.contains(item.url), let f = frames[item.url] else { return }
        let targetAim = max(-1, min(1, (f.midX - deskSize.width / 2) / (deskSize.width / 2)))
        aimOverride = targetAim
        // 1. spin round to face the desk (back to the viewer)
        throwPhase = .turning
        catTurn += 180
        // 2. throw from the raised paw
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            throwPhase = .release
            shots.append(Shot(target: item.url, from: AimingCat.pawOrigin(in: deskSize), to: CGPoint(x: f.midX, y: f.midY)))
        }
        // 3. keep spinning the same way until the cat faces the viewer again, then follow the mouse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            throwPhase = .returning
            catTurn += 180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            if throwPhase == .returning { throwPhase = .idle; aimOverride = nil }
        }
    }

    func land(_ shot: Shot) {
        shots.removeAll { $0.id == shot.id }
        guard !hits.contains(shot.target) else { return }
        hits.insert(shot.target)
        NSSound(named: "Pop")?.play()
        model.bop(url: shot.target) { failure in
            withAnimation(.easeIn(duration: 0.25)) { _ = hits.remove(shot.target) }
            if let failure {
                withAnimation { lastError = failure }
                NSSound(named: "Basso")?.play()
            }
        }
    }

    func bopAll() {
        let targets = model.items.filter { !$0.needsAdmin && !hits.contains($0.url) }
        for (i, item) in targets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) { shoot(item) }
        }
    }

    // MARK: chrome

    var header: some View {
        HStack(spacing: 14) {
            if let icon = model.appIcon { Image(nsImage: icon).resizable().frame(width: 48, height: 48) }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.app?.name ?? "").font(Paw.font(19, .heavy)).foregroundStyle(Paw.ink)
                HStack(spacing: 6) {
                    if let v = model.app?.version { Text("v\(v)") }
                    if let id = model.app?.bundleID { Text(id) }
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Paw.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.items.count) things on the desk").font(Paw.font(13, .bold)).foregroundStyle(Paw.ink)
                Text(ByteFormat.string(model.totalBytes)).font(Paw.font(12, .semibold)).foregroundStyle(Paw.inkSoft)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .pawGlass(Rectangle(), tint: Paw.pinkSoft.opacity(0.6), fallback: Paw.pinkSoft.opacity(0.8))
    }

    var footer: some View {
        HStack(spacing: 10) {
            Button("Back") { model.reset() }.buttonStyle(GhostButtonStyle())
            Text("Click a thing to throw. Or…")
                .font(Paw.font(12, .semibold)).foregroundStyle(Paw.inkSoft)
            Spacer()
            if let r = model.result, !r.trashed.isEmpty {
                Text("\(r.trashed.count) bopped · \(ByteFormat.string(r.bytesFreed))")
                    .font(Paw.font(12, .semibold)).foregroundStyle(Paw.inkSoft)
            }
            Button { bopAll() } label: { Label("Bop All", systemImage: "pawprint.fill") }
                .buttonStyle(PawButtonStyle())
                .disabled(model.items.allSatisfy(\.needsAdmin))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .pawGlass(Rectangle(), fallback: Paw.cream.opacity(0.85))
    }
}

struct Tile: View {
    let item: Leftover
    let hit: Bool
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable().frame(width: 56, height: 56)
                    .opacity(hit ? 0 : 1)
                    .scaleEffect(hit ? 0.3 : 1)
                if hit {
                    ClawSlash()
                    ShardBurst(color: Paw.orange)
                }
            }
            .frame(height: 64)
            Text(item.url.lastPathComponent)
                .font(Paw.font(11, .bold)).foregroundStyle(Paw.ink)
                .lineLimit(2).multilineTextAlignment(.center).truncationMode(.middle)
                .frame(height: 28, alignment: .top)
            HStack(spacing: 4) {
                Text(item.category.rawValue).lineLimit(1)
                Text("·")
                Text(ByteFormat.string(item.size)).monospacedDigit()
            }
            .font(Paw.font(9.5, .semibold)).foregroundStyle(Paw.inkSoft)
            if item.needsAdmin {
                Text("admin").font(Paw.font(9, .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Paw.orange, in: Capsule())
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .pawGlass(RoundedRectangle(cornerRadius: 16), tint: hover && !item.needsAdmin ? Paw.pinkSoft.opacity(0.8) : nil, interactive: !item.needsAdmin, fallback: Color.white.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(hover && !item.needsAdmin ? Paw.rose : Paw.dash.opacity(0.5), lineWidth: 1.5))
        .scaleEffect(hover && !item.needsAdmin ? 1.04 : 1)
        .animation(.spring(duration: 0.18), value: hover)
        .onHover { hover = $0 }
        .help(item.displayPath + (item.needsAdmin ? "\nLives in /Library — remove by hand with admin rights." : "\nClick to throw a shuriken at it."))
        .contextMenu { Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } }
    }
}

struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill").font(.system(size: 18)).foregroundStyle(Paw.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("The cat can't reach ~/Library/Containers yet.")
                    .font(Paw.font(12.5, .heavy)).foregroundStyle(Paw.ink)
                Text("Open Full Disk Access, press +, pick UTUVO Paw (or drag it in), turn it on, then relaunch.")
                    .font(Paw.font(11.5, .semibold)).foregroundStyle(Paw.inkSoft)
            }
            Spacer()
            Button("Open Full Disk Access") { Trasher.openFullDiskAccessSettings() }.buttonStyle(GhostButtonStyle())
            Button("Relaunch") { Trasher.relaunch() }.buttonStyle(PawButtonStyle(color: Paw.orange, shadow: Color(red: 0.80, green: 0.48, blue: 0.20)))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .pawGlass(Rectangle(), tint: Paw.pinkSoft.opacity(0.7), fallback: Paw.pinkSoft)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Done

struct DoneView: View {
    @EnvironmentObject var model: PawModel
    @State private var pop = false

    var body: some View {
        VStack(spacing: 14) {
            Paw.image("push").resizable().scaledToFit().frame(width: 300)
                .scaleEffect(pop ? 1 : 0.7)
            Text("boop!")
                .font(Paw.font(44, .heavy))
                .foregroundStyle(Paw.rose)
                .rotationEffect(.degrees(pop ? 4 : -10))
            if let r = model.result {
                Text("\(r.trashed.count) things off the desk · \(ByteFormat.string(r.bytesFreed)) moved to Trash")
                    .font(Paw.font(14, .bold)).foregroundStyle(Paw.ink)
                if !r.failed.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(r.failed, id: \.0.id) { f in
                            Text("Couldn't bop \(f.0.url.lastPathComponent): \(f.1.localizedDescription)")
                        }
                    }
                    .font(Paw.font(11, .semibold)).foregroundStyle(Paw.roseDark)
                    .padding(.horizontal, 30)
                }
            }
            HStack(spacing: 10) {
                Button("Empty Trash…") { NSAppleScript(source: "tell application \"Finder\" to empty trash")?.executeAndReturnError(nil) }
                    .buttonStyle(GhostButtonStyle())
                Button { model.reset() } label: { Label("Bop another", systemImage: "pawprint.fill") }
                    .buttonStyle(PawButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(30)
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.5)) { pop = true } }
    }
}
