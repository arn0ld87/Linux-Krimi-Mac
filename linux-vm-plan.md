# Lokale Linux-VM für Episode 0

> Status umgesetzt und auf Apple M3 geprüft

## Schritte

1. Alpine ARM64 reproduzierbar aus den offiziellen Archiven bauen. Boot über Apples Virtualization.framework mit eigener serieller Schnittstelle und beschreibbarem ext4-Abbild im isolierten Spielstand.
2. Das SwiftUI-Terminal mit der seriellen Schnittstelle verbinden. Linux-Befehle laufen mit dem Konto `azubi`. Die App übernimmt Belegdateien und den Reparaturzustand aus dem Gast, nutzt die vorhandene Vorwurfsprüfung und übernimmt bestehende Episode-0-Dateien beim ersten Start.
3. Signiertes Bundle auf dem M3 starten. Linux-Kernel, Belege, Vorwurf, erneutes Öffnen desselben Spielstands und frische VM nach einem Reset prüfen.

## Abnahme

- Der native Selbsttest bestätigte den Alpine-Boot, `Linux aarch64`, gültige Belege, die reparierte Kasse und den angenommenen Vorwurf (36 Prüfungen).
- Nach einem Neustart las die App die reparierte CSV und beide Belegdateien aus der wieder geöffneten Linux-Festplatte. `id -un` meldete `azubi`.
- Der Reset im isolierten Testspielstand legte Sicherungen für JSON und Festplatte an. Der nächste Boot zeigte wieder den veränderten Betrag `0.50`, und der Belegordner war leer.
- 45 Core-Tests, Grid-Lint, die zehn Layouts der Hell-/Dunkel-Matrix und die strikte Codesign-Prüfung bestanden.

Das native Terminal ist zeilenorientiert. Das Home-Verzeichnis und die Übungsdateien liegen auf dem Gast-Abbild. Beim ersten Start mit einem älteren Swift-Spielstand übernimmt die App die Kassenliste und bekannte Belegdateien.

## Belege

| Befund | Quelle | Prüfung |
|---|---|---|
| Das Browserterminal startet einen Linux-Gast in v86 | `src/components/missions/V86Terminal.tsx:82–114` in `alexle135.de` | CRG und Quelltext |
| Die Swift-App führt Terminalzeilen über GameEngine aus | `Sources/StaffelZwei/AppModel.swift:77`, `engine.run(input)` | CRG und Quelltext |
| Die Spiellogik bewertet Belege aus den bekannten Dateipfaden und vergleicht die reparierte CSV mit dem Original | `Sources/StaffelCore/GameEngine.swift:95–114,137–140` | CRG und Quelltext |
| Auf diesem Mac läuft Apple M3, ARM64 | `sysctl -n machdep.cpu.brand_string`, `uname -m` | Lokales System |
