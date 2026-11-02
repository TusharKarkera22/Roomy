import RoomyCore
import SwiftUI

/// Browse the scanned tree largest-first, or list the biggest files anywhere inside a folder.
struct ExplorerView: View {
    @Environment(AppModel.self) private var model
    @State private var showLargestFiles = false
    @State private var largestFiles: [Node] = []

    var body: some View {
        let _ = model.revision
        if let folder = model.current, let tree = model.result?.tree {
            HStack(alignment: .top, spacing: 18) {
                RetroPanel(clip(folder.name, 30)) {
                    VStack(spacing: 0) {
                        header(folder, tree: tree)
                        Hairline()
                        tabs
                        Hairline()
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if showLargestFiles {
                                    ForEach(largestFiles) { file in
                                        NodeRow(node: file, largest: largestFiles.first?.size ?? 1, location: relativeLocation(of: file, in: folder))
                                    }
                                    if largestFiles.isEmpty {
                                        Text("No files of 1 MB or more in here.").font(Retro.font(12)).foregroundStyle(Retro.dim).padding(24)
                                    }
                                } else {
                                    let largest = max(folder.children.first?.size ?? 0, folder.smallFilesSize, 1)
                                    ForEach(folder.children) { child in
                                        NodeRow(node: child, largest: largest)
                                    }
                                    if folder.smallFiles > 0 {
                                        SmallFilesRow(count: folder.smallFiles, size: folder.smallFilesSize, largest: largest)
                                    }
                                    if folder.children.isEmpty && folder.smallFiles == 0 {
                                        Text(folder.isLocked ? "macOS kept this folder closed." : "This folder is empty.")
                                            .font(Retro.font(12)).foregroundStyle(Retro.dim).padding(24)
                                    }
                                }
                            }
                        }
                    }
                }
                InfoPanel().frame(width: 350)
            }
            .task(id: "\(ObjectIdentifier(folder).hashValue)-\(model.revision)-\(showLargestFiles)") {
                if showLargestFiles { largestFiles = folder.largestFiles(limit: 300) }
            }
        } else {
            RetroPanel("EXPLORE") {
                Text("Scan a place first.").font(Retro.font(13)).foregroundStyle(Retro.phosphor).padding(30)
            }
        }
    }

    private func header(_ folder: Node, tree: Node) -> some View {
        HStack(spacing: 10) {
            Button("‹ Back") {
                model.selected = folder
                model.current = folder.parent
            }
            .buttonStyle(.retro)
            .disabled(folder === tree)
            .keyboardShortcut("[", modifiers: .command)

            ForEach(Array(trail(to: folder, from: tree).enumerated()), id: \.offset) { index, step in
                if index > 0 { Text("/").font(Retro.font(12)).foregroundStyle(Retro.dim) }
                Button(step.name) { model.enter(step) }
                    .buttonStyle(.plain)
                    .font(Retro.font(12))
                    .foregroundStyle(step === folder ? Retro.amber : Retro.phosphor)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VerdictTag(verdict: model.rule(for: folder)?.verdict, isLocked: folder.isLocked)
            PixelText(text: bytes(folder.size), pixel: 2.6, color: Retro.amber)
        }
        .padding(12)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            Tab(title: "In this folder", isActive: !showLargestFiles) { showLargestFiles = false }
            Tab(title: "Largest files inside", isActive: showLargestFiles) { showLargestFiles = true }
            Spacer()
            Text(showLargestFiles ? "Every file of 1 MB or more, however deep" : "Double-click a folder to open it")
                .font(Retro.font(10.5)).foregroundStyle(Retro.dim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// The folders from the scan root down to `folder`, shortened to the last few.
    private func trail(to folder: Node, from tree: Node) -> [Node] {
        var steps: [Node] = []
        var step: Node? = folder
        while let node = step {
            steps.insert(node, at: 0)
            if node === tree { break }
            step = node.parent
        }
        return Array(steps.suffix(4))
    }

    private func relativeLocation(of file: Node, in folder: Node) -> String {
        let parent = file.parent?.path ?? ""
        return parent == folder.path ? "in this folder" : "in " + String(parent.dropFirst(folder.path.count + 1))
    }
}

private struct Tab: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Retro.font(10.5)).tracking(1)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .foregroundStyle(isActive ? Retro.screen : Retro.phosphor)
                .background(Capsule().fill(isActive ? Retro.amber : .clear))
                .overlay(Capsule().stroke(isActive ? Retro.amber : Retro.line, lineWidth: 1))
                .glow(Retro.amber, isActive ? 5 : 0)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NodeRow: View {
    @Environment(AppModel.self) private var model
    let node: Node
    let largest: Int64
    /// Where a file sits, shown in the Largest files list.
    var location: String? = nil

    var body: some View {
        let rule = model.rule(for: node)
        let isSelected = model.selected === node
        let color = node.isOtherDisk ? Retro.dim : Retro.color(rule?.verdict, locked: node.isLocked)
        HStack(spacing: 12) {
            Rectangle().fill(isSelected ? Retro.amber : .clear).frame(width: 3).glow(Retro.amber, isSelected ? 4 : 0)
            PixelSprite(sprite: node.isDirectory ? Sprites.folder : Sprites.file, pixel: 1.5).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(node.name).font(Retro.font(12.5)).foregroundStyle(isSelected ? Retro.amber : Retro.phosphor).lineLimit(1)
                    if let title = rule?.title {
                        Text(title).font(Retro.font(10.5)).foregroundStyle(Retro.dim).lineLimit(1)
                    }
                }
                if let location {
                    Text(location).font(Retro.font(10)).foregroundStyle(Retro.dim).lineLimit(1).truncationMode(.middle)
                }
                SegmentBar(fraction: Double(node.size) / Double(max(largest, 1)), color: color, height: 5)
            }
            VerdictTag(verdict: rule?.verdict, isLocked: node.isLocked, isOtherDisk: node.isOtherDisk)
                .frame(width: 96, alignment: .trailing)
            Text(node.isLocked || node.isOtherDisk ? "—" : bytes(node.size))
                .font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                .frame(width: 86, alignment: .trailing)
            Group {
                if node.isDirectory {
                    Button { model.enter(node) } label: {
                        Text("›").font(.system(size: 18, weight: .heavy)).foregroundStyle(Retro.amber)
                            .frame(width: 22, height: 22).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open folder")
                } else {
                    Color.clear
                }
            }
            .frame(width: 22)
        }
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Retro.amber.opacity(0.1) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if node.isDirectory { model.enter(node) } }
        .onTapGesture { model.selected = node }
        .contextMenu {
            Button("Reveal in Finder") { reveal(node.url) }
            if let action = model.cleanAction(for: node) {
                Button(action.buttonTitle) { model.pending = action }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Retro.phosphor.opacity(0.07)).frame(height: 1) }
    }
}

private struct SmallFilesRow: View {
    let count: Int
    let size: Int64
    let largest: Int64

    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 3)
            PixelSprite(sprite: Sprites.file, pixel: 1.5).frame(width: 24).opacity(0.5)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(count.formatted()) small files").font(Retro.font(12.5)).foregroundStyle(Retro.phosphor)
                Text("Each under 1 MB, grouped together").font(Retro.font(10.5)).foregroundStyle(Retro.dim)
                SegmentBar(fraction: Double(size) / Double(max(largest, 1)), color: Retro.dim, height: 5)
            }
            Spacer()
            Text(bytes(size)).font(Retro.font(12)).foregroundStyle(Retro.phosphor).frame(width: 86, alignment: .trailing)
            Color.clear.frame(width: 22)
        }
        .padding(.trailing, 12)
        .padding(.vertical, 7)
    }
}

/// Explains the selected item, or the open folder when nothing is selected.
struct InfoPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let _ = model.revision
        RetroPanel("INFO") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let node = model.selected ?? model.current {
                        let rule = model.rule(for: node)
                        HStack(spacing: 14) {
                            PixelSprite(sprite: node.isDirectory ? Sprites.folder : Sprites.file, pixel: 3).glow(Retro.amber, 4)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(node.name).font(Retro.font(14)).bold().foregroundStyle(Retro.phosphor).textSelection(.enabled)
                                PixelText(text: node.isLocked || node.isOtherDisk ? "N/A" : bytes(node.size), pixel: 2.4, color: Retro.amber)
                            }
                        }
                        VerdictTag(verdict: rule?.verdict, isLocked: node.isLocked, isOtherDisk: node.isOtherDisk)
                        Text(tildePath(node.url)).font(Retro.font(10)).foregroundStyle(Retro.dim).textSelection(.enabled)
                        Hairline()

                        if node.isOtherDisk {
                            Field(label: "Another disk", text: "A separate disk or a connected device (such as an iPhone) appears here. It doesn't use this Mac's disk, so Roomy doesn't measure it.")
                        }
                        if node.isLocked {
                            Field(label: "macOS kept this folder closed", text: "Roomy couldn't look inside, so it isn't counted. Give Roomy Full Disk Access to measure it.")
                            Button("Give Full Disk Access…") { model.screen = .access }.buttonStyle(.retro)
                        }
                        Explanation(rule: rule)
                        if node.isDirectory && node.smallFiles > 0 {
                            Field(label: "Small files", text: "\(node.smallFiles.formatted()) files under 1 MB, \(bytes(node.smallFilesSize)) together.")
                        }

                        let action = model.cleanAction(for: node)
                        HStack {
                            Button("Reveal in Finder") { reveal(node.url) }.buttonStyle(.retro)
                            if let action {
                                Button(action.buttonTitle) { model.pending = action }.buttonStyle(.retroDefault)
                            }
                        }
                        if case .trashContents = action {
                            Text("macOS expects this folder to exist, so Roomy keeps the folder and moves everything inside it to the Trash.")
                                .font(Retro.font(10.5)).foregroundStyle(Retro.dim).fixedSize(horizontal: false, vertical: true)
                        } else if action == nil && !node.isLocked && !node.isOtherDisk {
                            Text("Roomy won't remove this folder itself: it's the scanned folder, or a top-level one like Library. Open it and clean what's inside.")
                                .font(Retro.font(10.5)).foregroundStyle(Retro.dim).fixedSize(horizontal: false, vertical: true)
                        }
                        if model.selected == nil {
                            Text("Click an item to see what it is. Double-click a folder to open it.")
                                .font(Retro.font(10.5)).foregroundStyle(Retro.dim)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The scanned folder itself can't be trashed from here: the tree would have nothing left to show.
func canTrash(_ node: Node) -> Bool {
    node.parent != nil && Safety.canTrash(node.url)
}
