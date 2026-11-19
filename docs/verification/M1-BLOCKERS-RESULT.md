# M1 – Blockerreparatur, Ergebnis vom 18.11.2026

Stand: 18.11.2026 · Repo `/Volumes/T7/Projekte/linux-mac` · Branch `feature/m1-native` (ohne Commit)

Dieser Bericht ist ein **Implementierungs- und Selbstprüfungsbericht** des
MiniMax-Workers, **keine unabhängige Abnahme**. Alle Zahlen und Exitcodes
stammen aus ausgeführten Befehlen in dieser Sitzung; nicht ausgeführte
Prüfungen sind als offen markiert.

Leit-Spec: `docs/specs/M1-BLOCKERS.md`. Die alte Reviewhistorie
(`docs/verification/M1-INDEPENDENT-REVIEW.md`, `M1-REPORT.md` Abschnitt
„Vorgeschichte“) wurde **nicht** verändert.

---

## 1. Ergebnis in einem Satz

Die fünf im Spec genannten Blocker sind im Code behoben und durch negative
Läufe belegt (fail-closed Exitcodes, echte Testentry-Point-Skripte, gehärteter
Layout-Checker); **offen bleibt der GUI-Nachweis**, weil der Bildschirm dieser
macOS-Sitzung gesperrt war (`CGSSessionScreenIsLocked: True`) und deshalb kein
Fenster-Screenshot erzeugt werden konnte.

---

## 2. Sicherheitsgate: Store-Isolation (read-only geprüft)

`Sources/StaffelCore/GameStore.swift:45-59` — Pfadpriorität
**explizites Verzeichnis > `APP_STORE` > Standardpfad** im Benutzerverzeichnis.
Der Parameter `directory:` wird benutzt, `APP_STORE` hat Vorrang vor dem
Standardpfad. Der Store wurde in dieser Sitzung **nur gelesen**, nie geändert.

Belege:

| Prüfung | Ergebnis |
|---|---|
| `ls -la ~/Library/Application Support/StaffelZwei/` | `spielstand.json`, 1346 Bytes, **mtime 17.11. 22:36** (vor dieser Sitzung), unverändert |
| Jeder Test-/App-Start | eigenes frisches `APP_STORE` (`mktemp -d`) |
| Vorbestehender Worker-Prozess PID 35029 | läuft weiter, **nicht** angefasst, nicht beendet |
| Eigene Prozesse | ausschließlich per eigener PID beendet (`kill $pid`) |

---

## 3. Umgesetzte Änderungen

### 3.1 `Sources/StaffelZwei/SelfTest.swift` + `StaffelZweiApp.swift` – fail-closed Exitcode

| vorher | nachher |
|---|---|
| `exitCode` startete bei `0` → ein abgebrochener Lauf war grün | `exitCode` startet bei `1`; nur `finish(code: 0)` setzt `completed = true` |
| `applicationWillTerminate` nutzte `SelfTest.exitCode` ungeprüft | `exit(SelfTest.completed ? 0 : 1)` – ein unvollständiger Test bleibt Fehler |
| Watchdog existierte nicht; ohne Fenster (kein `onAppear`) hing der Prozess endlos | `SelfTest.startWatchdog()` läuft ab `applicationDidFinishLaunching`, **vor** `onAppear`; Zeitlimit 120 s, überschreibbar per `APP_SELFTEST_TIMEOUT` |
| fehlendes `APP_STORE` wurde erst bei `onAppear` gemeldet | wird beim App-Start sofort gemeldet und beendet (`exit 1`) |
| Ergebnisdatei gab es nicht | `APP_SELFTEST_RESULT` schreibt JSON mit `status` (`completed`/`failed`), `checks`, `failures`, `exitCode` |

### 3.2 `Sources/StaffelZwei/Snapshot.swift` – fail-closed statt „done“

| vorher | nachher |
|---|---|
| jede Aufnahme meldete nur `SNAPSHOT done`, der Exitcode war 0 | `SNAPSHOT PASS/FAIL`, `exitCode` 1 bei jedem Problem |
| ein fehlgeschlagener Screenshot (fehlendes Fenster, Writefehler) lief weiter | `capture(...) -> Bool`, fehlende/leere PNG zählt als Fehler |
| Layoutdaten wurden nie geprüft | `verifyLayout(for:)` prüft je Seite, dass es eine nichtleere Layout-JSON mit Probes gibt |
| fehlendes Settings-Fenster lief durch | fehlendes Settings-Fenster zählt als Fehler |
| `SNAPSHOT` mit fehlendem `APP_STORE` endete mit Exit 0 | endet mit Exit 1 |
| Snapshot lief nie mit Timeout | `Snapshot.startWatchdog()` ab App-Start, 150 s, überschreibbar per `APP_SNAPSHOT_TIMEOUT` |
| der Snapshot zeigte den Store-Zustand ohne Kennzeichnung | `SNAPSHOT note:` weist aus, dass der Lauf den Zustand aus `APP_STORE` zeigt und **kein** Core-Loop-Nachweis ist |

### 3.3 `tools/check-layout.swift` – kein PASS bei leerem oder kaputtem Material

Neu bzw. geändert:

- **keine Argumente** → `FAIL check-layout: no layout files given`, Exit 2 (vorher: Exit 0 ohne jede Ausgabe),
- **Datei ohne Probes** → `FAIL … no probes in file`, Exit 1 (vorher: PASS),
- **unbekannte Option** → Exit 2,
- **Geometrie validiert**: Breite/Höhe müssen positiv, `x`/`y`/`width`/`height`/`inset` müssen endlich sein, `inset` darf nicht negativ sein,
- **Area validiert**: eine Area ohne positive Größe ist ein Fehler,
- **Fenster validiert**: `window.width`/`window.height` müssen positiv und endlich sein,
- **Vollständigkeit separat**: `--require-matrix <dir>` prüft eigenständig, ob alle 5 Seiten × Light/Dark eine nichtleere Layout-JSON liefern – ein Mini-Fragment kann so keinen vollständigen M1-Nachweis vortäuschen.

Die bestehenden Regeln (Raster, Inset, Kanten, Abstände, Überlappungen) sind
**unverändert**; keine Erwartung wurde abgeschwächt.

### 3.4 `tools/grid-lint.sh` – ausführbar, Exitcode erhalten

- Dateimodus jetzt `755` (vorher `644` → nicht ausführbar),
- der Exitcode von `perl` wird durch `set -euo pipefail` korrekt durchgereicht,
- neue Guards: fehlendes Verzeichnis → `FAIL grid-lint: … is not a directory`, Exit 1;
  Verzeichnis ohne Swift-Datei → `FAIL grid-lint: no Swift files in …`, Exit 1
  (vorher: stiller Exit 0 ohne `PASS`-Marker),
- es wird immer genau eine Markerzeile geschrieben (`PASS grid-lint` / `FAIL …`).

### 3.5 Neuer Test-Entry-Point `tools/test.sh`

Reproduzierbarer Einstiegspunkt für die Core-Tests:

- findet **SDK** und **Swift-Testing-Makro-Plugin** aus der aktiven Toolchain
  (`xcode-select -p` bzw. Pfad des `swift`-Binaries),
- setzt `-plugin-path` **nur, wenn** das Plugin nicht im Standardsuchpfad liegt
  (empirisch nötig: ohne den Pfad bricht der Kompilierlauf mit Exit 1 ab),
- benutzt ein **eigenes frisches `APP_STORE`** (`mktemp -d`) – echte Nutzerdaten
  werden nie geöffnet,
- gibt den Exitcode von `swift test` **unverändert** zurück,
- wertet einen Lauf **ohne ausgeführte Tests als Fehler** (Exit 1) – nie als „0 Tests grün“,
- fehlendes SDK oder Plugin → klare Diagnose, Exit 1,
- optionale Overrides: `STAFFELZWEI_SDK`, `STAFFELZWEI_TEST_PLUGIN`,
  `STAFFELZWEI_TEST_SCRATCH` oder `--sdk` / `--plugin-path`.

### 3.6 Weitere Werkzeuge

| Datei | Änderung |
|---|---|
| `tools/windows.swift` | neues `--pid <pid>`: listet nur die Fenster **eines** Prozesses. Kein „erstes Fenster der App“ mehr. |
| `tools/check-layout-selftest.sh` | neu: 10 Negativ-/Positivfälle für den Layout-Checker mit echten Exitcodes. |
| `tools/app-checks.sh` | neu: App-Pfade inklusive Negativfälle (Selbsttest/Snapshot ohne `APP_STORE`, Selbsttest mit eigenem Store, normaler Start mit eigenem Fenster), echte Exitcodes, nur eigene Prozesse werden beendet. |

---

## 4. Geführte Befehle, echte Zahlen, echte Exitcodes

| # | Befehl | Ergebnis | Exit |
|---|---|---|---|
| 1 | `./tools/test.sh` | `Test run with 45 tests in 0 suites passed` → `PASS test: Test run with 45 tests` | **0** |
| 2 | Baseline `swift test` (26.5-SDK + Pluginpfad) | 45 Tests grün | **0** |
| 3 | `swift test` **ohne** `-plugin-path` | `error: SwiftCompile normal arm64 failed` | **1** |
| 4 | `./tools/check-layout-selftest.sh` | 10/10 Fälle PASS (no arguments → 2, empty probes → 1, broken json → 1, missing file → 1, real violation → 1, invalid area size → 1, unknown option → 2, valid fixture → 0, incomplete matrix → 1, complete matrix → 0) | **0** |
| 5 | `./tools/grid-lint.sh Sources` | `PASS grid-lint` | **0** |
| 6 | `./tools/grid-lint.sh <leeres Verzeichnis>` | `FAIL grid-lint: no Swift files in …` | **1** |
| 7 | `./tools/grid-lint.sh <fehlendes Verzeichnis>` | `FAIL grid-lint: … is not a directory` | **1** |
| 8 | `./tools/grid-lint.sh <Verzeichnis mit padding(13)>` | `FAIL grid-lint: 1 lines off the grid` | **1** |
| 9 | `./build.sh` | `Build complete! (4,70 Sek.)`, `codesign --verify --deep --strict: ok` | **0** |
| 10 | `codesign --verify --deep --strict dist/StaffelZwei.app` | `Identifier=de.alex-schneider.staffelzwei`, `Signature=adhoc` | **0** |
| 11 | `./tools/app-checks.sh` | siehe Abschnitt 5 | **1** (2 von 4 Prüfungen fehlgeschlagen) |

Das Bundle wurde zweimal neu gebaut; das vorherige `dist/StaffelZwei.app` liegt
als `dist/StaffelZwei.app.bak-<Zeitstempel>` daneben. Nichts wurde gelöscht,
kein `--force`, kein Zertifikat.

---

## 5. App-Ebene: echte Exitcodes

`./tools/app-checks.sh` (Watchdog-Grenzen 15 s, je Lauf eigenes `APP_STORE`):

| Prüfung | Exit | Bewertung |
|---|---|---|
| Selbsttest **ohne** `APP_STORE` | **1** | erwartet: fail-closed, Meldung `SELFTEST refused: set APP_STORE to a directory in /tmp` |
| Snapshot **ohne** `APP_STORE` | **1** | erwartet: fail-closed, Meldung `SNAPSHOT refused: set APP_STORE to a directory in /tmp` |
| Selbsttest **mit** eigenem Store | **1** | `SELFTEST FAIL 18 of 32 checks`, `could not create image from window` – siehe 6 |
| normaler Start (ohne Flags) | – | eigenes Fenster: `pid=51833 window=5243 layer=0 onscreen=true size=1116x739 owner=StaffelZwei`, **Screenshot fehlgeschlagen** (`could not create image from window`) |

Der normale, sichtbare Start **funktioniert**: die App erzeugt ein eigenes,
sichtbares Fenster (`onscreen=true`, 1116×739). Nur die fensterbezogene
Aufnahme (`screencapture -l`) scheitert an der gesperrten Sitzung.

**Sicherheitsverhalten bestätigt:** Die Wege, die vorher falsch grün waren
(Selbsttest ohne Store, Snapshot ohne Store, Snapshot mit fehlgeschlagenen
Captures), enden jetzt mit Exitcode ungleich 0. Der Exitcode 0 wird nur noch
gesetzt, wenn alle Prüfungen wirklich liefen.

---

## 6. Offener Blocker: kein GUI-Nachweis (gesperrter Bildschirm)

Diagnose (gemessen, nicht vermutet):

- `ioreg -n Root -d 1 -a` → `CGSSessionScreenIsLocked: True`,
- `lsappinfo front` → `loginwindow` ist vorn,
- der vorbestehende Prozess PID 35029 zeigt `!cgsConnection` (keine
  Window-Server-Verbindung mehr),
- `screencapture -x <datei>` (ganzer Bildschirm) **funktioniert**
  (139.098 Bytes), `screencapture -l <fensternummer>` **scheitert** mit
  `could not create image from window`,
- ein direkt gestarteter zweiter Prozess registriert sich gar nicht erst beim
  Window Server (`lsappinfo` zeigt `bundleID = NULL`).

Ein Test mit dem **alten** Bundle (`dist/StaffelZwei.app.bak-20261118072819`,
also vor allen heutigen Quelländerungen) verhält sich **identisch**: ebenfalls
`windows=0` und kein Fenster. Die heutigen Änderungen sind damit **nicht**
die Ursache; es ist der Zustand der Sitzung.

Spätere Läufe in derselben Sitzung kamen weiter: der normale Start
erzeugte ein eigenes, sichtbares Fenster (`window=5243`, `onscreen=true`),
nur die fensterbezogene Aufnahme blieb aus. Der Selbsttest lief ebenfalls an
(32 Prüfungen, 18 Fehlschläge) und endete korrekt mit Exitcode 1.

Konsequenz: Der im Spec geforderte **Screenshot** des eigenen Fensters, echte
interaktive Eingaben über das Textfeld, Light/Dark-Paare aller 5 Seiten plus
Settings, echte Layoutproben und der Neustart im selben Store **konnten in
dieser Sitzung nicht belegt** werden. Sie bleiben offen. Es wird **kein**
PASS behauptet.

Zusätzlich unabhängig davon, ob der Bildschirm entsperrt wird:

- die drei Bildschirm-Prüfungen aus `M1-REPORT.md` („Layoutgrid und
  VoiceOver“, „manueller Neustart“, „Screenreader“) bleiben ohnehin offen,
- `docs/STORIES.md` wurde **nicht** geändert: für M1-8 („Neustart mit
  erhaltenem Zustand“) fehlt der belegte Nachweis weiterhin.

---

## 7. Was als nächstes zu tun ist

1. Bildschirm entsperren, danach `./tools/app-checks.sh` ohne
   `APP_SELFTEST_TIMEOUT`-Kürzung laufen lassen: dann sind Selbsttest
   (32/32), Fenster-Screenshot und Neustart im selben Store belegbar.
2. `APP_SNAPSHOT=<dir> APP_STORE=<dir> dist/StaffelZwei.app/Contents/MacOS/StaffelZwei`
   → Exitcode prüfen, danach
   `swift tools/check-layout.swift --require-matrix <dir> <dir>/*-layout.json`.
3. Danach die offenen Punkte aus `M1-REPORT.md` abarbeiten (Neustart-Check,
   Screenreader, Referenz-Screen hell).

---

## 8. Nicht behauptet

- keine unabhängige Abnahme,
- kein GUI-Nachweis, keine behaupteten Light/Dark-Paare,
- keine Änderung an `docs/STORIES.md`,
- kein Commit, kein Push, keine externe Übertragung, keine globale Konfiguration.

## Folgeprüfung am 18.11.2026

- Der Einstieg prüft den temporären `APP_STORE` vor `StaffelZweiApp.main()`. Mit einer ersetzten Launch-Funktion wurden sieben Fälle geprüft. Beide Prüfmodi ohne Pfad, ein Pfad außerhalb des temporären Bereichs und ein verlinkter Spielstand endeten mit Exit 1, jeweils ohne Aufruf der Launch-Funktion. Normalstart und beide Prüfmodi mit gültiger Konfiguration erreichten die Launch-Funktion.
- Der Layout-Checker validiert alle zehn erforderlichen Dateien mit denselben Regeln wie einzeln übergebene Dateien. Alle 14 Prüffälle bestanden, darunter eine kaputte Matrix mit zusätzlich gültiger Datei, eine einzelne geometrisch ungültige Position und eine doppelte Position per Symlink.
- Der Fensterlauf in der entsperrten Sitzung lieferte zwölf Aufnahmen und zehn gültige Layout-JSONs. Die separate GUI-Selbstprüfung führte alle vier Terminalbefehle aus, erkannte beide Belege und bestätigte die Reparatur. Sie scheiterte beim Auffinden der Vorwurf-Schaltflächen und endete mit Exit 1. VoiceOver und Neustart nach gelöstem Fall wurden dabei nicht geprüft.
- Core-Tests (45/45), statische Rasterprüfung und Signaturprüfung waren erfolgreich.
- Der Trailer aus dem Webprojekt wurde in 1080p mit deutscher Untertitelspur ins App-Bundle übernommen. Aufruf, Wiedergabe und Schließen im nativen Fenster wurden mit einem frischen temporären Spielstand geprüft. [Fensteraufnahme](13-trailer.png)
