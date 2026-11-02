import RoomyCore
import SwiftUI

struct ScanningView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        RetroPanel("SCANNING") {
            HStack(alignment: .center, spacing: 30) {
                OrbitScene().frame(width: 320, height: 320)
                VStack(alignment: .leading, spacing: 18) {
                    TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                        let cursor = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? "_" : " "
                        PixelText(text: "SCANNING" + cursor, pixel: 5, color: Retro.amber, aberration: true)
                    }
                    Text(tildePath(model.root)).font(Retro.font(12)).foregroundStyle(Retro.dim)
                    TimelineView(.periodic(from: .now, by: 0.15)) { _ in
                        let now = model.progress.snapshot
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Counter(label: "Files", value: now.files.formatted())
                                Counter(label: "Measured", value: bytes(now.bytes))
                            }
                            Text("> " + tildePath(URL(filePath: now.folder)))
                                .font(Retro.font(10.5)).foregroundStyle(Retro.green)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    Chaser()
                    if !AppModel.hasFullDiskAccess {
                        Text("macOS may ask if Roomy can open folders like Documents, Downloads or Desktop. Allow them for a complete scan. Anything you don't allow is skipped, and nothing leaves this Mac.")
                            .font(Retro.font(11)).foregroundStyle(Retro.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Stop and show what's found") { model.stopScan() }.buttonStyle(.retro)
                }
            }
            .padding(30)
        }
        .frame(maxWidth: 960)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Counter: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(Retro.font(9.5)).tracking(1.2).foregroundStyle(Retro.dim)
            PixelText(text: value, pixel: 3.2, color: Retro.phosphor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Retro.line, lineWidth: 1))
    }
}

/// A striped planet (your disk) with moons on dashed orbits, and a radar sweep lighting up blips as it passes.
struct OrbitScene: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                Self.draw(in: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private struct Moon {
        let orbit: CGFloat
        let speed: Double
        let phase: Double
        let radius: CGFloat
        let colors: [Color]
    }

    private static func draw(in context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 - 12
        let orbits = [outer, outer * 0.78, outer * 0.58]
        func square(_ radius: CGFloat, at point: CGPoint) -> CGRect {
            CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        }

        for orbit in orbits {
            context.stroke(Path(ellipseIn: square(orbit, at: center)), with: .color(Retro.phosphor.opacity(0.3)),
                           style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
        }

        // The sweep: a fan of thin wedges fading out behind the leading edge.
        let sweep = time * 1.3
        for step in 0..<28 {
            var wedge = Path()
            wedge.move(to: center)
            wedge.addArc(center: center, radius: outer, startAngle: .radians(sweep - Double(step + 1) * 0.035),
                         endAngle: .radians(sweep - Double(step) * 0.035), clockwise: false)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Retro.amber.opacity(0.22 * (1 - Double(step) / 28))))
        }

        // Blips glow when the sweep passes over them, then fade.
        let blips: [(distance: CGFloat, angle: Double)] = [(0.85, 0.6), (0.68, 2.3), (0.95, 3.9), (0.5, 5.2), (0.74, 4.6)]
        for blip in blips {
            var behind = (sweep - blip.angle).truncatingRemainder(dividingBy: 2 * .pi)
            if behind < 0 { behind += 2 * .pi }
            let point = CGPoint(x: center.x + cos(blip.angle) * outer * blip.distance, y: center.y + sin(blip.angle) * outer * blip.distance)
            context.fill(Path(square(3, at: point)), with: .color(Retro.green.opacity(max(0.1, 1 - behind / 2.5))))
        }

        context.stripedCircle(square(outer * 0.36, at: center), colors: [Retro.blue, Retro.phosphor, Retro.amber], stripe: 4)

        let moons = [
            Moon(orbit: orbits[0], speed: 0.35, phase: 0, radius: 13, colors: [Retro.amber, Retro.orange, Retro.red]),
            Moon(orbit: orbits[0], speed: 0.35, phase: 2.6, radius: 6, colors: [Retro.phosphor, Retro.amber]),
            Moon(orbit: orbits[1], speed: -0.6, phase: 1, radius: 9, colors: [Retro.red, Retro.magenta]),
            Moon(orbit: orbits[2], speed: 0.95, phase: 4, radius: 6, colors: [Retro.phosphor, Retro.blue]),
        ]
        for moon in moons {
            let angle = time * moon.speed + moon.phase
            let point = CGPoint(x: center.x + cos(angle) * moon.orbit, y: center.y + sin(angle) * moon.orbit)
            context.stripedCircle(square(moon.radius, at: point), colors: moon.colors, stripe: 3)
        }
    }
}

struct ReportView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        if let result = model.result {
            let safe = model.suggestions.filter { $0.rule.verdict == .safe }.reduce(0) { $0 + $1.node.size }
            let review = model.suggestions.filter { $0.rule.verdict == .review }.reduce(0) { $0 + $1.node.size }
            RetroPanel("REPORT") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .center, spacing: 20) {
                            Mascot(pixel: 5)
                            VStack(alignment: .leading, spacing: 10) {
                                PixelText(text: result.stoppedEarly ? "STOPPED EARLY" : "SCAN COMPLETE!", pixel: 4.5, color: Retro.amber, aberration: true)
                                Text("\(bytes(result.tree.size)) in \(result.files.formatted()) files under \(tildePath(model.root)), measured in \(Int(result.seconds.rounded())) seconds. Everything stayed on this Mac.")
                                    .font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button("Scan Again") { Task { await model.scan(model.root, fresh: true) } }.buttonStyle(.retro)
                        }

                        HStack(spacing: 14) {
                            StatCard(title: "Safe to clean", value: bytes(safe), note: "Rebuilt or downloaded again on its own", color: Retro.green)
                            StatCard(title: "Worth a look", value: bytes(review), note: "Might hold things you want", color: Retro.amber)
                            StatCard(title: "Locked by macOS", value: "\(model.locked.count) DIRS", note: "Couldn't be measured", color: Retro.magenta)
                        }

                        if !model.locked.isEmpty && !AppModel.hasFullDiskAccess {
                            HStack(spacing: 10) {
                                PixelSprite(sprite: Sprites.lock, pixel: 2)
                                Text("macOS kept \(model.locked.count) folders closed, so the totals are low.")
                                    .font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                                Button("Give Full Disk Access…") { model.screen = .access }.buttonStyle(.retro)
                            }
                        }

                        HStack(spacing: 12) {
                            PixelText(text: "BIGGEST WINS", pixel: 2.4, color: Retro.phosphor)
                            Hairline()
                        }
                        if model.suggestions.isEmpty {
                            Text("Nothing big that Roomy recognises. Use Explore to look around.").font(Retro.font(12)).foregroundStyle(Retro.dim)
                        }
                        VStack(spacing: 0) {
                            ForEach(model.suggestions.prefix(15)) { suggestion in
                                SuggestionRow(suggestion: suggestion, largest: model.suggestions.first?.node.size ?? 1)
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Explore every folder") { model.screen = .explore }.buttonStyle(.retroDefault)
                        }
                    }
                    .padding(26)
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let note: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(Retro.font(10)).tracking(1.2).foregroundStyle(color)
            PixelText(text: value, pixel: 3.4, color: color)
            Text(note).font(Retro.font(10.5)).foregroundStyle(Retro.dim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlowingCard(color: color, fill: color.opacity(0.06), border: color.opacity(0.7), glow: 0.5, radius: 5, cornerRadius: 10))
    }
}

private struct SuggestionRow: View {
    @Environment(AppModel.self) private var model
    let suggestion: Suggestion
    let largest: Int64

    var body: some View {
        let color = Retro.color(suggestion.rule.verdict)
        HStack(spacing: 14) {
            VerdictTag(verdict: suggestion.rule.verdict).frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(suggestion.rule.title).font(Retro.font(13)).bold().foregroundStyle(Retro.phosphor)
                Text(tildePath(suggestion.node.url)).font(Retro.font(10.5)).foregroundStyle(Retro.dim)
                    .lineLimit(1).truncationMode(.middle)
                SegmentBar(fraction: Double(suggestion.node.size) / Double(max(largest, 1)), color: color, height: 6)
            }
            Text(bytes(suggestion.node.size)).font(Retro.font(13)).foregroundStyle(color)
                .frame(width: 96, alignment: .trailing)
            Button("Show") { model.goTo(suggestion.node) }.buttonStyle(.retro)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
