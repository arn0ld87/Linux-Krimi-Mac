import SwiftUI
import StaffelCore

// MARK: - Terminal

struct TerminalView: View {
    @Bindable var model: AppModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            terminalBar
                .gridProbe("terminal-bar", area: "terminal", edge: nil)
            Divider()
            transcript
                .gridProbe("terminal-transcript", area: "terminal", edge: nil)
            Divider()
            inputRow
                .gridProbe("terminal-input", area: "terminal", edge: nil)
        }
        .background(Palette.terminalBackground)
        .foregroundStyle(Palette.terminalForeground)
        .onAppear {
            inputFocused = true
            model.startLinux()
        }
        .gridArea("terminal", inset: 0)
    }

    private var terminalBar: some View {
        HStack(spacing: Space.md) {
            Circle().fill(Palette.terminalPrompt).frame(width: 8, height: 8)
            Text("azubi@rw-srv01")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Palette.terminalPrompt)
            Text(model.linuxMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(model.linuxMessage)
            Spacer()
            Text(model.state.cwd)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Palette.terminalBackground)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.state.transcript) { entry in
                        Text(entry.text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(color(for: entry.kind))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(entry.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(Space.md)
            }
            .onChange(of: model.state.transcript.last?.id) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func color(for kind: TranscriptEntry.Kind) -> Color {
        switch kind {
        case .input: return Palette.terminalForeground
        case .output: return Palette.terminalForeground.opacity(0.9)
        case .error: return Palette.terminalError
        case .system: return Palette.terminalPrompt.opacity(0.85)
        }
    }

    private var inputRow: some View {
        HStack(spacing: Space.sm) {
            Text("azubi@rw-srv01:\(promptPath)$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Palette.terminalPrompt)
            TextField(model.terminalBusy ? "Linux arbeitet …" : "Befehl eingeben", text: $model.terminalInput)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Palette.terminalForeground)
                .focused($inputFocused)
                .onSubmit { model.runCommand(model.terminalInput) }
                .accessibilityLabel("Terminal-Eingabe")
            Button {
                model.runCommand(model.terminalInput)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Befehl ausführen")
            .accessibilityLabel("Befehl ausführen")
            .disabled(model.terminalBusy)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .background(Palette.terminalBackground)
    }

    private var promptPath: String {
        let home = VPath.home
        if model.state.cwd == home { return "~" }
        if model.state.cwd.hasPrefix(home + "/") {
            return "~" + model.state.cwd.dropFirst(home.count)
        }
        return model.state.cwd
    }
}

// MARK: - Aktenwand

struct AktenwandView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktenwand")
                        .font(.largeTitle.bold())
                    Text("Gesicherte Ausgaben aus dem Übungsterminal. Nur was du per Umleitung in ~/belege/ geschrieben hast, liegt hier.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .gridProbe("aktenwand-header", area: "page")

                if model.state.evidences.isEmpty {
                    emptyState
                        .gridProbe("aktenwand-empty", area: "page")
                } else {
                    ForEach(model.episode.tracks) { track in
                        let items = model.state.evidences.filter { $0.trackID == track.id }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text(track.title)
                                    .font(.title3.bold())
                                Text(track.summary)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                ForEach(items) { evidence in
                                    EvidenceCardView(
                                        evidence: evidence,
                                        isSelected: model.selectedEvidenceIDs.contains(evidence.id)
                                    ) {
                                        model.toggleEvidence(evidence.id)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(Space.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .gridProbe("aktenwand-track-\(track.id)", area: "page")
                        }
                    }
                }

                ProgressSummaryView(
                    completedTracks: model.state.completedTracks,
                    trackCount: model.episode.tracks.count,
                    evidenceCount: model.state.evidences.count,
                    validatedCount: model.state.evidences.filter(\.validated).count,
                    repaired: model.state.repaired,
                    solved: model.state.solved, caseID: model.episode.id
                )
                .padding(.top, 4)
                .gridProbe("aktenwand-progress", area: "page")
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("page")
        }
        .background(Palette.paper.opacity(0.25))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label("Noch keine Belege", systemImage: "tray")
                .font(.title3.bold())
            Text("Ein Beleg entsteht, wenn du die echte Ausgabe eines Befehls in eine Datei unter ~/belege/ umleitest – zum Beispiel mit `ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt`. Abgetippter Text zählt nicht.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Vorwurf

struct VorwurfView: View {
    @Bindable var model: AppModel
    @State private var feedback: AccusationResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vorwurf erheben")
                        .font(.largeTitle.bold())
                    Text("Mindestens zwei anerkannte Belege, mindestens ein Beleg aus jeder Spur. Die Prüfung erfolgt frisch, vor der Bewertung.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .gridProbe("vorwurf-header", area: "page")

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Verdächtige")
                        .font(.title3.bold())
                    ForEach(model.episode.suspects) { suspect in
                        SuspectRow(
                            suspect: suspect,
                            isSelected: model.selectedSuspectID == suspect.id
                        ) {
                            model.selectedSuspectID = suspect.id
                        }
                        .selfTestProbe("suspect-\(suspect.id)")
                    }
                }
                .gridProbe("vorwurf-verdaechtige", area: "page")

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Belege")
                        .font(.title3.bold())
                    if model.state.evidences.isEmpty {
                        Text("Noch keine erkannten Belege.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.state.evidences) { evidence in
                            EvidenceCardView(
                                evidence: evidence,
                                isSelected: model.selectedEvidenceIDs.contains(evidence.id)
                            ) {
                                model.toggleEvidence(evidence.id)
                            }
                            .frame(maxWidth: .infinity)
                            .selfTestProbe("evidence-\(evidence.id)")
                        }
                    }
                }
                .gridProbe("vorwurf-belege", area: "page")

                if let feedback {
                    feedbackView(feedback)
                        .gridProbe("vorwurf-feedback", area: "page")
                }

                HStack {
                    Button {
                        feedback = model.submitAccusation()
                    } label: {
                        Label("Prüfen", systemImage: "checkmark.seal")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.copper)
                    .help("Vorwurf prüfen (Cmd-Return)")
                    .disabled(model.terminalBusy)
                    .selfTestProbe("accusation")

                    if model.state.solved {
                        Label(model.episode.id == 0 ? "Probelauf bestanden" : "Fall gelöst",
                              systemImage: "flag.checkered")
                            .foregroundStyle(Palette.evidenceGreen)
                    }
                }
                .gridProbe("vorwurf-pruefen", area: "page")
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("page")
        }
        .background(Palette.paper.opacity(0.25))
        .onChange(of: model.state.lastAccusationFeedback) { _, newValue in
            if let newValue {
                feedback = AccusationResult(outcome: .missingEvidence(reason: ""), message: newValue)
            }
        }
    }

    @ViewBuilder
    private func feedbackView(_ result: AccusationResult) -> some View {
        switch result.outcome {
        case .accepted:
            Label(result.message, systemImage: "checkmark.seal.fill")
                .foregroundStyle(Palette.evidenceGreen)
        case .wrongSuspect:
            Label(result.message, systemImage: "xmark.octagon")
                .foregroundStyle(Palette.terminalError)
        case .notRepaired:
            Label(result.message, systemImage: "wrench.and.screwdriver")
                .foregroundStyle(Palette.evidenceAmber)
        case .missingEvidence:
            Label(result.message, systemImage: "questionmark.folder")
                .foregroundStyle(Palette.evidenceAmber)
        }
    }
}

struct SuspectRow: View {
    let suspect: Suspect
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Space.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.copper : .secondary)
                if let portrait = Einsatzbilder.load(suspect.portraitName ?? suspect.id, "webp") {
                    Image(nsImage: portrait)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: suspect.systemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(suspect.name)
                        .font(.headline)
                    Text(suspect.detail.isEmpty ? suspect.role : "\(suspect.role) – \(suspect.detail)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Palette.copperSoft : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Palette.copper : Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(suspect.name), \(suspect.role). \(suspect.detail)")
        .accessibilityValue(isSelected ? "ausgewählt" : "nicht ausgewählt")
    }
}

// MARK: - Hilfe

struct HelpView: View {
    @Bindable var model: AppModel

    private let commands: [(String, String)] = [
        ("pwd", "Aktuelles Verzeichnis anzeigen"),
        ("cd <pfad>", "Verzeichnis wechseln (~, ., .. und absolute Pfade)"),
        ("ls [pfad]", "Dateien auflisten"),
        ("ls -l <pfad>", "Dateien mit Besitzer, Rechten und Datum auflisten"),
        ("stat <datei>", "Besitzer, Rechte und Zeitstempel anzeigen"),
        ("cat <datei...>", "Dateiinhalt anzeigen"),
        ("grep [-i] <muster> <datei...>", "Zeilen mit Muster anzeigen"),
        ("cp <quelle> <ziel>", "Datei kopieren (überschreibt den Inhalt)"),
        ("mkdir [-p] <pfad>", "Verzeichnis anlegen, falls das Konto Schreibrechte hat"),
        ("uname -sm", "Linux und die Architektur des Gasts anzeigen"),
        ("clear", "Bildschirm leeren"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hilfe & Werkzeuge")
                        .font(.largeTitle.bold())
                    Text("Das Terminal führt Befehlszeilen in der Alpine-Shell aus. Für die Ermittlungen stehen unter anderem die folgenden Werkzeuge zur Verfügung.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .gridProbe("help-header", area: "page")

                VStack(alignment: .leading, spacing: Space.md) {
                    Text("Befehle")
                        .font(.title3.bold())
                    ForEach(commands, id: \.0) { command, description in
                        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                            Text(command)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 232, alignment: .leading)
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .gridProbe("help-befehle", area: "page")

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Beispielbefehle")
                        .font(.title3.bold())
                    Text("Zum Kopieren gedacht – sie werden nicht automatisch ausgeführt.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(exampleCommands, id: \.self) { example in
                        HStack(spacing: Space.sm) {
                            Text(example)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(example, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .help("Befehl kopieren")
                            .accessibilityLabel("Befehl kopieren: \(example)")
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .gridProbe("help-beispiele", area: "page")

                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Tastatur")
                        .font(.title3.bold())
                    Label("Cmd-1 … Cmd-5 – Seiten wechseln", systemImage: "keyboard")
                    Label("Cmd-Return – Vorwurf prüfen", systemImage: "keyboard")
                    Label("Cmd-, – Einstellungen öffnen", systemImage: "keyboard")
                }
                .font(.callout)
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .gridProbe("help-tastatur", area: "page")

                Label("Die lokale Linux-VM besitzt eine eigene Festplatte und arbeitet offline. Änderungen in deinem Linux-Home und in der Übung bleiben im Spielstand erhalten.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.copperSoft, in: RoundedRectangle(cornerRadius: 8))
                    .gridProbe("help-hinweis", area: "page")
            }
            .padding(Space.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridArea("page")
        }
        .background(Palette.paper.opacity(0.25))
    }

    private var exampleCommands: [String] {
        [
            "ls -l /srv/rechenwerk/uebung/",
            "ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt",
            "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt",
            "grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt",
            "cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv",
        ]
    }
}
