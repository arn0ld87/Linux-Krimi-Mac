// Regenerate the Mac campaign from the owned Browser source and static assets.
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "Sources", "StaffelCore", "Resources", "Missions.json");
const finale = require("./finale-missions.cjs");

function saveMissions(browser) {
  const missions = [...browser, ...finale].sort((a, b) => a.episode.id - b.episode.id);
  function unique(values, context) {
    if (new Set(values).size !== values.length) throw new Error(`Doppelte ID: ${context}`);
  }
  unique(missions.map(m => m.episode.id), "Episoden");
  unique(missions.map(m => m.episode.key), "Episodenschlüssel");
  for (const {episode, steps, evidenceIDs} of missions) {
    unique(episode.tracks.map(t => t.id), `Spuren in Episode ${episode.id}`);
    unique(steps.map(s => s.id), `Schritte in Episode ${episode.id}`);
    unique(evidenceIDs, `Belege in Episode ${episode.id}`);
  }
  fs.writeFileSync(output, JSON.stringify(missions, null, 2) + "\n");
}

if (process.argv[2] === "--local") {
  saveMissions(JSON.parse(fs.readFileSync(output, "utf8")).filter(m => m.episode.id < 4));
  return;
}

const web = path.resolve(process.argv[2]);
const ts = require(path.join(web, "node_modules/typescript"));

require.extensions[".ts"] = (module, filename) => {
  const source = fs.readFileSync(filename, "utf8").replace(/\.tsv\?raw/g, ".tsv");
  const result = ts.transpileModule(source, {
    compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true},
  });
  module._compile(result.outputText, filename);
};
require.extensions[".webp"] = (module, filename) => { module.exports = filename; };
require.extensions[".tsv"] = (module, filename) => { module.exports = fs.readFileSync(filename, "utf8"); };

const cases = {
  1: "Der Rechtefund",
  2: "Der Wiedergänger",
  3: "Die Loglücke",
};

const intros = {
  1: "Auf rw-srv01 ist eine unerwartete Freigabe aufgetaucht. Sichere die Regel, die Dateirechte und den passenden Audit-Eintrag. Bring anschließend die beiden auffälligen Dateien unverändert in Quarantäne.",
  2: "Der Lagerabgleich kehrt zurück, wenn man ihn beendet. Sichere den laufenden Prozess und seinen Starter. Ein Foto vom Wartungszettel hilft dir, die richtige Änderung im Journal zuzuordnen.",
  3: "Im Anmeldelog fehlt ein Stück der Nacht. Die weitergeleitete Kopie enthält die fehlenden Zeilen. Finde den Zeitraum, sichere die Zeilen und verschiebe das Löschskript unverändert in Quarantäne.",
};

const portrait = path.join(root, "Resources", "Einsatzszene");
function renderNote(message) {
  const args = [
    "-size", "1000x650", "xc:#1b2730",
    "-fill", "#43525e", "-draw", "rectangle 35,0 60,650 rectangle 930,0 955,650",
    "-fill", "#0c171f", "-draw", "roundrectangle 108,82 918,595 16,16",
    "-fill", "#f1e5a6", "-draw", "roundrectangle 92,67 902,580 12,12",
    "-fill", "#bcb399", "-draw", "rectangle 385,55 606,95",
    "-font", "/System/Library/Fonts/Supplemental/Courier New.ttf", "-pointsize", "32", "-fill", "#253141",
  ];
  for (const [index, line] of message.split("\n").entries()) {
    if (line) args.push("-annotate", `+140+${170 + 57 * index}`, line);
  }
  execFileSync("magick", [...args, path.join(portrait, "wiederganger-zettel.png")]);
}

const missions = [1, 2, 3].map(id => {
  const module = require(path.join(web, `src/data/staffeln/staffel-2/episode-${id}.ts`));
  const browser = module[`episode${id}`];
  let setup = browser.setup;
  if (id === 2) {
    const pattern = /LC_ALL=C\.UTF-8 bildbeleg ('[^']+') <<'EOF'\n([\s\S]*?)\nEOF/;
    const photo = setup.match(pattern);
    if (!photo) throw new Error("Episode 2: Foto im Browser-Setup fehlt");
    renderNote(photo[2]);
    setup = setup.replace(pattern, "install -m 0644 /staffel-missions/note.png $1");
  }
  for (const suspect of browser.vorwurf.verdaechtige) {
    fs.copyFileSync(suspect.portraet, path.join(portrait, `${suspect.id}.webp`));
  }

  const check = Object.fromEntries(browser.vorwurf.belege.map(e => [e.id, e.verify]));
  const responses = {};
  const repairs = [];
  const steps = browser.spuren.flatMap(track => track.schritte.map(step => {
    const answer = step.antwort;
    const nativePhoto = id === 2 && step.id === "kennung";
    if (answer) responses[step.id] = {question: answer.frage, format: answer.format, script: answer.pruefung};
    if (["reparieren", "eingreifen", "ordnen"].includes(step.art)) repairs.push(step.id);
    if (!answer) check[step.id] = step.verify;
    const hints = nativePhoto
      ? ["Öffne „Bildschirm“ und starte den Dateimanager. Im Ordner fotos liegt IMG_0417.png. Öffne das Bild und lies die Kennung vom Zettel ab."]
      : step.tipps.map(hint => hint.replace(/^Lösung: /, ""));
    return {
      id: step.id, trackID: track.id, title: step.title,
      detail: nativePhoto ? hints[0] : step.pager.at(-1),
      command: null,
      hints,
    };
  }));
  const episode = {
    id, key: browser.id, title: browser.titel, caseTitle: cases[id], organization: "Rechenwerk Ostwind GmbH",
    account: "azubi", briefing: intros[id],
    tracks: browser.spuren.map(track => ({id: track.id, title: track.titel, summary: ""})),
    evidenceSpecs: browser.vorwurf.belege.map(evidence => ({
      id: evidence.id, trackID: evidence.spurId, fileName: `${evidence.id}.txt`,
      title: steps.find(s => s.id === evidence.id)?.title ?? {
        "rechte-zeile": "Unerwartete Freigabe",
        "rechte-metadaten": "Dateirechte und Eigentümer",
        "log-zeile": "Eintrag im Audit-Log",
      }[evidence.id] ?? evidence.id,
      requiredFragments: [], forbiddenFragments: [], hint: evidence.beschreibung,
    })),
    suspects: browser.vorwurf.verdaechtige.map(person => ({
      id: person.id, name: person.name, role: person.rolle, detail: "", systemImage: "person.crop.circle",
    })),
    culpritID: browser.vorwurf.taeterId, steps, playable: true,
  };
  if (id === 1) {
    check["rechte-zeile"] = browser.vorwurf.belege.find(e => e.id === "rechte-zeile").verify;
    check["rechte-metadaten"] = browser.vorwurf.belege.find(e => e.id === "rechte-metadaten").verify;
    check["log-zeile"] = browser.vorwurf.belege.find(e => e.id === "log-zeile").verify;
  }
  return {episode, steps, setup, check, responses, repairs, sudo: module.SUDO_BEFEHLE ?? [],
    evidenceIDs: episode.evidenceSpecs.map(e => e.id),
    minimumEvidence: browser.vorwurf.mindestBelege,
    resolution: browser.vorwurf.antworten.richtig.join(" "),
    wrongSuspect: browser.vorwurf.antworten.falschePerson.join(" "),
    insufficientEvidence: browser.vorwurf.antworten.zuWenigBelege.join(" ")};
});

saveMissions(missions);
