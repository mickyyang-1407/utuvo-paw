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

    static func image(_ name: String) -> Image {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets"),
           let img = NSImage(contentsOf: url) {
            return Image(nsImage: img)
        }
        return Image(systemName: "pawprint.fill")
    }
}

struct PawButtonStyle: ButtonStyle {
    var color: Color = Paw.rose
    var shadow: Color = Paw.roseDark
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(color, in: Capsule())
            .background(Capsule().fill(shadow).offset(y: 4))
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Paw.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Paw.pinkSoft.opacity(configuration.isPressed ? 1 : 0.6), in: Capsule())
    }
}
