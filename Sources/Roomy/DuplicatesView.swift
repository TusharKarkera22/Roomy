import RoomyCore
import SwiftUI

struct DuplicatesView: View {
    @Environment(AppModel.self) private var model
    @State private var folder = URL.homeDirectory.appending(path: "Downloads")
    @State private var groups: [DuplicateGroup] = []
    @State private var scanning = false
    @State private var scanned = false

    var body: some View {
        RetroPanel("DUPLICATES") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    PixelSprite(sprite: Sprites.folder, pixel: 1.5)
                    Text(tildePath(folder)).font(Retro.font(12)).foregroundStyle(Retro.phosphor).lineLimit(1).truncationMode(.head)
                    Button("Choose Folder…") {
                        if let url = chooseFolder() { folder = url; groups = []; scanned = false }
                    }
                    .buttonStyle(.retro)
                    Spacer()
                    Button("Find Duplicates") { Task { await scan() } }
                        .buttonStyle(.retroDefault)
                        .disabled(scanning)
                }
                .padding(14)
                Hairline()

                if scanning {
                    VStack(spacing: 18) {
                        Mascot(pixel: 5, walking: true)
                        Chaser().frame(maxWidth: 320)
                        PixelText(text: "COMPARING FILES...", pixel: 2.4, color: Retro.amber)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if scanned && groups.isEmpty {
                    VStack(spacing: 16) {
                        Mascot(pixel: 5)
                        PixelText(text: "NO DUPLICATES!", pixel: 3.5, color: Retro.green, aberration: true)
                        Text("No identical files of 1 MB or more in this folder.").font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !scanned {
                    VStack(alignment: .leading, spacing: 12) {
                        PixelText(text: "FIND THE COPIES", pixel: 3.5, color: Retro.amber, aberration: true)
                        Text("Pick a folder and click Find Duplicates. Your Downloads folder is a good start.")
                            .font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                    }
                    .padding(26)
                    Spacer()
                } else {
                    HStack(spacing: 10) {
                        PixelText(text: bytes(groups.reduce(0) { $0 + $1.wasted }), pixel: 3, color: Retro.amber)
                        Text("taken by extra copies. Keep one of each and trash the rest.").font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                    }
                    .padding(14)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(groups) { group in
                                CopiesBox(group: group) { trash($0, from: group.id) }
                            }
                        }
                        .padding(14)
                    }
                }

                Hairline()
                Text("Files of 1 MB or more are compared by their full contents. The last copy of a file can't be trashed here. Copies made with Finder's Duplicate command can share disk space, so trashing them may free less than shown.")
                    .font(Retro.font(10.5)).foregroundStyle(Retro.dim).padding(12)
            }
        }
    }

    private func scan() async {
        scanning = true
        let folder = folder
        groups = await Task.detached { Duplicates.find(in: folder) }.value
        scanning = false
        scanned = true
    }

    /// Once one copy is left the group disappears, so the last copy can never be trashed here.
    private func trash(_ file: URL, from groupID: UUID) {
        do {
            try Safety.trash(file)
        } catch {
            model.toast = Toast(text: error.localizedDescription, isError: true)
            return
        }
        model.toast = Toast(text: "Moved “\(file.lastPathComponent)” to the Trash.", offersTrash: true)
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].files.removeAll { $0 == file }
        if groups[index].files.count < 2 { groups.remove(at: index) }
    }
}

private struct CopiesBox: View {
    let group: DuplicateGroup
    let onTrash: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(group.files.count) COPIES · \(bytes(group.size)) EACH").font(Retro.font(11)).tracking(1).foregroundStyle(Retro.amber)
                Spacer()
                Text("\(bytes(group.wasted)) extra").font(Retro.font(11)).foregroundStyle(Retro.phosphor)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Retro.amber.opacity(0.08))
            Hairline()
            ForEach(group.files, id: \.self) { file in
                HStack(spacing: 10) {
                    PixelSprite(sprite: Sprites.file, pixel: 1.25)
                    Text(tildePath(file)).font(Retro.font(11)).foregroundStyle(Retro.phosphor)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer()
                    Button("Reveal") { reveal(file) }.buttonStyle(.retro)
                    Button("Trash") { onTrash(file) }.buttonStyle(.retro)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Retro.amber.opacity(0.45), lineWidth: 1))
    }
}
