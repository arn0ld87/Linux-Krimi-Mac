// Source for the native continuation. The export shares these missions with the Alpine guest.
const home = "/home/azubi";
const approved = "sensor_id\ttemperatur_c\tzeit_utc";
const cleanExport = `${approved}\nOST-14\t22.4\t2026-04-18T00:00:00Z\n`;
const draft = `${approved}\tkunden_ref\tkontakt\nOST-14\t22.4\t2026-04-18T00:00:00Z\tDEMO-07\tprobe@example.invalid\n`;
const permit = "RW-3074 · Margit Ostwind\nNur Messwerte\nErlaubt: sensor_id, temperatur_c, zeit_utc\n";
const history = "kennung\tkonto\taktion\nRW-3074\tmargit\tfreigabe_messwerte\nRW-3074\ttimo\texportvorlage_erweitert\n";
const dispatch = "2026-04-18T00:20:00Z\tEXPORT-07\ttimo\tbereitgestellt\n";
const journal = "2026-04-18T04:21:37+02:00\tRW-1051\tnadia\tloeschlauf_gestartet\n2026-04-20T10:47:52+02:00\tRW-2122\tnadia\twaechter_eingetragen\n";
const timeline = "2026-04-18T00:20:00Z\tEXPORT-07\ttimo\n2026-04-18T02:21:37Z\tRW-1051\tnadia\n2026-04-20T08:47:52Z\tRW-2122\tnadia\n";
const status = "paket=EXPORT-07\nstatus=bereitgestellt\nkonto=timo\nzeit=2026-04-18T00:20:00Z\nfreigabe=RW-3074\n";
const hash = require("node:crypto").createHash("sha256").update(draft).digest("hex");

function quote(value) {
  return "'" + value.replaceAll("'", "'\\''") + "'";
}

function write(filename, content) {
  const parent = filename.slice(0, filename.lastIndexOf("/"));
  return `mkdir -p ${quote(parent)}; printf %s ${quote(content)} > ${quote(filename)}`;
}

function exact(filename, content) {
  // Compare without loading user-controlled paths into the root shell.
  return `{ file=${quote(filename)}; [ -f "$file" ] && [ ! -L "$file" ] && printf %s ${quote(content)} | cmp -s - "$file"; }`;
}

function answer(id, trackID, title, detail, format, values) {
  const script = [
    `a=$(printf '%s' "$ANTWORT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')`,
    `case "$a" in ${values.map(quote).join("|")}) exit 0 ;; *) exit 1 ;; esac`,
  ].join("\n");
  return {id, trackID, title, detail, response: {question: title, format, script}};
}

function evidence(id, trackID, title, detail, command, value) {
  return {id, trackID, title, detail, hints: [command],
    evidence: true, check: exact(`${home}/belege/${id}.txt`, value)};
}

function repair(id, trackID, title, detail, command, check) {
  return {id, trackID, title, detail, hints: [command], repair: true, check};
}

const people = [
  {id: "timo", name: "Timo Kessler", role: "Systemadministrator"},
  {id: "nadia", name: "Nadia Brem", role: "Datenbankverwaltung"},
  {id: "margit", name: "Margit Ostwind", role: "Schichtleitung und Freigabe"},
].map(person => ({...person, detail: "", systemImage: "person.crop.circle"}));

function mission({id, key, title, caseTitle, briefing, tracks, steps, files,
  folders = [], desktop, resolution, setup = []}) {
  const caseRelative = `faelle/0${id}`;
  const caseRoot = `${home}/${caseRelative}`;
  const episodeSteps = steps.map(({id, trackID, title, detail, hints = []}) =>
    ({id, trackID, title, detail, command: null, hints}));
  const evidenceSpecs = steps.filter(step => step.evidence).map(({id, trackID, title, detail}) =>
    ({id, trackID, title, fileName: `${id}.txt`, requiredFragments: [], forbiddenFragments: [], hint: detail}));
  return {
    episode: {id, key, title, caseTitle, organization: "Rechenwerk Ostwind GmbH", account: "azubi",
      briefing, tracks: tracks.map(([id, title]) => ({id, title, summary: ""})),
      evidenceSpecs, suspects: people, culpritID: "timo", steps: episodeSteps, playable: true},
    desktop: {initialApp: "files", ...desktop, directory: caseRelative},
    steps: episodeSteps,
    setup: ["set -eu", `mkdir -p ${caseRoot}`,
      ...Object.entries(files).map(([name, content]) => write(`${caseRoot}/${name}`, content)),
      ...folders.map(name => `mkdir -p ${caseRoot}/${name}; chown 1000:1000 ${caseRoot}/${name}`),
      ...setup,
    ].join("\n"),
    check: Object.fromEntries(steps.filter(step => step.check).map(step => [step.id, step.check])),
    responses: Object.fromEntries(steps.filter(step => step.response).map(step => [step.id, step.response])),
    repairs: steps.filter(step => step.repair).map(step => step.id),
    sudo: [],
    evidenceIDs: evidenceSpecs.map(e => e.id),
    minimumEvidence: evidenceSpecs.length,
    resolution,
    wrongSuspect: "Prüfe, welches Konto der Ausgang und die Änderung an der Vorlage wirklich nennen.",
    insufficientEvidence: "Es fehlen anerkannte Belege aus der Aktenwand.",
  };
}

module.exports = [
  mission({
    id: 4, key: "falscher-anhang", title: "Der falsche Anhang", caseTitle: "Freigabe und Vorlage",
    briefing: "Margit bringt die Originalfreigabe. Vergleiche sie mit dem Entwurf und sichere den Änderungsverlauf. Der Dateiname verrät nichts über die Spalten.",
    tracks: [["freigabe", "Freigabe"], ["vorlage", "Vorlage"]],
    files: {"freigabe.txt": permit, "entwurf.tsv": draft, "aenderungen.tsv": history},
    setup: [`install -m 0644 /staffel-missions/freigabe.png ${home}/faelle/04/freigabe.png`],
    desktop: {editor: "entwurf.tsv", photo: "freigabe.png"},
    steps: [
      answer("freigabe-id", "freigabe", "Welche Freigabekennung nennt Margit?",
        "Öffne freigabe.png im Bildbetrachter oder lies die gleichwertige Abschrift freigabe.txt.", "RW- und vier Ziffern", ["rw-3074"]),
      evidence("anhang-kopf", "freigabe", "Kopfzeile sichern", "Speichere genau die erste Zeile des Entwurfs.",
        "head -n 1 ~/faelle/04/entwurf.tsv > ~/belege/anhang-kopf.txt", draft.split("\n")[0] + "\n"),
      answer("zusatzfelder", "vorlage", "Welche zwei Felder stehen zusätzlich im Entwurf?",
        "Vergleiche die Kopfzeile im Editor mit der Freigabe.", "Zwei Spaltennamen, durch Komma getrennt",
        ["kunden_ref,kontakt", "kontakt,kunden_ref", "kunden_ref, kontakt", "kontakt, kunden_ref"]),
      evidence("anhang-audit", "vorlage", "Änderungsverlauf sichern", "Sichere die beiden Zeilen zu der Freigabekennung.",
        "grep '^RW-3074' ~/faelle/04/aenderungen.tsv > ~/belege/anhang-audit.txt", history.split("\n").slice(1).join("\n")),
      answer("vorlage-konto", "vorlage", "Wer erweiterte die Exportvorlage?", "Lies das Konto der Änderung ab.", "Kontoname", ["timo"]),
    ],
    resolution: "Margit gab nur Messwerte frei. Der Änderungsverlauf ordnet Timo die beiden zusätzlichen Felder zu. Prüfe als Nächstes, was im lokalen Ausgang bereitlag.",
  }),
  mission({
    id: 5, key: "letzter-export", title: "Der letzte Export", caseTitle: "Vorschau und Ausgang",
    briefing: "Vergleiche Vorschau und lokalen Ausgang. Sichere Status und Prüfsumme, bevor du den Entwurf unverändert in Quarantäne verschiebst.",
    tracks: [["ausgang", "Lokaler Ausgang"], ["sicherung", "Sicherung"]],
    files: {"vorschau/export-messwerte.tsv": cleanExport, "vorschau/info.txt": "paket=EXPORT-07-PREVIEW\n",
      "ausgang/export-07.tsv": draft, "ausgang/info.txt": status, "ausgang/empfang.txt": "uebergabebeleg=offen\n"},
    folders: ["ausgang", "quarantaene"],
    desktop: {editor: "ausgang/info.txt"},
    steps: [
      evidence("export-status", "ausgang", "Ausgangsstatus sichern", "Kopiere den kompletten Status in die Belegdatei.",
        "cp ~/faelle/05/ausgang/info.txt ~/belege/export-status.txt", status),
      answer("export-paket", "ausgang", "Welche Paketkennung liegt im lokalen Ausgang?", "Vergleiche mit der Vorschau.", "Paketkennung", ["export-07"]),
      answer("uebergabe-status", "ausgang", "Wie lautet der Übergabestatus?", "Lies empfang.txt im Ausgang.", "Wert hinter uebergabebeleg=", ["offen"]),
      evidence("export-sha256", "sicherung", "Prüfsumme sichern", "Speichere nur den SHA-256-Hash ohne Dateinamen.",
        "sha256sum ~/faelle/05/ausgang/export-07.tsv | cut -d' ' -f1 > ~/belege/export-sha256.txt", hash + "\n"),
      repair("export-quarantaene", "sicherung", "Export in Quarantäne verschieben", "Bewege nur export-07.tsv. Der Dateimanager und das Terminal sind gleichwertig.",
        "mv ~/faelle/05/ausgang/export-07.tsv ~/faelle/05/quarantaene/",
        `[ ! -e ${home}/faelle/05/ausgang/export-07.tsv ] && [ ! -L ${home}/faelle/05/ausgang/export-07.tsv ] && [ -f ${home}/faelle/05/vorschau/export-messwerte.tsv ] && ${exact(`${home}/faelle/05/quarantaene/export-07.tsv`, draft)}`),
    ],
    resolution: "Timo stellte EXPORT-07 im lokalen Ausgang bereit. Ein externer Empfang bleibt unbelegt. Der Entwurf liegt mit unverändertem Inhalt in Quarantäne.",
  }),
  mission({
    id: 6, key: "zwei-uhren", title: "Zwei Uhren", caseTitle: "Ortszeit und UTC",
    briefing: "Vergleiche die Uhrzeiten und Kennungen. Das Journal verwendet Ortszeit, der Ausgang UTC. Margits Schichteintrag ist kein Beleg für eine Exportaktion.",
    tracks: [["quellen", "Originalzeilen"], ["zeit", "Zeitfolge"]],
    files: {"ausgang.tsv": "zeit\tpaket\tkonto\tereignis\n" + dispatch, "journal.tsv": "zeit\tkennung\tkonto\tereignis\n" + journal,
      "schicht.txt": "2026-04-18T02:20:00+02:00 Margit verlässt den Raum. Keine Aktion zu EXPORT-07.\n",
      "uhren.txt": "Z bedeutet UTC. Bei +02:00 sind zwei Stunden abzuziehen.\nBeispiel: 14:30:00+02:00 entspricht 12:30:00Z.\n"},
    desktop: {initialApp: "editor", editor: "uhren.txt"},
    steps: [
      evidence("zeit-originale", "quellen", "Zeitzeilen sichern", "Sichere zuerst die Ausgangszeile, dann die zwei Journalzeilen, jeweils ohne Kopfzeile.",
        "tail -n +2 ~/faelle/06/ausgang.tsv > ~/belege/zeit-originale.txt; tail -n +2 ~/faelle/06/journal.tsv >> ~/belege/zeit-originale.txt", dispatch + journal),
      evidence("zeitfolge", "zeit", "Ereignisse chronologisch ordnen",
        "Schreibe je Zeile UTC-Zeit, Kennung und Konto in ~/belege/zeitfolge.txt. Trenne die drei Felder mit Tabulatoren und ordne vom ältesten zum jüngsten Ereignis.",
        "Öffne ~/belege/zeitfolge.txt in Mousepad. Behalte die vollständige ISO-Zeit mit Datum bei. Ziehe bei +02:00 zwei Stunden ab und ersetze den Offset durch Z.", timeline),
      answer("ausgang-konto", "zeit", "Wer stellte das Paket bereit?", "Begründe mit der Ausgangszeile und der Paketkennung.", "Kontoname", ["timo"]),
    ],
    resolution: "Timo stellte das Paket am 18. April bereit. Nadia startete danach das Löschskript. Ihr Eintrag zum Wächter stammt vom 20. April. Jetzt folgt die dokumentierte Übergabe.",
  }),
  mission({
    id: 7, key: "uebergabe", title: "Die Übergabe", caseTitle: "Staffelfinale",
    briefing: "Lege die freigegebenen Messwerte im lokalen Testausgang ab. Sichere den Vergleich und trenne bei der Übergabe belegte Aussagen von Vermutungen.",
    tracks: [["pruefung", "Funktionsprüfung"], ["akten", "Fallakte"]],
    files: {"freigabe/spalten.txt": "sensor_id\ntemperatur_c\nzeit_utc\n", "freigabe/messwerte.tsv": cleanExport,
      "vorlagen/uebergabe.md": "# Übergabe\n- Exportverantwortung\n- Start des Löschskripts\n- Externer Empfang\n- Freigabestatus\n",
      "vorlagen/fallakte.txt": "RW-3074: Timo erweiterte die Vorlage. Margit gab nur Messwerte frei.\nEXPORT-07: Timo stellte das Paket lokal bereit. Empfang offen.\nRW-1051: Nadia startete das Löschskript.\n"},
    folders: ["betrieb/testausgang"],
    desktop: {editor: "vorlagen/uebergabe.md"},
    steps: [
      repair("finale-testlauf", "pruefung", "Freigegebene Datei bereitstellen", "Kopiere ausschließlich die unveränderte Datei messwerte.tsv in betrieb/testausgang.",
        "cp ~/faelle/07/freigabe/messwerte.tsv ~/faelle/07/betrieb/testausgang/",
        exact(`${home}/faelle/07/betrieb/testausgang/messwerte.tsv`, cleanExport)),
      evidence("finale-pruefung", "pruefung", "Geprüfte Spalten sichern", "Sichere die Kopfzeile der lokal bereitgestellten Datei.",
        "head -n 1 ~/faelle/07/betrieb/testausgang/messwerte.tsv > ~/belege/finale-pruefung.txt", approved + "\n"),
      evidence("finale-fallakte", "akten", "Fallakte zur Übergabe sichern", "Kopiere die Zusammenfassung in die Belege und vergleiche sie mit den abgeschlossenen Fällen.",
        "cp ~/faelle/07/vorlagen/fallakte.txt ~/belege/finale-fallakte.txt",
        "RW-3074: Timo erweiterte die Vorlage. Margit gab nur Messwerte frei.\nEXPORT-07: Timo stellte das Paket lokal bereit. Empfang offen.\nRW-1051: Nadia startete das Löschskript.\n"),
      answer("schluss-export", "akten", "Wer änderte die Vorlage und stellte das Paket bereit?", "Verwende die Freigabe und den lokalen Ausgang.", "Kontoname", ["timo"]),
      answer("schluss-loeschlauf", "akten", "Wer startete das Löschskript?", "Verwende die bestätigte Zeitfolge.", "Kontoname", ["nadia"]),
      answer("schluss-empfang", "akten", "Welchen Status hat ein externer Empfang?", "Trenne bereitgestellt von empfangen.", "Status in einem Wort", ["unbelegt"]),
      answer("schluss-testlauf", "akten", "Welche Daten sind für den Testlauf freigegeben?", "Verwende die Freigabe und den lokalen Testausgang.", "freigegebene_messwerte oder freigegebene Messwerte", ["freigegebene_messwerte", "freigegebene messwerte"]),
    ],
    resolution: "Wir haben geklärt, wer den Export bereitstellte und wer die Spur löschte. Einen externen Empfang können wir nicht belegen. Margit übernimmt die dokumentierte Übergabe. Im Testausgang liegen ausschließlich die freigegebenen Messwerte.",
  }),
];
