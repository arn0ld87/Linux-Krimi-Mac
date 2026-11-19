# Brief – Staffel Zwei (native Mac-App)

## Produkt

**Name:** Staffel Zwei
**Bundle-ID:** `de.alex-schneider.staffelzwei`
**Zielplattform:** macOS 15 oder neuer, Swift 6 / SwiftUI, native App ohne WebView.
**Betrieb:** offline, single-user, keine Netzwerkverbindung, kein Konto, keine Telemetrie.

Die App ist die native Mac-Fassung des Linux-Krimis „Staffel 2 · Rechenwerk
Ostwind“ von <https://alex-schneider.dev/projekte/linux-krimi-staffel-2/>.
Sie richtet sich an Auszubildende, die Linux-Grundlagen an einem echten Fall
lernen wollen: Dateien untersuchen, Rechte lesen, Beweise sichern, einen
Täter überführen.

## Umfang M1

M1 ist bewusst klein. Spielbar ist **nur Episode 0 „Probelauf“ – Die
Kaffeekasse** (Beweisstück `S2-E0-KASSE`). Episode 1–3 sind in der
Episodenübersicht sichtbar und mit „Später verfügbar“ gekennzeichnet; sie
können nicht gestartet werden.

M1 enthält **kein echtes Linux**. Statt eines Browsers mit Alpine im
Backend gibt es ein Übungsterminal: eine dateibasierte Shell-Simulation mit
eigenem Parser, eigener virtueller Dateiwelt und deterministischem Zustand.
Die App startet keinen Prozess, öffnet keine echte Datei und spricht kein
Netzwerkprotokoll. Der Hinweis „Lokale Übungssimulation – keine Befehle auf
deinem Mac“ steht sichtbar im Terminal und in den Einstellungen.

## Designplan

### Archetyp

Sidebar-Archetyp mit `NavigationSplitView`: links die Navigation, rechts der
Arbeitsbereich. Keine Tab-Leiste, kein Dashboard, keine Kacheln.

Sidebar-Aufbau (von oben):

1. Kopfzeile `Fall 0 · Probelauf`
2. Seiten: Einsatzrahmen, Terminal, Aktenwand, Vorwurf, Hilfe & Werkzeuge
3. Episodenübersicht: Episode 0 spielbar, Episode 1–3 gesperrt
4. Fußzeile: Fortschrittsanzeige (Spuren, anerkannte Belege, Zustand der
   Kaffeekasse) – in der schmalen Sidebar untereinander, damit nichts
   zeichenweise umbricht

### Arbeitsflächen

| Seite | Inhalt |
|---|---|
| **Einsatzrahmen** | Auftrag, Organisation, Konto, Ordner, Grundregel des Falls, Schrittliste der Spuren, Erfolgsmeldung nach dem Probelauf |
| **Terminal** | Verlauf, Prompt mit aktuellem Arbeitsverzeichnis, Eingabefeld, Belege-Panel daneben |
| **Aktenwand** | Die gesicherten Belege mit echtem Inhalt, Spur und Anerkennungsstatus |
| **Vorwurf** | Verdächtigen-Auswahl, Belegauswahl, Prüfung mit konkreter Rückmeldung |
| **Hilfe & Werkzeuge** | Unterstützte Befehle, Erklärung der Belege, kopierbare Beispiele (die nichts ausführen) |

### Gefühl

Ruhig und ermittlerisch. Kein Zeitdruck, keine Punkte, keine Erfolgs-Confetti.
Fortschritt wird sachlich benannt („2 von 2 Spuren“, „2 von 2 Belegen
anerkannt“), nie mit erfundenen Kennzahlen.

### Visuelles System

- **Chrome** (Rahmen, Sidebar, Menüleiste, Toolbars): Systemschriften
  (SF Pro / SF Mono), SF Symbols, Systemfarben (`Color.primary`,
  `.secondary`, `.bar`). Kein festes Weiß – Light und Dark funktionieren
  automatisch.
- **Inhalt**: warmes Papier (`Palette.paper`) als Fläche, sparsame
  Kupfer-/Orange-Akzente (`Palette.copper`) für Aktionen und Auswahl,
  gedämpftes Grün (`Palette.evidenceGreen`) für anerkannte Belege.
- **Terminal**: grünliche Tinte auf dunkler Fläche, Monospace, farbige
  Ausgabearten (Eingabe, Ausgabe, Fehler, Systemhinweis).
- Keine Charts, keine Animationen, keine dekorativen Bilder.

### Menüs und Shortcuts

| Aktion | Shortcut |
|---|---|
| Einsatzrahmen / Terminal / Aktenwand / Vorwurf / Hilfe | Cmd-1 … Cmd-5 |
| Vorwurf prüfen | Cmd-Return |
| Einstellungen | Cmd-, (System) |
| Beenden | Cmd-Q (System) |

Keine globalen Return- oder Delete-Menüshortcuts – Return gehört der
Terminal-Eingabe, Delete dem Textfeld.

### Empty-States

- Terminal ohne Eingabe: Hinweis auf die Simulation plus Systemhinweis-Zeile
- Aktenwand ohne Belege: „Noch keine Belege“ mit Hinweis auf `~/belege/`
- Vorwurf ohne Belege: „Noch keine anerkannten Belege“ plus Regel „mindestens
  zwei, aus beiden Spuren“
- Vorwurf ohne Verdächtigen: „Wähle zuerst einen Verdächtigen.“
- Fehlerhafter Befehl: Klartext im Terminal, Zustand bleibt unverändert

### Barrierefreiheit

Icon-only-Schaltflächen haben `.help` und `accessibilityLabel`. Werte werden
über AX-Rollen und -Labels ausgegeben (im GUI-Test verifiziert: Sidebar,
Terminal-Eingabefeld, Verdächtigen-Auswahl und Belege-Karten sind als
`treeitem`, `textfield`, `radiobutton`/`checkbox` adressierbar).
Screenreader-Vorlese ist **nicht** vollständig geprüft.

## Technische Rahmenbedingungen

- Swift Package ohne externe Abhängigkeiten. `StaffelCore` ist reines
  Foundation und enthält die gesamte Spiellogik; `StaffelZwei` ist die
  SwiftUI-Oberfläche; `StaffelCoreTests` testet den Kern ohne App.
- Kein WebView, kein Electron, keine UI-Bibliothek von Dritten.
- Persistenz als Codable-JSON, atomar geschrieben, überschreibbar per
  Umgebungsvariable `APP_STORE` für isolierte Tests und Screenshots.
- Ad-hoc-Signierung, kein Zertifikat, keine private Entwicklungsidentität.
- Build ohne Xcode (Command Line Tools, SDK 26.5), Scratch-Verzeichnis
  `~/Library/Developer/StaffelZwei/build`.
