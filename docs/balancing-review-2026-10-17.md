# Balancing-Review – 17.10.2026

Das aktuelle System mischt echte Börsenzeit mit sehr großen Arcade-Belohnungen. Dadurch werden Handelsentscheidungen wirtschaftlich von Belohnungsmechaniken überlagert.

## Fehlerkorrekturen dieses Runs

- 100%-Orders behalten den Prozentwunsch bis zur Ausführung; Kaufmenge wird aus aktuellem Cash/Kurs einschließlich Gebühren neu berechnet.
- Anleihen: statt zehn Zinstagen ungefähr alle 50 Sekunden nun Actual/365 über reale Haltezeit mit lokal gespeichertem Profil-/Positionscursor. Bei 50.000 EUR und 7,8% waren es zuvor rund 106,85 EUR je Intervall bzw. 7.693 EUR pro Stunde ohne Wiederanlage.
- Rangliste: künstliche Multiplikatoren für Tages-/Wochenrenditen entfernt, bis echte historische Stände vorhanden sind.
- Pending-Käufe rechnen reserviertes Budget inklusive Gebühren zum tatsächlichen Ausführungskurs in Menge um; Einstand und Margin verwenden diesen Kurs.
- Fehlende Aktienkurse dürfen keine Positionen auf null abwerten und keine Pending Orders zu null ausführen.

## Noch offene Änderungen am Spielsystem

| Priorität | Befund | Wirkung | Empfehlung |
|---|---|---|---|
| Hoch | Tägliche Quests zahlen zusammen 13.800 EUR | 55,2% der anfänglichen 25.000 EUR Eigenkapital pro Tag; drei Trades plus zwei Positionen liefern bereits 4.500 EUR | Gesamtes Cash-Budget auf etwa 250–500 EUR/Tag reduzieren, weitere Belohnung über Prestige; Mindesteinsatz gegen Mikrotrade-Farming |
| Hoch | Kredit-Restschuld und angezeigter Gesamtbetrag mit Zinsen laufen auseinander | Rückzahlung kann nur Kapital tilgen; Überfälligkeit erzeugt überwiegend Anzeigeeffekte | Eine verbindliche Zins-/Tilgungsregel und einheitliche Restschuld; bestehende Spielstände transparent migrieren |
| Mittel | Verkaufsgebühr-Helfer wird nicht konsistent genutzt; Sparpläne umgehen Kaufspesen | Unterschiedliche Handelswege erzeugen unterschiedliche Kosten | Explizite einheitliche Gebührenregel für Direktorder, Pending und Sparplan |
| Mittel | Monatliche Dividende orientiert sich am augenblicklichen Bestand | Kauf kurz vor Monatswechsel kann überproportional belohnt werden | Spieldividende zeitanteilig ansammeln; echte Dividenden nur mit tatsächlichen Ex-/Zahltagsdaten |
| Mittel | Quest-/Achievement-Prestige wird angekündigt, aber Gesamtprestige zählt überwiegend Luxusbesitz | Belohnung und sichtbarer Fortschritt passen nicht zusammen | Verdientes Prestige dauerhaft separat erfassen und mit Besitzprestige addieren |
| Mittel | Beliebig viele günstige Luxusartikel liefern sehr effizientes Prestige; Verbrauchsartikel behalten vollen Vermögenswert | Stifte/Verbrauchsgüter können teure Statusobjekte wirtschaftlich dominieren | Wiederholungsbonus begrenzen; Verbrauch von wiederverkaufbarem Vermögen unterscheiden |
| Mittel | Achievement-Speicher ist noch nicht durchgehend profilbezogen | Fortschritt kann beim Kontowechsel übertragen werden | Persistenz wie bei täglichen Quests pro UID isolieren |

Empfehlung: eine reale Zeitbasis für Zinsen und Dividenden behalten; Spielfortschritt über dosierte Quests/Prestige erzeugen. Kein pauschaler Reset bestehender Guthaben in diesem Run.

Grenzen: Keine vollständige Langzeitsimulation und keine serverseitig autoritative Wirtschaft implementiert. Eigentümerregeln schützen andere Konten; ein manipulierter Client kann eigene Portfolio-/Rankingwerte weiterhin verfälschen. Lokale Kuponcursor sind nicht geräteübergreifend atomar – dafür gehört die Abrechnung in einen Server-Transaktionspfad. Echte lizenzierte Echtzeitkurse für alle Börsen benötigen einen passenden Datenanbieter; der jetzige Abruf kennzeichnet Quelle/Zeit und Verzögerung.
