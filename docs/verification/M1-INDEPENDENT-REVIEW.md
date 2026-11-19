# M1 – unabhängige Abnahme

## Iteration 2 – aktueller Stand nach GUI-Folgelauf (17./18.11.2026)

**Aktuelles Urteil: M1 nicht abgenommen.** Der erneute Normalstart liefert innerhalb von 30 Sekunden kein durch agent-desktop erfasstes Fenster des eigenen Prozesses. Zusätzlich scheitert der aktuelle unabhängige Test-Compile; die früheren 45 grünen Tests sind nur Historie. Frischer Release-Build, strikte Signatur und statisches Grid-Lint bestehen. Keine Implementierung, Fixes, neue Debug-Instrumentierung oder Writer gestartet.

### Scope und Datenisolation erneut geprüft

- CRG zuerst: 189 Nodes, 1712 Edges, Stand 23:29:57; explizite changed_files für App-Start, Debug, SelfTest, Snapshot und Gridtools. SelfTest ist noch nicht indexiert; dafür gezielter Quellenfallback, keine Voll-Repo-Exploration.
- Vor Ausführung `GameStore.swift:45–58` und beide Testdateien erneut geprüft: explizites directory > APP_STORE > Standard; schreibende Tests verwenden eigene UUID-Tempverzeichnisse. Jedem Check ein neuer APP_STORE zugewiesen.
- Read-only Prozessinventar vor Start: vorbestehender PID **35029**, PPID 1, Aufruf `dist/StaffelZwei.app/Contents/MacOS/StaffelZwei`. Nicht gestartet oder beendet durch diesen Reviewer; unangetastet gelassen. Kein Environment dieses Prozesses und kein Nutzerstore gelesen.
- Worker-Ende `.worker/minimax-m1-gui-final.exit`: **SUPERVISOR_TIMEOUT inner_exit=143**, kein erfolgreicher GUI-Abschluss. Kein M1-GUI-FINAL-Bericht und keine realen Layout-JSONs unter docs/verification vorgefunden.

### Aktueller tatsächlicher Normalstart

Direkt ausgeführt: `/Volumes/T7/Projekte/linux-mac/dist/StaffelZwei.app/Contents/MacOS/StaffelZwei`, **ohne Argumente**; APP_SNAPSHOT/APP_SEED/APP_GRID/APP_DEBUG/APP_SELFTEST/APP_SNAPSHOT_PAGES aus dem Kind-Environment entfernt. Frischer Store `/var/folders/hk/9jcb416d7j14n8pwsws8ymsw0000gn/T/m1-review2-normal-72tk8rd4`.

- Eigener PID **65526** blieb 30 Sekunden am Leben. Wiederholte PID-gefilterte `agent-desktop list-windows --app StaffelZwei` lieferten **kein Fenster dieses PID**. Deshalb kein eigener Fensterscreenshot möglich.
- Nach dem harten Prüflimit ausschließlich PID 65526 sauber mit SIGTERM beendet; Prozessende **-15**. Kein fremder Prozess beendet, keine globalen Einstellungen verändert.
- Evidenz: `independent-iteration2-normal.log` (keine Ausgabe), `independent-iteration2-start.json` (PID, isolierter Store, leere Fensterliste, Cleanup-Exit).
- Der Befund ist ein **reproduzierbarer aktueller Start-Abnahmeblocker im verwendeten Startweg**, nicht nur eine fehlende Screenshotmatrix. **Nicht bewiesen:** dass systemweit keinerlei Fenster existiert, oder dass der App-Startcode allein ursächlich ist. Vorbestehende Instanz/LaunchServices, Sichtbarkeit und AX-/Fenstererkennung sind mögliche Störfaktoren; keine CoreGraphics-Triangulation während dieses Prüffensters. Keine weitere Start-/AX-Diagnoseschleife.
- Vor diesem Start war keine Swift-Quelle neuer als die getestete Binary. Danach wurde mit denselben Quellen nochmals gebaut und neu paketiert; diese frisch signierte Ausgabe wurde nicht erneut gestartet. SHA256 vor Normalstart `e922a2ff62bdcd6ff70aea183e99507a6add9688e0e8af3cc8baa9bdb9b29a22`; nach erneutem Build `12e2b041700fd84f2f7c4c8400712f09c9e23dad0f2622e10f6e2c54dcb9b161`. Der Normalstartbefund darf nicht als ausgeführter Start der später neu signierten Datei ausgegeben werden.

### Aktuelle unabhängige Gates

| Gate | Tatsächliches Ergebnis |
|---|---|
| `swift test --package-path /Volumes/T7/Projekte/linux-mac --scratch-path "$HOME/Library/Developer/StaffelZwei/build" --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` | **Exit 1**, Test-Compile gescheitert, **0 Tests ausgeführt**. `external macro implementation type 'TestingMacros.TestDeclarationMacro' could not be found ... plugin for module 'TestingMacros' not found`, danach Build failed/fatalError. `independent-iteration2-tests.log`. Toolchain-/Pluginblocker, kein nachgewiesener fachlicher Assertion-Fehler; keine Reparatur/Retry-Schleife |
| `build.sh` ohne Argumente, eigener neuer APP_STORE | **Exit 0**, Build complete 6.71 s; ad-hoc und interne Strict-Verifikation erfolgreich. Vorheriges Bundle erhalten in `dist/StaffelZwei.app.bak-20261117235900`. `independent-iteration2-build.log` |
| `codesign --verify --deep --strict /Volumes/T7/Projekte/linux-mac/dist/StaffelZwei.app` | **Exit 0**, `independent-iteration2-codesign.log` (erwartungsgemäß leer) |
| `tools/grid-lint.sh` direkt | Nicht gestartet: Dateimodus **0644**, PermissionError. Keine chmod-Änderung |
| `/bin/zsh /Volumes/T7/Projekte/linux-mac/tools/grid-lint.sh` | **Exit 0, PASS grid-lint**. `independent-iteration2-grid-lint.log`; rein statische Prüfung |
| Dynamischer Layoutcheck | **Nicht ausgeführt**, **0 echte *-layout.json** unter docs/verification. Keine nichtleeren Probe-/Area-Abdeckungszahlen, daher kein Layout-PASS |
| GUI-SelfTest/Snapshot-Modus | **Nicht gestartet**, weil Normalstart nicht bestätigt. Kein weiterer 180s-Hänger |

### Gezielte Prüfung der neuen Testinstrumentierung

- `StaffelZweiApp.swift:21–27,59–82`: Aktivierungsrichtlinie wird vor Launch und in onAppear auf regular gesetzt; Snapshot/SelfTest werden erst in onAppear aufgerufen. Damit sind fehlende SelfTest-Ausgaben bei ausbleibendem onAppear erklärbar, aber die Startursache ist dadurch nicht festgestellt.
- `Debug.swift:8–13`: stderr-Diagnose ausschließlich hinter APP_DEBUG=1, keine Erfolgsflags oder Nutzerdaten-Ausgaben im geprüften Code.
- `SelfTest.swift:59–158`: Befehle werden über Tastaturevents in das echte Feld eingespeist; Vorwurf nutzt Button-/Accessibility-Aktionen und prüft den entstandenen Modellzustand. **Keine direkte markSolved-/Beleg-Erzeugung als Erfolgssurrogat gefunden**. Navigation wird im Test über model.page gesetzt; dies beweist keine Navigationsshortcuts. Kein echter Neustart enthalten. Quelle ist kein Laufnachweis.
- `Snapshot.swift:18–61`: setzt appinterne Darstellung und Seiten, erfasst Fenster; erzeugt nicht selbst eine vollständige gelöste Fallwelt. Zustands-/Aufnahmecheck, kein Ersatz für den interaktiven Core-Loop.
- Instrumentierungsgrenzen: SelfTest exitCode ist zunächst 0 (`SelfTest.swift:19`), das AppDelegate gibt diesen beim Beenden im SelfTest-Modus zurück. Ein vorzeitig beendeter Lauf darf **ohne finale `SELFTEST PASS N checks`-Zeile nicht anhand Exit 0 akzeptiert werden**. Snapshot kann am Ende `SNAPSHOT done` ausgeben, obwohl einzelne captures vorher fehlten; Fehlermeldungen und tatsächliche Dateien prüfen.
- `tools/check-layout.swift:46–64,131–140` lehnt fehlende Eingabepfade bzw. leere Probe-Arrays nicht ausdrücklich ab: ohne Dateien ist der Exit rechnerisch 0, leere Arrays können `PASS ... 0 probes in 0 areas` ergeben. **Kein solcher Leer-PASS als Abnahme akzeptiert**. Der Runner muss echte JSON-Dateien und nichtleere ausreichende Coverage verlangen.

### Aktuelle Restlücken und kleinster notwendiger nächster Schritt

1. **Normalstart nachweisen:** unter kontrollierter Instanzsituation, ohne fremde Prozesse zu beenden, normales isoliertes Bundle starten und eigenes sichtbares Fenster/PID unabhängig bestätigen. Erst danach GUI-Selftest oder echte Tastatur-/Mausbedienung. Startursache aktuell offen; kein bestimmter Codefix aus dem Befund abgeleitet.
2. **Aktuelles Testgate wieder ausführbar machen:** TestingMacros-/Toolchain-Kontext aufklären, dann denselben isolierten Testbefehl erneut mit tatsächlicher Testzahl ausführen. Keine Übertragung der historischen 45 PASS auf diesen Lauf.
3. Danach weiterhin Pflicht: vollständige Lösung mit echten Eingaben, fehlende Belege/falscher/richtiger Vorwurf, eigener Fenster-/Prozessneustart nach Lösung mit Belegen und Transcript, Settings/Shortcuts, aktive Light/Dark-Matrix aller Seiten/Settings sowie reale Layout-JSONs mit ausreichender nichtleerer Abdeckung. VoiceOver bleibt gesondert ungetestet.

Die folgenden Ergebnisse sind **Historie der ersten Iteration**, keine aktuelle GUI-Abnahme und kein aktueller grüner Teststatus.

---

## Iteration 1 – historischer Prüfstand

**Ergebnis: M1 nicht abgenommen.** Stand 17.11.2026, Branch `feature/m1-native`, ohne Commits. Keine Implementierung, Codefixes, Commits, Pushes oder Subagenten. Funktionale Core-Tests, frischer Build und Signatur bestehen. Die verbindliche vollständige native GUI-Abnahmematrix ist nicht nachgewiesen. Das ist eine Nachweislücke, kein nachgewiesener Fehler des Core-Loops.

## Scope und Sicherheit

Maßstab: `docs/specs/M1.md` und `docs/specs/M1-COMPLETION.md`. CRG-Registry bestätigt den Root; Minimal-Kontext: 189 Nodes, 1712 Edges, aktualisiert 23:05:48. Gezielte Graph-/Quellenprüfung von GameStore, AppModel, GameEngine, TerminalShell und beiden Testdateien. Kein `HEAD~1`: Repository hat keine Commits und die Implementierung ist untracked.

Vor dem ersten ausführbaren Check geprüft:
- `Sources/StaffelCore/GameStore.swift:45–58`: explizites `directory` wird tatsächlich verwendet und hat Vorrang vor `APP_STORE`; erst danach kommt der Standardpfad.
- Store-Tests verwenden UUID-basierte temporäre Verzeichnisse; IsolationRegressionTests prüft zusätzlich die Priorität. Dessen Environment-Test verändert APP_STORE, alle schreibenden Store-Tests verwenden jedoch explizite isolierte Verzeichnisse.
- `Sources/StaffelZwei/AppModel.swift:35–54`: defekter Store erhält Schreibschutz; Navigation persistiert über diesen geschützten Store. Keine stillschweigende Reparatur oder Wiederherstellung durchgeführt.
- Jeder Test-/Buildlauf erhielt ein neues APP_STORE-Tempverzeichnis. GUI initial in `/var/folders/hk/9jcb416d7j14n8pwsws8ymsw0000gn/T/m1-independent-gui-1k4jjj58`; nur der ausdrücklich geprüfte Neustart verwendete exakt dasselbe Verzeichnis.
- Der echte Application-Support-Spielstand wurde weder gelesen noch geändert. Keine Secrets ausgegeben, keine globalen macOS-Einstellungen verändert, keine Nutzer-App beendet.

## Tatsächlich ausgeführte Gates

| Prüfung | Ergebnis / Evidenz |
|---|---|
| `swift test --package-path /Volumes/T7/Projekte/linux-mac --scratch-path "$HOME/Library/Developer/StaffelZwei/build" --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` | **Exit 0, 45 Tests bestanden**, 0 Suites, 0.174 s Testlauf; Build 3.62 s. `independent-tests.log` |
| `/Volumes/T7/Projekte/linux-mac/build.sh` ohne Argumente | **Exit 0**, Release-Build 44.14 s; `independent-build.log`. Vorher Script vollständig auf Zieloperationen und Identität geprüft. Frische Stage, ad-hoc, kein `--force`, kein Install/Open. Vorheriges Bundle erhalten unter `dist/StaffelZwei.app.bak-20261117231343` |
| `codesign --verify --deep --strict /Volumes/T7/Projekte/linux-mac/dist/StaffelZwei.app` | **Exit 0**; außerdem im Build geprüft |
| `git diff --check` | **Exit 0**, allein nicht aussagekräftig für untracked Dateien. Zusätzliche Prüfung aller Swift-/Markdown-Dateien unter Sources, Tests, docs: **0 Zeilen mit nachgestelltem Whitespace** |
| Worker-Exitbeleg | `.worker/minimax-m1-completion.exit` enthält **0**. Alter abgebrochener Lauf `.worker/minimax-m1.exit` enthält **124** |
| Worker-Logs gelesen | gate1: 45 Tests; gate2: Build 70.89 s, Signaturprüfung ok; gate2b: Build 28.29 s, Signaturprüfung ok. Diese Logs ersetzen nicht die oben separat ausgeführten Gates |

Linker-Warnungen zu fehlenden CLT Developer-Library-Suchpfaden traten auf; sie verhinderten Build und Signatur nicht.

## Quellenbestätigte frühere Fehler

Die aktuelle Fassung behebt die geprüften Mechanismen; die 45 unabhängig gestarteten Tests sind grün:
- CSV-Reparatur über `cp`, Tildepfade nach `cd`, Backup-/Host-Schreibschutz: Regressionstests vorhanden und bestanden.
- `TerminalShell.swift:195–208`: Fehler rollen Dateiwelt und cwd zurück, einschließlich Fehlern bei nachgelagerter Umleitung.
- `GameEngine.swift:95–113`: Belege werden aus wirklich vorhandenen virtuellen Belegdateien und deren Inhalt neu validiert.
- `GameEngine.swift:207–236`: nur explizit ausgewählte validierte Belege zählen; beide Spuren und Reparatur sind erforderlich.
- Defekter Store bleibt durch GameStore/AppModel geschützt. **Navigation mit tatsächlich defektem Store wurde in der GUI nicht nochmals ausgeführt**; das ist Quellen-/Testnachweis, kein GUI-Nachweis.

Kein neuer schwerer funktionaler oder aktiver Datenschutzfehler in diesem Prüfscope nachgewiesen. Keine Aussage über unvollständig untersuchte Randfälle.

## Eigene GUI-Verifikation

Eigene dist-Binary direkt mit APP_STORE gestartet, PID 39225; kein Seed und keine künstlich gesetzten Erfolgsflags. agent-desktop-Anleitungen `desktop`, `platform` sowie Help gelesen. Accessibility und Screen Recording werden als granted gemeldet. Dennoch liefert der Fenster-Snapshot `ACTION_NOT_SUPPORTED`, `window_without_accessibility_element`. Keine Berechtigungsänderung und keine Debug-Brücke hinzugefügt. Ein Aktivierungsversuch über System Events lief ins Zeitlimit; nicht fortgesetzt. Nach Display-Wake mit `caffeinate -u -t 2` funktionierten ausschließlich eigene Fensterscreenshots.

Tatsächlich beobachtet:
1. Frischer Einsatzrahmen, 0 Belege, Simulationshinweis sichtbar: `independent-initial.png`.
2. `agent-desktop press cmd+2 --app StaffelZwei` öffnete sichtbar das Terminal: `independent-terminal.png`.
3. Cmd-4 öffnete Vorwurf; Cmd-Return ohne Auswahl zeigte inline **„Wähle zuerst einen Verdächtigen.“**, bei **„Noch keine erkannten Belege.“**: `independent-vorwurf-empty.png`. Das beweist den ganz leeren Zustand, nicht den gesonderten Fall „Person gewählt, Belege fehlen“.
4. Cmd-5 öffnete Hilfe mit Befehlen, Beispielen und Kopieren-Icons: `independent-help.png`.
5. Ausschließlich eigener PID 39225 beendet; Binary mit **demselben APP_STORE** erneut gestartet, PID 19050. Neues Fenster w-5146/PID 19050 bestätigt; Hilfe-Navigation blieb erhalten: `independent-restart-help.png`. Gespeicherter Zustand vorher: page=help, 1 initialer Transcript-Eintrag. **Kein Nachweis für Erhalt selbst eingegebener Befehle oder gesicherter Belege**, da dieser GUI-Durchlauf nicht zustande kam.
6. Anschließend ausschließlich eigener PID 19050 beendet.

Alle eigenen Bilder mit Read visuell angesehen. Fenster sind weiterhin inaktiv (graue Traffic Lights); deshalb **keine abgeschlossene visuelle Kontrast-/Dark-Mode-Abnahme**. Die Bilder belegen sichtbare Zustände und die Shortcutwirkung, nicht die Qualität eines aktiven Fensters.

### Nicht durchgeführte GUI-Pflichtfälle

- Vollständige vier Befehle der vorgegebenen Lösung durch echte Eingabe; gesicherte Ausgaben interaktiv öffnen.
- Person wählen, Belege explizit auswählen, falschen und korrekten Vorwurf interaktiv prüfen; Person ohne Belege → konkrete Beleg-Inlinehilfe.
- Fenster schließen/wieder öffnen und App-Neustart nach echter Lösung mit Belegen, selbst erzeugtem Transcript und Auswahl.
- Settings selbst öffnen/bedienen, Cmd-comma und Cmd-W prüfen; Cmd-Q wurde nicht als Produktverhalten geprüft (eigene Prozesse beendet).
- Aktive Light-/Dark-Aufnahmen **jeder** Seite und Settings, einschließlich Hilfe, Vorwurfzuständen und Erfolg.
- Layoutgrid: **nicht geprüft**. Keine `tools/grid-lint.sh`, `tools/check-layout.swift` oder Layout-JSONs vorhanden. Kein PASS behauptet.
- VoiceOver: **nicht durchgeführt**.

## Artefakte und Referenzvergleich

Vorhanden: `dist/StaffelZwei.app`, README, BRIEF, GLOSSARY, STORIES, Screen-INDEX, 12 originale Web-PNGs, 12 Worker-native PNGs, M1-REPORT. STORIES enthält **8 M1-Stories**, Flow-/Surface-Blöcke und spätere Milestones.

Alle 12 Originale und 12 nativen Worker-Bilder lokal als beschriftete Kontaktbögen erstellt und mit Read verglichen: `independent-original-contact.png`, `independent-native-contact.png`. Kontaktbögen erlauben Coverage-/Zustandsprüfung, ersetzen aber keine detaillierte Einzelbild-Kontrastprüfung jeder Seite.

Originale:
- 01 Projektseite; 02/03 Episode-0-Terminal mit Pager; 04 Terminal mit Fallakte, **nicht eigenständige Aktenwand**; 05 Serverraum mit Aktenwand.
- 06 Vorwurfdialog ohne Belege; 07 **Fortschritt-löschen-Bestätigung**, kein Vorwurfdialog.
- 08–10 Episode 1–3 im Ladezustand, keine tatsächlich spielbaren Episoden damit bewiesen; korrekt Later für M1.
- 11 Episode-0-Ladezustand; 12 dunkles Terminal, **kein Light-Mode-Nachweis**.
- INDEX benennt die vier irreführenden Capture-Notizen, insbesondere 07/12, ausdrücklich und behauptet keine vollständige helle Web-Coverage. Separate native Hilfeseite ist im Original nicht vorhanden. Native Simulation ersetzt bewusst echte Web-VM; keine 1:1-Laufzeitgleichheit behauptet.

Native Worker-Screens:
- 01 Einsatzrahmen mit Spuren; 02 Terminal leer; 03/05 gespeicherte Befehle und Reparaturstatus; 04 Aktenwand mit zwei anerkannten Belegen.
- 06 Vorwurf **ohne Auswahl, aber mit vorhandenen Belegen**; 07 Person und zwei Belege ausgewählt; 08 Erfolg/Nachspiel.
- 09 Settings; 10 heller Einsatzrahmen; 11 dunkler Einsatzrahmen; 12 Reset-Bestätigung.
- Damit **keine Light/Dark-Paare aller Seiten**; Hilfe fehlte im Worker-Satz und wurde als Zustand separat aufgenommen. Worker-Screens sind nicht als eigene erfolgreiche Core-Loop-Interaktionen ausgegeben.

## Abnahmeblocker und kleinster Restschritt

1. **Verbindliche GUI-/Layout-Verifikation unvollständig** (`docs/specs/M1.md:65–71`, `docs/specs/M1-COMPLETION.md:37`). Kein erwiesener Core-Defekt. Restschritt: in einem aktiven eigenen isolierten Fenster Lösung eintippen, Fehler-/Erfolgsfälle prüfen, Prozess-/Fensterneustart prüfen, Light/Dark-Matrix einschließlich Settings aufnehmen und Layout messen. AX-Probleme müssen dabei nicht gelöst werden, wenn echte Tastatur-/Mausinteraktionen und Screens den Nachweis liefern.
2. **Story-Status ist stärker als Nachweis** (`docs/STORIES.md:245–255`): Neustart-Story „erfüllt“, obwohl manueller Core-Neustart offen ist; eigene Teilprüfung schließt nur Navigation. Restschritt: obigen vollständigen Neustart nachholen oder Story bis dahin als teilweise geprüft führen. Kein Fix als Reviewer vorgenommen.

**M1 bleibt nicht abgenommen**, bis die verpflichtenden funktionalen GUI- und Layoutnachweise geschlossen sind. VoiceOver bleibt danach gegebenenfalls ausdrücklich genannte Einschränkung, niemals als durchgeführt ausgeben. Keine falsche grüne Statusänderung am Implementierungsbericht oder an Stories.
