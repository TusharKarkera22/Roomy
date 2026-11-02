import SwiftUI

/// First launch: Roomy is offline, and the user picks full access or folder-by-folder.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        RetroPanel("WELCOME") {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 24) {
                    Mascot(pixel: 7)
                    VStack(alignment: .leading, spacing: 12) {
                        PixelText(text: "HI, I'M ROOMY", pixel: 5, color: Retro.amber, aberration: true)
                        Text("I'll find out where your disk space went, explain every big folder, and tell you what's safe to delete.")
                            .font(Retro.font(13)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    PixelSprite(sprite: Sprites.lock, pixel: 3)
                    VStack(alignment: .leading, spacing: 6) {
                        PixelText(text: "100% OFFLINE", pixel: 2, color: Retro.green)
                        Text("Roomy never connects to the internet. No account, no tracking, nothing about your files leaves this Mac. It only reads sizes and names, and moves things to the Trash only when you say so.")
                            .font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Retro.green.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))

                Text("To measure every folder, macOS needs your permission. Pick one:")
                    .font(Retro.font(12)).foregroundStyle(Retro.dim)

                HStack(alignment: .top, spacing: 16) {
                    Choice(title: "FULL ACCESS", note: "RECOMMENDED",
                           text: "One switch in System Settings and Roomy measures everything, including Mail, Messages and other apps' data.",
                           button: "Give Full Access", isDefault: true) {
                        model.screen = .access
                        model.openFullDiskAccessSettings()
                    }
                    Choice(title: "ONE BY ONE", note: nil,
                           text: "Roomy starts now. macOS asks before Roomy opens Documents, Downloads, Desktop and other protected folders. Anything you don't allow is skipped and marked Locked.",
                           button: "Scan Without It", isDefault: false) {
                        model.finishOnboarding()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
        }
        .frame(maxWidth: 800)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Choice: View {
    let title: String
    let note: String?
    let text: String
    let button: String
    let isDefault: Bool
    let action: () -> Void

    var body: some View {
        let accent = isDefault ? Retro.amber : Retro.phosphor
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PixelText(text: title, pixel: 2.4, color: accent)
                if let note {
                    Text(note).font(Retro.font(9)).bold().foregroundStyle(Retro.screen)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Retro.green).glow(Retro.green, 3)
                }
            }
            Text(text).font(Retro.font(12)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(button, action: action).buttonStyle(isDefault ? .retroDefault : .retro)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(GlowingCard(color: accent, fill: accent.opacity(isDefault ? 0.06 : 0.02), border: accent.opacity(isDefault ? 0.9 : 0.35),
                                glow: isDefault ? 0.5 : 0, radius: 6, cornerRadius: 10))
    }
}

/// Walks the user through adding Roomy to Full Disk Access, and notices when it's on.
struct AccessView: View {
    @Environment(AppModel.self) private var model
    @State private var granted = AppModel.hasFullDiskAccess

    var body: some View {
        RetroPanel("FULL DISK ACCESS", accent: Retro.magenta) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    PixelSprite(sprite: Sprites.lock, pixel: 4)
                    VStack(alignment: .leading, spacing: 8) {
                        PixelText(text: "3 STEPS, 20 SECONDS", pixel: 3.4, color: Retro.magenta, aberration: true)
                        Text("Roomy stays offline either way. This only lets it read folder sizes macOS normally hides.")
                            .font(Retro.font(12)).foregroundStyle(Retro.dim)
                    }
                }
                Step(number: 1, text: "Click Open Settings. System Settings opens at Privacy & Security › Full Disk Access, and a Finder window shows Roomy.")
                Step(number: 2, text: "Roomy isn't in the list yet, because macOS only lists apps you add. Drag Roomy from the Finder window into the list (or click + and pick Roomy), then switch it on.")
                Step(number: 3, text: "If macOS offers Quit & Reopen, click it. Otherwise click Restart Roomy below.")

                HStack(spacing: 12) {
                    if granted {
                        PixelSprite(sprite: Sprites.check, pixel: 2.5, ink: Retro.green)
                        PixelText(text: "ACCESS IS ON. STARTING...", pixel: 2, color: Retro.green)
                    } else {
                        Chaser(color: Retro.magenta).frame(width: 140)
                        Text("Waiting for you to switch Roomy on…").font(Retro.font(12)).foregroundStyle(Retro.phosphor)
                    }
                }

                HStack(spacing: 10) {
                    Button("Open Settings") { model.openFullDiskAccessSettings() }.buttonStyle(.retroDefault)
                    Button("Restart Roomy") { model.relaunch() }.buttonStyle(.retro)
                    Spacer()
                    Button("Skip, ask one by one") { model.finishOnboarding() }.buttonStyle(.retro)
                }

                Text("Building Roomy yourself? Each new build looks like a new app to macOS, so switch it on again after rebuilding.")
                    .font(Retro.font(10.5)).foregroundStyle(Retro.dim)
            }
            .padding(26)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // macOS may apply the switch to the running app; if so, carry on without a restart.
            while !Task.isCancelled && !granted {
                try? await Task.sleep(for: .seconds(1.5))
                granted = AppModel.hasFullDiskAccess
            }
            guard granted else { return }
            try? await Task.sleep(for: .seconds(1))
            model.finishOnboarding()
        }
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PixelText(text: "\(number)", pixel: 3, color: Retro.screen, glows: false)
                .frame(width: 30, height: 30)
                .background(Retro.magenta)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .glow(Retro.magenta, 5)
            Text(text).font(Retro.font(12.5)).foregroundStyle(Retro.phosphor).fixedSize(horizontal: false, vertical: true)
        }
    }
}
