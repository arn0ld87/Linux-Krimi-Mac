import SwiftUI
import Virtualization
import StaffelCore

struct LinuxDesktopView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.sm) {
                Label("Linux-Bildschirm", systemImage: "display")
                    .font(.headline)
                Spacer()
                launcher("Dateimanager", icon: "folder", action: "files")
                launcher("Grafisches Terminal", icon: "terminal", action: "terminal")
                launcher("Texteditor", icon: "doc.text", action: "editor")
                if BrowserMission.forEpisode(model.episode.id)?.desktop?.photo != nil {
                    launcher("Bildbetrachter", icon: "photo", action: "photo")
                }
                Button("Stand prüfen") { model.refreshGuest() }
                    .disabled(!model.desktopReady || model.terminalBusy)
            }
            if let machine = model.desktopMachine {
                LinuxMachineDisplay(machine: machine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .accessibilityLabel("Grafische Oberfläche von Alpine Linux")
            } else if let message = model.desktopMessage {
                ScrollView {
                    Text(message)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
                Button("Bildschirm erneut starten") { Task { await model.useDesktop("start") } }
                    .disabled(model.terminalBusy)
            } else {
                ProgressView("Linux-Bildschirm startet …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(Space.md)
        .task {
            while model.terminalBusy, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if !Task.isCancelled { await model.useDesktop("start") }
        }
    }

    private func launcher(_ title: String, icon: String, action: String) -> some View {
        Button {
            Task { await model.useDesktop(action) }
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(!model.desktopReady || model.terminalBusy)
    }
}

private struct LinuxMachineDisplay: NSViewRepresentable {
    let machine: VZVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.virtualMachine = machine
        return view
    }

    func updateNSView(_ view: VZVirtualMachineView, context: Context) {
        view.virtualMachine = machine
    }
}
