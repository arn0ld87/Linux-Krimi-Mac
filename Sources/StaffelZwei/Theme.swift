import SwiftUI
import StaffelCore

/// Farbpalette: ruhiges Papier im Inhalt, sparsame kupferfarbene Akzente,
/// grünliches Terminal. Das Chrome bleibt in Systemfarben.
public enum Palette {
    // Terminal
    public static let terminalBackground = Color(red: 0.07, green: 0.09, blue: 0.08)
    public static let terminalForeground = Color(red: 0.85, green: 0.90, blue: 0.84)
    public static let terminalPrompt = Color(red: 0.62, green: 0.82, blue: 0.60)
    public static let terminalError = Color(red: 0.90, green: 0.47, blue: 0.38)

    // Inhalt (warmes Papier)
    public static let paper = Color(red: 0.93, green: 0.92, blue: 0.89)
    public static let ink = Color(red: 0.15, green: 0.15, blue: 0.13)
    public static let mutedInk = Color(red: 0.42, green: 0.41, blue: 0.38)

    // Akzent (Kupfer/Orange, sparsam)
    public static let copper = Color(red: 0.85, green: 0.44, blue: 0.22)
    public static let copperSoft = Color(red: 0.85, green: 0.44, blue: 0.22).opacity(0.12)

    // Belege
    public static let evidenceGreen = Color(red: 0.24, green: 0.52, blue: 0.36)
    public static let evidenceAmber = Color(red: 0.72, green: 0.52, blue: 0.16)
}

/// Ein Karteikarten-Beleg im Aktenwand-Stil.
public struct EvidenceCardView: View {
    let evidence: Evidence
    let isSelected: Bool
    let onToggle: () -> Void

    public init(evidence: Evidence, isSelected: Bool, onToggle: @escaping () -> Void) {
        self.evidence = evidence
        self.isSelected = isSelected
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: evidence.validated ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(evidence.validated ? Palette.evidenceGreen : Palette.evidenceAmber)
                        .font(.caption)
                    Text(evidence.title)
                        .font(.headline)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.copper)
                            .font(.caption)
                    }
                }
                Text(evidence.fileName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(evidence.validated ? "Anerkannt" : "Noch nicht anerkannt")
                    .font(.caption)
                    .foregroundStyle(evidence.validated ? Palette.evidenceGreen : Palette.evidenceAmber)
                if !evidence.validated, let hint = evidence.validationHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Palette.copperSoft : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Palette.copper : Color.primary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(evidence.title), \(evidence.validated ? "anerkannt" : "noch nicht anerkannt")")
        .accessibilityHint(isSelected ? "Auswahl aufheben" : "Als Beleg auswählen")
    }
}

/// Fortschrittsanzeige ohne erfundene Kennzahlen.
public struct ProgressSummaryView: View {
    /// Anordnung der Fortschrittszeilen.
    ///
    /// In der schmalen Sidebar müssen die Zeilen untereinander stehen –
    /// nebeneinander werden sie zeichenweise umgebrochen und unlesbar.
    public enum Layout: Sendable, Equatable {
        case horizontal
        case vertical
    }

    let completedTracks: Int
    let trackCount: Int
    let evidenceCount: Int
    let validatedCount: Int
    let repaired: Bool
    let solved: Bool
    let layout: Layout
    let caseID: Int

    public init(completedTracks: Int, trackCount: Int, evidenceCount: Int,
                validatedCount: Int, repaired: Bool, solved: Bool,
                layout: Layout = .horizontal, caseID: Int = 0) {
        self.completedTracks = completedTracks
        self.trackCount = trackCount
        self.evidenceCount = evidenceCount
        self.validatedCount = validatedCount
        self.repaired = repaired
        self.solved = solved
        self.layout = layout
        self.caseID = caseID
    }

    public var body: some View {
        Group {
            switch layout {
            case .horizontal:
                HStack(spacing: 16) { labels }
            case .vertical:
                VStack(alignment: .leading, spacing: 4) { labels }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var labels: some View {
        Label("\(completedTracks) von \(trackCount) Spuren", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            .help("Fortschritt in den Spuren")
            .lineLimit(1)
        Label("\(validatedCount) von \(evidenceCount) Belegen anerkannt", systemImage: "doc.text")
            .help("Anerkannte Belege")
            .lineLimit(1)
        Label(caseID == 0
              ? (repaired ? "Kasse wiederhergestellt" : "Kasse nicht wiederhergestellt")
              : (repaired ? "Eingriff abgeschlossen" : "Eingriff offen"),
              systemImage: repaired ? "checkmark.circle" : "circle.dashed")
            .help(caseID == 0 ? "Zustand der Kaffeekasse" : "Prüfung des Eingriffs")
            .lineLimit(1)
        if solved {
            Label(caseID == 0 ? "Probelauf bestanden" : "Fall gelöst", systemImage: "flag.checkered")
                .foregroundStyle(Palette.evidenceGreen)
                .lineLimit(1)
        }
    }
}
