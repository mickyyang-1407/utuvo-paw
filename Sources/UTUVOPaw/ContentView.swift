import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var model: PawModel

    var body: some View {
        ZStack {
            Paw.milk.ignoresSafeArea()
            switch model.phase {
            case .idle: DropZone()
            case .scanning: ScanningView()
            case .results, .bopping: ResultsView()
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
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .foregroundStyle(model.isDropTargeted ? Paw.rose : Paw.dash)
                    .background(RoundedRectangle(cornerRadius: 22).fill(model.isDropTargeted ? Paw.pinkSoft : Paw.cream.opacity(0.5)))
                VStack(spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Paw.rose)
                        .scaleEffect(breathe ? 1.08 : 0.94)
                    Text("Drop apps here")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Paw.ink)
                    Text("The cat will find every leftover file.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                if let e = model.errorText {
                    Text(e).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Paw.roseDark)
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
            Text("Sniffing…").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Paw.ink)
            ProgressView().controlSize(.small)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { wiggle = true } }
    }
}

// MARK: - Results

struct ResultsView: View {
    @EnvironmentObject var model: PawModel
    @State private var pawX: CGFloat = 1.4   // fraction of width; >1 = off-screen right

    var grouped: [(Leftover.Category, [Leftover])] {
        Dictionary(grouping: model.items, by: \.category).sorted { $0.key < $1.key }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().overlay(Paw.dash)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6, pinnedViews: []) {
                        ForEach(grouped, id: \.0) { cat, items in
                            Text(cat.rawValue.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.2)
                                .foregroundStyle(Paw.inkSoft)
                                .padding(.top, 12).padding(.horizontal, 20)
                            ForEach(items) { item in LeftoverRow(item: item) }
                        }
                    }
                    .padding(.bottom, 16)
                }
                Divider().overlay(Paw.dash)
                footer
            }
            .disabled(model.phase == .bopping)

            if model.phase == .bopping {
                GeometryReader { geo in
                    Paw.image("paw").resizable().scaledToFit()
                        .frame(width: 260)
                        .rotationEffect(.degrees(-25))
                        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                        .position(x: geo.size.width * pawX, y: geo.size.height * 0.5)
                        .onAppear {
                            pawX = 1.4
                            withAnimation(.easeOut(duration: 0.45)) { pawX = 0.35 }
                            withAnimation(.easeIn(duration: 0.4).delay(0.55)) { pawX = -0.6 }
                        }
                }
                .allowsHitTesting(false)
            }
        }
    }

    var header: some View {
        HStack(spacing: 14) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.app?.name ?? "").font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(Paw.ink)
                HStack(spacing: 6) {
                    if let v = model.app?.version { Text("v\(v)") }
                    if let id = model.app?.bundleID { Text(id) }
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Paw.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.items.count) things found").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Paw.ink)
                Text(ByteFormat.string(model.totalBytes)).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Paw.inkSoft)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(Paw.pinkSoft)
    }

    var footer: some View {
        HStack(spacing: 10) {
            Button("Back") { model.reset() }.buttonStyle(GhostButtonStyle())
            Button(model.selectedItems.count == model.items.filter { !$0.needsAdmin }.count ? "None" : "All") {
                model.selectAll(!(model.selectedItems.count == model.items.filter { !$0.needsAdmin }.count))
            }.buttonStyle(GhostButtonStyle())
            Spacer()
            Text("\(model.selectedItems.count) selected · \(ByteFormat.string(model.selectedBytes))")
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Paw.inkSoft)
            Button {
                model.bop()
            } label: {
                Label(model.selectedItems.count == model.items.count ? "Bop All" : "Bop", systemImage: "pawprint.fill")
            }
            .buttonStyle(PawButtonStyle())
            .disabled(model.selectedItems.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Paw.cream)
    }
}

struct LeftoverRow: View {
    @EnvironmentObject var model: PawModel
    let item: Leftover

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { item.selected }, set: { _ in model.toggle(item) }))
                .toggleStyle(.checkbox).labelsHidden()
                .disabled(item.needsAdmin)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Paw.ink).lineLimit(1)
                Text(item.displayPath).font(.system(size: 11, design: .monospaced)).foregroundStyle(Paw.inkSoft).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if item.needsAdmin {
                Text("admin").font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Paw.orange, in: Capsule())
                    .help("Lives in /Library. Paw won't touch it; remove it by hand with admin rights.")
            }
            Text(ByteFormat.string(item.size)).font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(Paw.inkSoft)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        .background(item.selected ? Paw.pinkSoft.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture { if !item.needsAdmin { model.toggle(item) } }
        .contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
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
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Paw.rose)
                .rotationEffect(.degrees(pop ? 4 : -10))
            if let r = model.result {
                Text("\(r.trashed.count) things off the desk · \(ByteFormat.string(r.bytesFreed)) moved to Trash")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Paw.ink)
                if !r.failed.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(r.failed, id: \.0.id) { f in
                            Text("Couldn't bop \(f.0.url.lastPathComponent): \(f.1.localizedDescription)")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Paw.roseDark)
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
