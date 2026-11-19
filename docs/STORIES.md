# User Stories – M1 (Staffel Zwei)

Abnahme-Kategorien:

- `[unit]` – automatisierter Test in `Tests/StaffelCoreTests` (Swift Testing)
- `[self]` – im App belegbare Selbstprüfung (sichtbarer Zustand in der App)
- `[snap]` – Screenshot in `docs/verification/` (echte App, echte Interaktion)
- `[manual]` – noch nicht geprüft, bleibt offen

Referenz-Screens der Web-Fassung: `docs/screens/INDEX.md`. Die PNGs dort sind
Wegwerf-Aufnahmen der öffentlichen Seite; die native App hat eigene Screens in
`docs/verification/`.

**Status** ist nur `erfüllt`, wenn die Story nachweislich geprüft ist.
Nachweise stehen in `docs/verification/M1-REPORT.md`.

---

## M1-1 · Einsatzrahmen lesen

**Als** Auszubildender **möchte ich** den Auftrag und die Grundregel des Falls
lesen **damit** ich weiß, wonach ich ermittle.

**Screens:** `docs/screens/02-einsatzrahmen-pager.png` (Pager der Web-Fassung),
`docs/screens/04-aktenwand.png` (Aktentext der Web-Fassung).
Native Entsprechung: Seite *Einsatzrahmen* (`docs/verification/01-einsatzrahmen.png`).

**Akzeptanz**

- [unit] Der Briefing-Text nennt Organisation „Rechenwerk Ostwind GmbH“, Konto `azubi`, die Ordner `/srv/rechenwerk/uebung/` und `~/belege/` sowie die Regel „erst Belege sichern, dann reparieren“.
- [unit] Die App nennt den Fall `Fall 0 · Probelauf` und den Beweisstück-Code `S2-E0-KASSE`.
- [self] Der Einsatzrahmen ist über die Sidebar („Einsatzrahmen“) und Cmd-1 erreichbar.
- [snap] `docs/verification/01-einsatzrahmen.png` zeigt den vollständigen Auftrag ohne abgeschnittenen Text.
- [manual] Screenreader liest den Auftrag vor.

**UX**

- *Flow:* App startet → Sidebar wählt „Einsatzrahmen“ → Auftrag lesen → „Terminal“ wählen.
- *Surface:* Detailbereich der NavigationSplitView, ScrollView.
- *States:* Normalfall, Erfolgsfall („Probelauf bestanden. Jetzt wird es ernst.“), Fehlerfall bei defektem Spielstand (Banner statt Absturz).
- *Wörter:* „Einsatzrahmen“, „Auftrag“, „Grundregel“, „Beleg“. Kein „Level“, kein „Punkte“.
- *Access:* Überschrift als `heading`, Absätze als `statictext`, Absatzlänge durch ScrollView sichergestellt.

**Status:** erfüllt (Nachweis: `M1-REPORT.md`, Abschnitt „Implementiert und geprüft“)

---

## M1-2 · Befehle im Übungsterminal ausführen

**Als** Auszubildender **möchte ich** im Terminal Verzeichnisse und Dateien
untersuchen **damit** ich den Zustand der Kaffeekasse erfasse.

**Screens:** `docs/screens/03-terminal.png`.
Native Entsprechung: `docs/verification/02-terminal.png`, `docs/verification/03-terminal-probelauf.png`.

**Akzeptanz**

- [unit] `pwd`, `cd`, `ls`, `ls -l`, `stat`, `cat`, `grep`, `cp`, `mkdir -p`, `help`, `clear` werden unterstützt; unbekannte Befehfe und Pipes/`;`/`&&`/`$(`/Backtick werden mit klartext abgelehnt.
- [unit] `ls -l /srv/rechenwerk/uebung/` zeigt Besitzer `kaffee`/`root`, Rechte `0664`/`0644` und die Änderungszeiten `2026-04-17 03:12` / `2026-04-16 22:05`.
- [unit] `stat` zeigt die Rechte vierstellig (`0664`) wie GNU-stat.
- [unit] Mac-Pfade (`/etc/passwd`, `/Users/…`, `~/Library/…`) existieren in der Simulation nicht.
- [unit] Ein fehlgeschlagener Befehl verändert weder Dateiwelt noch Arbeitsverzeichnis (transaktional).
- [self] Die Promptzeile zeigt das aktuelle Arbeitsverzeichnis (`/home/azubi`), die Simulation ist dauerhaft sichtbar.
- [snap] `docs/verification/03-terminal-probelauf.png` zeigt vier ausgeführte Befehle im Verlauf.
- [manual] Tastaturbedienung: Befehl eintippen, Return, Verlauf bleibt erhalten.

**UX**

- *Flow:* Terminal wählen → Befehl eintippen → Return → Ausgabe lesen.
- *Surface:* Detailbereich, Verlauf oben, Eingabeleinzeile unten mit Prompt.
- *States:* leere Eingabe, gültige Ausgabe, Fehlermeldung, Simulationshinweis als erste Zeile.
- *Wörter:* „Übungssimulation“, „Befehl eingeben“, Fehler im Klartext („No such file or directory“).
- *Access:* Eingabefeld `textfield` mit Namen „Terminal-Eingabe“, Verlauf als `statictext`.

**Status:** erfüllt

---

## M1-3 · Metadaten als Beleg sichern

**Als** Auszubildender **möchte ich** die Metadaten der Kaffeekasse in einer
Datei sichern **damit** der Besitzer `kaffee` beweissicher feststeht.

**Screens:** `docs/screens/04-aktenwand.png`.
Native Entsprechung: `docs/verification/04-aktenwand.png`.

**Akzeptanz**

- [unit] `ls -l /srv/rechenwerk/uebung/ > ~/belege/kasse-meta.txt` erzeugt die Datei und der Beleg `kasse-meta` wird anerkannt.
- [unit] Der Beleg gilt nur bei echtem Inhalt: derselbe Dateiname mit anderer Ausgabe bleibt ungültig.
- [unit] Geschrieben werden darf nur unter `~/belege/`; `/tmp`, `/etc` und die Sicherung `.bak` bleiben geschützt.
- [self] Die Spur „Akte“ zählt erst nach der Umleitung als erledigt.
- [snap] `docs/verification/04-aktenwand.png` zeigt den anerkannten Beleg mit echtem Inhalt.
- [manual] —

**UX**

- *Flow:* Terminal → Befehl mit `>` → Aktenwand öffnen → Beleg prüfen.
- *Surface:* Aktenwand-Seite, Belegkarten mit Name, Spur, Status, Inhalt.
- *States:* keine Belege, Beleg vorhanden aber nicht anerkannt, Beleg anerkannt (grün), Beleg ausgewählt.
- *Wörter:* „Beleg“, „anerkannt“, „gesichert“. Nicht „Beweisstück gesammelt“.
- *Access:* Belegkarten als Button mit `accessibilityLabel` („…, anerkannt“ / „…, noch nicht anerkannt“).

**Status:** erfüllt

---

## M1-4 · Zeilen sichern und die Liste reparieren

**Als** Auszubildender **möchte ich** die geänderte Zeile und ihr Original
sichern und danach die Liste aus der Sicherung wiederherstellen **damit**
der Schaden behoben ist, ohne den Beweis zu verlieren.

**Screens:** `docs/screens/04-aktenwand.png`.
Native Entsprechung: `docs/verification/04-aktenwand.png`, `docs/verification/05-terminal-repariert.png`.

**Akzeptanz**

- [unit] `grep 2026-04-15 …kaffeekasse.csv > ~/belege/kasse-zeilen.txt` liefert einen noch nicht anerkannten Beleg.
- [unit] Erst das Anhängen der Zeile aus der `.bak` per `>>` macht den Beleg gültig.
- [unit] `cp …kaffeekasse.bak …kaffeekasse.csv` repariert die Liste, behält Besitzer `kaffee`, Gruppe `azubi` und Rechte `0664` der CSV und lässt die Sicherung unverändert.
- [unit] Die Reparatur allein erzeugt keine Belege.
- [unit] Bereits gesicherte Belege bleiben nach der Reparatur gültig.
- [self] Die Statuszeile meldet „Kasse wiederhergestellt“.
- [snap] `docs/verification/05-terminal-repariert.png` zeigt den reparierten Zustand.
- [manual] —

**UX**

- *Flow:* Spur „Inhalt“ abarbeiten → reparieren → Beleg bleibt gültig → Vorwurf.
- *Surface:* Terminal und Aktenwand.
- *States:* Zeile gesichert / Original fehlt / beides vorhanden / repariert.
- *Wörter:* „wiederhergestellt“, „Sicherung“, „Beleg bleibt gültig“.
- *Access:* Statuszeile als Text, nicht nur als Farbe.

**Status:** erfüllt

---

## M1-5 · Belege auf der Aktenwand prüfen

**Als** Auszubildender **möchte ich** meine gesicherten Belege an einem Ort
sehen **damit** ich weiß, was ich vor dem Vorwurf vorlegen kann.

**Screens:** `docs/screens/05-serverraum.png` (Aktenwand-Ansicht der Web-Fassung).
Native Entsprechung: `docs/verification/04-aktenwand.png`.

**Akzeptanz**

- [unit] `refreshEvidences` bewertet die Belege nach jedem Befehl neu; die Auswahl wird auf noch vorhandene Belege beschränkt.
- [unit] Die Fortschrittsanzeige nennt abgeschlossene Spuren und anerkannte Belege, ohne erfundene Kennzahlen.
- [self] Die Aktenwand zeigt den echten Inhalt der gesicherten Dateien.
- [snap] `docs/verification/04-aktenwand.png` zeigt beide Belege.
- [manual] —

**UX**

- *Flow:* Sidebar „Aktenwand“ → Belege durchsehen → ggf. zurück ins Terminal.
- *Surface:* Detailbereich mit vertikalem Stapel der Belegkarten.
- *States:* leer, ein Beleg, beide Belege anerkannt.
- *Wörter:* „Aktenwand“, „Beleg“, „anerkannt“.
- *Access:* Karten als Buttons, Auswahlzustand über `isSelected`.

**Status:** erfüllt

---

## M1-6 · Vorwurf mit Verdächtigem und Belegauswahl erheben

**Als** Auszubildender **möchte ich** einen Verdächtigen auswählen, die
Belege markieren und den Vorwurf prüfen **damit** ich eine begründete
Entscheidung treffe.

**Screens:** `docs/screens/06-vorwurf-leer.png`.
Native Entsprechung: `docs/verification/06-vorwurf-leer.png`, `docs/verification/07-vorwurf-gefuellt.png`.

**Akzeptanz**

- [unit] Ohne Verdächtigen: „Wähle zuerst einen Verdächtigen.“
- [unit] Mit zu wenigen Belegen oder Belegen aus nur einer Spur: konkrete Hilfe, welche Spur fehlt.
- [unit] Vor der Reparatur: Hinweis, dass die Kaffeekasse zuerst wiederhergestellt werden muss.
- [unit] Falscher Verdächtiger: Inline-Erklärung, keine Sperre, der Vorwurf bleibt erneut möglich.
- [unit] Nur ausgewählte **und** anerkannte Belege zählen; Reparatur allein genügt nicht.
- [self] Der Erfolgsfall meldet „Probelauf bestanden. Jetzt wird es ernst.“ und schaltet auf den Einsatzrahmen.
- [snap] `docs/verification/06-vorwurf-leer.png` (leer), `07-vorwurf-gefuellt.png` (Auswahl), `08-vorwurf-erfolg.png` (Erfolg).
- [manual] —

**UX**

- *Flow:* Vorwurf wählen → Verdächtigen wählen → Belege markieren → Cmd-Return → Rückmeldung lesen.
- *Surface:* eigene Seite im Detailbereich, kein Modal (die Seite bleibt erreichbar).
- *States:* kein Verdächtiger, unvollständige Belege, falscher Täter, Erfolg.
- *Wörter:* „Vorwurf erheben“, „Verdächtige“, „Belege“, „anerkannt“. Kein „Game over“.
- *Access:* Verdächtige als Radiobuttons, Belege als Checkboxen, Feedback als Text.

**Status:** erfüllt

---

## M1-7 · Erfolg und Übergang zum Nachspiel

**Als** Auszubildender **möchte ich** nach dem gelösten Fall eine klare
Abschlussmeldung und einen Ausblick sehen **damit** ich weiß, dass der
Probelauf bestanden ist.

**Screens:** `docs/screens/08-episode-1.png` (Episodenwechsel in der Web-Fassung).
Native Entsprechung: `docs/verification/08-vorwurf-erfolg.png`.

**Akzeptanz**

- [unit] Erfolgsnachricht: „Probelauf bestanden. Jetzt wird es ernst.“, Erfolgszustand wird gesetzt.
- [self] Der Einsatzrahmen zeigt den Erfolg und den Ausblick auf den nächtlichen Kassenabgleich.
- [snap] `docs/verification/08-vorwurf-erfolg.png` zeigt die Erfolgsmeldung.
- [manual] —

**UX**

- *Flow:* Vorwurf angenommen → automatische Rückkehr zum Einsatzrahmen → Erfolgsblock lesen.
- *Surface:* Einsatzrahmen-Seite, Erfolgsblock mit Beweisstück-Code.
- *States:* Erfolg, Nicht-Erfolg.
- *Wörter:* „Probelauf bestanden“, „Beweisstück“, „S2-E0-KASSE“.
- *Access:* Erfolgsblock als Text mit `heading` für „Beweisstück“.

**Status:** erfüllt

---

## M1-8 · Neustart mit erhaltenem Zustand

**Als** Auszubildender **möchte ich** die App schließen und wieder öffnen,
ohne meinen Fortschritt zu verlieren **damit** ich in Ruhe weiterarbeiten kann.

**Screens:** keine Web-Entsprechung – die Web-Fassung speichert nur gelöste Episoden.
Native Entsprechung: `docs/verification/09-einstellungen.png` (Pfad des Spielstands).

**Akzeptanz**

- [unit] JSON-Roundtrip erhält Dateiwelt, Arbeitsverzeichnis, Verlauf, Belege, Auswahl, Reparatur, Erfolg und gewählte Seite.
- [unit] Ein Neustart setzt nichts zurück.
- [unit] Ein defekter Spielstand bleibt unangetastet, bis der Nutzer das Zurücksetzen bestätigt; ein Speichern scheitert dann sichtbar.
- [unit] Ein bestätigtes Zurücksetzen legt ein Backup an, löscht nur die eigenen Daten und lässt fremde Dateien im Ordner unberührt.
- [unit] Tests schreiben ausschließlich in ihr eigenes temporäres Verzeichnis (niemals in echte Nutzerdaten).
- [self] Der Pfad des Spielstands ist in den Einstellungen sichtbar.
- [snap] `docs/verification/09-einstellungen.png` zeigt die Einstellungen inkl. Spielstandpfad und Zurücksetzen-Dialog.
- [manual] App beenden und neu starten, Zustand prüfen (nicht automatisiert ausgeführt).

**UX**

- *Flow:* Einstellungen (Cmd-,) → „Fortschritt zurücksetzen…“ → Bestätigungsdialog → Bestätigen oder Abbrechen.
- *Surface:* native Settings-Szene, Tab „Allgemein“, Formulargruppen „Darstellung“, „Übungsterminal“, „Tastatur“, „Spielstand“.
- *States:* normal, defekter Spielstand (Warnung), Rücksetzen-Bestätigung offen.
- *Wörter:* „Fortschritt zurücksetzen“, „Abbrechen“, „Zurücksetzen“. Der Dialog nennt ausdrücklich, dass nur eigene Daten betroffen sind und ein Backup bleibt.
- *Access:* Formularfelder mit Label, Dialog-Buttons mit `role: .destructive` bzw. `.cancel`.

**Status:** erfüllt (der manuelle Neustart-Check bleibt offen)

---

## Spätere Milestones (nicht in M1)

| Story | Warum später |
|---|---|
| Echtes Linux in einer VM statt Simulation | braucht VM-Image, Startzeit und echte Rechte; M1 liefert bewusst die dateibasierte Simulation |
| Episode 1 „Zu viele Rechte“ | Daten, Spuren und Belege sind aus der Quelle übernommen, aber nicht umgesetzt |
| Episode 2 „Der Prozess, der nicht stirbt“ | dito; zusätzlich eigener Bildschirm-Reiter in der Web-Fassung |
| Episode 3 „Die Lücke im Log“ | dito |
| Pager mit Tonausgabe und „Verlaut“ | Web-Fassung, in der nativen App nicht nachgebaut |
| Notizen und Merkliste je Fall | in der Web-Fassung nicht vorhanden |
| Bildschirm-Reiter (Live-Ansicht der VM) | nur in Episode 2 der Web-Fassung |

## Bewusst nicht umgesetzt

- **Kein WebView / Electron / HTML-Einbettung** – die App ist reines SwiftUI.
- **Keine Netzwerkverbindung, kein Telemetrie, kein Konto.**
- **Keine Shell-Escape, Pipes oder Command-Substitution** – sie werden
  ausdrücklich als „in dieser Übung nicht unterstützt“ abgelehnt.
- **Kein Zugriff auf echte Mac-Dateien aus dem Terminal heraus.**
