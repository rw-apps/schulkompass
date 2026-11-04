# Datenschutzhinweis – App „Schulkompass“

Stand: 04.11.2026

## 1. Wer verantwortlich ist

Reinhard Wedhorn  
Altenhainer Straße 7  
60326 Frankfurt am Main  
E-Mail: reinhard.wedhorn@gmx.de

„Schulkompass“ (bis Version 4.1.0+9472 „Schulportal“) ist eine inoffizielle, private und nicht kommerzielle Abwandlung der quelloffenen App [Lanis-Mobile](https://github.com/lanis-mobile/lanis). Mit dem Land Hessen, dem Schulportal Hessen und den Entwicklern von Lanis-Mobile besteht keine Verbindung.

Für die Daten **im Schulportal selbst** (Noten, Nachrichten, Stundenpläne usw.) sind deine Schule und das Land Hessen verantwortlich. Die App ist nur ein anderes Fenster auf diese Daten – wie ein Browser.

## 2. Der Grundsatz: Alles bleibt auf deinem Gerät

Die App hat **keinen eigenen Server**. Sie verbindet sich direkt mit dem Schulportal und, wenn du es einrichtest, mit der Bestellseite deines Caterers. Der Verantwortliche erhält von dir nur dann etwas, wenn du einem Fehlerbericht zugestimmt hast (Abschnitt 5).

## 3. Was auf deinem Gerät gespeichert wird

| Was | Wozu | Wie lange |
|---|---|---|
| Schulnummer, Benutzername, Passwort fürs Schulportal | Anmeldung | bis du das Konto entfernst oder die App deinstallierst |
| Inhalte aus dem Portal (Stundenplan, Vertretungen, Termine, Nachrichten, Kurse …) | Anzeige, auch ohne Netz | wird laufend ersetzt; gelöscht mit dem Konto |
| Deine Eingaben (Klasse, Gruppenwahl, Stundenzeiten, Lehrernamen, abgehakte Hausaufgaben, gesendete Entschuldigungen, Farben, Einstellungen) | damit die App so aussieht, wie du sie eingerichtet hast | bis du sie änderst oder das Konto entfernst |
| Adresse der Bestellseite des Caterers, gelesene Gerichte und Guthaben | „Essen und Caterer“, Hinweise auf „Heute“ | bis du die Adresse löschst |
| Benutzername und Passwort beim Caterer – **nur wenn du sie hinterlegst** | automatische Anmeldung nur auf dieser Bestellseite | bis du sie löschst oder die Adresse änderst |
| Fehlerprotokoll **ohne Inhalte** (App-Version, Bereich, Fehlerart, Stelle im Code) | Fehlersuche | die letzten Einträge; gelöscht mit der App |

Passwörter liegen im geschützten Schlüsselspeicher von Android (Keystore). Benachrichtigungen und das Startbildschirm-Widget entstehen auf dem Gerät; es gibt keinen Push-Dienst.

## 4. Mit wem die App Verbindung aufnimmt

- **Schulportal Hessen** (`*.schulportal.hessen.de`, auch das Moodle deiner Schule): Anmeldung und Inhalte. Vor der Anmeldung lädt die App die öffentliche Schulliste (`startcache.schulportal.hessen.de`).
- **Bestellseite deines Caterers** – nur wenn du unter „Essen und Caterer“ eine Adresse eingetragen hast. Die Seite läuft in einer eingebetteten Ansicht; dabei gelten die Datenschutzbestimmungen des Caterers.
- **GitHub** (GitHub Inc., USA; `api.github.com`): Die App fragt dort nach neuen Versionen und lädt auf „Über die App“ die Liste der Mitwirkenden. GitHub erfährt deine IP-Adresse, aber keine Zugangsdaten und keine Portal-Inhalte. Rechtsgrundlage: berechtigtes Interesse an Sicherheitsupdates (Art. 6 Abs. 1 lit. f DSGVO).
- **Cloudflare** (Cloudflare Inc., USA; `*.workers.dev`): nur für Fehlerberichte mit deiner Zustimmung (Abschnitt 5).
- **Termine abonnieren:** Die Abo-Adresse stellt das Schulportal bereit. Dein Kalenderdienst (z. B. Google Kalender) ruft die Termine dann selbst beim Portal ab; die App ist daran nicht beteiligt.

GitHub und Cloudflare sitzen in den USA. Beide nehmen am EU-US-Datenschutzrahmen (Data Privacy Framework) teil; die Übermittlung stützt sich auf den Angemessenheitsbeschluss der EU-Kommission (Art. 45 DSGVO).

## 5. Fehlerberichte – nur mit deiner Einwilligung

- **Automatisch melden:** Nur wenn du zustimmst (Frage auf „Heute“ oder Einstellungen → Über die App → Fehlersuche). Ein Bericht enthält App-Version, Bereich, Fehlerart und Stellen im Code – **keine** Namen, Noten, Nachrichten, Zugangsdaten oder sonstigen Portal-Inhalte. Du kannst jeden Bericht vorher unter „Erkannte Probleme“ ansehen.
- **Anonym senden:** Kann die App eine Portalseite nicht lesen, kannst du deren Aufbau senden. Alle Wörter außer festen Beschriftungen werden durch Zufallsbuchstaben ersetzt, Noten zufällig neu vergeben, Schulnummer, Bilder und Anmeldedaten entfernt. Gesendet wird erst, nachdem du die unverändert gebliebenen Wörter gesehen und auf „Senden“ getippt hast.
- **Weg:** Ein Weiterleitungsdienst bei Cloudflare legt den Bericht als Eintrag in einem **privaten** GitHub-Repository ab, das nur der Verantwortliche sehen kann. Cloudflare und GitHub erfahren dabei technisch bedingt deine IP-Adresse. Der Dienst selbst speichert sie nicht; er merkt sich nur zwei Tage lang einen nicht umkehrbaren, verschlüsselten Wert aus Tag und Adresse, um höchstens fünf Berichte je Absender und Tag anzunehmen.
- **Speicherdauer:** Berichte werden gelöscht, sobald der Fehler behoben ist, spätestens nach 12 Monaten.
- **Rechtsgrundlage:** deine Einwilligung (Art. 6 Abs. 1 lit. a DSGVO). Du kannst sie jederzeit unter Einstellungen → Über die App → Fehlersuche widerrufen; bereits gesendete Berichte bleiben davon unberührt, bis sie nach den Regeln oben gelöscht werden.

## 6. Übertragen zwischen Geräten

- **Per QR-Code:** Zugangsdaten und Eingaben gehen verschlüsselt direkt von einem Gerät zum anderen, mit einem Schlüssel, den nur das neue Gerät kennt. Es läuft nichts über das Internet.
- **Per Datei („Nur Eingaben per Datei“, „Sicherungsdatei“):** Die Datei enthält Schulnummer, Benutzername, Schulname und deine Eingaben je Konto, **keine** Passwörter. Sie ist nicht verschlüsselt; wohin du sie schickst (Mail, Messenger, Cloud), entscheidest du. Lösche sie, wenn du sie nicht mehr brauchst.

## 7. Kinder und Jugendliche

Die App wird auch mit Schülerkonten genutzt. Sie sammelt von niemandem Daten für den Verantwortlichen, außer über die freiwilligen Fehlerberichte, die keine Personendaten enthalten. Bei Kindern unter 16 Jahren sollten die Eltern über die Zustimmung zu Fehlerberichten entscheiden.

## 8. Was die App nicht tut

Keine Werbung, kein Tracking, keine Nutzungs- oder Login-Statistik, keine automatisierten Entscheidungen. Die Fehlererfassung des Originals (Sentry) ist entfernt.

## 9. Deine Rechte

Du hast das Recht auf Auskunft (Art. 15 DSGVO), Berichtigung (Art. 16), Löschung (Art. 17), Einschränkung (Art. 18), Datenübertragbarkeit (Art. 20) und Widerspruch (Art. 21) sowie auf Widerruf einer Einwilligung (Art. 7 Abs. 3). Da die App fast alles nur auf deinem Gerät speichert, kannst du die meisten dieser Rechte selbst ausüben: Konto entfernen oder App deinstallieren löscht alles auf dem Gerät. Für gesendete Fehlerberichte genügt eine E-Mail an die Adresse oben.

Du kannst dich bei einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel beim
Hessischen Beauftragten für Datenschutz und Informationsfreiheit, Postfach 31 63, 65021 Wiesbaden, https://datenschutz.hessen.de

## 10. Änderungen

Ändert sich, was die App mit Daten tut, wird dieser Hinweis angepasst; die App fragt dann erneut nach deiner Zustimmung.
