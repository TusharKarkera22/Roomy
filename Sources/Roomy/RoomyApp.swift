import AppKit
import RoomyCore
import SwiftUI

@main
struct RoomyApp: App {
    init() {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--make-icon"), flag + 1 < arguments.count {
            IconMaker.write(into: arguments[flag + 1])
            exit(0)
        }
        // Started from `swift run` there's no app bundle, so macOS needs telling this is a regular windowed app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Roomy") { RootView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1300, height: 880)
    }
}

/// The whole window is an old TV: orange bezel, and everything happens on the screen.
struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        VStack(spacing: 0) {
            // Top bezel, where the window buttons sit.
            Color.clear.frame(height: 34)
            ZStack {
                CRTBackground()
                VStack(spacing: 0) {
                    MenuStrip()
                    HStack(alignment: .top, spacing: 18) {
                        if ![.welcome, .access].contains(model.screen) {
                            Sidebar().frame(width: 224)
                        }
                        screen.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(20)
                }
                if model.pending != nil { CleanAlert() }
                VStack {
                    Spacer()
                    if let toast = model.toast {
                        ToastView(toast: toast).padding(26).transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                CRTGlass().allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.black.opacity(0.75), lineWidth: 4))
            .padding(.horizontal, 20)
            BezelFooter().frame(height: 50)
        }
        .background(Bezel())
        .animation(.easeOut(duration: 0.2), value: model.toast?.id)
        .ignoresSafeArea()
        .frame(minWidth: 1080, minHeight: 760)
        .environment(model)
        .preferredColorScheme(.dark)
        .tint(Retro.amber)
        .task { model.start() }
    }

    @ViewBuilder private var screen: some View {
        switch model.screen {
        case .welcome: WelcomeView()
        case .access: AccessView()
        case .scanning: ScanningView()
        case .report: ReportView()
        case .explore: ExplorerView()
        case .duplicates: DuplicatesView()
        }
    }
}

struct MenuStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            PixelSprite(sprite: Sprites.mascot, pixel: 1.6)
            PixelText(text: "ROOMY", pixel: 2.6, color: Retro.amber, aberration: true)
            Text("WHERE DID MY SPACE GO?").font(Retro.font(11)).tracking(1.5).foregroundStyle(Retro.dim)
            Spacer()
            Circle().fill(Retro.green).frame(width: 7, height: 7).glow(Retro.green, 4)
            Text("100% OFFLINE").font(Retro.font(11)).tracking(1.5).foregroundStyle(Retro.green).glow(Retro.green, 3)
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            RetroPanel("PLACES") {
                VStack(alignment: .leading, spacing: 2) {
                    PlaceRow(title: "Home", sprite: Sprites.house, isActive: isScanned(.homeDirectory)) {
                        Task { await model.scan(.homeDirectory) }
                    }
                    PlaceRow(title: "Applications", sprite: Sprites.folder, isActive: isScanned(URL(filePath: "/Applications"))) {
                        Task { await model.scan(URL(filePath: "/Applications")) }
                    }
                    PlaceRow(title: "Open Folder…", sprite: Sprites.folder, isActive: false) {
                        if let url = chooseFolder() { Task { await model.scan(url) } }
                    }
                    Hairline().padding(.vertical, 6)
                    PlaceRow(title: "Report", sprite: Sprites.file, isActive: model.screen == .report) { model.screen = .report }
                        .disabled(model.result == nil)
                    PlaceRow(title: "Explore", sprite: Sprites.magnifier, isActive: model.screen == .explore) { model.screen = .explore }
                        .disabled(model.result == nil)
                    PlaceRow(title: "Duplicates", sprite: Sprites.file, isActive: model.screen == .duplicates) { model.screen = .duplicates }
                }
                .padding(.vertical, 8)
            }
            DiskPanel()
            if !AppModel.hasFullDiskAccess {
                RetroPanel("ACCESS", accent: Retro.magenta) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            PixelSprite(sprite: Sprites.lock, pixel: 2)
                            Text("Limited access. Some folders can't be measured.")
                                .font(Retro.font(11)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                        }
                        Button("Fix this…") { model.screen = .access }.buttonStyle(.retro)
                    }
                    .padding(12)
                }
            }
            Spacer()
        }
    }

    private func isScanned(_ url: URL) -> Bool {
        model.root == url && [.scanning, .report, .explore].contains(model.screen)
    }
}

struct PlaceRow: View {
    let title: String
    let sprite: Sprite
    let isActive: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Rectangle().fill(isActive ? Retro.amber : .clear).frame(width: 3, height: 20).glow(Retro.amber, isActive ? 4 : 0)
                PixelSprite(sprite: sprite, pixel: 1.3).frame(width: 20)
                Text(title.uppercased()).font(Retro.font(12)).tracking(1)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.trailing, 8)
            .foregroundStyle(isActive ? Retro.amber : isEnabled ? Retro.phosphor : Retro.dim.opacity(0.45))
            .background(isActive ? Retro.amber.opacity(0.1) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DiskPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        let (total, free) = startupDisk()
        let used = Double(total - free) / Double(max(total, 1))
        RetroPanel("DISK") {
            VStack(alignment: .leading, spacing: 8) {
                PixelText(text: bytes(free), pixel: 2.6, color: used > 0.9 ? Retro.red : Retro.amber)
                Text("FREE OF \(bytes(total))").font(Retro.font(10)).tracking(1).foregroundStyle(Retro.dim)
                if let disk = model.diskBreakdown {
                    // After a home folder scan: what fills the disk, as one bar in parts, with a key that opens the parts Roomy can scan.
                    let parts = [
                        DiskPart(name: "HOME", spoken: "Home folder", size: disk.home, color: Retro.amber, place: .homeDirectory),
                        DiskPart(name: "APPS", spoken: "Apps", size: disk.apps, color: Retro.blue, place: URL(filePath: "/Applications")),
                        DiskPart(name: "MACOS & SYSTEM", spoken: "macOS and system", size: disk.system, color: Retro.system),
                    ]
                    // The Free swatch is filled to the gray the bar's narrow outlined slots blend into.
                    let key = parts + [DiskPart(name: "FREE", spoken: "Free", size: free, color: Retro.phosphor.opacity(0.25))]
                    StackedBar(parts: parts.map { (Double($0.size) / Double(max(total, 1)), $0.color) }, height: 10)
                        .accessibilityElement()
                        .accessibilityLabel(key.map { "\($0.spoken) \(bytes($0.size))" }.joined(separator: ", "))
                    VStack(spacing: 3) {
                        ForEach(key, id: \.name) { part in
                            if let place = part.place {
                                Button { Task { await model.scan(place) } } label: { row(part, opens: true) }
                                    .buttonStyle(.plain)
                                    .help("Show \(part.spoken.lowercased())")
                                    .accessibilityLabel("\(part.spoken), \(bytes(part.size))")
                                    .accessibilityHint("Shows what's in it")
                            } else {
                                row(part, opens: false)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(part.spoken), \(bytes(part.size))")
                            }
                        }
                    }
                } else {
                    SegmentBar(fraction: used, color: used > 0.9 ? Retro.red : Retro.amber, height: 10)
                    Text("\(Int(used * 100))% USED").font(Retro.font(10)).tracking(1).foregroundStyle(Retro.dim)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One line of the key: a swatch, the part's name and size, and a chevron when clicking it opens that place.
    private func row(_ part: DiskPart, opens: Bool) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(part.color).frame(width: 8, height: 8)
                .overlay(Rectangle().stroke(Retro.slot, lineWidth: 1))
            Text(part.name).tracking(1).foregroundStyle(opens ? Retro.phosphor : Retro.dim)
            Spacer(minLength: 4)
            Text(bytes(part.size)).foregroundStyle(Retro.phosphor)
            Text("›").foregroundStyle(Retro.amber).opacity(opens ? 1 : 0)
        }
        .font(Retro.font(10))
        .lineLimit(1)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

/// A part of the startup disk shown in the Disk panel.
private struct DiskPart {
    let name: String
    /// What VoiceOver reads and tooltips say.
    let spoken: String
    let size: Int64
    let color: Color
    /// Where clicking it goes, for the parts Roomy can scan.
    var place: URL? = nil
}

/// Confirms a cleanup, spelling out what happens.
struct CleanAlert: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let action = model.pending {
            let node = action.node
            let rule = model.rule(for: node)
            ZStack {
                Color.black.opacity(0.6).contentShape(Rectangle()).onTapGesture {}
                RetroPanel(title(action), accent: Retro.red) {
                    HStack(alignment: .top, spacing: 18) {
                        PixelSprite(sprite: Sprites.trash, pixel: 4)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(question(action))
                                .font(Retro.font(14)).bold().foregroundStyle(Retro.phosphor)
                                .fixedSize(horizontal: false, vertical: true)
                            switch action {
                            case .trash:
                                if rule?.verdict == .keep {
                                    Text("Roomy recommends keeping this. \(rule?.howToClean ?? "")")
                                        .font(Retro.font(12)).foregroundStyle(Retro.red).fixedSize(horizontal: false, vertical: true)
                                }
                                Text(rule.map { "If you delete it: \($0.ifDeleted)" } ?? "Roomy doesn't know what this is. Check it in Finder first.")
                                    .font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                                Text("You can put it back from the Trash until you empty it.")
                                    .font(Retro.font(11)).foregroundStyle(Retro.dim)
                            case .trashContents:
                                Text(rule.map { "If you delete it: \($0.ifDeleted)" } ?? "")
                                    .font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                                Text("The folder itself stays. Files an open app is using stay too; quit apps first to clear more. You can put things back from the Trash until you empty it.")
                                    .font(Retro.font(11)).foregroundStyle(Retro.dim).fixedSize(horizontal: false, vertical: true)
                            case .emptyTrash:
                                Text("This permanently deletes everything in the Trash. It can't be undone.")
                                    .font(Retro.font(12)).foregroundStyle(Retro.red).fixedSize(horizontal: false, vertical: true)
                                Text("Roomy asks Finder to do it, so macOS may ask once whether Roomy can control Finder.")
                                    .font(Retro.font(11)).foregroundStyle(Retro.dim).fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Spacer()
                                Button("Cancel") { model.pending = nil }
                                    .buttonStyle(.retro).keyboardShortcut(.cancelAction)
                                Button(confirm(action)) { model.confirmPending() }
                                    .buttonStyle(.retroDefault).keyboardShortcut(.defaultAction)
                            }
                        }
                    }
                    .padding(20)
                }
                .frame(width: 560)
            }
        }
    }

    private func title(_ action: CleanAction) -> String {
        switch action {
        case .trash, .trashContents: "MOVE TO TRASH?"
        case .emptyTrash: "EMPTY TRASH?"
        }
    }

    private func question(_ action: CleanAction) -> String {
        let node = action.node
        switch action {
        case .trash: return "Move “\(node.name)” (\(bytes(node.size))) to the Trash?"
        case .trashContents: return "Move everything inside “\(node.name)” (\(bytes(node.size))) to the Trash?"
        case .emptyTrash: return "Empty the Trash and free \(bytes(node.size))?"
        }
    }

    private func confirm(_ action: CleanAction) -> String {
        switch action {
        case .trash, .trashContents: "Move to Trash"
        case .emptyTrash: "Empty Trash"
        }
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model
    let toast: Toast

    var body: some View {
        let color = toast.isError ? Retro.red : Retro.green
        HStack(spacing: 12) {
            if toast.isError {
                PixelSprite(sprite: Sprites.bang, pixel: 3, ink: Retro.red)
            } else {
                PixelSprite(sprite: Sprites.trash, pixel: 2)
            }
            Text(toast.text).font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if toast.offersTrash {
                Button("Open Trash") { NSWorkspace.shared.open(URL.homeDirectory.appending(path: ".Trash")) }.buttonStyle(.retro)
            }
            Button("OK") { model.toast = nil }.buttonStyle(.retro)
        }
        .padding(14)
        .frame(maxWidth: 700)
        .background(Retro.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color.opacity(0.8), lineWidth: 1.5))
        .glow(color, 8)
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(9))
            if model.toast?.id == toast.id { model.toast = nil }
        }
    }
}
