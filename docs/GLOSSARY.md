# Glossar – Staffel Zwei

Einheitliche Begriffe für die native Mac-App. Wo die Web-Fassung andere Wörter
verwendet, steht der Bezug in Klammern.

| Begriff | Bedeutung |
|---|---|
| **Episode** | Ein abgeschlossener Fallabschnitt mit eigenem Titel, Verdächtigen und Spuren. In M1 ist nur Episode 0 („Probelauf“) spielbar; Episode 1–3 sind sichtbar, aber gesperrt („Später verfügbar“). |
| **Fall** | Die Gesamtheit aus Episode, Spuren, Belege und Vorwurf. In der Sidebar trägt die Kopfzeile den Fall (`Fall 0 · Probelauf`). |
| **Probelauf** | Episode 0 – die Einstiegsübung an der Kaffeekasse der Rechenwerk Ostwind GmbH. |
| **Einsatzrahmen** | Der Briefing-Text, der den Auftrag erklärt: Organisation, Konto, Ordner, Grundregel („erst Belege sichern, dann reparieren“). Entspricht dem Pager der Web-Fassung. |
| **Übungsterminal** | Die Befehlseingabe der nativen App. Eine dateibasierte Simulation: es läuft **kein** Prozess auf dem Mac, es gibt keine Linux-VM und kein Netzwerk. |
| **Befehl** | Eine eingegebene Zeile, z. B. `ls -l /srv/rechenwerk/uebung/`. Unterstützt sind `pwd`, `cd`, `ls`, `ls -l`, `stat`, `cat`, `grep`, `cp`, `mkdir -p`, `help`, `clear` sowie `>` und `>>`. |
| **Umleitung** | `befehl > datei` ersetzt den Dateiinhalt, `befehl >> datei` hängt an. Umleitungsziel ist der Belege-Ordner `~/belege/`. |
| **Spur** | Eine Ermittlungsrichtung mit eigenen Schritten. Episode 0 hat zwei Spuren: **Akte** (Metadaten) und **Inhalt** (Dateizeilen). |
| **Schritt** | Eine einzelne Aufgabe innerhalb einer Spur, meist mit einem Befehlsvorschlag. Schritte werden als erledigt markiert, wenn ihr Beleg anerkannt ist. |
| **Beleg** | Die **echte Ausgabe** eines ausgeführten Befehls, in eine Textdatei unter `~/belege/` umgeleitet. Abgetippter Text zählt nicht. Ein Beleg ist *anerkannt*, wenn sein Inhalt zur erwarteten Ausgabe passt. |
| **Belegauswahl** | Die vom Nutzer getroffene Auswahl anerkannter Belege. Nur ausgewählte Belege zählen für den Vorwurf. |
| **Aktenwand** | Die Seite mit den gesicherten Belegen: Dateiname, Spur, Anerkennungsstatus und Inhalt der echten Ausgabe. |
| **Verdächtiger** | Eine Person oder ein Dienstkonto, das als Täter in Frage kommt. Episode 0: Timo Kessler, Nadia Brem, Kaffeeautomat (Dienstkonto `kaffee`). |
| **Täter** | Der tatsächliche Verursacher. In Episode 0 ist es das Dienstkonto `kaffee` (Besitzer der `kaffeekasse.csv`). |
| **Vorwurf** | Die Seite, auf der Verdächtiger und Belege ausgewählt und der Vorwurf geprüft wird. Erwartet: der richtige Verdächtige, mindestens zwei anerkannte **und ausgewählte** Belege aus **beiden** Spuren sowie die reparierte Kaffeekasse. |
| **Beweisstück** | Das Erfolgsobjekt des Falls: **Die Kaffeekasse**, Code `S2-E0-KASSE`. |
| **Reparatur** | Das Zurückspielen der Sicherung `kaffeekasse.bak` über die `kaffeekasse.csv` per `cp`. Die Besitzer-Metadaten der CSV bleiben dabei unverändert. |
| **Sicherung** | Die Datei `kaffeekasse.bak` im Übungsordner. Besitzer `root`, Rechte `0644` – sie ist nie schreibbar. |
| **Spielstand** | Der persistierte Zustand: Dateiwelt, Arbeitsverzeichnis, Terminalverlauf, anerkannte Belege, Auswahl, Reparatur- und Erfolgszustand, gewählte Seite. Ablage als JSON unter `~/Library/Application Support/StaffelZwei/spielstand.json`, überschreibbar per Umgebungsvariable `APP_STORE`. |
| **Zurücksetzen** | Löschen des eigenen Fortschritts, ausschließlich nach ausdrücklicher Bestätigung. Vorher wird ein Backup des Spielstands im selben Ordner angelegt; fremde Dateien werden nicht angefasst. |
| **Defekter Spielstand** | Eine Spielstanddatei, die nicht gelesen werden kann. Sie bleibt unangetastet, bis der Nutzer das Zurücksetzen bestätigt. |
| **Simulation** | Der sichtbare Hinweis, dass die App Befehle nur in einer virtuellen Dateiwelt ausführt: „Lokale Übungssimulation – keine Befehle auf deinem Mac.“ |
