import AppKit
import AVKit
import SwiftUI

enum FinaleScene: String, Identifiable {
    case briefing = "ep4-briefing"
    case dispatch = "ep5-ausgang"
    case clocks = "ep6-uhren"
    case credits = "ep7-abspann"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .briefing: "Alex’ Briefing"
        case .dispatch: "Blick in den lokalen Ausgang"
        case .clocks: "Zwei Uhren ansehen"
        case .credits: "Schlusssequenz ansehen"
        }
    }

    var caption: String {
        switch self {
        case .briefing: "Sichere die Freigabe und den tatsächlich erzeugten Export. Der Dateiname sagt nichts über den Inhalt."
        case .dispatch: "EXPORT-07 wurde lokal bereitgestellt. Der externe Empfang ist unbelegt."
        case .clocks: "Z bedeutet UTC. Ziehe bei +02:00 zwei Stunden ab. Der Linux-Texteditor öffnet die Uhrzeit-Legende."
        case .credits: "Margit übernimmt die dokumentierte Übergabe. Der lokale Testausgang enthält die freigegebenen Messwerte."
        }
    }

    fileprivate var parts: [FinalePart] {
        switch self {
        case .briefing:
            [FinalePart(video: rawValue, audio: "ep4-briefing", caption: "Alex · " + caption)]
        case .credits:
            [
                FinalePart(video: "ep7-alex", audio: "ep7-abschluss",
                           caption: "Alex · Wir haben geklärt, wer den Export bereitstellte und wer die Spur löschte. Einen externen Empfang können wir nicht belegen."),
                FinalePart(video: "ep7-micha", audio: "micha-ep7-abschluss",
                           caption: "Micha · Und diesmal läuft nur, was freigegeben ist."),
                FinalePart(video: rawValue, audio: nil, caption: caption),
            ]
        case .dispatch, .clocks:
            [FinalePart(video: rawValue, audio: nil, caption: caption)]
        }
    }

    static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Einsatzszene/finale")
    }

    static func poster(for name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Einsatzszene/finale"),
           let picture = NSImage(contentsOf: url) {
            return picture
        }
        switch name {
        case "ep4-briefing", "ep7-alex": return Einsatzbilder.load("alex-portraet", "png")
        case "ep7-micha": return Einsatzbilder.load("micha-awake", "jpg")
        default: return Einsatzbilder.load("serverraum", "webp")
        }
    }
}

private struct FinalePart {
    let video: String
    let audio: String?
    let caption: String
}

struct FinaleSceneView: View {
    let scene: FinaleScene
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var showVideo = false
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text(scene.title).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Schließen") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if let player, showVideo {
                TrailerPlayer(player: player)
                    .frame(width: 768, height: 432)
                    .accessibilityLabel(scene.title)
            } else if let picture = FinaleScene.poster(for: scene.parts[index].video) {
                Image(nsImage: picture)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 768, height: 432)
                    .accessibilityHidden(true)
            }
            Text(scene.parts[index].caption)
                .textSelection(.enabled)
                .frame(maxWidth: 768, alignment: .leading)
            HStack {
                Button("Erneut ansehen") { playPart(0) }
                if player != nil {
                    Button("Pause") { player?.pause() }
                    Button("Fortsetzen") { player?.play() }
                }
                if index + 1 < scene.parts.count {
                    Button("Weiter") { playPart(index + 1) }
                }
            }
        }
        .padding(Space.lg)
        .onAppear { playPart(0) }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { event in
            guard let item = event.object as? AVPlayerItem, item === player?.currentItem,
                  index + 1 < scene.parts.count else { return }
            playPart(index + 1)
        }
        .onDisappear { player?.pause() }
    }

    private func playPart(_ next: Int) {
        player?.pause()
        index = next
        let part = scene.parts[next]
        let video = reduceMotion ? nil : FinaleScene.url(for: part.video)
        let audio = part.audio.flatMap { Einsatzbilder.url($0, "mp3") }
        showVideo = video != nil
        player = (video ?? audio).map { AVPlayer(url: $0) }
        player?.play()
    }
}
