# Staffel Zwei

Native macOS-Fassung des Linux-Krimis „Staffel 2 · Rechenwerk Ostwind“ von
<https://alex-schneider.dev/projekte/linux-krimi-staffel-2/>.

Staffel Zwei ist eine **offline** nutzbare SwiftUI-App für Apple Silicon.
Spielbar sind der Probelauf und sieben weitere Fälle bis zur Übergabe im
Staffelfinale. Folge 4 wird nach Folge 3 freigeschaltet. Danach öffnet jeder
abgeschlossene Fall die nächste Folge. Das Terminal führt
Befehle als `azubi` in einer lokalen Alpine-Linux-VM (ARM64) aus.
Die VM hat eine eigene Festplatte und arbeitet ohne Netzwerkkarte
oder freigegebene Mac-Verzeichnisse.

Bundle-ID: `de.alex-schneider.staffelzwei`

## Bauen

Voraussetzungen: Swift 6 (getestet mit 6.4.2), die Command Line Tools,
Python 3.11 oder neuer, Go und `7zz`. Der Build benötigt beim ersten Lauf
Internetzugriff für die per SHA-256 fixierten Alpine-Archive.
Ein volles Xcode wird nicht benötigt.

```bash
./build.sh              # Release-Build nach dist/StaffelZwei.app
./build.sh --debug      # Debug-Build
./build.sh --install    # zusätzlich nach ~/Applications/StaffelZwei.app
```

Das Skript:

- baut mit dem SDK 26.5 der Command Line Tools (`STAFFELZWEI_SDK` überschreibt das),
- legt das Bundle in einem frischen Staging-Verzeichnis unter
  `~/Library/Developer/StaffelZwei/staging` an und verschiebt es danach nach `dist/`,
- sichert ein vorhandenes `dist/StaffelZwei.app` als `StaffelZwei.app.bak-<Zeitstempel>`
  (nichts wird gelöscht),
- legt Kernel und Startdateisystem im App-Bundle ab und signiert
  **ad hoc** mit dem Virtualization-Entitlement,
- prüft am Ende `codesign --verify --deep --strict`.

Build-Artefakte liegen außerhalb des Repos:
`~/Library/Developer/StaffelZwei/build`.

## Starten

```bash
open dist/StaffelZwei.app
```

Für isolierte Läufe (Tests, Screenshots) den Ablageort des Spielstands
umbiegen – die App schreibt dann ausschließlich dorthin:

```bash
open -n --env "APP_STORE=$(mktemp -d)" dist/StaffelZwei.app
```

Ohne `APP_STORE` liegen `spielstand.json` und `linux-arm64.raw` unter
`~/Library/Application Support/StaffelZwei/`. Beim ersten VM-Start werden die
Kassenliste und vorhandene Missionsbelege aus älteren Spielständen übernommen.
Die weiteren Episoden haben getrennte Abbilder unter `episoden/`. „Fortschritt
zurücksetzen“ sichert den Spielstand und die Festplatte der aktiven Episode.

## Testen

Der reproduzierbare Test-Entry-Point steckt Toolchain, SDK und
Swift-Testing-Makro-Plugin selbst zusammen und läuft mit eigenem frischen
`APP_STORE`:

```bash
./tools/test.sh
```

Er findet das SDK und das Plugin aus der aktiven Toolchain, setzt die Flags nur
wenn sie nötig sind, gibt den Exitcode von `swift test` unverändert zurück und
wertet einen Lauf **ohne ausgeführte Tests als Fehler**. Fehlt SDK oder Plugin,
endet er mit Exitcode 1 und einer Diagnose – nie mit „0 Tests grün“.

Optional überschreibbar: `STAFFELZWEI_SDK`, `STAFFELZWEI_TEST_PLUGIN`,
`STAFFELZWEI_TEST_SCRATCH`, oder direkt `--sdk` / `--plugin-path`.

Der rohe Aufruf, den das Skript intern verwendet:

```bash
swift test --scratch-path "$HOME/Library/Developer/StaffelZwei/build" \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

Der Pfad für `-plugin-path` ist nötig, weil das Swift-Testing-Makro-Plugin nur
über diesen Weg gefunden wird, wenn gegen das 26.5-SDK gebaut wird. Ohne Xcode
im Standard-SDK (27.x) wird `@State` als Makro behandelt und der Build bricht ab.

Die Tests laufen ausschließlich in frisch erzeugten temporären Verzeichnissen
und berühren niemals echte Nutzerdaten.

## Prüfwerkzeuge

| Werkzeug | Zweck |
|---|---|
| `tools/test.sh` | Core-Tests reproduzierbar starten, echter Exitcode |
| `tools/app-checks.sh` | App-Pfade inklusive Negativfälle, echte Exitcodes |
| `tools/check-layout.swift` | Layout-JSONs prüfen (`--require-matrix` für die volle Screenmatrix) |
| `tools/check-layout-selftest.sh` | Negativ- und Positivtests für den Layout-Checker |
| `tools/grid-lint.sh` | Rasterregeln für `Sources` |
| `tools/windows.swift` | Fenster eines Prozesses per `--pid` auflisten |

## Der Probelauf

Im Einsatzrahmen öffnet **Staffel-2-Trailer ansehen** den nativen Videoplayer.
Der Trailer samt deutscher Untertitelspur liegt im App-Bundle und ist offline verfügbar.

Ziel: die veränderte Kaffeekasse-Liste (`/srv/rechenwerk/uebung/kaffeekasse.csv`)
sichern, die Beweise ablegen, die Liste aus der Sicherung reparieren und den
Täter überführen.

```bash
ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt
grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.csv > ~/belege/kasse-zeilen.txt
grep 2026-04-15 /srv/rechenwerk/uebung/kaffeekasse.bak >> ~/belege/kasse-zeilen.txt
cp /srv/rechenwerk/uebung/kaffeekasse.bak /srv/rechenwerk/uebung/kaffeekasse.csv
```

Danach im Vorwurf den Verdächtigen **Kaffeeautomat (Dienstkonto `kaffee`)** und
beide anerkannten Belege auswählen und „Prüfen“ auslösen.

Mit `uname -sm` kannst du Kernel und Architektur prüfen. Die Shell unterstützt
Pipes, Umleitungen und weitere Shell-Ausdrücke. `clear` leert die Anzeige.

## Umfang

- In Episode 2 und 4–7 öffnet **Bildschirm** (Cmd-6) den Linux-Desktop mit XTerm,
  PCManFM, Bildbetrachter und Mousepad. Das Wartungsfoto liegt unter
  `~/fotos/IMG_0417.png`. **Stand prüfen** aktualisiert die Belege nach
  Eingaben im grafischen Terminal.
- Der separate Terminal-Reiter führt Befehlszeilen mit einem Zeitlimit aus.
- Die Episoden 1–7 haben drehbare Serverraum-Ansichten und lokale Sprachclips
  mit Alex. Der Abschlussclip wird nach dem gelösten Fall verfügbar.
- Micha gibt im Einsatzrahmen pro Episode einen gesprochenen Tipp. Nach
  einer Weile döst er und reagiert auf „Micha wecken“. Seine Clips wurden mit
  seiner Stimmreferenz aus dem Trailer in Fish Audio Drama 3 gerendert.
- Die Übergabe in Folge 7 prüft vier Aussagen und den Inhalt der freigegebenen
  Datei. Nach der erfolgreichen Abgabe sind Bericht und Schlusssequenz verfügbar.
- Die Ausschnitte und Michas Bewegungsclips werden lokal aus dem App-Bundle
  abgespielt. Bei reduzierter Bewegung zeigt die App Standbilder und Dialogtext.
- `/home/azubi` und die Kassenliste bleiben in der Linux-Festplatte erhalten.
  Die Sicherungsdatei in der Übung ist für `azubi` schreibgeschützt.

## Kurzbefehle

| Taste | Wirkung |
|---|---|
| Cmd-1 … Cmd-5 | Einsatzrahmen, Terminal, Aktenwand, Vorwurf, Hilfe & Werkzeuge |
| Cmd-6 | Linux-Bildschirm in Folge 2 und 4–7 |
| Cmd-Return | Vorwurf prüfen oder Übergabe abgeben |
| Cmd-, | Einstellungen |

## Dokumentation

| Datei | Inhalt |
|---|---|
| `docs/specs/M1.md` | M1-Spezifikation |
| `docs/specs/M1-COMPLETION.md` | Ergänzung: Abschluss-Spec mit Sicherheitsgrenzen |
| `docs/BRIEF.md` | Produkt- und Design-Brief |
| `docs/GLOSSARY.md` | einheitliche Begriffe |
| `docs/STORIES.md` | User Stories mit Abnahmekriterien |
| `docs/screens/INDEX.md` | Screen-Index der Web-Referenz |
| `docs/verification/M1-REPORT.md` | Abnahmebericht: geprüft, umgesetzt, offen |
| `docs/verification/M1-BLOCKERS-RESULT.md` | Blockerreparatur vom 18.11.2026: Änderungen, echte Exitcodes, offene Punkte |
