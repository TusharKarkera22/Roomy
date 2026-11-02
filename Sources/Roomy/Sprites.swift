import SwiftUI

/// Pixel art drawn from text: one character per pixel, `.` is transparent. Colours come from `Sprite.palette`.
struct Sprite {
    let pixels: [[Character]]
    var width: Int { pixels.first?.count ?? 0 }
    var height: Int { pixels.count }

    init(_ art: String) {
        pixels = art.split(separator: "\n").map(Array.init)
    }

    static let palette: [Character: Color] = [
        "K": .black,
        "W": .white,
        "B": Color(hex: 0xD9A066), // cardboard
        "b": Color(hex: 0xA8703A), // cardboard shade
        "Y": Color(hex: 0xF4E3B5), // tape
        "R": Color(hex: 0xFF8FA3), // cheeks
        "C": Color(hex: 0xA8E6F5), // glass
        "F": Color(hex: 0xF7D774), // manila folder
        "L": Color(hex: 0xBDBDBD),
        "D": Color(hex: 0x7A7A7A),
        "H": Retro.phosphor, // outlines that must show on the dark screen
    ]
}

enum Sprites {
    /// Roomy, the cardboard-box mascot.
    static let mascot = Sprite("""
    ................
    .KKKKKKKKKKKKKK.
    .KBBBBBYYBBBBBK.
    .KBBBBBYYBBBBBK.
    .KKKKKKKKKKKKKK.
    .KBBBBBBBBBBBBK.
    .KBBKKBBBBKKBBK.
    .KBBKKBBBBKKBBK.
    .KBBBBBBBBBBBBK.
    .KBRRBBBBBBRRBK.
    .KBBBKBBBBKBBBK.
    .KBBBBKKKKBBBBK.
    .KBBBBBBBBBBBBK.
    .KbbbbbbbbbbbbK.
    .KKKKKKKKKKKKKK.
    ..KK........KK..
    """)

    static let mascotBlink = Sprite("""
    ................
    .KKKKKKKKKKKKKK.
    .KBBBBBYYBBBBBK.
    .KBBBBBYYBBBBBK.
    .KKKKKKKKKKKKKK.
    .KBBBBBBBBBBBBK.
    .KBBBBBBBBBBBBK.
    .KBBKKBBBBKKBBK.
    .KBBBBBBBBBBBBK.
    .KBRRBBBBBBRRBK.
    .KBBBKBBBBKBBBK.
    .KBBBBKKKKBBBBK.
    .KBBBBBBBBBBBBK.
    .KbbbbbbbbbbbbK.
    .KKKKKKKKKKKKKK.
    ..KK........KK..
    """)

    static let mascotStep = Sprite("""
    ................
    .KKKKKKKKKKKKKK.
    .KBBBBBYYBBBBBK.
    .KBBBBBYYBBBBBK.
    .KKKKKKKKKKKKKK.
    .KBBBBBBBBBBBBK.
    .KBBKKBBBBKKBBK.
    .KBBKKBBBBKKBBK.
    .KBBBBBBBBBBBBK.
    .KBRRBBBBBBRRBK.
    .KBBBKBBBBKBBBK.
    .KBBBBKKKKBBBBK.
    .KBBBBBBBBBBBBK.
    .KbbbbbbbbbbbbK.
    .KKKKKKKKKKKKKK.
    ....KK....KK....
    """)

    static let magnifier = Sprite("""
    ..HHHH....
    .HCCCCH...
    HCWCCCCH..
    HCWCCCCH..
    HCCCCCCH..
    HCCCCCCH..
    .HCCCCHH..
    ..HHHHHHH.
    .......HHH
    ........HH
    """)

    static let folder = Sprite("""
    .KKKK.........
    KFFFFK........
    KFFFFFKKKKKKK.
    KFFFFFFFFFFFFK
    KKKKKKKKKKKKKK
    KFFFFFFFFFFFFK
    KFFFFFFFFFFFFK
    KFFFFFFFFFFFFK
    KFFFFFFFFFFFFK
    KFFFFFFFFFFFFK
    KKKKKKKKKKKKKK
    """)

    static let file = Sprite("""
    KKKKKKK...
    KWWWWWKK..
    KWWWWWKWK.
    KWWWWWKKKK
    KWWWWWWWWK
    KWLLLLLLWK
    KWWWWWWWWK
    KWLLLLLLWK
    KWWWWWWWWK
    KWLLLLLWWK
    KWWWWWWWWK
    KKKKKKKKKK
    """)

    static let trash = Sprite("""
    ....KKK....
    KKKKKKKKKKK
    KWWWWWWWWWK
    KKKKKKKKKKK
    .KWKWKWKWK.
    .KWKWKWKWK.
    .KWKWKWKWK.
    .KWKWKWKWK.
    .KWKWKWKWK.
    .KWKWKWKWK.
    .KWWWWWWWK.
    .KKKKKKKKK.
    """)

    static let house = Sprite("""
    ....K....
    ...KWK...
    ..KWWWK..
    .KWWWWWK.
    KKWWWWWKK
    .KWWKWWK.
    .KWWKWWK.
    .KKKKKKK.
    """)

    static let lock = Sprite("""
    ..HHHHH..
    .HH...HH.
    .H.....H.
    KKKKKKKKK
    KFFFFFFFK
    KFFFKFFFK
    KFFFKFFFK
    KFFFFFFFK
    KKKKKKKKK
    """)

    // Small one-colour glyphs for labels, drawn in whatever `ink` the label uses.
    static let check = Sprite("""
    ......W
    .....WW
    W...WW.
    WW.WW..
    .WWW...
    ..W....
    """)

    static let bang = Sprite("""
    ..WWW..
    ..WWW..
    ..WWW..
    ...W...
    .......
    ...W...
    """)

    static let shut = Sprite("""
    .WWWWW.
    WW...WW
    WWWWWWW
    WWW.WWW
    WWW.WWW
    WWWWWWW
    """)

    static let question = Sprite("""
    .WWWW..
    W...WW.
    ...WW..
    ..WW...
    .......
    ..WW...
    """)
}

struct PixelSprite: View {
    let sprite: Sprite
    var pixel: CGFloat = 3
    /// Draws every visible pixel in this colour instead of the palette.
    var ink: Color? = nil

    var body: some View {
        Canvas { context, _ in
            for (y, row) in sprite.pixels.enumerated() {
                for (x, key) in row.enumerated() {
                    guard let color = key == "." ? nil : (ink ?? Sprite.palette[key]) else { continue }
                    let rect = CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)
                    context.fill(Path(rect.insetBy(dx: -0.01, dy: -0.01)), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(sprite.width) * pixel, height: CGFloat(sprite.height) * pixel)
    }
}

/// Roomy, blinking every few seconds and optionally hopping along.
struct Mascot: View {
    var pixel: CGFloat = 6
    var walking = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let blinking = time.truncatingRemainder(dividingBy: 3.4) < 0.15
            let step = walking && Int(time * 5) % 2 == 1
            PixelSprite(sprite: blinking ? Sprites.mascotBlink : step ? Sprites.mascotStep : Sprites.mascot, pixel: pixel)
                .offset(y: step ? -pixel : 0)
        }
        .frame(width: 16 * pixel, height: 17 * pixel, alignment: .bottom)
    }
}
