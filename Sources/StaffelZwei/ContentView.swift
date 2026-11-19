import AVKit
import SwiftUI
import StaffelCore
/// Hauptfenster: NavigationSplitView mit Fall/Spuren links, Inhalt rechts.
public struct ContentView: View {
    @Bindable var model: AppModel
    public init(model: AppModel) {
        self.model = model
    }
    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(minWidth: 680, minHeight: 460)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Palette.paper.opacity(0.35))
    }
    // MARK: Sidebar
    private var sidebar: some View {
        List(selection: Binding(
            get: { model.page },
            set: { if let page = $0 { model.page = page } }
        )) {
            Section {
                Label("Einsatzrahmen", systemImage: "doc.text.magnifyingglass")
                    .tag(AppPage.briefing)
                Label("Terminal", systemImage: "terminal")
                    .tag(AppPage.terminal)
                if model.supportsDesktop {
                    Label("Bildschirm", systemImage: "display")
                        .tag(AppPage.desktop)
                }
                Label("Aktenwand", systemImage: "rectangle.stack")
                    .tag(AppPage.aktenwand)
                Label(model.episode.id == 7 ? "Übergabe" : "Vorwurf", systemImage: "flag")
                    .tag(AppPage.vorwurf)
                Label("Hilfe & Werkzeuge", systemImage: "questionmark.circle")
                    .tag(AppPage.help)
            } header: {
                Text("Fall \(model.episode.id) · \(model.episode.title)")
            }
            Section("Episoden") {
                ForEach(EpisodeCatalog.all) { episode in
                    Button {
                        model.selectEpisode(episode)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Episode \(episode.id) · \(episode.title)")
                                    .lineLimit(2)
                                Text(episode.caseTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: !model.isUnlocked(episode) ? "lock" :
                                    model.episode.id == episode.id ? "play.circle.fill" : "play.circle")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(model.terminalBusy || !model.isUnlocked(episode))
                    .accessibilityLabel("Episode \(episode.id) · \(episode.title)")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 224, max: 300)
        .safeAreaInset(edge: .bottom) {
            ProgressSummaryView(
                completedTracks: model.state.completedTracks,
                trackCount: model.episode.tracks.count,
                evidenceCount: model.state.evidences.count,
                validatedCount: model.state.evidences.filter(\.validated).count,
                repaired: model.state.repaired,
                solved: model.state.solved,
                layout: .vertical, caseID: model.episode.id
            )
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(.bar)
        }
    }
    // MARK: Detail
    @ViewBuilder
    private var detail: some View {
        switch model.page {
        case .briefing:
            BriefingView(model: model).id(model.episode.id)
        case .terminal:
            TerminalView(model: model)
        case .desktop:
            LinuxDesktopView(model: model)
        case .aktenwand:
            AktenwandView(model: model)
        case .vorwurf:
            if model.episode.id == 7 {
                FinaleHandoffView(model: model)
            } else {
                VorwurfView(model: model)
            }
        case .help:
            HelpView(model: model)
        }
    }
}
// MARK: - Einsatzrahmen
struct BriefingView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingTrailer = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                header
                    .gridProbe("header", area: "page")
                Einsatzszene(episodeID: model.episode.id, solved: model.state.solved,
                             michaActivity: $model.lastMichaInteraction,
                             isShowingTrailer: showingTrailer, openTerminal: { model.page = .terminal },
                             openDesktop: { model.page = .desktop })
                .gridProbe("einsatzszene", area: "page")
                Button {
                    showingTrailer = true
                } label: {
                    Label("NACHTDIFF-Trailer ansehen", systemImage: "play.circle")
                }
                .gridProbe("trailer", area: "page")
                if model.state.solved {
                    successBanner
                        .gridProbe("success", area: "page")
                }
                Text(model.episode.briefing)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridProbe("briefing", area: "page")
                linuxNotice
                    .gridProbe("notice", area: "page")
                ForEach(model.episode.tracks) { track in
                    TrackSection(model: model, track: track)
                        .gridProbe("track-\(track.id)", area: "page")
                }
                if let warning = model.loadWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(Palette.evidenceAmber)
                        .padding(Space.md)
                        .background(Palette.evidenceAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        .gridProbe("warning", area: "page")
                }
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("page")
        }
        .background(Palette.paper.opacity(colorScheme == .dark ? 0.04 : 0.25))
        .sheet(isPresented: $showingTrailer) {
            TrailerView()
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Episode \(model.episode.id) · \(model.episode.title)")
                .font(.largeTitle.bold())
            Text(model.episode.caseTitle)
                .font(.title2)
                .foregroundStyle(Palette.copper)
            HStack(spacing: Space.sm) {
                Label(model.episode.organization, systemImage: "building.2")
                Label("Konto \(model.episode.account)", systemImage: "person")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
    private var linuxNotice: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(Palette.copper)
            Text("Die Befehle laufen als azubi in einer lokalen Alpine-Linux-VM ohne Netzwerk und ohne Zugriff auf deine Mac-Ordner.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Palette.copperSoft, in: RoundedRectangle(cornerRadius: 8))
    }
    private var successBanner: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label(model.episode.id == 7 ? "Staffel abgeschlossen" :
                    model.episode.id == 0 ? "Probelauf bestanden. Jetzt wird es ernst." : "Fall gelöst",
                  systemImage: "flag.checkered")
                .font(.title3.bold())
                .foregroundStyle(Palette.evidenceGreen)
            if let message = BrowserMission.forEpisode(model.episode.id)?.resolution {
                Text(message).font(.callout)
            } else {
                Text("Auf Juris Bon stehen 0,50 Euro. Die Sicherung bestätigt Rikes 2,50 Euro. Der nächtliche Abgleich des Kaffeeautomaten hat die Buchung verändert. Rike heftet beide Fassungen zusammen. In Episode 1 wartet die nächste Akte: „Zu viele Rechte“.")
                    .font(.callout)
                Label("Beweisstück „Der Bon von 03:12 Uhr“ · Code S2-E0-KASSE", systemImage: "shippingbox")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if model.episode.id == 7 {
                DisclosureGroup("Übergabebericht") {
                    Text(FinaleHandoffView.report).textSelection(.enabled)
                }
                ShareLink(item: FinaleHandoffView.report) { Label("Bericht teilen", systemImage: "square.and.arrow.up") }
            }
            if let next = EpisodeCatalog.all.first(where: { $0.id == model.episode.id + 1 }), model.isUnlocked(next) {
                Button("Weiter zu Episode \(next.id)") { model.selectEpisode(next) }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.evidenceGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TrailerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("NACHTDIFF · Ein Linux-Krimi")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Schließen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            if let player {
                TrailerPlayer(player: player)
                    .frame(width: 768, height: 432)
                    .accessibilityLabel("NACHTDIFF-Trailer")
            } else {
                Text("Der Trailer konnte im App-Bundle nicht gefunden werden.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Space.lg)
        .onAppear {
            guard let url = Bundle.main.url(forResource: "StaffelZwei-Trailer", withExtension: "mp4") else {
                return
            }
            let trailer = AVPlayer(url: url)
            player = trailer
            trailer.play()
        }
        .onDisappear { player?.pause() }
    }
}

struct TrailerPlayer: NSViewRepresentable {
    let player: AVPlayer
    var controls: AVPlayerViewControlsStyle = .inline

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = controls
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
    }
}

// MARK: - Spur
struct TrackSection: View {
    @Bindable var model: AppModel
    let track: Track
    private var steps: [EpisodeStep] {
        model.episode.steps.filter { $0.trackID == track.id }
    }
    private var evidenceForTrack: [Evidence] {
        model.state.evidences.filter { $0.trackID == track.id }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text(track.title)
                    .font(.title3.bold())
                    .gridProbe("track-title-\(track.id)", area: "card-\(track.id)")
                Text(track.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: Space.md) {
                    Image(systemName: done(step) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done(step) ? Palette.evidenceGreen : Palette.copper)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.headline)
                        Text(step.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let command = step.command {
                            Text(command)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, Space.sm)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                                .textSelection(.enabled)
                        }
                        if let mission = BrowserMission.forEpisode(model.episode.id) {
                            if model.episode.id != 7, let answer = mission.responses[step.id] {
                                MissionAnswerView(model: model, step: step, answer: answer)
                            }
                            let hints = mission.stepsByID[step.id]?.hints ?? []
                            if !hints.isEmpty {
                                DisclosureGroup("Hinweise") {
                                    VStack(alignment: .leading, spacing: Space.xs) {
                                        ForEach(hints, id: \.self) { Text($0).textSelection(.enabled) }
                                    }
                                    .font(.callout)
                                }
                            }
                        }
                    }
                }
            }
            if !evidenceForTrack.isEmpty {
                HStack(spacing: Space.md) {
                    ForEach(evidenceForTrack) { evidence in
                        EvidenceCardView(evidence: evidence, isSelected: model.selectedEvidenceIDs.contains(evidence.id)) {
                            model.toggleEvidence(evidence.id)
                        }
                        .frame(maxWidth: 260)
                    }
                }
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .gridArea("card-\(track.id)", inset: Space.lg)
    }
    private func done(_ step: EpisodeStep) -> Bool {
        if model.episode.id != 0 { return model.state.isStepComplete(step.id) }
        switch step.id {
        case "meta-sichern":
            return model.state.evidences.first { $0.specID == "kasse-meta" }?.validated == true
        case "zeilen-original":
            return model.state.evidences.first { $0.specID == "kasse-zeilen" }?.validated == true
        case "reparatur":
            return model.state.repaired
        case "vorwurf":
            return model.state.solved
        default:
            return false
        }
    }
}

struct MissionAnswerView: View {
    let model: AppModel
    let step: EpisodeStep
    let answer: BrowserMission.Answer
    @State private var input = ""
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(answer.question).font(.callout)
            if model.state.isStepComplete(step.id) {
                Label("Antwort angenommen", systemImage: "checkmark.circle")
                    .foregroundStyle(Palette.evidenceGreen)
            } else {
                HStack {
                    TextField(answer.format, text: $input)
                        .onSubmit(verify)
                        .accessibilityLabel(answer.question)
                    Button("Antwort prüfen", action: verify)
                        .disabled(model.terminalBusy || input.isEmpty)
                }
                if let feedback { Text(feedback).font(.caption).foregroundStyle(Palette.copper) }
            }
        }
    }

    private func verify() {
        guard !model.terminalBusy, !input.isEmpty else { return }
        Task { feedback = await model.submitAnswer(input, for: step.id) }
    }
}
