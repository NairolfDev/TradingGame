# Versions-Gate

Jede App liest beim Start und beim Zurückkehren in den Vordergrund `config/app` aus Firestore.
Ist `build` der App kleiner als `minBuild`, kommt der nicht schließbare Update-Dialog.
Ist die Datenbank nicht erreichbar, gilt die alte GitHub-Prüfung als Rückfall.

Zusätzlich stempelt die App nach dem Login ihren Build in `sessions/{uid}`. Die Firestore-Regeln
(`currentBuild()`) lassen Schreibzugriffe nur zu, wenn dieser Stempel `>= config/app.minBuild` ist.
Lesen bleibt offen, damit auch alte Apps den Update-Dialog zeigen können.

## Dokument `config/app`
| Feld | Typ | Bedeutung |
|---|---|---|
| `minBuild` | Zahl | kleinste erlaubte Build-Nummer (`+N` in `pubspec.yaml`) |
| `version` | Text, optional | Anzeige im Dialog, z. B. `1.10.0` |
| `notes` | Text, optional | „Was ist neu“ im Dialog |

Das Dokument ist per Regel nicht von Apps beschreibbar. Setzen: Firebase Console oder
`tools/set_min_build.sh <build> [version]` (gcloud-Login nötig).

## Reihenfolge beim Ausrollen
1. Neue Version veröffentlichen (Play-Test/Produktion, Hosting).
2. Erst wenn sie bei den Spielern ankommt: `minBuild` auf ihre Build-Nummer setzen.
Wer `minBuild` vor der Veröffentlichung hochsetzt, sperrt alle Spieler aus.
Ohne Dokument `config/app` sind die Regeln offen (Notausgang: Dokument löschen).
