# Staffel 2 auf dem Mac – Episoden 1 bis 3

> Im macOS-Build umgesetzt

## Belege

| Befund | Quelle | Prüfung |
|---|---|---|
| Episoden 1–3 laden die Browser-Missionen und speichern Linux-Belege pro Episode. | `Sources/StaffelCore/Resources/Missions.json` | Kampagnentest mit 35 Prüfungen einschließlich erneutem Öffnen der Episoden. |
| Episode 2 öffnet den Alpine-Desktop der laufenden VM. | `Sources/StaffelZwei/LinuxDesktopView.swift` | XTerm und PCManFM im App-Fenster geprüft. |
| Alex begleitet die Episoden mit Offline-Dialogen und einem interaktiven 3D-Serverraum. | `Sources/StaffelZwei/Einsatzszene.swift`, `Sources/StaffelZwei/OstwindRoomView.swift` | Perspektivwechsel im 3D-Serverraum im App-Fenster geprüft. |
| Micha schläft in der Startszene im Bürostuhl. Seine Assistenz lässt sich wecken und gibt gesprochene Hinweise. | `Resources/Einsatzszene/micha-buerostuhl.png`, `Sources/StaffelZwei/Einsatzszene.swift` | Schlafzustand, Wecken und Episodenhinweis mit deutscher Standardstimme geprüft. |
