/// Identität dieses Forks („Schulkompass“ von rw-apps, bis 9472 „Schulportal“) an EINER Stelle.
///
/// Ursache: Das Original (lanis-mobile/lanis) hat Namen, Repo-, Store- und
/// Kontaktadressen über ~12 Dateien verstreut (u. a. whats_new.dart,
/// about.dart, debug_export.dart, lanis_bootstrap.dart, school_selector.dart).
/// Im Fork würden diese Stellen sonst auf das Original zeigen: Die
/// Update-Prüfung meldete deren Releases und schickte Nutzer in den Play Store
/// zur Original-App, der Debug-Export nannte deren E-Mail als Empfänger.
///
/// Grenze: Jede betroffene Datei referenziert nur noch diese Konstanten. Beim
/// Nachziehen des Originals (git merge upstream/main) bleiben Konflikte so auf
/// eine Zeile je Datei begrenzt. Neue Upstream-Stellen mit „alessioc42“ oder
/// „lanis-mobile“ fängt der Test test/fork_identity_test.dart ab.
library;

/// Anzeigename in App-Leiste und Task-Umschalter (Launcher-Name steht in
/// android/app/src/main/AndroidManifest.xml, android:label).
///
/// Umbenennung 04.11.26 (Build 9473): „Schulportal“ war der Name des Portals
/// selbst und ließ die App wie ein offizielles Angebot des Landes wirken.
/// Repo und APK-Dateien folgten am 08.11.26 (Build 9501): github.com/
/// rw-apps/schulkompass, schulkompass-v….apk. GitHub leitet die alte Adresse
/// (rw-apps/schulportal) weiter, auch für die Release-Schnittstelle, die
/// Obtainium abfragt. Grenze: Die Weiterleitung endet, sobald unter rw-apps
/// wieder ein Repo „schulportal“ entsteht. App-ID (io.github.rwapps.sph) und
/// interne Kennungen (Kanal „schulportal/…“, Widget-Schema, Format der
/// Geräteübertragung) bleiben – ein neuer Paketname hätte eine zweite,
/// getrennte App erzeugt, neue Kennungen alte Dateien und Widgets ungültig.
const forkAppName = 'Schulkompass';

/// GitHub-Repo des Forks: Quelle für Update-Prüfung, Fehlermeldungen, Quellcode.
const forkRepo = 'rw-apps/schulkompass';
const forkRepoUrl = 'https://github.com/$forkRepo';
const forkIssuesUrl = '$forkRepoUrl/issues';
const forkReleasesApiUrl = 'https://api.github.com/repos/$forkRepo/releases';
const forkLatestReleaseUrl = '$forkRepoUrl/releases/latest';

/// Datenschutzhinweis des Forks (liegt als PRIVACY.md im Repo).
const forkPrivacyPolicyUrl = '$forkRepoUrl/blob/main/PRIVACY.md';

/// Herkunft — Pflichthinweis (GPL-3.0 §5: geänderte Fassung kenntlich machen).
const upstreamName = 'Lanis-Mobile';
const upstreamRepoUrl = 'https://github.com/lanis-mobile/lanis';

/// User-Agent gegenüber dem Schulportal.
///
/// Ursache: Das Original meldet sich als „Lanis-Mobile/v…“. Der Fork ist eine
/// andere App mit eigener Versionszählung; unter fremdem Namen aufzutreten
/// würde Fehler im Portal-Log dem Original zuschreiben.
String forkUserAgent(String version, String buildNumber) =>
    'Schulkompass-rw/v${appVersionLabel(version, buildNumber)} '
    '(fork of $upstreamName)';

/// „4.1.0+9452“ aus PackageInfo. Ursache: Seit 30.10.26 trägt der
/// Versionsname den Build schon (android/app/build.gradle, versionName);
/// angehängt wird die Build-Nummer nur noch bei älteren Builds oder auf
/// Plattformen ohne diesen Namen (iOS) – sonst stünde „4.1.0+9452+11452“
/// da. Grenze: buildNumber ist auf Android der versionCode mit
/// ABI-Aufschlag (11452), nicht die Release-Nummer.
String appVersionLabel(String version, String buildNumber) =>
    version.contains('+') ? version : '$version+$buildNumber';
