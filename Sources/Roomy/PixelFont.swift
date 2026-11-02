import SwiftUI

/// Roomy's own 5×7 dot-matrix font for headings and big numbers. Each glyph is its character, then seven rows.
enum PixelFont {
    static let glyphs: [Character: [[Bool]]] = {
        var glyphs: [Character: [[Bool]]] = [" ": Array(repeating: Array(repeating: false, count: 5), count: 7)]
        for block in source.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true)
            guard lines.count == 8, let character = lines[0].first else { continue }
            glyphs[character] = lines.dropFirst().map { $0.map { $0 == "#" } }
        }
        return glyphs
    }()

    private static let source = """
    A
    .###.
    #...#
    #...#
    #####
    #...#
    #...#
    #...#

    B
    ####.
    #...#
    #...#
    ####.
    #...#
    #...#
    ####.

    C
    .###.
    #...#
    #....
    #....
    #....
    #...#
    .###.

    D
    ####.
    #...#
    #...#
    #...#
    #...#
    #...#
    ####.

    E
    #####
    #....
    #....
    ####.
    #....
    #....
    #####

    F
    #####
    #....
    #....
    ####.
    #....
    #....
    #....

    G
    .###.
    #...#
    #....
    #.###
    #...#
    #...#
    .####

    H
    #...#
    #...#
    #...#
    #####
    #...#
    #...#
    #...#

    I
    #####
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..
    #####

    J
    ..###
    ...#.
    ...#.
    ...#.
    #..#.
    #..#.
    .##..

    K
    #...#
    #..#.
    #.#..
    ##...
    #.#..
    #..#.
    #...#

    L
    #....
    #....
    #....
    #....
    #....
    #....
    #####

    M
    #...#
    ##.##
    #.#.#
    #.#.#
    #...#
    #...#
    #...#

    N
    #...#
    ##..#
    #.#.#
    #..##
    #...#
    #...#
    #...#

    O
    .###.
    #...#
    #...#
    #...#
    #...#
    #...#
    .###.

    P
    ####.
    #...#
    #...#
    ####.
    #....
    #....
    #....

    Q
    .###.
    #...#
    #...#
    #...#
    #.#.#
    #..#.
    .##.#

    R
    ####.
    #...#
    #...#
    ####.
    #.#..
    #..#.
    #...#

    S
    .####
    #....
    #....
    .###.
    ....#
    ....#
    ####.

    T
    #####
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..

    U
    #...#
    #...#
    #...#
    #...#
    #...#
    #...#
    .###.

    V
    #...#
    #...#
    #...#
    #...#
    #...#
    .#.#.
    ..#..

    W
    #...#
    #...#
    #...#
    #.#.#
    #.#.#
    #.#.#
    .#.#.

    X
    #...#
    #...#
    .#.#.
    ..#..
    .#.#.
    #...#
    #...#

    Y
    #...#
    #...#
    .#.#.
    ..#..
    ..#..
    ..#..
    ..#..

    Z
    #####
    ....#
    ...#.
    ..#..
    .#...
    #....
    #####

    0
    .###.
    #...#
    #..##
    #.#.#
    ##..#
    #...#
    .###.

    1
    ..#..
    .##..
    ..#..
    ..#..
    ..#..
    ..#..
    .###.

    2
    .###.
    #...#
    ....#
    ...#.
    ..#..
    .#...
    #####

    3
    ####.
    ....#
    ....#
    .###.
    ....#
    ....#
    ####.

    4
    ...#.
    ..##.
    .#.#.
    #..#.
    #####
    ...#.
    ...#.

    5
    #####
    #....
    ####.
    ....#
    ....#
    #...#
    .###.

    6
    .###.
    #....
    #....
    ####.
    #...#
    #...#
    .###.

    7
    #####
    ....#
    ...#.
    ..#..
    .#...
    .#...
    .#...

    8
    .###.
    #...#
    #...#
    .###.
    #...#
    #...#
    .###.

    9
    .###.
    #...#
    #...#
    .####
    ....#
    ....#
    .###.

    .
    .....
    .....
    .....
    .....
    .....
    .##..
    .##..

    ,
    .....
    .....
    .....
    .....
    .##..
    ..#..
    .#...

    :
    .....
    .##..
    .##..
    .....
    .##..
    .##..
    .....

    !
    ..#..
    ..#..
    ..#..
    ..#..
    ..#..
    .....
    ..#..

    ?
    .###.
    #...#
    ....#
    ...#.
    ..#..
    .....
    ..#..

    -
    .....
    .....
    .....
    #####
    .....
    .....
    .....

    _
    .....
    .....
    .....
    .....
    .....
    .....
    #####

    /
    ....#
    ....#
    ...#.
    ..#..
    .#...
    #....
    #....

    %
    ##..#
    ##..#
    ...#.
    ..#..
    .#...
    #..##
    #..##

    ~
    .....
    .....
    .#...
    #.#.#
    ...#.
    .....
    .....

    '
    ..#..
    ..#..
    .#...
    .....
    .....
    .....
    .....

    (
    ...#.
    ..#..
    .#...
    .#...
    .#...
    ..#..
    ...#.

    )
    .#...
    ..#..
    ...#.
    ...#.
    ...#.
    ..#..
    .#...

    +
    .....
    ..#..
    ..#..
    #####
    ..#..
    ..#..
    .....

    >
    .#...
    ..#..
    ...#.
    ....#
    ...#.
    ..#..
    .#...

    <
    ...#.
    ..#..
    .#...
    #....
    .#...
    ..#..
    ...#.
    """
}

/// Text drawn in the dot-matrix font, glowing like phosphor. `aberration` adds the red/blue fringe of a misaligned CRT.
struct PixelText: View {
    let text: String
    var pixel: CGFloat = 3
    var color: Color = Retro.phosphor
    var aberration = false
    var glows = true

    var body: some View {
        let characters = Array(text.uppercased())
        Canvas { context, _ in
            if aberration {
                draw(characters, in: context, color: Retro.red.opacity(0.8), shift: -pixel * 0.6)
                draw(characters, in: context, color: Retro.blue.opacity(0.8), shift: pixel * 0.6)
            }
            draw(characters, in: context, color: color, shift: 0)
        }
        .frame(width: CGFloat(max(characters.count * 6 - 1, 0)) * pixel + pixel * 1.2, height: 7 * pixel)
        .shadow(color: glows ? color.opacity(0.7) : .clear, radius: pixel * 1.5)
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    private func draw(_ characters: [Character], in context: GraphicsContext, color: Color, shift: CGFloat) {
        for (index, character) in characters.enumerated() {
            // Characters the font doesn't have are left blank.
            guard let glyph = PixelFont.glyphs[character] else { continue }
            for (y, row) in glyph.enumerated() {
                for (x, isOn) in row.enumerated() where isOn {
                    let dot = CGRect(x: pixel * 0.6 + shift + CGFloat(index * 6 + x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel)
                    context.fill(Path(roundedRect: dot.insetBy(dx: pixel * 0.08, dy: pixel * 0.08), cornerRadius: pixel * 0.22), with: .color(color))
                }
            }
        }
    }
}
