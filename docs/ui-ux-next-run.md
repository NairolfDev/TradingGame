# UI/UX-Vorschläge für den nächsten Run

Stand: 17.10.2026. Empfehlungen anhand der vorhandenen Flutter-App, des gemeldeten Sidebar-Überlaufs und der neuen Filter. Noch keine vollständige Neugestaltung implementiert.

| Priorität | Vorschlag | Konkretes Ergebnis / Akzeptanzkriterium | Aufwand grob |
|---|---|---|---|
| 1 | Marktübersicht als Arbeitsfläche | Desktop: kompakte sortierbare Tabelle mit Name/Symbol, Index, Branche, EUR-Kurs, Tagesänderung, Kurszeit und Stern. Mobil: klare Karten mit denselben Kerninformationen. Suche und aktive Filter bleiben beim Scrollen sichtbar. | mittel |
| 1 | Orderdialog vereinfachen | Ein Formular für Kaufen/Verkaufen, Eingabe wahlweise EUR oder Stück, 25/50/75/100%, Gebühren und Gesamtbetrag direkt daneben; am Handy feste Abschlussleiste. Nach Ausführung eindeutige Bestätigung mit tatsächlich ausgeführter Menge. | mittel |
| 1 | Mobile Navigation aufräumen | Fünf Ziele: Übersicht, Märkte, Portfolio, Aktivität, Mehr. Bank, Prestige, Ranking und Einstellungen unter Mehr; aktueller Bereich bleibt erkennbar. Keine winzigen Beschriftungen. | mittel |
| 2 | Portfolio verständlicher machen | Nettovermögen, verfügbares Cash, investierter Wert und Schulden getrennt; Gewinn seit Start ausdrücklich auf 25.000 EUR Eigenkapital beziehen. Pending Orders mit reserviertem Geld sichtbar. | klein–mittel |
| 2 | Gespeicherte Filteransichten | Ansichten wie „DAX“, „ATX“, „Nasdaq Technologie“ und persönliche Watchlist speichern. Aktive Filterchips einzeln entfernbar, Reset und Trefferzahl sichtbar. Branchen nur anzeigen, wenn eine Quelle vorhanden ist. | klein–mittel |
| 2 | Einheitliche Zustände und Schrift | Ladeplatzhalter, „Kein Kurs“, Offline und verzögert überall gleich; Gewinn/Verlust auch mit Vorzeichen erklären. Weniger dekorative Rahmen/Emojis, konsistente Abstände und Zahlenbreiten. | mittel |
| 3 | Charts und Datentransparenz | Kurszeit, Quelle und Umrechnung direkt am Chart; Zeiträume ohne Daten deaktiviert. Zugängliche Tooltip-Zahlen, keine erfundenen Kurven. Währungsbereinigte historische Kurse benötigen passende historische FX-Daten. | mittel–groß |

Empfohlener nächster Run: zuerst Marktübersicht + Orderdialog + mobile Navigation. Das verbessert die häufigsten Abläufe stärker als eine komplette Farbänderung. Dunkles Grunddesign behalten, Grün für primäre Aktionen und Gewinne, Gold sparsam für Rang/Prestige.

Abnahme: 375, 768 und 1440 px; 200% Textgröße; Tastaturbedienung; große Touch-Flächen; Fehler-/Lade-/Leerzustände; Kauf und Verkauf mit 100%; Rückkehr von Details erhält Suche/Filter/Scrollposition.

Grundlagen: [Flutter Accessibility Testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing), [Flutter adaptive input](https://docs.flutter.dev/ui/adaptive-responsive/input), [Material Navigation](https://m2.material.io/design/navigation/). Aufwand ist eine grobe Einschätzung, keine Zeitgarantie.
