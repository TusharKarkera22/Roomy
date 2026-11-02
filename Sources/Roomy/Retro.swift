import RoomyCore
import SwiftUI

/// The CRT look: a dark phosphor screen inside an orange TV bezel, amber glow, scanlines, dot-matrix headings.
enum Retro {
    static let screen = Color(hex: 0x120D0B)
    static let panel = Color(hex: 0x1B1411)
    static let phosphor = Color(hex: 0xF6E7C8)
    static let dim = Color(hex: 0xA38F78)
    static let line = Color(hex: 0xF6E7C8).opacity(0.2)
    static let amber = Color(hex: 0xFFB238)
    static let orange = Color(hex: 0xFF6A1F)
    static let red = Color(hex: 0xFF3D2E)
    static let magenta = Color(hex: 0xFF4FD8)
    static let blue = Color(hex: 0x8FB4FF)
    static let green = Color(hex: 0x8CFF6A)
    static let plastic = Color(hex: 0x5C220A)

    static func font(_ size: CGFloat) -> Font { .custom("Monaco", size: size) }

    static func color(_ verdict: Verdict?, locked: Bool = false) -> Color {
        if locked { return magenta }
        switch verdict {
        case .safe: return green
        case .review: return amber
        case .keep: return red
        case nil: return dim
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// Phosphor bloom.
    func glow(_ color: Color = Retro.amber, _ radius: CGFloat = 5) -> some View {
        shadow(color: color.opacity(0.65), radius: radius)
    }
}

extension GraphicsContext {
    /// A circle filled with a gradient and cut into horizontal stripes, like the planets on an old space console.
    func stripedCircle(_ rect: CGRect, colors: [Color], stripe: CGFloat = 3) {
        var context = self
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.clip(to: circle)
        var y = rect.minY
        while y < rect.maxY {
            context.fill(Path(CGRect(x: rect.minX, y: y + stripe * 0.62, width: rect.width, height: stripe * 0.38)), with: .color(Retro.screen.opacity(0.9)))
            y += stripe
        }
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Retro.line).frame(height: 1) }
}

/// A console module: dot-matrix title, status lights, thin glowing outline.
struct RetroPanel<Content: View>: View {
    let title: String
    var accent: Color
    let content: Content

    init(_ title: String, accent: Color = Retro.amber, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach([Retro.red, Retro.amber, Retro.green], id: \.self) { light in
                        Circle().fill(light.opacity(0.85)).frame(width: 6, height: 6)
                    }
                }
                PixelText(text: title, pixel: 1.7, color: accent)
                Spacer(minLength: 8)
                Ticks().frame(width: 56, height: 8)
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            Hairline()
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(GlowingCard(color: accent, fill: Retro.panel.opacity(0.93), border: Retro.phosphor.opacity(0.28), glow: 0.14, radius: 14))
    }
}

/// A rounded card whose glow sits on the shape alone. Glowing the content instead would recalculate the glow
/// every time the content changes, such as on every frame of scrolling.
struct GlowingCard: View {
    let color: Color
    var fill: Color = .clear
    var border: Color? = nil
    var glow: Double = 0.5
    var radius: CGFloat = 6
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(border ?? color, lineWidth: 1))
            .shadow(color: color.opacity(glow), radius: radius)
    }
}

/// Decorative tick marks for panel headers.
struct Ticks: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var index = 0
            while x < size.width {
                let height = index % 4 == 0 ? size.height : size.height * 0.5
                context.fill(Path(CGRect(x: x, y: size.height - height, width: 1.5, height: height)), with: .color(Retro.dim.opacity(0.6)))
                x += 4
                index += 1
            }
        }
    }
}

struct RetroButtonStyle: ButtonStyle {
    var isDefault = false

    func makeBody(configuration: Configuration) -> some View {
        Label(configuration: configuration, isDefault: isDefault)
    }

    private struct Label: View {
        let configuration: Configuration
        let isDefault: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let filled = isDefault || configuration.isPressed
            configuration.label
                .font(Retro.font(11))
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .foregroundStyle(filled ? Retro.screen : Retro.amber)
                .background(Capsule().fill(filled ? Retro.amber.opacity(configuration.isPressed ? 0.7 : 1) : Retro.amber.opacity(hovering ? 0.14 : 0)))
                .overlay(Capsule().stroke(Retro.amber, lineWidth: 1))
                .background(Capsule().fill(Retro.amber.opacity(filled ? 0.5 : 0)).blur(radius: 6))
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Capsule())
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == RetroButtonStyle {
    static var retro: RetroButtonStyle { RetroButtonStyle() }
    static var retroDefault: RetroButtonStyle { RetroButtonStyle(isDefault: true) }
}

/// A size bar made of LED segments.
struct SegmentBar: View {
    let fraction: Double
    var color: Color = Retro.amber
    var height: CGFloat = 7

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 4
            let count = Int(size.width / step)
            let lit = Int((Double(count) * min(max(fraction, 0), 1)).rounded(.up))
            for index in 0..<count {
                let segment = CGRect(x: CGFloat(index) * step, y: 0, width: step - 1.6, height: size.height)
                context.fill(Path(segment), with: .color(index < lit ? color : Retro.phosphor.opacity(0.08)))
            }
        }
        .frame(height: height)
    }
}

/// A light running back and forth along a row of segments: "working on it".
struct Chaser: View {
    var color: Color = Retro.amber

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let step: CGFloat = 7
                let count = max(Int(size.width / step), 2)
                let head = (sin(timeline.date.timeIntervalSinceReferenceDate * 1.7) + 1) / 2 * Double(count - 1)
                for index in 0..<count {
                    let brightness = max(0.08, 1 - abs(Double(index) - head) / 8)
                    context.fill(Path(CGRect(x: CGFloat(index) * step, y: 0, width: step - 2, height: size.height)), with: .color(color.opacity(brightness)))
                }
            }
        }
        .frame(height: 12)
    }
}

struct VerdictTag: View {
    let verdict: Verdict?
    var isLocked = false
    var isOtherDisk = false

    var body: some View {
        let color = isOtherDisk ? Retro.dim : Retro.color(verdict, locked: isLocked)
        HStack(spacing: 4) {
            if !isOtherDisk { PixelSprite(sprite: glyph, pixel: 1.3, ink: color) }
            Text(label).font(Retro.font(9.5)).bold()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.85), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .fixedSize()
    }

    private var label: String {
        if isOtherDisk { return "OTHER DISK" }
        if isLocked { return "LOCKED" }
        switch verdict {
        case .safe: return "SAFE"
        case .review: return "REVIEW"
        case .keep: return "KEEP"
        case nil: return "UNKNOWN"
        }
    }

    private var glyph: Sprite {
        if isLocked { return Sprites.shut }
        switch verdict {
        case .safe: return Sprites.check
        case .review: return Sprites.bang
        case .keep: return Sprites.shut
        case nil: return Sprites.question
        }
    }
}

/// A labelled paragraph in the info panel.
struct Field: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Retro.font(9.5)).tracking(1.2).foregroundStyle(Retro.dim)
            Text(text).font(Retro.font(12)).foregroundStyle(Retro.phosphor).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct Explanation: View {
    let rule: Rule?

    var body: some View {
        if let rule {
            Text(rule.title).font(Retro.font(14)).bold().foregroundStyle(Retro.amber).glow(Retro.amber, 3)
            Field(label: "What it is", text: rule.what)
            Field(label: "Belongs to", text: rule.owner)
            Field(label: "If you delete it", text: rule.ifDeleted)
            Field(label: "Comes back on its own", text: rule.comesBack ? "Yes" : "No")
            if let how = rule.howToClean { Field(label: "Better way to clean it", text: how) }
        } else {
            Field(label: "Roomy doesn't know this one yet",
                  text: "Reveal it in Finder to see what's inside. If you work out what it is, add it to rules.json so everyone gets the answer.")
        }
    }
}

// MARK: - The TV

/// Orange plastic around the screen.
struct Bezel: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF29447), Color(hex: 0xD2601F), Color(hex: 0x9A3812)], startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
        }
    }
}

struct BezelFooter: View {
    var body: some View {
        HStack(spacing: 14) {
            PixelText(text: "ROOMY-1", pixel: 2, color: Retro.plastic, glows: false)
            Text("DISK SPACE EXPLAINER").font(Retro.font(10)).tracking(2).foregroundStyle(Retro.plastic)
            Spacer()
            Circle().fill(Retro.green).frame(width: 8, height: 8).glow(Retro.green, 4)
            Text("POWER").font(Retro.font(9)).tracking(1.5).foregroundStyle(Retro.plastic)
            Knob()
            Knob()
        }
        .padding(.horizontal, 34)
    }
}

struct Knob: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFC08A), Color(hex: 0x8E3410)], center: .topLeading, startRadius: 1, endRadius: 24))
            .overlay(Rectangle().fill(Retro.plastic).frame(width: 2, height: 9).offset(y: -5))
            .overlay(Circle().stroke(Retro.plastic, lineWidth: 1.5))
            .frame(width: 26, height: 26)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
    }
}

/// The dark tube with a faint grid.
struct CRTBackground: View {
    var body: some View {
        ZStack {
            Retro.screen
            Canvas { context, size in
                let step: CGFloat = 34
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Retro.magenta.opacity(0.06)))
                    x += step
                }
                var y: CGFloat = 0
                while y < size.height {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Retro.magenta.opacity(0.06)))
                    y += step
                }
            }
        }
    }
}

/// Scanlines, the darker edges of the tube and a reflection on the glass. Static, so it costs nothing while scrolling.
struct CRTGlass: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.16)))
                        y += 3
                    }
                }
                RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center,
                               startRadius: min(geometry.size.width, geometry.size.height) * 0.45,
                               endRadius: max(geometry.size.width, geometry.size.height) * 0.75)
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: geometry.size.width * 0.5, height: 150)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 30, y: 12)
            }
        }
        .drawingGroup()
    }
}
