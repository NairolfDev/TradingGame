# Qualitätsprüfung vom 16. Oktober 2026

## Behoben

- Negative, nicht endliche oder ungültig gehebelte Kauforders abweisen; Bestätigungen mit dem aktuellen Asset verarbeiten.
- Doppelte und gleichzeitige Verkäufe derselben Position verhindern.
- Reservierte Kaufmittel und wartende Verkaufspositionen im Nettovermögen berücksichtigen.
- Kreditbetrag/Laufzeit und Tilgungsbetrag validieren; Startkredite anhand ihres ID-Präfixes erkennen.
- Sanierung erst nach angemeldeter Insolvenz und abgelaufener fünftägiger Sperre zulassen; passende UI-Aktion anbieten.
- Monatliche Dividenden nicht mehrfach auszahlen.
- Keine globale Top-10-Belohnung für ein Profil ohne Konkurrenten; Start-Rendite und Reingewinn auf tatsächlichem Eigenkapital berechnen.
- Tagesquests und eingelöste Belohnungen pro Profil speichern; echte aufeinanderfolgende Login-Tage zählen; Initialisierung zählt nicht als Trade.
- Erfundene Copy-Trader, Zufallskurse, künstliche Nachrichtenimpulse, Zufallshistorien, OHLC-Kerzen und Orderbuchmengen aus dem aktiven Produkt entfernen.
- Vorhandene EUR-Aktien/ETFs und Krypto-EUR-Historien an den Kursabruf anbinden. Abrufe in Gruppen von sechs ausführen; überlappende Portfolio-Refreshes verhindern.
- Rohstoff-Futures in Fremdwährung nicht als EUR übernehmen. Nicht aktualisierte Werte als Katalogkurse kennzeichnen.
- Veraltete Chart-Antworten nach Zeitraumwechsel verwerfen; fehlende Daten mit Wiederholen-Aktion anzeigen.
- Textkontrast, Formulare, Mindestgrößen und mobile Kopfzeile verbessern; Chart-Zeiträume bedienbar machen und reduzierte Bewegung beim Laufband respektieren.
- Android-Signierdaten aus dem Workflow entfernen und durch die ausdrücklich genehmigten GitHub-Secrets ersetzen.
- Push auf dev führt Tests und Web-Deployment aus. Plattform-Releases bleiben auf main; Pull Requests deployen nicht. Hosting-Fehler werden nicht mehr verschluckt.

## Bewusste Grenzen

- US-/asiatische Aktien, Anleihen, CFDs und Rohstoffe ohne geeigneten EUR-Feed bleiben als Katalogkurse verfügbar. Es werden keine Ersatzkurse erfunden. Für deren Livebetrieb fehlt eine verlässliche Währungs-/Einheitenumrechnung oder ein geeigneter Anbieter.
- Copy-Trading und Level-2-Markttiefe zeigen einen Leerzustand, bis echte freigegebene Feeds angebunden sind. Historische OHLC-Daten fehlen; deshalb nur Liniencharts.
- Externe Kursdienste können verzögerte Kurse liefern oder Anfragen drosseln. „Abgerufen“ bezeichnet die Abrufzeit, keine Echtzeitgarantie.
- Der zuvor eingecheckte Android-Schlüssel bleibt in der Git-Historie. Das Speichern als Secret widerruft ihn nicht; ein Austausch des Upload-Schlüssels sollte über die Play Console erfolgen.
- Kein vollständiger Hardwaretest auf Android/iOS/macOS/Linux; kein Umbau der serverseitigen Spielvalidierung.

## Validierung

- 57 Flutter-Tests bestanden, einschließlich Trading-Regressionsfällen, Tageswechsel/Profiltrennung und 375-Pixel-Layouttest.
- Flutter-Analyse ohne Befund.
- Web-Release-Build und unabhängiges Code-Review durchgeführt.
- Öffentliche Kursendpunkte für OMV.VI und BTC-EUR antworten mit Kursen und historischen Punkten.
