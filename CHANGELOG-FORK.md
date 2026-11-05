## Schulkompass (rw-apps, bis 9472 „Schulportal“) – Änderungen gegenüber Lanis-Mobile

**4.1.0+9493** – Anonymer Export: Stundenplan je Kind

- **Für Geschwister-Familien:** Der „Anonyme Export“ in den Einstellungen ruft bei Elternkonten jetzt auch den Stundenplan je Kind ab und nennt Weiterleitungen. So kann eine Familie mit zwei Kindern an einer Schule die nötige Auskunft schicken, ohne echte Namen preiszugeben.

**4.1.0+9492** – Fehlerexport: Stundenplan je Kind

- **Vorbereitung für Geschwister:** Der Fehlerexport kann bei einem Elternkonto mit mehreren Kindern zusätzlich den Stundenplan je Kind abrufen („Stundenplan je Kind“). Damit lässt sich klären, ob das Portal den Plan eines zweiten Kindes liefert – Voraussetzung für eine eigene Karte je Kind. An der Anzeige ändert sich nichts.

**4.1.0+9491** – Krankmeldung: Ferien und Geschwister

- **Ferien:** „Krank melden“ nach Schulschluss und „Auch … melden“ in der Krankmeldung schlagen keinen Ferien- oder Studientag mehr vor, sondern den nächsten Schultag laut Schulkalender.
- **Geschwister in einem Elternkonto:** „Daran denken“ in der Krankmeldung nennt Essen und Arbeiten für jedes gemeldete Kind, mit Namen; „Abbestellen“ öffnet die Essensseite des richtigen Kindes.

**4.1.0+9490** – Krankmeldung: Essen abbestellen, verpasste Arbeit, nächster Tag

- **Essen abbestellen:** Ist für einen Krankheitstag Essen bestellt und die Frist noch offen, steht auf „Heute“ „Essen abbestellen bis 08:30“. Antippen öffnet die Essensseite gleich mit der Rückfrage für genau diesen Tag – abbestellt wird erst nach deiner Bestätigung. In der Krankmeldung steht dasselbe unter „Daran denken“ mit einem Knopf je Tag. (Nur wenn „Bestellen und Abbestellen in der App“ eingeschaltet ist; sonst ein Hinweis.)
- **Verpasste Arbeit:** Eine Arbeit an einem Krankheitstag heißt „verpasst“; die Krankmeldung erinnert daran, dass die Schule ein Attest verlangen kann.
- **Nächster Schultag:** Nach Schulschluss zeigt die Karte für einen gemeldeten nächsten Schultag „Morgen krank gemeldet“, der Plan ist gedämpft, Ausfälle und „Essen bestellen“ für diesen Tag entfallen. „Krank melden“ schlägt nachmittags gleich den nächsten Schultag vor.

**4.1.0+9489** – Keine Erinnerungen für krank gemeldete Kinder

- **Benachrichtigungen:** Für Tage, an denen ein Kind krank gemeldet ist, meldet die Sammel-Benachrichtigung keine Ausfälle und Vertretungen mehr und erinnert nicht ans Essen-Bestellen. Bei einer Verspätung bleibt alles wie bisher.
- Bei Geschwistern in einem Elternkonto gilt das nur für das gemeldete Kind.

**4.1.0+9488** – Widget-Krankmeldung abgesichert

- **Behoben:** In seltenen Fällen konnte eine gerade gesendete Krankmeldung im Widget kurz fehlen – wenn die Aktualisierung im Hintergrund gleichzeitig eine ältere Liste las oder der Name des Kindes noch nicht bekannt war. Bekannte Meldungen bleiben jetzt stehen, bis eine neuere Liste da ist.
- Das Band auf „Heute“ erkennt Verspätungen genauso wie die Auswahl dahinter.

**4.1.0+9487** – Krankmeldung von „Heute“ aus öffnen

- **Antippen:** Das Band „Heute krank gemeldet“ auf „Heute“ öffnet jetzt direkt die Krankmeldung des Kindes – wie die Zeile unter „Nachrichten“ (Pfeil rechts).

**4.1.0+9486** – Krankmeldung im Startbildschirm-Widget

- **Widget zeigt gemeldete Abwesenheit:** Statt der Unterrichtszeit steht beim Kind ein Haken mit „krank gemeldet“, bei mehreren Tagen „krank bis 16.11.“ (letzter gemeldeter Schultag, auch über mehrere Meldungen und das Wochenende). Arbeit, Aufgaben und Essen sind an diesen Tagen blass; knappes Guthaben bleibt sichtbar. Im großen Widget steht in der Tagesvorschau „krank“ statt der Symbole.
- **Verspätung:** „verspätet gemeldet“ statt der Zeit, die Symbole bleiben.
- **Auch im Hintergrund:** Die Aktualisierung im Hintergrund liest bei Elternkonten die Meldungen mit, damit das Widget das Kind nicht nach einer Weile wieder mit vollem Plan zeigt.
- Die Erklärung der Widget-Symbole in den Einstellungen nennt den Haken.

**4.1.0+9485** – Gesendete Krankmeldung als Anzeige

- **Krankmeldung öffnen nach dem Melden:** Gibt es schon eine Meldung ab heute, zeigt die Seite sie nur an (Kind, Art, Tag, Eintragszeit, Kommentar). Darunter „Auch Fr 6.11. melden“ (nächster Schultag, vorausgefüllt) und „Andere Meldung“ für einen anderen Tag oder eine Verspätung.
- **Formular bleibt offen:** Das automatische Neuladen wirft einen nicht mehr aus einem halb ausgefüllten Formular; während des Sendens sind Zurück, „Ändern“ und Neu laden gesperrt, und die Zurück-Geste führt im Formular zur Anzeige.
- **„Ändern“ oben rechts:** Das Portal kennt für gesendete Meldungen weder Ändern noch Zurückziehen – „Ändern“ erklärt das und öffnet eine Nachricht an die Schule oder das Portal.

**4.1.0+9483** – Krankmeldung auf „Heute“ und bei den Nachrichten

- **Heute:** Ist ein Kind für heute gemeldet, steht unter seinem Namen „Heute krank gemeldet“ (bzw. „Heute Verspätung gemeldet“) mit Tag und Eintragszeit; der Knopf heißt dann „Gemeldet“. Bei Krankmeldung ist der Stundenplan gedämpft, und die heutigen Hinweise (z. B. Essen nicht bestellt) entfallen.
- **Nachrichten:** Über dem Postfach stehen unter „Krankmeldungen“ alle aktuellen und kommenden Meldungen; Antippen öffnet die Krankmeldung. Es sind keine Nachrichten – das Portal führt sie getrennt.
- **Behoben:** In 9481/9482 erschienen die Meldungen nicht – die App las sie zwar, gab sie aber nicht an „Heute“ und „Nachrichten“ weiter.
- In „Alle“ öffnet jede Meldung die Krankmeldung ihres eigenen Kontos; ohne Postfach der Schule stehen die Meldungen trotzdem unter „Nachrichten“. Das Guthaben bleibt an Kranktagen sichtbar.
- Die Meldungen liest die App bei Elternkonten beim normalen Aktualisieren mit. Die Erinnerungen im Hintergrund (Benachrichtigungen) kennen sie noch nicht.

**4.1.0+9480** – Krankmeldung ohne Testknöpfe

- **Einfacher:** „Beim Portal prüfen“ und „Vorschau der Portal-Felder“ aus der Probephase sind weg. Es gibt nur noch „Abwesenheit melden“ mit der Rückfrage – geprüft wird dabei automatisch.

**4.1.0+9479** – Krankmeldung absenden (abgesichert)

- **Krankmeldung wirklich senden:** „Abwesenheit melden“ bzw. „Verspätung melden“ schickt die Meldung jetzt an die Schule – nach einer Rückfrage mit Zusammenfassung. Wie im Portal prüft das Portal zuerst, erst danach wird gespeichert.
- **Kontrolle danach:** Die App lädt die Liste „Aktuelle und zukünftige Meldungen“ neu und zeigt, ob die Meldung dort steht. Ist das unklar (z. B. Verbindung weg), sendet sie nie von selbst noch einmal und verweist aufs Portal; wer dieselbe Meldung gleich noch einmal senden will, bekommt einen Hinweis – auch nachdem die Seite neu geladen hat. Während des Sendens lädt die Seite nicht mehr von selbst neu.
- **Demo:** Dort lässt sich nichts absenden.
- **Umstieg von 4.1.0+9472 oder älter** (neue Signatur, einmalig): In der alten App Einstellungen → Daten → „Auf neues Gerät übertragen“ (dort noch der alte Name) → „Nur Eingaben per Datei“ → „Als Datei senden“. Alte App deinstallieren, in Obtainium „Installieren“, dann „Sicherungsdatei“.

**4.1.0+9477** – Vollständiger Datenschutzhinweis

- **Datenschutzhinweis neu:** Verantwortlicher mit Kontakt, alle Verbindungen der App, Rechtsgrundlagen, Speicherdauer der Fehlerberichte (spätestens 12 Monate), Übertragen zwischen Geräten, Kinder, deine Rechte und die zuständige Aufsichtsbehörde. Die App fragt deshalb einmal neu nach deiner Zustimmung.
- **Umstieg von 4.1.0+9472 oder älter** (neue Signatur, einmalig): In der alten App Einstellungen → Daten → „Auf neues Gerät übertragen“ (dort noch der alte Name) → „Nur Eingaben per Datei“ → „Als Datei senden“. Alte App deinstallieren, in Obtainium „Installieren“, dann „Sicherungsdatei“.

**4.1.0+9476** – Willkommen auf einer Seite, QR-Übertragung ohne Scrollen

- **Willkommensseite:** Symbol und Name nebeneinander, die Funktionen als knappe Liste, darunter „Anmelden“ und – nebeneinander – „Sicherungsdatei“ und „Anderes Gerät“. Alles passt auch bei großer Schrift auf eine Seite.
- **„Zwischen Geräten übertragen“** heißt jetzt der Eintrag unter Einstellungen → Daten (vorher „Auf neues Gerät übertragen“) – darüber wird gesendet und empfangen, per QR-Code oder Datei.
- **QR-Übertragung:** Der Code auf dem neuen Gerät ist etwas kleiner, damit Prüfcode, Hinweis und „Code des alten Geräts scannen“ ohne Scrollen zu sehen sind. Die Codes des alten Geräts bleiben groß.
- **Umstieg von 4.1.0+9472 oder älter** (neue Signatur, einmalig): In der alten App Einstellungen → Daten → „Auf neues Gerät übertragen“ (dort noch der alte Name) → „Nur Eingaben per Datei“ → „Als Datei senden“. Alte App deinstallieren, in Obtainium „Installieren“, dann „Sicherungsdatei“.

**4.1.0+9474** – Mit Sicherungsdatei einrichten

- **Neu einrichten ohne Abtippen:** Auf der Willkommensseite und bei der Anmeldung gibt es „Mit Sicherungsdatei einrichten“. Die App liest Schule und Benutzername aller Konten aus der Datei; je Konto nur noch das Passwort eingeben. Stundenzeiten, Gruppenwahl, Mensa und Haken werden nach jeder Anmeldung gleich übernommen. „Von anderem Gerät übernehmen“ (QR-Code, mit Passwörtern) steht jetzt auch auf der Anmeldeseite.
- **Kompass auch auf der Willkommensseite** statt des alten Doktorhuts.
- **Hinweis auf Bestellseiten:** Beim Übernehmen einer Datei nennt die App die Bestellseiten für „Essen“ aus der Datei – das funktionierte bei echten Dateien bisher nicht.
- **Umstieg von 4.1.0+9472 oder älter** (neue Signatur, einmalig): In der alten App Einstellungen → Daten → „Auf neues Gerät übertragen“ → „Nur Eingaben per Datei“ → „Als Datei senden“ und die Datei sichern. Alte App deinstallieren, in Obtainium „Installieren“, dann „Mit Sicherungsdatei einrichten“.

**4.1.0+9473** – Neuer Name „Schulkompass“, neue Signatur: einmal neu installieren

- **Neuer Name:** Die App heißt jetzt „Schulkompass“ und hat ein Kompass-Symbol. „Schulportal“ ist der Name des Portals selbst; die App sollte nicht wie ein offizielles Angebot wirken.
- **Neue Signatur – einmalig neu installieren:** Die App ist mit einem neuen Schlüssel signiert. Android installiert das Update deshalb nicht über die alte App („App nicht installiert“ bzw. Signaturfehler in Obtainium). So gehts:
  1. In der alten App: Einstellungen → Daten → „Auf neues Gerät übertragen“ → „Nur Eingaben per Datei“ → „Als Datei senden“ und die Datei z. B. per Mail an dich selbst oder in „Dateien“ speichern (Gruppenwahl und Lehrernamen im Stundenplan, Stundenzeiten, Mensa-Adressen, abgehakte Hausaufgaben, gesendete Entschuldigungen; Zugangsdaten sind nicht enthalten).
  2. Alte App deinstallieren.
  3. Neue App installieren – in Obtainium auf „Installieren“ tippen oder die APK aus dem Release laden.
  4. Alle Konten wieder anmelden, dann Einstellungen → Daten → „Auf neues Gerät übertragen“ → „Nur Eingaben per Datei“ → „Datei übernehmen“.
- **Prüfen:** Zertifikat SHA-256 `8D:4A:42:80:3C:12:28:D9:D3:D3:0E:EC:C8:40:5A:55:15:E6:97:97:B9:5B:12:C5:44:AE:62:0F:4C:64:FC:EE` (auch im README).

**4.1.0+9351** – Krankmeldung: Zurück statt totem Menü-Knopf

- Oben links in der Krankmeldung stand noch der Menü-Knopf der alten Ansicht; Antippen tat nichts und erzeugte einen Fehler. Jetzt steht dort der Zurück-Pfeil.

**4.1.0+9350** – Absturz in „Unterricht“ behoben

- Nach einem Kindwechsel konnte „Unterricht“ mit „Ein Fehler ist aufgetreten“ abstürzen, wenn eine Kursseite offen war. Geöffnete Seiten werden jetzt einmal aufgebaut und hängen nicht mehr an der Seite, aus der sie kamen.

**4.1.0+9349** – Kindwahl bleibt beim Reiterwechsel

- **Ein Kind für alle Bereiche:** Die Wahl oben (Kalender, Unterricht, Nachrichten, Mehr) gilt jetzt für alle Reiter; nach einem Wechsel bleibt das gewählte Kind stehen.
- **Fehlersuche:** Bleibt ein Stundenplan leer, obwohl das Portal Einträge liefert, steht unter Einstellungen → Fehlersuche ein Eintrag mit Zählwerten (ohne Inhalte), damit sich die Ursache eingrenzen lässt.

**4.1.0+9348** – Stundenzeiten selbst eintragen

- **Für Schulen ohne Uhrzeiten im Stundenplan:** Im Kalender (Tag) steht „Stundenzeiten eintragen“. Einmal Beginn der 1. Stunde, Länge einer Stunde, Pause nach je wie vielen Stunden und Pausenlänge wählen (Vorgabe: 8:00, 45 Minuten, Pause nach je 2 Stunden, 15 Minuten) – die Vorschau zeigt sofort die Zeiten. Danach gibt es wieder „Jetzt“, „Danach“, die Zeitlinie und Uhrzeiten in Heute, Kalender und Kursseite.
- Ohne Eintrag funktioniert alles wie bisher mit Stundennummern. Gespeichert wird nur auf dem Handy und nur für dieses Konto; „Ändern“ oder „Löschen“ jederzeit. Liefert das Portal Uhrzeiten, gelten immer diese.

**4.1.0+9348** – 0. Stunde, Stundenzeiten selbst eintragen

- **0. Stunde/Block fehlte:** Stand in der ersten Zeile des Stundenplans ein Eintrag (z. B. die Klassenstunde im 0. Block um 8:00), ließ die App ihn weg – Heute und Kalender begannen erst mit dem 1. Block. Jetzt erscheint er wie im Portal.
- **Stundenzeiten selbst eintragen** (für Schulen ohne Uhrzeiten im Stundenplan): Im Kalender (Tag) steht „Stundenzeiten eintragen“. Beginn der 1. Stunde, Länge einer Stunde, Pause nach je wie vielen Stunden und Pausenlänge wählen (Vorgabe: 8:00, 45 Minuten, Pause nach je 2 Stunden, 15 Minuten); die Vorschau zeigt sofort die Zeiten. Danach gibt es wieder „Jetzt“, „Danach“, die Zeitlinie und Uhrzeiten.
- Ohne Eintrag funktioniert alles wie bisher mit Stundennummern. Gespeichert wird nur auf dem Handy und nur für dieses Konto; „Ändern“ oder „Löschen“ jederzeit. Liefert das Portal Uhrzeiten, gelten immer diese.

**4.1.0+9347** – Wochen blättern, Raster ohne abgeschnittene Zeilen

- **Kalender: Wochen wechseln.** Über den Tagen steht die Woche („19.10.–23.10. · KW 43“) mit Pfeilen; Wischen nach links/rechts blättert ebenfalls. Antippen der Woche öffnet einen Kalender, um auch Monate weiter zu springen; „Diese Woche“ führt zurück. Vertretungen erscheinen, soweit das Portal sie für jene Tage schon zeigt.
- **Wochenraster:** Kurze Stunden zeigen nur noch ganze Zeilen (Fach und Raum) statt einer halb abgeschnittenen Lehrkraft.
- Die Kinder behalten ihre Reihenfolge und Farbe, auch nach einem Kontowechsel.

**4.1.0+9346** – Stundenplan ohne Uhrzeiten

- **Schulen ohne Uhrzeiten im Stundenplan:** Der Plan blieb leer, und alle Kurse landeten unter „Weitere Angebote“. Jetzt baut die App den Plan aus den Stundennummern: Kalender, Heute und Unterricht zeigen die Stunden mit „1. Stunde“ usw. statt Uhrzeiten. „Heute“ nennt dann die erste Stunde des Tages; was gerade läuft, kann die App ohne Uhrzeiten nicht wissen.
- Kurse werden ihrem Fach im Plan auch bei anderer Schreibweise zugeordnet („Ev. Religion“ ↔ „Religion - evangelisch“, Kurs mit Kürzel als Namen).
- Einstellungen zeigen die weiteren angemeldeten Konten der Familie.

**4.1.0+9345** – Familienansicht über mehrere Konten

- **Alle Kinder zusammen:** Sind mehrere Konten eingerichtet (z. B. Elternkonto an der einen Schule, Schülerkonto an der anderen), meldet die App alle an. „Heute“ zeigt eine Karte je Kind, der Kalender die Pläne aller Kinder zur Auswahl und die Termine beider Schulen.
- **Unterricht, Nachrichten und Mehr** bleiben je Kind getrennt: oben wählt man das Kind. Schreiben, Krankmeldung, Abgabe und Unterhaltungen laufen immer über das Konto dieses Kindes.
- Die Zahlen an der Leiste (Hausaufgaben, ungelesene Nachrichten) zählen alle Kinder. Einstellungen und Abmelden gelten weiter für das aktive Konto.

**4.1.0+9344** – Leiste auf allen Lese-Seiten, mehrere Konten beim Einrichten

- **Leiste unten bleibt sichtbar** auf Kursseite, Unterhaltung, Statistik und Einstellungen. Jeder Bereich merkt sich, wo man war; erneutes Antippen des Bereichs führt an seinen Anfang. „Zurück“ geht erst im Bereich zurück, dann nach „Heute“.
- **Ohne Leiste** öffnen die Seiten zum Eingeben: Neue Nachricht, Krankmeldung, Abgabe und Mensa-Bestellseite – dort steht „Schließen“ oben, und kein angefangener Text bleibt versehentlich liegen.
- **Erste Anmeldung mit mehreren Schulen:** Nach dem ersten Konto fragt die App, ob ein weiteres Kind an einer anderen Schule eingerichtet werden soll, und zeigt die bisher eingerichteten Zugänge.

**4.1.0+9343** – Fehlersuche und Aufräumen

- **Probleme erkennen ohne Inhalte:** Die App merkt sich Abstürze und Lesefehler nur auf dem Handy, ohne Namen, Noten oder Nachrichten. Unter Einstellungen → Fehlersuche steht dann „1 Problem erkannt“; der Bericht ist vor dem Senden vollständig sichtbar und lässt sich teilen (Messenger, Mail) oder auf GitHub melden. Automatisch gesendet wird nichts.
- **Debug-Export versteckt:** Er enthält echte Portalseiten und erscheint erst nach siebenmaligem Antippen der Version.
- **Zwischenspeicher räumt sich selbst auf:** Geöffnete Dateien werden nach 30 Tagen gelöscht; der Knopf „Zwischenspeicher leeren“ entfällt.
- **Mensa-Adresse vorgeschlagen:** Führt die Schule die Essensbestellung in ihrer App-Liste, schlägt die App diese Adresse beim Eintragen vor.

**4.1.0+9342** – Essen bestellen je Kind, direkt in der App

- **Eine Bestellseite je Kind:** Unter „Mehr“ steht bei mehreren Kindern je Kind ein Eintrag „Essen bestellen · Name“. Die bisher eingetragene Adresse gilt weiter, bis ein Kind eine eigene bekommt.
- **Bestellseite in der App:** Sie öffnet jetzt in der App statt im Browser und bleibt angemeldet. Steht in der eingetragenen Adresse eine Woche (…/2025/35/), öffnet die App stattdessen die aktuelle Bestellwoche, ab Freitagmittag die nächste.
- **Schutz vor Bestellung fürs falsche Kind:** War auf derselben Bestellseite zuletzt ein anderes Kind angemeldet, erscheint ein Hinweis mit „Abmelden“.
- Fremde Links der Bestellseite (z. B. Zahlungsanbieter) öffnen im Browser. „Abmelden“ in den Einstellungen meldet auch dort ab.

**4.1.0+9341** – Mehrsprachigkeit, Teil 2

- **Nachrichten, Neue Nachricht und Krankmeldung** erscheinen jetzt auch auf Englisch und Türkisch, samt Prüfhinweisen der Krankmeldung.
- Vorlagen für Nachrichten bleiben deutsch, weil die Schule Deutsch liest; in Englisch und Türkisch steht ein Hinweis dazu, die Auswahl selbst ist übersetzt.
- Datumsangaben der Krankmeldung folgen der gewählten Sprache. Was an das Portal geht, bleibt unverändert.

**4.1.0+9340**

- **Kursseite, Leistungskontrollen:** Jede Kontrolle steht als eigene Zeile mit Datum vorn, doppelte Einträge entfallen. Vorher brach die Überschrift Buchstabe für Buchstabe um.
- Die nächste Leistungskontrolle aus der Kursmappe erscheint unter „Als Nächstes“, wenn der Schulkalender keine Arbeit für das Fach nennt.

**4.1.0+9339** – Korrekturen nach der Code-Prüfung

- **Kursseite:** „Schreiben“ wählt immer die richtige Lehrkraft (vorher verschoben, wenn ein eigener Lehrername gelöscht war). Schnelles Umschalten der Halbjahre zeigt nicht mehr das falsche; Aktualisieren behält den Stand, bis der neue da ist.
- **Elternkonto:** Solange der Name des Kindes noch nicht geladen ist, steht „Dein Kind“ statt des Namens des Elternteils.
- **Benachrichtigungen:** Es gilt nur noch das Zeitfenster aus den Einstellungen; die zusätzliche feste Ruhezeit 21–6 Uhr entfällt (ein Ende um 22 Uhr wirkte vorher nicht).
- Kleinere Stabilitätskorrekturen (Dialoge und Auswahlfenster).

**4.1.0+9338** – Aufräumen, Teil 2

- **Alte Lanis-Ansichten entfernt** (rund 16 000 Zeilen): Gerüst mit Schublade, alte Bereiche (Vertretungsplan, Kalender, Stundenplan, Unterricht, Nachrichtenliste, Dateispeicher, Lerngruppen), alte Einstellungen und ungenutzte Bausteine. Unterhaltung, Abgabe, Moodle, Kontowechsel und Anmeldung bleiben.
- **Ohne Verbindung beim Start:** „Letzten Stand ansehen“ öffnet Heute und Kalender aus dem gespeicherten Stundenplan und Vertretungsplan, mit dem Hinweis „Offline · Stand …“. Nachrichten, Unterricht und Termine brauchen eine Verbindung.
- Sechs nicht mehr benötigte Bibliotheken entfernt.

**4.1.0+9337** – Aufräumen, Teil 1

- Fehlerbericht-Anbindung (Sentry) ausgebaut – sie war ohne Server ohnehin stumm; die APK wird etwas kleiner.
- Entfernt: iOS-Projekt, F-Droid-Metadaten der Original-App (6,7 MB im Repository), alte Bau-Skripte, unbenutzte Bilder und vier Dateien ohne Verwendung. Keine Änderung an der Bedienung.

**4.1.0+9336** – Sicherheitsprüfung

- **Benachrichtigungen vertraulich:** Auf dem gesperrten Handy zeigt Android nur „Schulportal“ ohne Inhalt, wenn unter Sperrbildschirm „sensible Inhalte ausblenden“ gewählt ist.
- **Keine Übertragung beim Gerätewechsel:** Konten und gespeicherte Daten gehen weder ins Cloud-Backup noch beim Umzug aufs neue Handy; dort meldet man sich neu an.
- **Kein „lanis://“-Link mehr:** Webseiten können die App nicht mehr mit eigenen Adressen öffnen; die Abgabe-Seite lädt nur Adressen aus „Mein Unterricht“.
- **Dateinamen geprüft:** Namen von heruntergeladenen Dateien können keine Pfade mehr enthalten.
- **Moodle:** Downloads nur vom Schulportal, fremde Seiten öffnen erst nach Antippen, die Anmeldung schickt das Passwort nur an Adressen des Schulportals.
- **Abmelden** entfernt auch die heruntergeladenen Dateien und die Moodle-Anmeldung.
- **Fehlersuche:** Der Bericht schwärzt alle Sitzungs-Cookies und Weiterleitungsadressen; ältere Berichtsdateien werden gelöscht; eigene Portal-Anfragen gibt es nur noch in Entwicklerversionen.
- **Mensa-Adresse** nur noch mit https und ohne Anmeldedaten in der Adresse.
- Türkisch steht in den Android-Spracheinstellungen der App zur Auswahl.

**4.1.0+9335**

- **Kleinere Downloads:** Je Prozessorart eine eigene APK – „arm64-v8a“ für fast alle Handys (etwa 20 MB statt 53 MB), „armeabi-v7a“ für ältere 32-Bit-Geräte. In Obtainium einmal die arm64-Datei wählen (APK-Filter „arm64“). Keine Änderung an der App selbst.
- Die Release-Notizen zeigen nur noch die Neuerungen der jeweiligen Version.

**4.1.0+9334**

- **Neue Kursseite** statt der bisherigen Lanis-Ansicht: getrennte Bereiche mit eigenem Kopf – Als Nächstes (nächste Stunde laut Plan, anstehende Arbeit laut Schulkalender, offene Abgaben), Lehrkraft mit „Schreiben“ und letzter Nachricht, Anwesenheit als Balken mit den Fehltagen, Verlauf zugeklappt und nach Themen gegliedert, Material gesammelt, Leistungen. Halbjahr umschaltbar, wenn das Portal es anbietet; leere Kursmappe mit Hinweis.
- **Unterricht neu geordnet:** offene Hausaufgaben oben, Fächer in Reihenfolge und Farbe des Wochenplans mit Marken für offene Hausaufgabe und Fehlstunden, weitere Angebote (Ganztag u. a.) eingeklappt.
- **Marken in der unteren Leiste:** offene Hausaufgaben, ungelesene Nachrichten, „!“ bei Ausfall heute oder morgen; Leiste etwas flacher.
- **Schriftgrößen** Klein, Normal, Groß – jede etwa 2 Punkte kleiner als bisher; „Sehr groß“ entfällt.
- Alle neuen Texte in Deutsch, Englisch und Türkisch.

**4.1.0+9333**

- **Sprachen Deutsch, Englisch und Türkisch:** Neue Wahl unter Einstellungen → Darstellung → Sprache (wie das Handy, Deutsch, English, Türkçe). Übersetzt sind in diesem Schritt Heute, Kalender (Tag, Woche, Termine), Mehr, Einstellungen, die Benachrichtigungen und alle übernommenen Lanis-Seiten; Unterricht, Nachrichten und Krankmeldung folgen. Datum und Wochentage stehen in der gewählten Sprache. Inhalte der Schule (Fächer, Termine, Nachrichten) bleiben, wie die Schule sie schreibt.
- Die Texte stehen in eigenen Sprachdateien, getrennt vom Code. Ein Handy in einer anderen Sprache bekommt Englisch.

**4.1.0+9332**

- **Neues Repository mit bereinigter Projektgeschichte:** Ältere Stände mit Schul- und Personendaten sind nicht mehr öffentlich. Keine Änderung an der App; die Version zeigt, dass Updates über Obtainium mit demselben Schlüssel weiterlaufen.

**4.1.0+9331**

- **Einstellungen neu** im Stil der App, nur noch das Nötige: Konto (Benutzerdaten, wechseln/hinzufügen, abmelden), Benachrichtigungen (an/aus, Vertretungen, Nachrichten, Zeitfenster), Darstellung (hell/dunkel/wie das Handy, Schriftgröße), Daten (Termine abonnieren, Zwischenspeicher), Über die App (Version, Neuerungen, Datenschutz, Quellcode und Lizenz), Fehlersuche (Debug-Export, eingeklappt). Entfallen: Sprache, Farbschemata, Moodle, Stundenplan-Anpassung, Lanis-Mitwirkende.
- **Bisherige Ansicht entfernt:** Die App startet immer mit der neuen Oberfläche; „Alle Funktionen“ und der Start-Schalter sind weg.
- **Kalender zeigt Vertretungen:** Ausfall, Vertretung und Raumwechsel der laufenden Woche stehen jetzt auch in Tag und Woche, nicht nur unter „Heute“.
- **Schriftgröße gilt überall**, auch auf Kursseite, Unterhaltung, Krankmeldung und Einstellungen.
- „Mehr“ ist aufgeräumt: Krank melden, Essen bestellen, Lernplattform (falls angeboten), Schulportal im Browser, Einstellungen.

**4.1.0+9330**

- **Datenschutz:** Schulnamen, Schulnummer, Räume und der Caterer stehen nicht mehr im öffentlichen Code. Die Fachnamen-Zuordnung „TXT → Projekt Text“ stand fest im Code an der Schulnummer; jetzt erkennt die App den Fachnamen allgemein über die Lehrkräfte des passenden Kurses in „Mein Unterricht“.
- **Essen bestellen:** Die Adresse der Bestellseite trägst du einmal selbst ein (Mehr → Essen bestellen); sie bleibt nur auf dem Gerät. Danach erscheint der Knopf wieder auf der Kinderkarte.
- **Hintergrund-Abfrage abgesichert:** Schlägt bei einem Konto die Anmeldung oder eine Abfrage fehl, wird dieses Konto übersprungen und sauber abgemeldet; die übrigen Konten werden weiter geprüft.

**4.1.0+9329**

Korrekturen nach der Nachprüfung von 9328:
- **Laden konnte dauerhaft hängen bleiben** (in 9328 neu eingeführt): Lief ein Ladedurchgang ohne eine einzige Abfrage durch – etwa kurz vor der Anmeldung oder nach einem Kontowechsel –, blieb jedes weitere Laden gesperrt und „Erneut versuchen“ wirkungslos. Der Lader ist jetzt ein eigener, getesteter Baustein.
- Nachladen alle 10 Minuten nur noch bei geöffneter App und nur Vertretungen und Nachrichten; beim Zurückkehren nach mehr als 10 Minuten alles.
- Nachrichten: Aktualisieren und das Nachladen nach dem Lesen laufen über denselben Lader; ein Fehler zeigt „Erneut versuchen“ statt endlos „Wird geladen …“.
- Benachrichtigungen: Die ganze Aufgabe ist gegen Fehler abgesichert, andere Konten werden weiter geprüft. Elternkonto ohne geladene Kinder: „… bei deinem Kind“.

**4.1.0+9328**

Korrekturen nach einer unabhängigen Prüfung des Codes:
- „Heute“ und die anderen Bereiche laden alle 10 Minuten und beim Zurückkehren in die App neu. Vorher konnte das Nachladen nach einem Besuch der bisherigen Ansicht stehen bleiben.
- Schlägt eine Quelle fehl (z. B. Neuanmeldung), werden die übrigen trotzdem geladen; Unterricht und Nachrichten zeigen dann „Erneut versuchen“ statt endlos „Wird geladen …“.
- „Ziehen zum Aktualisieren“ während eines laufenden Ladens wird nachgeholt statt verworfen.
- Nachricht schreiben: Ist die Nachricht beim Portal angekommen, meldet die App keinen Fehler mehr, nur weil das anschließende Nachladen der Liste scheitert (verhinderte doppeltes Senden).
- Benachrichtigungen: Ein Fehler bei einem Konto bricht die Prüfung der übrigen Konten nicht mehr ab; Schülerkonten heißen „Heute in der Schule“.
- Menü der bisherigen Ansicht: Trennlinien wieder an der richtigen Stelle.

**4.1.0+9327**

- **Benachrichtigungen neu** (ersetzen die bisherige Vertretungsplan-Meldung, die jede Zeile der ganzen Klasse schickte):
  - **Heute:** Ausfall, Vertretung oder Raumwechsel einer noch kommenden Stunde des Kindes – sobald es im Plan steht.
  - **Vorabend ab 19 Uhr:** Änderungen für den nächsten Schultag plus große Termine (Arbeiten, schulfreie Tage, Fristen, Elternabende, Feste, Ausflüge). Freitagabend nichts, Sonntagabend für Montag.
  - **Ruhezeit 21–6 Uhr.** Nichts kommt doppelt; kommt etwas hinzu, ersetzt eine vollständige Meldung die vorige.
  - Es gelten dieselben Stunden und Gruppen wie in „Heute“ (andere Projekt-Text-Gruppen bleiben stumm).
- Standard der Benachrichtigungszeiten jetzt **alle Tage 6–21 Uhr** (vorher angezeigt Mo–Fr 6:30–15:00). Wer die Zeiten selbst eingestellt hat, behält seine Werte – für die Vorabend-Meldung muss das Ende nach 19 Uhr liegen.
- Grenze: Android lässt die App nur etwa alle 15–60 Minuten nachsehen; eine Meldung kann entsprechend später kommen.

**4.1.0+9326**

- **Die neue Oberfläche ist jetzt die Startseite.** Nach dem Öffnen und nach einem Kontowechsel erscheint direkt „Heute“.
- Die bisherige Ansicht bleibt vollständig erreichbar: „Mehr“ → „Alle Funktionen“. „Zurück“ führt von dort wieder in die neue Oberfläche. Im Menü der bisherigen Ansicht steht oben „Neue Oberfläche“.
- Unter „Mehr“ lässt sich der Start umstellen („Mit der neuen Oberfläche starten“).
- „Zurück“ in der neuen Oberfläche führt erst nach „Heute“, erst dann aus der App.
- Kurs- und Kalenderseiten aus der neuen Oberfläche öffnen sich darüber; „Zurück“ kehrt an dieselbe Stelle zurück.

**4.1.0+9325**

- **Nachrichten** im neuen Stil: Liste der Unterhaltungen, ungelesene hervorgehoben mit Punkt, oben „Neue Nachricht“. Lesen und Antworten öffnet die gewohnte Unterhaltung.
- **Neue Nachricht in drei Schritten:** (1) An wen? – Lehrkräfte aus dem Unterricht des Kindes mit ihren Fächern zum Antippen, Fachlehrkräfte oben, große Ganztags-Teams unten; freie Suche als Rückfall. (2) Worum geht es? – Vorlagen „Frage zur Hausaufgabe“, „Bitte um Rückruf“, „Termin vereinbaren“. (3) Senden – mit Rückfrage „Nachricht senden?“.
- Ob das Portal eine Lehrkraft für Eltern freigibt, zeigt sich beim Antippen; wenn nicht: „Über das Portal nicht erreichbar“.

**4.1.0+9324**

- **Unterricht** im neuen Stil: oben die Hausaufgaben (offene gelb, erledigte darunter), darunter alle Kurse mit Lehrkräften, neuestem Eintrag der Kursmappe und Fehlzeiten. Antippen öffnet die Kursseite mit allen Einträgen.
- Kurse heißen kurz nach dem Fach („Naturwissenschaften“ statt „Naturwissenschaften 06 … (061NAWI05-IGS)“); lange Lehrerlisten werden gekürzt („… +4“).
- Auf der Kinderkarte in „Heute“ erscheint die Zahl offener Hausaufgaben und ungelesener Nachrichten; Antippen führt in den jeweiligen Bereich.

**4.1.0+9323**

- Neue Leiste nach dem Konzept vom 17.10.: **Heute · Kalender · Unterricht · Nachrichten · Mehr**. Jedes Ding hat einen Ort, „Heute“ zeigt nur Auszüge.
- **Kalender** vereint Stundenplan und Termine: Tag, Woche und neu „Termine“ (alle Schultermine der nächsten vier Monate, nach Tagen gruppiert, Arbeiten und schulfreie Tage markiert, mehrtägige mit „bis …“).
- **Mittagessen:** „Kein Essen …“ erscheint nicht mehr als Kachel unter „Demnächst“, sondern als Hinweis an der Kinderkarte (ab 14 Uhr der von morgen). Neuer Knopf **„Essen bestellen“** öffnet die Bestellseite der Mensa im Browser.
- **Mehr:** Krank melden, Essen bestellen, Termine in eigenen Kalender, Schulportal im Browser, alle bisherigen Funktionen, Einstellungen, Schriftgröße.
- **Moodle** erscheint nur noch, wenn die Schule es anbietet (an manchen Schulen nicht).
- Alle Bereiche teilen sich die Daten: Stundenplan, Unterricht, Vertretungen, Kalender und Nachrichten werden einmal und nacheinander geladen. Ziehen nach unten lädt neu.
- Unterricht und Nachrichten im neuen Stil folgen in den nächsten Versionen; bis dahin führt ein Knopf in die bisherige Ansicht.

**4.1.0+9322**

- Vorschau „Heute“ zeigt jetzt **echte Daten** des angemeldeten Kontos: den heutigen Plan mit „Jetzt“, „Danach“ und Tagesleiste, dieselben Gruppen und Lehrernamen wie unter „Plan“.
- Vertretungen aus dem Vertretungsplan erscheinen im Kasten „Wichtig heute und morgen“, als Punkte in der Wochenleiste und in der Tagesliste (Ausfall rot, Raumwechsel und Vertretung gelb). Vertretungen der anderen Projekt-Text-Gruppen werden übergangen. Fehlt bei Doppelbesetzung nur eine Lehrkraft, gilt die Stunde nicht als Ausfall.
- „Demnächst“ zeigt die Termine der nächsten 14 Tage aus dem Schulkalender, Arbeiten und Lernkontrollen als solche erkannt. Termine für andere Jahrgänge („8-10 Klassen …“) werden ausgeblendet.
- „Krank melden“ öffnet die Krankmeldung (weiterhin nur prüfen).
- Tagesliste: „1.“ statt „1. Block“ in der schmalen Spalte.

**4.1.0+9321**

- Gruppen werden automatisch vorgewählt, wenn „Mein Unterricht“ sie verrät. Projekt Text: Der Kurs nennt zwei Lehrkräfte, beide stehen in jeder TXT-Stunde – die App zeigt beide als eine Stunde. Ändern über das Tauschen-Symbol; die Wahl ist mit „Erkannt über den Kurs in „Mein Unterricht““ markiert.
- Fachnamen: TXT = „Projekt Text“ (an einer Schule), ÄSTH = „Ästhetik“, KL = „Klassenstunde“.
- Schriftgröße in der Vorschau unter „Mehr“: Normal / Groß / Sehr groß, alle Stufen größer als bisher.
- Lehrernamen fett.
- Unbekannte Kürzel lassen sich benennen: Stunde antippen → „Name für …“. Die Namen bleiben nur auf diesem Gerät, je Konto.
- Titel „Stundenplan“ bricht bei großer Schrift nicht mehr mitten im Wort um.

**4.1.0+9320**

- Vorschau „Plan“ zeigt jetzt den **echten Stundenplan** des angemeldeten Kontos (Einstellungen → „Neue Oberfläche (Vorschau)“ → Plan). „Heute“ bleibt vorerst mit Beispieldaten.
- Lehrkräfte mit Namen aus „Mein Unterricht“, Fächer ausgeschrieben, wo das Kürzel eindeutig ist (sonst bleibt das Kürzel, z. B. TXT).
- Doppelbesetzung (gleiches Fach, gleicher Raum, zwei Lehrkräfte) wird eine Stunde; nur echte Parallelgruppen erscheinen unter „Gruppe wählen“.
- Die Gruppenwahl wird je Konto gespeichert.

**4.1.0+9319**

- Krankmeldung: neuer Knopf **„Beim Portal prüfen (sendet nichts)“**. Das Portal sagt, ob es die Meldung annehmen würde, oder nennt seine Gründe. Es wird nichts gespeichert, die Schule sieht davon nichts.
- Absenden bleibt gesperrt.

**4.1.0+9318**

- Krankmeldung wie im Portal: „Abwesend“ = Von- und Bis-Tag ohne Blöcke, „Verspätet“ = ein Tag („Am“) mit Block von–bis.
- Kommentarfeld zeigt die Warnung des Portals „Bitte keine Gesundheitsdaten eingeben“.
- Bestehende Meldungen der Schule erscheinen unter der Maske.
- Abschicken bleibt gesperrt, bis es ausdrücklich freigegeben ist.

**4.1.0+9317**

- Wochenansicht: Zeilen höchstens 72 dp hoch; bei wenigen Blöcken nicht mehr aufgebläht, unten bleibt Platz frei.
- Lehrkräfte ausgeschrieben statt Kürzel: Tagesansicht und Gruppenwahl mit Vor- und Nachname, Wochenraster mit Nachname. Die Namen kommen später aus „Mein Unterricht“; wer dort nicht vorkommt (z. B. Vertretung), bleibt als Kürzel.

**4.1.0+9316**

- Vorschau: Inhalte laufen nicht mehr unter die untere Leiste, sie enden darüber.
- Wochenansicht neu: Die ganze Woche passt ohne Scrollen auf den Bildschirm, Zeilenhöhe nach freiem Platz. Breitere Zellen mit lesbaren Fachnamen, Raum und Lehrkraft. Pausen als sichtbare Lücke, heutige Spalte hinterlegt mit Jetzt-Linie. Jedes Fach eines Kindes bekommt eine eigene Farbe.
- „Gruppe wählen“ nur noch als eine Zeile über dem Plan.

**4.1.0+9315**

- Vorschau „Plan“ im neuen Stil: je Kind umschaltbar, Tagesansicht (Uhrzeit links, laufende Stunde mit Fortschritt, Vertretung/Ausfall farbig, Pausen) und Wochenraster (Doppelstunden als ein Block, Farbe je Fach, Tag antippen öffnet ihn).
- Neu: **Gruppe wählen** bei Parallelgruppen (z. B. vier Textil-Gruppen oder Religion/Ethik). Einmal je Fach gewählt, zeigt der Plan nur noch die eigene Gruppe – statt jede Kachel einzeln auszublenden.

**4.1.0+9314**

- Vorschau „Heute“ im neuen Stil (Entwurf A + C): Begrüßung, Wochenleiste mit Terminpunkten, Kasten „Wichtig heute und morgen“ für alle Kinder, je Kind eine Karte mit „Jetzt“ und Restzeit, Tagesleiste und aufklappbarem Tag (Doppelstunden zusammengefasst, längere Pausen sichtbar), „Demnächst“ als Kacheln, schwebende Leiste unten.
- Eigene Schrift (Manrope), fest eingebaut; hell und dunkel nach Handy-Einstellung.
- Behoben (nur Vorschau): Datumsrechnung über die Zeitumstellung, Leiste bei großer Systemschrift.

**4.1.0+9313**

- Neu: **Vorschau der neuen Oberfläche** unter Einstellungen → „Neue Oberfläche (Vorschau)“. Erster Entwurf der Seite „Heute“: je Kind eine Karte (laufende und nächste Stunde, Vertretungen und Ausfälle, Hausaufgaben, Nachrichten, Krankmeldung) und darunter „Demnächst“ für alle Kinder. Nur erfundene Beispieldaten, keine Abfragen beim Portal.
- Neue untere Leiste im Entwurf: Heute · Plan · Nachrichten · Termine · Mehr (die übrigen Ziele folgen nach Abnahme).

**4.1.0+9312**

- Behoben: Die Krankmeldung ließ sich nicht ganz nach unten scrollen; der letzte Knopf lag halb unter der Navigationsleiste.

**4.1.0+9311**

- Neu für Elternkonten: **Krankmeldung** im Menü, wenn die Schule das Modul anbietet. Die Maske übernimmt Kind, Art (abwesend/verspätet), Blöcke und die erlaubten Tage direkt vom Portal und prüft die Eingaben.
- Abschicken ist noch gesperrt, bis wir es gemeinsam getestet haben. „Vorschau der Portal-Felder“ zeigt, was gesendet würde.
- Debug-Export „Abwesenheiten“ liest zusätzlich das Portal-Skript der Seite (nur lesen). Daraus geht hervor, wie das Portal die Meldung abschickt.

**4.1.0+9310**

- Neu für Elternkonten: **Unterricht**, also die Kurse des Kindes mit aktuellen Einträgen, Kursseiten und Anwesenheiten. Bei mehreren Kindern an einer Schule steht der Vorname vor dem Kurs.
- Eltern sehen den Hausaufgaben-Stand, abhaken kann ihn nur das Kind. Abgaben gibt es im Elternkonto nicht.

**4.1.0+9309**

- Behoben: Beim Elternkonto zeigte „Stundenplan“ nur einen Fehlerhinweis. Die Navigation sprang noch auf den Pfad für Schülerkonten.

**4.1.0+9308**

- Debug-Export: neuer Punkt „Mein Unterricht: Kursseiten“, öffnet die ersten zwei Kurse nur lesend. Nötig, um Hausaufgaben und Kurse für Elternkonten zu bauen.

**4.1.0+9307**

- Neu für Elternkonten: **Stundenplan** des Kindes (bisher nur für Schülerkonten).

**4.1.0+9306**

- Debug-Export fragt nur noch Module ab, die die Schule freigeschaltet hat. Ruft man ein anderes auf, beendet das Portal die Anmeldung, und alle weiteren Abfragen wären leer gewesen.
- Neuer Export-Punkt „Abwesenheiten“ (Krankmeldung), nur die Ansicht, es wird nichts abgeschickt.
- Zurückgenommen: die Cookie-Korrektur aus 4.1.0+9305. Der Export hat gezeigt, dass das Portal die Sitzung absichtlich beendet und keinen Schlüssel austauscht; die Korrektur war wirkungslos.

**4.1.0+9305**

- Debug-Export schwärzt den Sitzungsschlüssel und prüft die Anmeldung auch nach allen Abfragen.
- (Zurückgenommen in 9306: vermutete Korrektur zum Sitzungsschlüssel, sie war wirkungslos.)

**4.1.0+9304**

- Debug-Export prüft vorab, ob die Anmeldung beim Portal noch gilt, und meldet sich bei Bedarf einmal neu an. Das Ergebnis steht im Export, ohne Sitzungsschlüssel.

**4.1.0+9303**

- Debug-Export um die „App-Übersicht der Schule“ ergänzt: Sie zeigt, welche Portal-Module die Schule freigeschaltet hat (z. B. Krankmeldung).

**4.1.0+9302**

- Debug-Export wieder erreichbar: jetzt direkt unter Einstellungen, statt wie bisher über die entfernte Seite „Fehlerberichte“.

**Erste Fassung (Basis Lanis-Mobile 4.1.0)**

- Eigener Name „Schulportal“ und eigene App-ID. Die App läuft neben dem Original und ersetzt es nicht.
- Keine Login-Statistik mehr an Server der Original-Entwickler.
- Keine automatischen Fehlerberichte; Einstellung und Login-Häkchen sind entfernt.
- Update-Hinweise, Quellcode- und Fehler-Links zeigen auf dieses Repository.
- Absturzbericht per Mail-Entwurf ohne festen Empfänger, nicht öffentlich.
- Gegenüber dem Schulportal meldet sich die App mit eigenem Namen.
- Eigener Datenschutzhinweis: PRIVACY.md.
