# Staffel 2 – Figuren, Raum und Stimme

> Status umgesetzt und im nativen Fenster geprüft

## Umsetzung

Der Einsatzrahmen von Episode 0 erhält eine interaktive Szene mit dem Originalserverraum, Alex in mehreren Originalposen und einer perspektivischen Verschiebung zwischen Vorder- und Hintergrund. Drei Aktionen starten die Begrüßung, geben den Archivhinweis wieder oder wechseln zum Terminal. Die Originalgrafiken aus den Terminal-Missionen sind als Bildmaterial im Einsatzrahmen erreichbar.

Die Sprachclips werden mit Fish Audio Drama 3 erzeugt, zusammen mit ihrem deutschen Text ausgeliefert und lokal über AVFoundation abgespielt. Das Ziel ist ein eigenständig startbares Bundle mit Prüfung von Navigation, Clip-Inhalten, reduzierter Bewegung und Layout.

Die Figur bleibt grafisch beim Original. Die Tiefe entsteht durch getrennte Ebenen, perspektivische Drehung und einen Bodenschatten. Die Körperbewegung verwendet den Audiopegel und der Dialog zeigt zur jeweiligen Tonspur die passende Porträtpose. Für einen texturierten GLB-Export hat Higgsfield über Meshy 30 Credits veranschlagt. Das App-Bundle verwendet die native 2,5D-Szene.

## Prüfung

Der Release-Build ist ad hoc signiert. `tools/test.sh` meldet 45 bestandene Core-Tests, `tools/grid-lint.sh` meldet PASS und `check-layout.swift` bestätigt die Matrix mit zehn Layouts. Im nativen Fenster wurden beide Wiedergabezustände, das Grafiken-Popover und der Wechsel ins Terminal geprüft. Der Pfad für reduzierte Bewegung ist implementiert. Die Bedienprüfung lief mit der Standard-Bewegungseinstellung.

## Belege

| Befund | Quelle | Prüfung |
|---|---|---|
| `linux-mac` besitzt das native Briefing und die Navigation | `Sources/StaffelZwei/ContentView.swift`, `struct BriefingView: View` | CRG und Quelldatei |
| Die Web-Fassung verwendet das Originalmotiv des Serverraums | `src/pages/projekte/terminal-missionen/app/staffel-2.astro:34`, `src="/missions/hintergrund/serverraum.webp"` in `alexle135.de` | CRG und Quelldatei |
| Alex liegt mit transparenten Originalposen in `public/missions/figur` | `git ls-files public/missions`, `sips -g hasAlpha` | Originaldateien |
| Das Buildskript füllt die Bundle-Ressourcen vor der Signatur | `build.sh:70`, `cp "$here/Resources/StaffelZwei-Trailer.mp4" "$app/Contents/Resources/"` | CRG und Quelldatei |
