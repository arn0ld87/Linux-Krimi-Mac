# Medienplan für Staffel 2 auf macOS

## Ziel

Alex führt als animierte Einsatzleitung durch den Probelauf „Die Kaffeekasse“. Er spricht das Briefing und meldet sich nach erfolgreichem Abschluss zurück. Priorität hat eine Figur mit glaubwürdiger Mimik, Gestik und lippensynchroner Sprache. Der vorhandene Trailer kann als Stilreferenz dienen. Eine neue Trailerproduktion ist nachrangig.

## Umfang des Piloten

| Ort in der App | Bild und Animation | Ton |
|---|---|---|
| Einsatzrahmen | Alex als Halbfigur. In Ruhe blinzelt er und atmet dezent. Beim Briefing blickt er zum Spieler und setzt eine Handgeste zur Betonung. Die Buchhaltung bei Nacht bleibt als optionaler Hintergrund vorgesehen. | „Einsatz anhören“ startet das Briefing mit Alexanders vorhandener Fish-Audio-Stimme. |
| Vorwurf | Drei gleich große Motive für Timo Kessler, Nadia Brem und den Kaffeeautomaten als Dienstkonto. Produktion nach Abnahme von Alex. | Kein Dialog im Piloten. |
| Erfolgsansicht | Alex kehrt für die Rückmeldung zurück. Ein kurzes Nicken und ein leichtes Lächeln begleiten den Abschluss. Die Textmeldung bleibt sichtbar. | „Abschluss anhören“ startet die Rückmeldung. |

Wenn die zusätzlichen Illustrationen produziert werden, stehen Namen, Rollen und Hinweise als App-Text daneben. Die Buchhaltung und die Kartenmotive folgen der mit Alex festgelegten Bildsprache.

## Arbeitspakete

1. **Alex gestalten.** Über den Higgsfield-MCP mit Nano Banana Pro ein Figurenbild als stilisierte 2D-Halbfigur erstellen. Gesicht, Kleidung und Silhouette sollen auch klein erkennbar bleiben. Das freigegebene Figurenbild als Referenz für die Sprechszenen verwenden.
2. **Eine kurze Sprechszene bauen.** Über den Higgsfield-MCP in Intone das freigegebene Figurenbild und etwa 6–9 Sekunden aus der Fish-Audio-Hörprobe als Eingaben verwenden. Intone ergänzt rund 2,5 Sekunden. Ein fester Bildausschnitt, ein natürlicher Blick und eine kleine Handgeste genügen für die Probe. In der vorgesehenen App-Größe prüfen, ob die Mundbewegungen der Tonspur folgen und die Lippen bei Pausen und Lauten wie M, B und P schließen.
3. **Zwei Szenen ausarbeiten.** Nach Abnahme der Probe Briefing und Abschluss mit derselben Bildreferenz und der vorhandenen Fish-Audio-Stimme produzieren. Intone liefert fertige Videoclips mit Ton. Bewertet werden Figurenkonsistenz, Lippensynchronität und die Übergänge zur Ruheanimation. Für separat steuerbare Mimik und Gestik wäre ein eigenes bearbeitbares Rig nötig.
4. **In die App integrieren.** Eine kurze stumme Ruheanimation, ihr Standbild und die beiden Sprechszenen lokal ins App-Bundle aufnehmen. Erst nach der Abnahme von Alex die Buchhaltungsillustration und die drei Kartenmotive produzieren.

## Stimme und Hörprobe

Alexander hat den privaten Stimmklon bereits erstellt. Für neue Takes dient `8d6a38b914f54501bd8189402ef466b4` als Fish-Audio-`reference_id`. Die fertigen Sprachaufnahmen werden lokal mit den Szenen ausgeliefert. Die ursprüngliche Sprachaufnahme bleibt privat.

**Text für die erste generierte Hörprobe**

> Willkommen bei Rechenwerk Ostwind. In der Kaffeekasse stimmt ein Betrag nicht. Sieh dir die Liste und ihre Sicherung an. Sichere beide Spuren, bevor du etwas änderst.

Bei der Hörprobe auf Wiedererkennbarkeit, natürliche Pausen und die Aussprache von „Rechenwerk Ostwind“ achten.

## Einbau und Abnahme

- Den Einsatzrahmen und die Erfolgsansicht als Einbaupunkte verwenden. Die Szenen über `build.sh` ins App-Bundle aufnehmen. [Einsatzrahmen](../../Sources/StaffelZwei/ContentView.swift#L104)
- Alex bleibt zwischen Ruhe, Briefing und Rückmeldung als dieselbe Figur erkennbar. In App-Größe sind die Lippenbewegungen, die Blickrichtung und die Geste erkennbar. Bewegungen beginnen und enden flüssig. In Sprechpausen kommt der Mund zur Ruhe.
- Die Sprechszenen starten auf Klick und lassen sich per Tastatur steuern. Pause hält Stimme und Bewegung gemeinsam an. Bei Seitenwechsel oder Start des vorhandenen Trailers endet die Wiedergabe. Mit aktivierter Einstellung „Bewegung reduzieren“ steht eine statische Pose mit Ton zur Verfügung. Text und Spielablauf bleiben auch bei fehlenden Medien bedienbar.
- Figur und Steuerung im hellen und dunklen Erscheinungsbild prüfen. Bei späterer Produktion der drei Karten darauf achten, dass alle Motive gleich prominent sind und die Lösung offenbleibt.
- Signierte App mit isoliertem Spielstand und ohne Netzwerk testen. Einen fehlenden Medienpfad mitprüfen und die bestehenden Core- und Layout-Prüfungen laufen lassen.

## Nächster gemeinsamer Schritt

Die kurze animierte Sprechprobe ist die erste Vorlage zur Abnahme. An ihr werden Aussehen, Wiedererkennbarkeit, Lippensynchronität und Gestik beurteilt, bevor die vollständigen Szenen entstehen.
