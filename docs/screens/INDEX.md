# Screen-Index – Referenz der Web-Fassung

Grundlage sind die zwölf PNGs in diesem Ordner. Jeder Abschnitt beschreibt nur das,
was im Bild tatsächlich zu sehen ist. Die Datei `_capture-report.json` enthält
Notizen aus dem Aufnahmelauf; **zwei davon widersprechen dem Bildinhalt** und
sind unten als Korrektur vermerkt (siehe „Korrekturen an den Aufnahme-Notizen“).

Quelle der Aufnahmen: <https://alex-schneider.dev/projekte/terminal-missionen/app/staffel-2/>
(öffentliche Seite, frischer Browser-Kontext, Wegwerf-Zustand, kein Nutzerkonto).

---

## Gemeinsames Grundgerüst (alle App-Screens)

| Bereich | Inhalt |
|---|---|
| Top-Leiste | Logo „alex-schneider.dev“, Wortmarke „EIN LINUX-KRIMI | STAFFEL 2“, Episoden-Dropdown, „Fortschritt löschen“, „Spiel verlassen“ |
| Titelzeile | „Episode N · <Episodentitel>“, Badge „SERVER IW-SRV01“, Fortschritt „0 von 2 Spuren“ mit Regler |
| Pager-Leiste | Porträt „Alex“, Label „PAGER · ALEX“, Meldungstext, „Ton an“, „Verlaut“ |
| Reiter | „Terminal“, optional „Bildschirm“ (nur Episode 2), „Serverraum“; rechts „Fallakte“ |
| Terminal-Kopf | „echtes Linux · Alpine · ohne Netzwerk“, rechts „Tab verlassen: Esc, dann Tab“, „Neu starten“ |
| Fußzeile | Status „Linux bereit“ / „Linux lädt“, „Spuren 0/2“, „Belege 0“, Aktion „Vorwurf erheben“ |

Dunkles Farbschema mit warmem Papierweiß im Textbereich, orange-roten Akzenten
für Aktionen, grünlich-schwarzem Terminal.

---

## 01 — Projektseite (`01-projektseite.png`)

- **Zugang:** öffentliche Projektseite, kein App-Screen (Kontext).
- **Inhalt:** Kicker „PROJEKT / KONZEPT, ERMITTLUNGS-ENGINE & EPISODENDESIGN“,
  Headline „Ein Linux-Krimi · Staffel 2 · Rechenwerk Ostwind“.
  Fließtext: „Echtes Alpine Linux im Browser. Staffel 2: Du prüfst als
  Junior-Pentester die Server der Rechenwerk Ostwind GmbH, findest die Spuren
  eines Eindringlings und beweist mit selbst gesicherten Belegen, wer es war.
  Episode 0 bis 3 sind spielbar.“
- **Sichtbare Aktionen:** Button „STAFFEL 2 SPIELEN →“.
- **Weiteres:** Tech-Stack-Chips (V86, Alpine Linux, XTERM.JS, React 19,
  TypeScript, Astro, Xorg, Openbox), Navigation „Was ich kann / Projekte / Über
  mich / Blog / Zertifikate / Kontakt“, Sprachumschalter „Bauplan“.

## 02 — Einsatzrahmen im Pager (`02-einsatzrahmen-pager.png`)

- **Zugang:** Start der Episode 0; der Auftrag erscheint als Pager-Nachricht über
  dem Terminal.
- **Inhalt:** „Episode 0 · Probelauf“, Pager mit „Ton an“ und „Verlaut“, darunter
  das Terminal mit Prompt `azubi@rw-srv01`, Statuszeile „echtes Linux · Alpine ·
  ohne Netzwerk“, rechts „Fallakte“.
- **Sichtbare Aktionen:** Terminalreiter „Terminal | Serverraum“, „Neu starten“,
  „Fallakte“, Fußzeile „Vorwurf erheben“.

## 03 — Terminal (`03-terminal.png`)

- **Zugang:** Hauptansicht der Episode 0 nach Schließen des Pagers.
- **Inhalt:** Prompt `azubi@rw-srv01:~$`, Zeilen „Alex' Server · Dein Auftrag
  steht im Pager über dem Terminal · alex-schneider.dev“ und
  „iw-srv01 login: azubi (automatic login)“.
- **Sichtbare Aktionen:** Terminalreiter, „Neu starten“, „Fallakte“, „Vorwurf
  erheben“.

## 04 — Aktenwand (`04-aktenwand.png`)

- **Zugang:** rechtes Panel „Fallakte“ über der Hauptansicht geöffnet.
- **Inhalt:** Panel „Fallakte“ mit Knopf „Schließen“, einklappbarem Abschnitt
  „EINSATZRAHMEN“, Abschnitt „SPUREN“ mit den Spuren **AKTE** und **INHALT**
  (je „0 von 2 Schritten erledigt“) und darunter der ausformulierte Aktentext
  („Sichere Besitzer, Rechte und Datum der Dateien“ …).
- **Sichtbare Aktionen:** „Schließen“, Spur-Auswahl, „Vorwurf erheben“.

## 05 — Serverraum / Aktenwand-Ansicht (`05-serverraum.png`)

- **Zugang:** Reiter „Serverraum“ (Episodenübersicht der Web-Fassung).
- **Inhalt:** Ansichtsgruppe „Ansichten“ mit Chip „AKTENWAND“, Abschnitt
  „AKTENWAND“ mit Knopf „AKTUALISIEREN“ und dem Hinweis „Dateien werden beim
  Öffnen oder Aktualisieren gelesen. Belege prüft das Terminal nach einem
  Befehl.“, Leerzustand „Noch keine Dateien in ~/belege/“.
- **Sichtbare Aktionen:** „AKTUALISIEREN“, „Fallakte“, „Vorwurf erheben“.

## 06 — Vorwurf, leer (`06-vorwurf-leer.png`)

- **Zugang:** Modal „Vorwurf erheben“ über abgedunkelter Hauptansicht.
- **Inhalt:** Regeltext „Mindestens 2 Belege(e), mindestens ein Beleg aus jeder
  Spur. Die Prüfung erfolgt frisch vor der Bewertung.“
- **Sichtbare Aktionen:** Radio-Auswahl unter **VERDÄCHTIGE**:
  - Timo Kessler – Systemadministrator, trinkt den meisten Kaffee
  - Nadia Brem – Datenbankverwaltung, führt die Kaffeekasse
  - Kaffeeautomat (Konto kaffee) – Dienstkonto, gleicht nachts die Kasse ab
  - Abschnitt **BELEGE** mit Leerzustand „Noch keine anerkannten Belege.“
  - Buttons „Abbrechen“ und „Absenden“ (orange).

## 07 — Bestätigungsdialog Fortschritt löschen (`07-vorwurf-dialog.png`)

- **Zugang:** Aktion „Fortschritt löschen“ in der Top-Leiste.
- **Inhalt:** Dialog „Fortschritt löschen?“ mit dem Text „Alle gelösten Episoden
  von Staffel 2 werden vergessen. Staffel 1 bleibt unberührt. Danach beginnt die
  Seite wieder bei Episode 0. Gespeichert wird nur, welche Episoden du gelöst
  hast. Neustart“ im Terminal beginnt die laufende Episode von vorn.“
- **Sichtbare Aktionen:** „ABBRECHEN“, „ENDGÜLTIG LÖSCHEN“ (rot umrandet).
- **Hinweis:** nicht bestätigt; der Dialog wurde nur aufgenommen.

## 08 — Episode 1, Ladezustand (`08-episode-1.png`)

- **Zugang:** Episoden-Dropdown → „Episode 1 · Zu viele Rechte“.
- **Inhalt:** Titelzeile „Episode 1 · Zu viele Rechte“, Terminalzeile
  „Linux wird geladen … 50 %“, Overlay-Karte „Linux wird geladen …“ mit „Auf dem
  Handy dauert der erste Start etwas länger.“ und Fortschrittsbalken.
- **Sichtbare Aktionen:** „Neu starten“, „Fallakte“, „Vorwurf erheben“.
- **Korrektur:** Die Aufnahme-Notiz nennt eine „Episodenübersicht“ – im Bild ist
  **keine Übersicht**, sondern der Ladezustand der Episode 1 zu sehen.

## 09 — Episode 2, Ladezustand (`09-episode-2.png`)

- **Zugang:** Episoden-Dropdown → „Episode 2 · Der Prozess, der nicht stirbt“.
- **Inhalt:** Titel „Episode 2 · Der Prozess, der nicht stirbt“, Reiter
  „Terminal | Bildschirm | Serverraum“ (hier ist zusätzlich der Reiter
  „Bildschirm“ vorhanden), Terminalzeile „Linux wird geladen … 50 %“, dieselbe
  Lade-Karte mit Fortschrittsbalken.
- **Sichtbare Aktionen:** „Neu starten“, „Fallakte“, „Vorwurf erheben“.
- **Korrektur:** Auch hier ist keine Episodenübersicht abgebildet.

## 10 — Episode 3, Ladezustand (`10-episode-3.png`)

- **Zugang:** Episoden-Dropdown → „Episode 3 · Die Lücke im Log“.
- **Inhalt:** Titel „Episode 3 · Die Lücke im Log“, Terminalzeile „Linux wird
  geladen … 50 %“, Lade-Karte mit Fortschrittsbalken.
- **Sichtbare Aktionen:** „Neu starten“, „Fallakte“, „Vorwurf erheben“.
- **Korrektur:** Auch hier ist keine Episodenübersicht abgebildet.

## 11 — Hauptansicht (`11-hauptansicht-dark.png`)

- **Zugang:** Hauptansicht der Episode 0.
- **Inhalt:** dunkle Darstellung; Pager „Noch keine Nachricht.“, Terminal mit
  Prompt, Status „Linux lädt“, Lade-Karte „Linux startet …“.
- **Korrektur:** Dateiname und Notiz sagen „Dark Mode“, das Bild ist tatsächlich
  dunkel – die Notiz ist also richtig, aber es existiert **keine** echte
  Light-Aufnahme (siehe 12).

## 12 — Hauptansicht (`12-hauptansicht-light.png`)

- **Zugang:** Hauptansicht der Episode 0, vermeintlich in hellem Erscheinungsbild.
- **Inhalt:** identisch aufgebaut wie 11 – Pager „Noch keine Nachricht.“,
  Terminal mit Prompt, Lade-Karte „Linux startet …“.
- **Korrektur:** **Das Bild ist dunkel, nicht hell.** Der Dateiname und die
  Aufnahme-Notiz („Hauptansicht im Light Mode“) widersprechen dem Bildinhalt.
  Eine echte Light-Aufnahme der Web-Fassung liegt **nicht** vor. Die native App
  liefert helle und dunkle Screens separat (siehe
  `docs/verification/M1-REPORT.md`).

---

## Korrekturen an den Aufnahme-Notizen

| Datei | Notiz im Capture-Report | Befund im Bild |
|---|---|---|
| `08-episode-1.png` | „Episodenübersicht Episode 1“ | Ladezustand „Linux wird geladen … 50 %“, keine Übersicht |
| `09-episode-2.png` | „Episodenübersicht Episode 2“ | Ladezustand, keine Übersicht |
| `10-episode-3.png` | „Episodenübersicht Episode 3“ | Ladezustand, keine Übersicht |
| `12-hauptansicht-light.png` | „Hauptansicht im Light Mode“ | Bild ist dunkel; keine helle Aufnahme vorhanden |

Die Notizen wurden nicht angepasst – `_capture-report.json` bleibt unverändert,
die Korrektur steht hier.

---

## Navigation-Map (Web-Fassung)

```
Projektseite ──▶ Episode (Dropdown: 0 Probelauf, 1 Zu viele Rechte,
                             2 Der Prozess, der nicht stirbt,
                             3 Die Lücke im Log)
      │
      ├── Pager (Auftrag, Ton an, Verlaut)
      ├── Terminal ──────────────┐
      ├── Bildschirm (nur Ep. 2) ├── Ansichten
      ├── Serverraum ────────────┘
      ├── Fallakte (Panel: Einsatzrahmen, Spuren AKTE/INHALT)
      └── Vorwurf (Modal: Verdächtige + Belege)
```

Top-Leiste: Episoden-Dropdown, „Fortschritt löschen“, „Spiel verlassen“.
Fußzeile: Status, „Spuren x/2“, „Belege n“, „Vorwurf erheben“.

## Command-Map (Web-Fassung)

| Element | Wirkung |
|---|---|
| Episoden-Dropdown | Episode wechseln |
| Tab-Reiter Terminal / Bildschirm / Serverraum | Ansicht wechseln |
| „Fallakte“ / „Schließen“ | Fallakten-Panel öffnen/schließen |
| Spuren AKTE / INHALT | Spur im Panel markieren |
| „AKTUALISIEREN“ | Aktenwand neu einlesen |
| „Neu starten“ | laufende Episode neu starten |
| „Ton an“ / „Verlaut“ | Pager-Ausgabe |
| Verdächtigen-Radio, Belege-Auswahl, „Absenden“ | Vorwurf erheben |
| „Fortschritt löschen“ → „ENDGÜLTIG LÖSCHEN“ | Fortschritt zurücksetzen |
| „Spiel verlassen“ | Web-Fassung beenden |

Die eigentlichen Shell-Befehle (`ls -l`, `grep`, `cp` …) laufen in der
Web-Fassung im echten Alpine-Terminal; in der nativen M1-Version ersetzt das
Übungsterminal diese Eingabe.

## Datenmodell (aus der Oberfläche abgeleitet, nicht aus dem Quellcode verifiziert)

```
Episode (id, titel, server, fortschritt)
 └─ Spuren[]            AKTE, INHALT  (je "x von 2 Schritten erledigt")
     └─ Schritte[]      je Schritt: Titel, Detail, Befehl, Erledigt-Status
 └─ Verdächtige[]       Name, Rolle, Detail
 └─ Belege[]            anerkannte Belege (Anzahl in der Fußzeile)
 └─ Terminalzustand     Verlauf, Arbeitsverzeichnis
 └─ Fortschritt         0..n Spuren, Regler in der Titelzeile
```

---

## Coverage

| Screen | Status |
|---|---|
| Projektseite | captured |
| Einsatzrahmen im Pager | captured |
| Terminal (Prompt, Login-Zeile) | captured |
| Fallakte / Aktenwand-Panel | captured |
| Serverraum-Ansicht inkl. Aktenwand-Leerzustand | captured |
| Vorwurf-Modal im leeren Zustand | captured |
| Bestätigungsdialog „Fortschritt löschen“ | captured |
| Episode 1 / 2 / 3 | captured (nur Ladezustand, keine Übersicht) |
| Hauptansicht hell | **blocked** – Aufnahme ist dunkel, echte Light-Aufnahme fehlt |
| Hauptansicht mit anerkannten Belegen | **not applicable** – die Web-Fassung wurde im Wegwerf-Zustand ohne gespielten Beleg aufgenommen |
| Vorwurf-Modal mit ausgewählten Belegen / Erfolg | **not applicable** – siehe oben |
| Bildschirm-Reiter (Episode 2) | captured (nur als Reiter sichtbar) |
| Hilfe-/Werkzeugseite | **not applicable** – in der Web-Fassung nicht vorhanden, native M1-Version hat eine eigene Seite |
