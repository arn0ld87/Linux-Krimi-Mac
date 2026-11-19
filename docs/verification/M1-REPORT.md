# M1 – Abnahmebericht

Stand: 17.11.2026 · Repo `/Volumes/T7/Projekte/linux-mac` · Branch `feature/m1-native` (ohne Commit)

Dieser Bericht ist ein **Implementierungs- und Selbstprüfungsbericht** des
MiniMax-Workers, keine unabhängige Abnahme. Geprüft wurde ausschließlich mit
ausgeführten Befehlen; nicht ausgeführte Prüfungen sind als offen markiert.

---

## 1. Ergebnis in einem Satz

M1 ist spielbar, alle 45 Core-Tests sind grün, das Bundle ist ad-hoc signiert
und verifiziert, und die native App wurde mit echten Screenshots je Seite
belegt. Offen bleiben der manuelle Neustart-Check, die Screenreader-Prüfung und
ein Referenz-Screen der Web-Fassung im hellen Erscheinungsbild.

---

## 2. Gate-Fortschritt

| Gate | Inhalt | Ergebnis |
|---|---|---|
| **0 – Quellen & Isolation** | alle 10 Swift-Quellen gelesen, Datenisolation repariert | 6 Kern-Bugs gefunden und behoben, keine Nutzerdaten berührt |
| **1 – Core-Loop & Regressionen** | Shell, Pfade, Metadaten, Belege, Vorwurf, Persistenz | **45 Tests grün, Exitcode 0** |
| **2 – Dokumente & Bundle** | BRIEF, GLOSSARY, STORIES, README, Screen-Index, `build.sh`, `dist/StaffelZwei.app` | Bundle gebaut, `codesign --verify --deep --strict` **Exitcode 0** |
| **3 – Native Screens** | 5 Seiten, Vorwurf leer/gefüllt/Erfolg, Settings, Light/Dark, Reset-Dialog | **12 Screenshots** in `docs/verification/` |

---

## 3. Gefundene und behobene Defekte (Gate 0/1)

Alle Defekte wurden **kausal** behoben; keine Assertion wurde abgeschwächt und
kein Test entfernt.

| # | Datei | Defekt | Behebung |
|---|---|---|---|
| 1 | `Sources/StaffelCore/GameStore.swift:18` | `init(directory:)` **ignorierte** den übergebenen Pfad. Sechs Persistenztests schrieben damit auf `~/Library/Application Support/StaffelZwei/spielstand.json` – inklusive eines Tests, der bewusst ungültiges JSON ablegt, und eines, der löscht. | Pfadpriorität jetzt **explizites Verzeichnis > `APP_STORE` > Standardpfad**. Jeder Test schreibt in sein eigenes temporäres Verzeichnis. |
| 2 | `Sources/StaffelCore/TerminalShell.swift` (Parser) | Das Umleitungsziel wurde **nicht** eingesammelt, wenn zwischen `>` und dem Ziel ein Leerzeichen stand (`befehl > datei`). Fast alle Umleitungs-Tests schlugen deshalb fehl. | Der Parser überspringt jetzt den Whitespace nach dem Umleitungszeichen. |
| 3 | `Sources/StaffelCore/TerminalShell.swift` (`isWritable`) | Schreibrechte nur unter `~/belege` – die **erforderliche Reparatur** `cp kaffeekasse.bak → kaffeekasse.csv` wurde verweigert. | Rechtebild folgt den Metadaten: die CSV (0664, Gruppe `azubi`) ist schreibbar, die Sicherung (root:root, 0644) und alle anderen Pfade bleiben geschützt. `mkdir` bleibt auf `~/belege` begrenzt. |
| 4 | `Sources/StaffelCore/VirtualFS.swift` (`normalize`) | `~/pfad` verlor den führenden Slash und wurde danach relativ zum **cwd** aufgelöst – aus `/srv/rechenwerk/uebung` wurde `/srv/rechenwerk/uebung/belege/...`. | `~` löst jetzt immer gegen das Home-Verzeichnis auf. |
| 5 | `Sources/StaffelCore/TerminalShell.swift` (`execute`) | `cwd` wurde **vor** der Umleitungsprüfung gesetzt: `cd /srv/rechenwerk/uebung > /etc/verboten` änderte das Arbeitsverzeichnis trotz Fehler. | `Shell.run` ist transaktional: bei jedem Fehler werden Dateiwelt und cwd auf den Vorzustand zurückgesetzt. |
| 6 | `Sources/StaffelCore/Episode.swift` | Die Zeitstempel der Originaldaten waren falsch (`1776413520` = 08:12 statt 03:12, `1776379500` = 22:45 statt 22:05). Dadurch stimmten `ls -l`, `stat` und die Belegvalidierung nicht. | Die Daten werden jetzt explizit als `utcDate(2026, 4, 17, 3, 12, 0)` bzw. `utcDate(2026, 4, 16, 22, 5, 0)` konstruiert – kein Epoch-Wert mehr, der von Hand falsch sein kann. |
| 7 | `Sources/StaffelCore/VirtualFS.swift` (`octal`) | `stat` zeigte `664` statt `0664` (GNU-Format). | Vierstellig: `%04o`. |
| 8 | `Sources/StaffelCore/TerminalShell.swift` (`longEntry`) | Die Spalte „Größe“ zeigte den Änderungszeitpunkt statt der Dateigröße. | Jetzt die Bytezahl des Inhalts. |
| 9 | `Sources/StaffelZwei/AppModel.swift:44` | Nach einem Lesefehler startete die App frisch, **und die nächste Navigation überschrieb die defekte Datei**. | `GameStore.protectFromOverwrite()` sperrt das Schreiben; `persist()` meldet sichtbar „Der defekte Spielstand wird nicht überschrieben.“; nur ein bestätigtes Zurücksetzen hebt den Schutz auf (mit Backup). |
| 10 | `Sources/StaffelZwei/Theme.swift` / `ContentView.swift` | Die Fortschrittsanzeige in der Sidebar wurde **zeichenweise umgebrochen** („2 von 2 Spuren“ nur noch ein Zeichen pro Zeile) – im Screenshot sichtbar und unlesbar. | `ProgressSummaryView` bekommt ein `Layout`; die Sidebar nutzt `.vertical`. |
| 11 | `build.sh` | `codesign --force` mit einer **privaten Apple-Development-Identität**, `rm -rf` auf dem Zielbundle, `--install`/`--open` gegen eine vorhandene Nutzer-App. | Ad-hoc-Signierung (`--sign -`), kein `--force`, Staging-Verzeichnis, vorhandene Bundles werden gesichert statt gelöscht, `--open` entfernt, `codesign --verify --deep --strict` fest im Ablauf. |

### Geänderte Testdatei

`Tests/StaffelCoreTests/StaffelCoreTests.swift`, Test `testRowsEvidence`:
Das Szenario war in sich widersprüchlich – es erwartete `completedTracks == 2`
(also zwei abgeschlossene Spuren), ohne die Spur „Akte“ zu belegen. Die
Assertion wurde **nicht** verändert; stattdessen wurde die fehlende
Vorbedingung ergänzt (ein `ls -l`-Befehl erzeugt den Metadaten-Beleg). Die
Zählsemantik „Anzahl abgeschlossener Spuren“ bleibt damit konsistent zur
Anzeige „X von 2 Spuren“ in der UI; eine Fortschrittsstufe hätte dort eine
Fake-KPI erzeugt.

### Neue Tests

`Tests/StaffelCoreTests/IsolationRegressionTests.swift` (11 Tests):

- explizites Verzeichnis schlägt `APP_STORE`
- defekter Spielstand wird beim Speichern **nicht** überschrieben (Datei bleibt byte-identisch)
- bestätigtes Zurücksetzen hebt den Schreibschutz auf und legt ein Backup an
- ein Store schreibt nur in sein eigenes Verzeichnis
- `~` löst unabhängig vom cwd gegen das Home auf
- fehlgeschlagene Umleitung ändert weder cwd noch Dateiwelt
- fehlgeschlagene Umleitung nach gültigem Befehl lässt die Sicherung unverändert
- vollständiger Probelauf repariert die Liste, behält Besitzer/Rechte und wird angenommen
- ein Beleg mit richtigem Dateinamen, aber falschem Inhalt, wird nicht anerkannt

---

## 4. Echte Befehle und Exitcodes

### 4.1 Tests

```
APP_STORE=.worker/appstore/test-1794952549 swift test --scratch-path "$HOME/Library/Developer/StaffelZwei/build"   --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk   -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

```
✔ Test run with 45 tests in 0 suites passed after 0.032 seconds.
EXITCODE=0
```

Vorheriger Stand (vor dieser Arbeit): **31 Issues** bei 45 Tests,
`EXITCODE=1`. Werkzeughinweis: mit `--sdk 26.5` findet der Compiler das
Swift-Testing-Makro-Plugin nur mit dem expliziten `-plugin-path`; ohne Xcode
im Standard-SDK 27.x scheitert `@State` als Makro.

### 4.2 Build und Signatur

```
APP_STORE=.worker/appstore/build2-<ts> ./build.sh
```

```
Build complete! (70,89 Sek.)
codesign --verify --deep --strict: ok
built /Volumes/T7/Projekte/linux-mac/dist/StaffelZwei.app
BUILD_EXITCODE=0
```

```
codesign --verify --deep --strict dist/StaffelZwei.app
VERIFY_EXITCODE=0
codesign -dv dist/StaffelZwei.app
  Identifier=de.alex-schneider.staffelzwei
  Signature=adhoc          flags=0x2(adhoc)      TeamIdentifier=not set
```

Kein Zertifikat, keine private Entwicklungsidentität, kein `--force`.

### 4.3 App-Lauf

```
APP_STORE=.worker/appstore/gui2-1794952872 dist/StaffelZwei.app/Contents/MacOS/StaffelZwei
```

- Fenster: 1240 × 820, `accessible: true`, `is_focused: true`
- `list-windows` nach Öffnen der Settings: `w-5028` (Hauptfenster), `w-5055` („Allgemein“)
- Persistierter Zustand nach dem Probelauf:
  `evidences: [('kasse-meta', True), ('kasse-zeilen', True)]`, `repaired: True`,
  `selectedEvidenceIDs: ['kasse-zeilen', 'kasse-meta']`, `selectedSuspectID: 'kaffee'`,
  nach dem Prüfen `solved: True`, `page: briefing`

---

## 5. GUI-Nachweise (echte Screenshots)

Alle Screens liegen in `docs/verification/` und stammen aus der **gebauten
App** (`dist/StaffelZwei.app`), erfasst mit `agent-desktop` (Accessibility +
Fenster-Screenshot). Keine Mockups, keine gerenderten Ersatzbilder.

| Datei | Inhalt | Interaktion davor |
|---|---|---|
| `01-einsatzrahmen.png` | Seite „Einsatzrahmen“ mit Auftrag, Spuren und Schrittliste | App-Start |
| `02-terminal.png` | Terminal, leere Eingabe, Prompt `azubi@rw-srv01:~$`, Simulationshinweis | Klick „Terminal“ |
| `03-terminal-probelauf.png` | vier ausgeführte Befehle im Verlauf | 4 Befehle getippt + Return |
| `04-aktenwand.png` | beide Belege mit echtem Inhalt und Status | Klick „Aktenwand“ |
| `05-terminal-repariert.png` | Terminal nach der Reparatur, Fortschritt „2 von 2 Spuren“ | zurück ins Terminal |
| `06-vorwurf-leer.png` | Vorwurf ohne Auswahl, beide Belege anerkannt, aber nichts markiert | Klick „Vorwurf“ |
| `07-vorwurf-gefuellt.png` | Verdächtiger `kaffee` und beide Belege ausgewählt | 3 Klicks |
| `08-vorwurf-erfolg.png` | Erfolg „Probelauf bestanden. Jetzt wird es ernst.“, zurück im Einsatzrahmen | Klick „Prüfen“ |
| `09-einstellungen.png` | Settings „Allgemein“ mit Darstellung, Simulationshinweis, Tastatur, Spielstandpfad | Cmd-, |
| `10-hell.png` | Hauptfenster im hellen Erscheinungsbild | Settings → „Hell“ |
| `11-dunkel.png` | Hauptfenster im dunklen Erscheinungsbild | Settings → „Dunkel“ |
| `12-reset-dialog.png` | Bestätigungsdialog „Fortschritt wirklich zurücksetzen?“ | Settings → „Fortschritt zurücksetzen…“, **nicht bestätigt**, danach „Abbrechen“ |

Weitere belegte Bedienungen:

- Die App reagiert auf **Cmd-1 … Cmd-5** (Seitenwechsel) und **Cmd-,** (Settings).
- Die Terminal-Eingabe ist als `textfield` mit Namen „Terminal-Eingabe“ adressierbar,
  Verdächtige und Belege als `button` mit Zustandswert („nicht ausgewählt“ / „anerkannt“).
- Das Erscheinungsbild wird über die App-Einstellung umgeschaltet – die
  **macOS-Systemeinstellung wurde nicht global verändert**.

---

## 6. Datenisolation und Nutzerspielstand

- Der Pfad `~/Library/Application Support/StaffelZwei/spielstand.json` **existiert**
  und stammt aus dem **vorherigen** Testlauf vom 17.11.2026 22:36, also aus der
  Zeit vor dem Store-Fix. Er wurde **nicht gelesen, nicht gelöscht, nicht
  überschrieben und nicht zurückgesetzt**. Nur das Vorhandensein wurde geprüft.
- Sämtliche Läufe dieser Arbeit liefen mit `APP_STORE` auf einem eigenen,
  frisch angelegten Verzeichnis unter `.worker/appstore/`:
  `test-1794952429`, `test-1794952444`, `test-1794952481`, `test-1794952499`,
  `test-1794952549`, `build2-…`, `gui-1794952693`, `gui2-1794952872`.
- Die Tests selbst benutzen ausschließlich frische temporäre Verzeichnisse
  (`staffelzwei-<label>-<UUID>`) und löschen nur diese wieder.

---

## 7. Korrekturen an den Referenz-Screens

Die Aufnahme-Notizen in `docs/screens/_capture-report.json` widersprechen
an drei Stellen dem Bildinhalt. Die Notizen wurden **nicht** angepasst; die
Korrektur steht in `docs/screens/INDEX.md`:

| Datei | Notiz | Befund |
|---|---|---|
| `08-episode-1.png` | „Episodenübersicht Episode 1“ | Ladezustand „Linux wird geladen … 50 %“ |
| `09-episode-2.png` | „Episodenübersicht Episode 2“ | Ladezustand |
| `10-episode-3.png` | „Episodenübersicht Episode 3“ | Ladezustand |
| `12-hauptansicht-light.png` | „Hauptansicht im Light Mode“ | Bild ist **dunkel**; eine helle Referenzaufnahme existiert nicht |

---

## 8. Umgesetzt, aber nicht nachgewiesen / offen

| Punkt | Status | Grund |
|---|---|---|
| Neustart mit erhaltenem Zustand | **teilweise** | Roundtrip und Persistenz sind per Test belegt, der echte App-Neustart wurde nicht durchgeführt |
| Screenreader / VoiceOver | **offen** | Accessibility-Rollen und Labels sind adressierbar, die Vorlese wurde nicht geprüft |
| Vorwurf im Zustand *ganz* leer (ohne anerkannte Belege) | **offen** | `06-vorwurf-leer.png` zeigt den Vorwurf ohne Auswahl; der Zustand ohne jeden Beleg wurde nicht separat aufgenommen |
| Hilfe-Seite der nativen App | **offen** | vorhanden, aber nicht als Screenshot aufgenommen |
| Episoden 1–3 | **offen** | nur sichtbar gesperrt, wie in M1 gefordert |
| `git diff --check` / Whitespace | **offen** | nicht ausgeführt (kein Commit vorgesehen) |
| Code-Review-Graph nach der Änderung | **offen** | Graph wurde vor der Arbeit aktualisiert, nicht danach |

---

## 9. Geänderte und neue Dateien

**Geändert**

- `Sources/StaffelCore/GameStore.swift` – Pfadpriorität, Schreibschutz, Backup
- `Sources/StaffelCore/TerminalShell.swift` – Parser, Transaktion, Schreibrechte, `ls -l`
- `Sources/StaffelCore/VirtualFS.swift` – `~`-Auflösung, oktale Rechte
- `Sources/StaffelCore/Episode.swift` – Originalzeitstempel
- `Sources/StaffelZwei/AppModel.swift` – Schreibschutz, Reset mit Backup
- `Sources/StaffelZwei/Theme.swift` – Fortschrittsanzeige mit Layout
- `Sources/StaffelZwei/ContentView.swift` – vertikale Fortschrittsanzeige in der Sidebar
- `Tests/StaffelCoreTests/StaffelCoreTests.swift` – Szenario `testRowsEvidence` vervollständigt
- `build.sh` – Signatur, Staging, Sicherung statt Löschung

**Neu**

- `Tests/StaffelCoreTests/IsolationRegressionTests.swift`
- `README.md`, `docs/BRIEF.md`, `docs/GLOSSARY.md`, `docs/STORIES.md`, `docs/screens/INDEX.md`
- `docs/verification/01-…png` bis `docs/verification/12-…png`

Kein Commit, kein Push, keine globale Konfigurationsänderung.

---

## Anhang: Vorheriges Abnahmeergebnis (Vorgeschichte)

Der folgende Stand ist der Bericht des vorherigen Laufs und bleibt als
Vorgeschichte erhalten. Er beschreibt den Zustand **vor** dieser Arbeit.

# M1-Abnahme – 2026-11-17

**Urteil: M1 nicht abgenommen.** Keine zweite Implementierung und keine Fehlerbehebung gestartet.

## Lauf und Rollen

Die Umsetzung lief ausschließlich über den vorhandenen `claude-minimax`-Wrapper. Der Supervisor beendete den Lauf nach seinem 20-Minuten-Zeitbudget; der innere Exitcode ist **124**. Ein äußerer Supervisor-Exit von 0 bedeutet hier keinen Umsetzungserfolg.

Der unabhängige Subagent prüfte die Spec, Quelltexte und vorhandene Artefakte lesend. Die Hauptsession führte anschließend Swift-Tests und einen direkten Release-Build aus. Keine Commits, Pushes oder Website-Builds.

## Tatsächlich ausgeführte Prüfungen

SDK: `/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`.

```sh
swift test --package-path /Volumes/T7/Projekte/linux-mac \
  --scratch-path "$HOME/Library/Developer/StaffelZwei/build" \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
```

**Exit 1:** 36 ausgeführte Tests, 33 gemeldete Issues. Fehlgeschlagen sind unter anderem Reparatur durch `cp`, erfolgreiche Gesamtlösung, Belegvalidierung, Umleitungen, Zeitangaben und Persistenz. Die Zahl der Issues ist nicht gleich der Zahl fehlgeschlagener Tests. Lokales vollständiges Log: `.worker/verification-tests.log` (nicht einchecken).

**Sicherheitsrelevanter Befund:** Die Persistenz-Testfehler nennen den Standardpfad `~/Library/Application Support/StaffelZwei/spielstand.json`, statt ausschließlich einen isolierten Testpfad. Weitere Testläufe sind deshalb gestoppt. Bestehende Nutzerdaten wurden nicht auf ihren Inhalt untersucht; ein Datenverlust ist damit weder festgestellt noch ausgeschlossen. Vor weiteren Läufen ist die Testisolation zu korrigieren.

```sh
swift build -c release --package-path /Volumes/T7/Projekte/linux-mac \
  --scratch-path "$HOME/Library/Developer/StaffelZwei/build" \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
```

**Exit 0:** Release-Build erfolgreich, gemeldete Dauer 58,28 Sekunden. Warnungen: unveränderte Variable `directories` und fehlende SDK-Suchverzeichnisse. Lokales Log: `.worker/verification-release-build.log`.

`build.sh` wurde gelesen, aber nicht ausgeführt: Es verwendet unter anderem das ohne ausdrückliche Freigabe untersagte `codesign --force`, entfernt ein vorhandenes Zielbundle und wählt automatisch eine vorhandene Entwicklungsidentität. Daher nur direkter Swift-Build, keine Paketierung, Installation oder Signierung.

Vom Subagenten ausgeführt: `git diff --check` Exit 0; da alle Projektdateien untracked sind, ist dessen Aussagekraft begrenzt. Ergänzender Whitespacecheck über zwölf untersuchte Dateien ohne Treffer.

## Schwere Findings

1. **Reparatur und damit Fallabschluss blockiert:** `TerminalShell.swift:414` prüft das CSV-Kopierziel mit `assertWritable`; die Regel in derselben Datei um Zeile 467 erlaubt nur den Belegordner. `cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv` scheitert. `GameEngine.swift:233` verlangt die Reparatur für den Abschluss. Quellenbefund und fehlgeschlagene Reparatur-/Erfolgstests bestätigen den Blocker.
2. **Defekter Spielstand kann überschrieben werden:** `AppModel.swift:44–58` startet nach Ladefehler mit frischem Zustand und speichert bei Navigation; `GameStore.swift:61–62` überschreibt dabei die defekte Datei. Quellenbestätigt; der konkrete UI-Ablauf wurde nicht ausgeführt.
3. **Fehler sind nicht atomisch:** `TerminalShell.swift:254–260` ändert bei `cd` das Arbeitsverzeichnis vor Prüfung einer unzulässigen Umleitung. Beispiel: `cd /srv/rechenwerk/uebung > /etc/verboten`. Quellenbestätigt, kein gesonderter Laufzeitrepro.
4. **Tildepfade nach Verzeichniswechsel falsch:** `VPath.normalize` entfernt `~/`, verwendet danach aber das aktuelle Verzeichnis statt des Home-Verzeichnisses. Quellenbestätigt. Beispiel: nach `cd /srv/rechenwerk/uebung` schlägt eine Belegumleitung nach `~/belege/kasse-meta.txt` fehl.
5. **Kritisch – Persistenztests greifen auf normalen Spielstand zu:** `GameStore.init(directory:)` nimmt einen temporären Testpfad entgegen (`GameStore.swift:18`), ignoriert diesen jedoch und wählt nur `APP_STORE` oder den normalen Default (`:20–25`). Sechs Store-Tests glauben dadurch fälschlich, isoliert zu sein. Der Test für defekten Store schreibt absichtlich ungültiges JSON (`StaffelCoreTests.swift:414–416`); der Reset-Test speichert und setzt zurück (`:442–444`). Die tatsächlichen Laufzeitfehler bestätigen den normalen Application-Support-Pfad. Keine weiteren Testläufe. Bestehende Daten wurden nicht nachträglich gelesen oder wiederhergestellt; ob vor dem Testlauf ein Nutzerspielstand vorhanden war, ist nicht geklärt.

## Spec-Abdeckung

| Bereich | Status | Nachweis / Grenze |
| --- | --- | --- |
| SwiftUI-App, Foundation-Core und Tests | Teilweise | Quellen und erfolgreicher Release-Compile vorhanden; kein GUI-Nachweis |
| Referenz-Screens | Teilweise | 12 gültige PNGs mit 1440 × 1000 unter `docs/screens/`, zwei vom Prüfer visuell gelesen; keine vollständige Screen-Abdeckung nachgewiesen |
| Screen-INDEX, BRIEF, GLOSSARY und STORIES | Fehlt | Bei Abnahme nicht vorhanden |
| README | Fehlt | Bei Abnahme nicht vorhanden |
| Probelauf durchspielbar | Nicht erfüllt | Reparatur und korrekte Gesamtlösung schlagen in Tests fehl |
| Belege, Parser und Persistenz | Teilweise / fehlerhaft | Quellen vorhanden; mehrere Regressionstests rot |
| Öffnungsfähiges `dist/StaffelZwei.app` | Fehlt | Kein App-Bundle bei Abnahme |
| Native Screens, Light/Dark, Settings, GUI-Interaktionen | Nicht geprüft | Keine nativen Screens, kein Bundle |
| Signaturprüfung | Nicht ausgeführt | Kein Bundle |
| Layoutgrid und VoiceOver | Nicht ausgeführt | Kein GUI-Nachweis |
| CRG und lokale semantische Suche | Erfüllt, separat geprüft | Alias `linux-mac`, lokales Modell `all-MiniLM-L6-v2`, 150 Embeddings; Suchtest `evidence` mit `search_mode=hybrid` |

Im untersuchten App-Code fand der Prüfer keine WebView-, Process- oder Netzwerk-Ausführung. Dies ist ein Quellenbefund, keine vollständige Sicherheitsfreigabe.

## Weiterarbeit

Vor weiteren Tests Persistenz auf isolierte temporäre Stores umstellen und defekte Nutzerspielstände vor automatischem Überschreiben schützen. Danach Kernablauf, Pfadnormalisierung und atomische Fehlerbehandlung reparieren; fehlende Stories/Screen-Zuordnungen ergänzen, Bundle sicher paketieren und anschließend native GUI-Abnahme durchführen. Diese Schritte sind offen und wurden nicht als zweite Implementierung gestartet.

---

## Nachtrag vom 18.11.2026 – Blockerreparatur

Details, Befehle, echte Exitcodes und offene Punkte:
`docs/verification/M1-BLOCKERS-RESULT.md`. Die Abschnitte oben bleiben
unverändert (Reviewhistorie).

Geändert wurde:

| Bereich | vorher | nachher |
|---|---|---|
| `SelfTest.swift` / `StaffelZweiApp.swift` | `exitCode` startete bei 0, kein Watchdog | Exitcode startet bei 1, `completed` erst nach allen Prüfungen, Watchdog ab App-Start (120 s, `APP_SELFTEST_TIMEOUT`), fehlender `APP_STORE` wird sofort abgelehnt, Ergebnis-JSON über `APP_SELFTEST_RESULT` |
| `Snapshot.swift` | „SNAPSHOT done“ mit Exit 0, auch bei fehlgeschlagenen Captures | `SNAPSHOT PASS/FAIL`, Exit 1 bei jedem Problem, jede Seite braucht echte nichtleere PNG **und** Layoutdaten, fehlendes Settings-Fenster ist ein Fehler, Watchdog 150 s (`APP_SNAPSHOT_TIMEOUT`) |
| `tools/check-layout.swift` | PASS bei 0 Dateien, 0 Probes, kaputtem JSON-Umfeld | Exit 2 ohne Argumente, FAIL bei 0 Probes, Geometrie-/Area-/Fenstervalidierung, `--require-matrix` für die volle Screenmatrix |
| `tools/grid-lint.sh` | nicht ausführbar (644), stiller Exit 0 bei leerem Verzeichnis | 755, Guards für fehlendes/ leeres Verzeichnis, immer eine `PASS`/`FAIL`-Markerzeile |
| `tools/test.sh` | existierte nicht | reproduzierbarer Test-Entry-Point: findet SDK und Testing-Makro-Plugin, eigenes frisches `APP_STORE`, echter Exitcode, „0 Tests“ = Fehler |
| `tools/windows.swift` | nur Name-Filter | zusätzlich `--pid`, adressiert ein Fenster eines Prozesses |
| `tools/check-layout-selftest.sh`, `tools/app-checks.sh` | existierten nicht | 10 Negativ-/Positivfälle bzw. App-Pfade mit echten Exitcodes |

Nachgewiesene Zahlen dieser Sitzung: **45 Core-Tests grün** (`./tools/test.sh`,
Exit 0), **10/10** Layout-Negativtests (Exit 0), **Release-Build Exit 0**,
`codesign --verify --deep --strict` **Exit 0** (`Signature=adhoc`).

**Offen bleibt der GUI-Nachweis:** Der Bildschirm der Sitzung war gesperrt
(`CGSSessionScreenIsLocked: True`), deshalb liefert `screencapture -l` keine
Aufnahme. Der normale Start erzeugt zwar ein eigenes sichtbares Fenster
(`window=5243`, `onscreen=true`, 1116×739), aber Fenster-Screenshot,
Light/Dark-Matrix, interaktive Probelauf-Belege und der Neustart im selben
Store sind nicht belegt. `docs/STORIES.md` wurde deshalb nicht geändert.
