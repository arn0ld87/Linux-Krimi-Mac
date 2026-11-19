# M1 – gezielte Blockerreparatur vom 18.11.2026

## Auftrag / Rollen

Aktueller Nutzerauftrag: Blocker in `docs/verification/M1-INDEPENDENT-REVIEW.md` beheben (normaler Fensterstart, TestingMacros, falschgrüne Prüfskripte), danach unabhängig gegen `docs/specs/M1.md` prüfen. Bestehende M1- und Completion-Spec gelten weiter. Nur bestehende MiniMax-CLI im Runner-Subagenten implementiert. Keine neue App/Architektur, keine zusätzlichen Subagenten aus dem Worker, keine Commits/Pushes/externen Uploads/globalen Einstellungen. Separater Reviewer erst NACH Ende des einzigen Writers.

## Neue, bereits verifizierte Diagnose – NICHT erneut blind forschen

### Normaler Start ist im JETZT gebauten Bundle nachgewiesen

Die letzte Review-Iteration prüfte einen Start VOR ihrem letzten Build; ihr danach gebautes Bundle wurde nicht nochmal gestartet. Lead hat am 18.11.2026 genau das aktuelle `dist/StaffelZwei.app/Contents/MacOS/StaffelZwei` in neuem isoliertem `APP_STORE` gestartet. Nur APP_DEBUG=1, keine Snapshot/Grid/SelfTest-Flags. Nach 4 Sekunden:
- eigener PID84068, Fenster `w-5199`, 1240x820, visible=true, accessible=true, is_focused=true.
- Debug: willFinishLaunching policy0, didFinishLaunching windows0, nach2s windows0, **danach** onAppear und sichtbares Fenster.
- 2-Sekunden-Prozesssample zeigt normalen AppKit Eventloop, keinen Deadlock. Prozess danach vom Lead sauber terminiert, keine Fremdprozesse geändert.
- Diagnoseartefakte `.worker/m1-start-diagnosis-wjyp3veu/{start.log,stack.txt}`.
- Vorbestehender Worker-PID35029 mit eigenem Fenster ist NICHT Teil des neuen Tests. Unangetastet lassen; alle Automatisierung anhand EIGENEM PID/Fenster-ID, nicht 'erstes Fenster der App'.

**Folgerung:** Keine weiteren spekulativen ActivationPolicy-Reparaturen. Zuerst aktuellen normalen Start selber mit eigenem PID und maximal15s überprüfen, tatsächliches Fenster per agent-desktop/CoreGraphics und Screenshot bestätigen. Danach denselben Start NACH finalem Rebuild prüfen. Ein einziges app-name-list Matching oder frühes Debug 'windows=0' beweist keinen Startfehler. APP_DEBUG entfernen für abschließenden normalen Start; APP_STORE isoliert lassen. Nur bei tatsächlicher Reproduktion gezielt korrigieren.

### TestingMacros Ursache / bekannter funktionierender Aufruf

Der unabhängige Reviewer ließ die bereits vorher nötige Plugin-Suchpfadoption weg. Erfolgreiche ältere Logs enthalten:
```
swift test --scratch-path "$HOME/Library/Developer/StaffelZwei/build" \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```
Das Pluginverzeichnis existiert, ebenso `swift-plugin-server`. Eine neue Testframework-Dependency, Installation von Xcode oder Umstellung auf XCTest ist NICHT erforderlich. Der normale macOS27SDK hat abweichende @State-Deklarationen, daher bisher26.5SDK. Baue einen kleinen portablen **dokumentierten Test-Entry-Point** (`test.sh` oder vorhandenes Tool), der die ausgewählte lokale Toolchain/SDK und Testing-Plugin korrekt findet, nur bei Bedarf Flags setzt, den Original-Exitcode bewahrt und Tests mit eigenem frischen APP_STORE ausführt. Pfadfindung aus aktiver Toolchain, keine Änderungen globaler Env/Settings. Optional explizite Overrides. Fehlendes SDK/Plugin => klare Diagnose/Exit!=0, nicht '0 Tests grün'. Kein manuelles Abändern grüner Assertions/Testentfernung. Die Standardbefehle in README/Report müssen den gleichen reproduzierbaren Test-Entry-Point nutzen; vorige45 grünen Tests bleiben Historie bis aktueller Lauf bestätigt.

## Minimale Reparaturen mit Negativtests

1. `Sources/StaffelZwei/SelfTest.swift` und `StaffelZweiApp.swift`: Exitcode vor vollständigem Erfolg **ungleich0**. Ausnahme/Window fehlt/Timeout/Abbruch bleibt FAIL. Nur nach allen Prüfungen darf genau eine finale PASS-Zeile geschrieben und Exit0 gesetzt werden. `applicationWillTerminate` darf unvollständigen Test nicht grün machen. Begrenzter Watchdog/Runner mit realem Timeout, kein >180s unsichtbares Hängen. Ergebnisdatei optional, aber mit abgeschlossenem Status und Anzahl. Selbsttest muss dieselben echten Actions/Textfeld/Buttons ausführen; keine Erfolgflags oder Belege direkt setzen.
2. `Sources/StaffelZwei/Snapshot.swift`: keine pauschale done-Meldung/Exit0 nach einzelnen fehlgeschlagenen Captures. Alle angeforderten Seiten/Appearance-Paare müssen echte nichtleere PNGs UND Layoutdaten liefern; Fehler/fehlendes Fenster/Writefehler/fehlende Settings => begründetes FAIL, Exit!=0. Keine Seed-Erfolgflags zum Core-Loop-Beweis; Snapshotansichten dürfen zu Layoutzwecken Zustand zeigen, als solche kennzeichnen.
3. `tools/check-layout.swift`: kein PASS bei0 Dateien,0 Probes, fehlenden/unlesbaren/malformed JSONs, fehlender oder ungültiger Area, nichtendlichen Werten. Validiert tatsächliche positive Geometrie und referenzierte Areas, nicht nur Summen. Negative CLI-Regressionen mit temporären Fixtures: keine Argumente,[],leere Probes, kaputtes JSON, nicht existierende Datei, echte Verletzung => Exit!=0; ein tatsächlich gültiges Fixture => Exit0. Vollständigkeitsanforderung gegen echte Screenmatrix separat, damit ein Mini-Fragment keinen vollständigen M1-Layoutnachweis vortäuscht. Keine Erwartungen abschwächen, um echte Layoutfehler zu verbergen. `tools/grid-lint.sh` ausführbar setzen und Exitcode korrekt bewahren.
4. Test-/GUI-Runner dürfen fehlende finale PASS-Marker, zero tests oder fehlende Artefakte NICHT über Exit0 alleine akzeptieren. Schreibe fokussierte Regressionstests der negativen Pfade. Keine Endlos-E2E-Suite als Voraussetzung für kleine Fixes, kein ungefragtes Refactoring.

## Abschlussnachweise und verbleibende M1-Matrix

- Erst read-only `GameStore`-Isolationsschutz prüfen (bekannt richtig: explicit directory > APP_STORE > Default). Jeden Lauf mit eigenem frischem Store, bestehende Nutzerdatei NICHT öffnen/ändern/resetten. Nur eigene erzeugte Prozesse beenden.
- Aktueller reproduzierbarer Core-Testlauf: echte Anzahl/Exitcode. Prüfskript-Negativtests: echte Anzahl/Exitcodes. Release-Build über sicheres vorhandenes build.sh, ad-hoc codesign strict. Keine --force und keine vorhandenen Bundle-Artefakte ungeprüft löschen.
- Normale frisch gebaute App ohne Prüf-/Debugflags, mit isoliertem APP_STORE: echtes fokussiertes eigenes Fenster screenshotten, Agent-desktop ref-loop. Installierte Anleitungen von agent-desktop und test-mac-app/build-and-verify/layout-grid gezielt nutzen. Lead hat Accessibility jetzt als verfügbar verifiziert, keine globale Berechtigungsänderung nötig.
- Wenn eigener UI-Selftest funktioniert, kompletten Probelauf tatsächlich durch Textfeld/Aktionen laufen lassen, eigene Transcript/Belege/Navigation/Erfolg im selben Store nach Prozessneustart prüfen; Window close/reopen und Settings prüfen, aktive Light/Dark-Paare aller5Seiten+Settings und reale Layoutprobes aufnehmen. Original-Spec-Lösung beibehalten. Log/PNG/JSON exakt zuordnen. Normale UI-Klicks nach Snapshot/Selftest separat zeigen. Kein Fake-Solved-JSON als interaktiver Nachweis.
- `docs/verification/M1-BLOCKERS-RESULT.md` schreiben: genaue kleine Änderungen, neue echte Befehle/Zahlen/Exits, Fehlertestmatrix, normale Startnachweise vor/nach Build, verbliebene M1-Nachweise. README und M1-REPORT aktualisieren, alte Reviewhistorie unangetastet. STORIES nur bei belegten Criteria done.
- Neue Workerlogs `.worker/minimax-m1-blockers.jsonl` und `.exit` (bestehende nicht überschreiben). Ziel20min, maximal35min; früh melden wenn ein Gate blockiert. Nicht stundenlang UI-Aktivierung jagen; nach maximal2 gezielten Ansätzen konkreten Blocker dokumentieren. Keine unabhängige Abnahme selbst behaupten.

## Präziser unabhängiger Review-Follow-up

Der erste Blocker-Worker ist beendet (Exit0). Unabhängig bestätigt: `tools/test.sh` führt45Tests aus/Exit0; echter Nulltrefferfilter Exit1; echte ungültige Swift-Option bleibt Exit64; Layout-Selftest10/10 und statisches Grid Exit0. Diese Punkte nicht wieder neu implementieren. Vor Änderungen erst abgeschlossene aktuelle Revieweriteration lesen und sicherstellen, dass kein Writer läuft. Nur die folgenden beiden kausal reproduzierten Restfehler korrigieren, dann unabhängig nachprüfen lassen:

### A. Prüfmodus-Isolation muss vor SwiftUI-Stateinitialisierung greifen

`StaffelZweiApp.swift:13` initialisiert `@State model=AppModel()` -> `AppModel.init:37–39` -> `GameStore.load:66–69`. Die Defaultdatei kann dadurch gelesen werden, bevor der spätere Guard in `applicationDidFinishLaunching:76–85` ablehnt. `tools/app-checks.sh:85,91` entfernt APP_STORE für zwei Negativfälle. Reviewer hat diese beiden Fälle aus Sicherheitsgründen NICHT ausgeführt.

Minimaler Fix: Prüfmodus-Konfiguration in einem echten frühen Einstieg **vor jeglicher AppModel-/GameStore-Erzeugung** validieren (z.B. schmaler main-Bootstrap vor SwiftUI App.main). Ohne gültigen expliziten isolierten Store sofort nonzero und verständliche Meldung; weder normaler Userstore noch Nutzer-Defaultprefs lesen/schreiben. Normaler Appstart ohne Prüfmodus bleibt unverändert möglich. Kein bloßer zweiter Guard in didFinishLaunching/onAppear. Der Negativtest muss diese Reihenfolge objektiv belegen, nicht nur späteren Exitcode. Verifiziere die gefährlichen Fälle nur in einer wirklich geschlossenen Sandbox mit synthetischem Home/Defaultstore oder instrumentiertem isolierten Store-Factory-Spy; niemals durch Ausführen gegen tatsächlichen Nutzerhome hoffen, dass der Guard funktioniert. Der sicherere Ersatz ist ein Entry-Guard-Test mit stubbed App-Launch, der nachweist, dass die Launch-/Modelfactory bei ungültiger Config nicht aufgerufen wird. Echte Defaultdatei niemals prüfen/lesen/ändern.

### B. Matrixdateien vollständig derselben Validierung unterziehen

Reproduktion: `--require-matrix` akzeptiert10 Dateien mit jeweils `{"probes":[{}]}` und separat eine geometrisch gültige `valid.json`, dann Exit0/„10 screen layouts“. `tools/check-layout.swift:215–226` zählt Matrixdateien, validiert aber deren Schema/Geometrie nicht gemeinsam mit den eigentlich geprüften Inputs.

Minimaler Fix: Jede REQUIRED Matrixdatei muss eindeutig zu Screen/Appearance gehören, existieren und durch denselben strikten vollständigen Validator gehen, BEVOR sie als erfüllte Matrixposition zählt. Keine bloße Dateinamen-/Probeanzahlprüfung. Keine separate gültige Datei darf fehlerhafte Matrixdateien kompensieren. Doppelte/fehlende Kombinationen und malformed/empty/schemawidrige/geometrisch ungültige required Dateien nonzero. Reale Matrixabdeckung und synthetische Fixtures getrennt berichten.

Verpflichtende neue Regressionen: (1) genau das obige Gegenbeispiel schlägt fehl, (2) eine ungültige erforderliche Datei bei sonst gültiger Matrix schlägt fehl, (3) fehlende/duplizierte Required-Kombination schlägt fehl, (4) vollständig gültige synthetische Matrix besteht. Vorhandene10 Fälle behalten, nicht Assertions lockern. Geforderte dynamische M1-Layoutabnahme wird dadurch NICHT automatisch bestanden.

### Datenschutz und Laufgrenzen dieser Follow-up-Runde

Während des ersten Blocker-Laufs hat der Worker entgegen ausdrücklicher Begrenzung einen Fullscreen-Captureversuch nach `/tmp/m1-full.png` gemacht. **Nutzerentscheidung: Datei unberührt lassen.** Nicht öffnen, löschen, indexieren, kopieren, anhängen, hochladen oder verwenden. Kein weiterer Fullscreen-Captureversuch, keine Umgehung der Bildschirmsperre. Wenn CGSSessionScreenIsLocked=True: interaktive GUI-Nachweise als blockiert dokumentieren; keine weiteren Captureversuche. CLI-/Core-Prüfungen bleiben mit isoliertem APP_STORE erlaubt.

Diese Runde ist KEIN neuer M1-Komplettbau: genau zwei Fixes plus Regressionen, sicherer Release-Build/Signatur und Code-/Test-Nachweise. Ziel10–15min, hart20min. Keine weiteren App-Aktivierungs-/GUI-Workarounds, keine Fremdprozesse anfassen. Ergebnis an bestehenden M1-BLOCKERS-RESULT-Bericht als neue Iteration anhängen, historische Aussagen erhalten; keine unabhängige Abnahme vorwegnehmen.

