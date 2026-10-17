# Benachrichtigungen

Stand 17.10.2026.

| Ereignis | Wie | Wenn die App zu ist |
|---|---|---|
| **Kursalarm** (über/unter, einmalig oder wiederkehrend) | Server: Cloud Function `checkPriceAlerts` prüft jede Minute die EUR-Kurse und sendet Push (FCM) | Ja (Android, Web) |
| **Order ausgeführt** (Pending-, Limit-, Bot-Order) | Lokale Benachrichtigung, sobald die App die Order ausführt | Nur solange die App im Hintergrund noch läuft |
| **Börse öffnet/schließt** | Lokal geplante Erinnerungen für Börsen, in denen du Positionen oder offene Orders hast | Ja (Android) |
| **Kredit fällig**, **Erfolge** | Kredit: geplant, 1 Tag vorher und zur Fälligkeit. Erfolge: lokal im Hintergrund | Kredit ja, Erfolge nur im Hintergrund |

Wichtig: Orders und Bots werden vom **Client** ausgeführt, nicht vom Server. Ist die App ganz beendet,
wird nichts ausgeführt. Die Marktöffnungs-Erinnerung sagt dir dann, dass deine Orders beim nächsten
App-Start ausgeführt werden.

Windows/Linux: nur Hinweise in der App (kein Push, FCM gibt es dort nicht). iOS/macOS: Code ist
vorbereitet, aber ohne APNs-Schlüssel und Firebase-iOS-App noch ohne Push.

## Bauteile
- Firestore: `priceAlerts/{id}` (Alarme), `deviceTokens/{fcmToken}` (Geräte). Regeln in `firestore.rules`.
- Server: `functions/price_alerts.js` (Logik, getestet), `functions/price_alerts_job.js` (Zeitplan), `functions/yahoo.js` (Kurs-Abruf).
- App: `lib/logic/notification_service.dart`, `notification_planner.dart`, `price_alerts_controller.dart`,
  `lib/ui/widgets/notification_host.dart`, `price_alert_sheet.dart`, `lib/ui/screens/notifications_screen.dart`.
- Web: `web/firebase-messaging-sw.js` und der öffentliche VAPID-Schlüssel in `notification_service.dart`.

## Deploy
Die Pipeline deployt nur Hosting. Funktionen und Regeln: `firebase deploy --only firestore:rules,functions`.

## Wiederkehrende Alarme
Nach dem Auslösen ist der Alarm „entschärft“ und schärft sich erst wieder, wenn der Kurs die Schwelle
in die Gegenrichtung verlassen hat. So gibt es keinen Dauerbeschuss, wenn der Kurs um die Schwelle pendelt.

## Manuell testen (Handy)
1. Anmelden, bei einem Krypto-Instrument (läuft 24/7) auf die Glocke tippen.
2. „Kurs über“ knapp über dem aktuellen Kurs wählen, Benachrichtigungen erlauben, App schließen.
3. Spätestens 1–2 Minuten nach Erreichen der Schwelle kommt die Push-Nachricht.
