import AppKit
import SwiftUI

/// The app icon: a little orange CRT with Roomy glowing on the screen next to a striped planet.
struct IconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 190, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF29447), Color(hex: 0xD2601F), Color(hex: 0x9A3812)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 190, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center))

            ZStack {
                Retro.screen
                Canvas { context, size in
                    var x: CGFloat = 0
                    while x < size.width {
                        context.fill(Path(CGRect(x: x, y: 0, width: 4, height: size.height)), with: .color(Retro.magenta.opacity(0.12)))
                        x += 70
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 4)), with: .color(Retro.magenta.opacity(0.12)))
                        y += 70
                    }
                    context.stripedCircle(CGRect(x: 450, y: 50, width: 200, height: 200), colors: [Retro.blue, Retro.phosphor, Retro.amber], stripe: 16)
                }
                PixelSprite(sprite: Sprites.mascot, pixel: 25)
                    .shadow(color: Retro.amber.opacity(0.7), radius: 40)
                    .offset(x: -40, y: 50)
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 4)), with: .color(.black.opacity(0.28)))
                        y += 11
                    }
                }
                RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 220, endRadius: 470)
            }
            .frame(width: 700, height: 580)
            .clipShape(RoundedRectangle(cornerRadius: 110, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 110, style: .continuous).stroke(.black.opacity(0.7), lineWidth: 16))
            .offset(y: -50)

            HStack(spacing: 34) {
                Circle().fill(Retro.green).frame(width: 30, height: 30).shadow(color: Retro.green, radius: 14)
                Spacer()
                ForEach(0..<2, id: \.self) { _ in
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFC08A), Color(hex: 0x8E3410)], center: .topLeading, startRadius: 2, endRadius: 70))
                        .overlay(Circle().stroke(Retro.plastic, lineWidth: 6))
                        .frame(width: 70, height: 70)
                }
            }
            .padding(.horizontal, 110)
            .offset(y: 330)
        }
        .frame(width: 824, height: 824)
        .frame(width: 1024, height: 1024)
    }
}

/// Writes the .iconset PNGs (`Roomy --make-icon <folder>`); scripts/build-app.sh turns them into AppIcon.icns.
@MainActor
enum IconMaker {
    static func write(into folder: String) {
        let sizes = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                     ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
        let directory = URL(filePath: folder)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, pixels) in sizes {
            let renderer = ImageRenderer(content: IconArt())
            renderer.scale = CGFloat(pixels) / 1024
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: directory.appending(path: "icon_\(name).png"))
        }
    }
}
