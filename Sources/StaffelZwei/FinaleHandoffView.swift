import SwiftUI
import StaffelCore

struct FinaleHandoffView: View {
    let model: AppModel

    static let report = """
    Rechenwerk Ostwind · Übergabe

    Export · Timo erweiterte die Vorlage unter RW-3074 und stellte EXPORT-07 lokal bereit.
    Protokoll · Nadia startete das Löschskript unter RW-1051.
    Empfang · Ein externer Empfang ist unbelegt.
    Testlauf · Der lokale Testausgang enthält ausschließlich die freigegebenen Messwerte.

    Quellen · anhang-audit.txt, export-status.txt und zeitfolge.txt.
    Prüfung · ~/belege/finale-pruefung.txt und ~/belege/finale-fallakte.txt.
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Label("Die Übergabe", systemImage: "checklist")
                    .font(.title2.bold())
                Text("Ordne die Erkenntnisse zu und wähle beide anerkannten Belege aus.")
                if let mission = BrowserMission.forEpisode(model.episode.id) {
                    ForEach(mission.episode.steps) { step in
                        if let answer = mission.responses[step.id] {
                            MissionAnswerView(model: model, step: step, answer: answer)
                        }
                    }
                }
                ForEach(model.state.evidences) { evidence in
                    EvidenceCardView(evidence: evidence, isSelected: model.selectedEvidenceIDs.contains(evidence.id)) {
                        model.toggleEvidence(evidence.id)
                    }
                }
                Button("Übergabe abgeben") {
                    Task { _ = await model.submitFinale() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.terminalBusy)
                if let feedback = model.state.lastAccusationFeedback {
                    Text(feedback).foregroundStyle(.secondary)
                }
            }
            .padding(Space.lg)
            .frame(maxWidth: 800, alignment: .leading)
        }
    }
}
