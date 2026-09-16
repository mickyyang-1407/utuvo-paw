import CoreText
import SwiftUI

enum Paw {
    static let night = Color(red: 0x2A/255, green: 0x21/255, blue: 0x40/255)
    static let cream = Color(red: 0xFF/255, green: 0xF3/255, blue: 0xE4/255)
    static let milk = Color(red: 0xFF/255, green: 0xFD/255, blue: 0xF8/255)
    static let pink = Color(red: 0xFF/255, green: 0xC9/255, blue: 0xD6/255)
    static let pinkSoft = Color(red: 0xFF/255, green: 0xE7/255, blue: 0xEE/255)
    static let rose = Color(red: 0xFF/255, green: 0x6B/255, blue: 0x8B/255)
    static let roseDark = Color(red: 0xE2/255, green: 0x49/255, blue: 0x6C/255)
    static let orange = Color(red: 0xF5/255, green: 0xA0/255, blue: 0x5A/255)
    static let ink = Color(red: 0x3B/255, green: 0x2A/255, blue: 0x3E/255)
    static let inkSoft = Color(red: 0x6E/255, green: 0x5A/255, blue: 0x72/255)
    static let dash = Color(red: 0xE5/255, green: 0xB8/255, blue: 0xCB/255)
    static let mint = Color(red: 0x3F/255, green: 0xC3/255, blue: 0xA0/255)

    /// Fredoka (OFL, bundled) — the same face as the website. Falls back to SF Rounded if the
    /// font failed to register.
    static var fontRegistered = false
    static func registerFonts() {
        guard let dir = Bundle.module.url(forResource: "Fonts", withExtension: nil) else { return }
        for f in ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []) where f.pathExtension == "ttf" {
            if CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) { fontRegistered = true }
        }
    }
    /// Body text: Nunito, one weight lighter than asked — Micky finds bold text tiring.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let softened: Font.Weight = switch weight {
            case .black, .heavy: .bold
            case .bold: .semibold
            case .semibold: .medium
            default: .regular
        }
        return fontRegistered ? Font.custom("Nunito", size: size).weight(softened)
                              : Font.system(size: size, weight: softened, design: .rounded)
    }
    /// Display text (titles, "boop!"): Fredoka Medium — round, never bold.
    static func display(_ size: CGFloat) -> Font {
        fontRegistered ? Font.custom("Fredoka", size: size).weight(.medium)
                       : Font.system(size: size, weight: .medium, design: .rounded)
    }

    /// Bundled WAVs (Sounds/whoosh.wav, Sounds/hit.wav). Drop a replacement with the same name to change it.
    private static var soundCache: [String: NSSound] = [:]
    static func play(_ name: String) {
        if let s = soundCache[name] { s.stop(); s.play(); return }
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav", subdirectory: "Sounds"),
              let s = NSSound(contentsOf: url, byReference: true) else { NSSound(named: "Pop")?.play(); return }
        soundCache[name] = s; s.play()
    }

    static func image(_ name: String) -> Image {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets"),
           let img = NSImage(contentsOf: url) {
            return Image(nsImage: img)
        }
        return Image(systemName: "pawprint.fill")
    }
}

/// Liquid Glass on macOS 26+, a soft material below that. Same call site either way.
extension View {
    @ViewBuilder
    func pawGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false, fallback: Color = Paw.milk.opacity(0.7)) -> some View {
        if #available(macOS 26.0, *) {
            let glass: Glass = (tint.map { Glass.regular.tint($0) } ?? .regular).interactive(interactive)
            self.glassEffect(glass, in: shape)
        } else {
            self.background(fallback, in: shape).background(.thinMaterial, in: shape)
        }
    }
}

/// Soft pink and peach blobs behind everything so the glass has something to refract.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Paw.milk
            Circle().fill(Paw.pink.opacity(0.55)).frame(width: 420).blur(radius: 90).offset(x: -220, y: -200)
            Circle().fill(Color(red: 1, green: 0.86, blue: 0.72).opacity(0.7)).frame(width: 380).blur(radius: 90).offset(x: 240, y: -120)
            Circle().fill(Paw.rose.opacity(0.28)).frame(width: 360).blur(radius: 100).offset(x: 180, y: 260)
            Circle().fill(Color(red: 0.86, green: 0.82, blue: 1).opacity(0.55)).frame(width: 300).blur(radius: 90).offset(x: -200, y: 240)
        }
        .ignoresSafeArea()
    }
}

struct PawButtonStyle: ButtonStyle {
    var color: Color = Paw.rose
    var shadow: Color = Paw.roseDark
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Paw.font(14, .heavy))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .pawGlass(Capsule(), tint: color.opacity(0.9), interactive: true, fallback: color)
            .shadow(color: shadow.opacity(0.45), radius: configuration.isPressed ? 2 : 8, y: configuration.isPressed ? 1 : 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Paw.font(13, .bold))
            .foregroundStyle(Paw.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .pawGlass(Capsule(), tint: configuration.isPressed ? Paw.pinkSoft : nil, interactive: true, fallback: Paw.pinkSoft.opacity(0.7))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}
