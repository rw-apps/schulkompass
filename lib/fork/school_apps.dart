import 'package:flutter/material.dart';

import 'school_links.dart' show offersMoodle;

/// Ein Angebot aus der App-Liste des Portals (Session.travelMenu,
/// startseite.php?a=ajax&f=apps), das die App nicht selbst anzeigt.
class SchoolApp {
  const SchoolApp({
    required this.name,
    required this.link,
    required this.folder,
  });

  /// Name wie im Portal („Wahltool“).
  final String name;

  /// Adresse relativ zum Portal („wahl.php“, „index.php?a=f&e=l1“).
  final String link;

  /// Rubrik wie im Portal („Organisation“).
  final String folder;

  /// Weiterleitung des Portals zu einem fremden Angebot
  /// (index.php?a=f&e=…, z. B. Office365, bettermarks).
  bool get external =>
      absolute || RegExp(r'^index\.php\?(?:.*&)?a=f(?:&|$)').hasMatch(link);

  /// Technische Kennung ohne Namen („wahl.php“, „Weiterleitung“) – nur sie
  /// geht in Berichte, der Name könnte die Schule verraten.
  String get module => external ? 'Weiterleitung' : link.split('?').first;

  /// Zieladresse; absolute Links der Schule (https://…) unverändert.
  /// null nur, wenn Uri.tryParse scheitert (selten; „%zz“ etwa wird zu
  /// „%25zz“ und gilt als gültig).
  Uri? get uri => absolute
      ? Uri.tryParse(link)
      : Uri.tryParse('https://start.schulportal.hessen.de/$link');

  /// Link auf eine fremde Seite direkt in der App-Liste (ohne Portal).
  /// Schema ohne Rücksicht auf Groß-/Kleinschreibung („HTTPS://“ zählt
  /// mit; Prüfbefund 14.11.26).
  bool get absolute {
    final l = link.toLowerCase();
    return l.startsWith('http://') || l.startsWith('https://');
  }
}

/// Module, die die App selbst zeigt (Kalender, Unterricht, Nachrichten,
/// Stundenplan, Vertretungsplan, Krankmeldung, Dateien der Schule) – sie
/// stehen nicht noch einmal unter „Angebote der Schule“.
const nativeModules = {
  'kalender.php',
  'meinunterricht.php',
  'nachrichten.php',
  'stundenplan.php',
  'vertretungsplan.php',
  'abwesenheitsmeldung.php',
  'dateispeicher.php',
};

/// Module, die in Exporten schon vorkamen (Exporte 16.–28.10.26, beide
/// Schulen der Familie). Nur sie gehen mit ihrem Dateinamen ins
/// Fehlerprotokoll (PortalAppPage), andere als „App“. Neue Module anderer
/// Schulen zeigt der Berichtskontext (noteLoadTerms, report_terms.dart);
/// als Begriff meldet sie die App bewusst nicht (Prüfung 08.11.26, dort
/// begründet; Nachprüfung 14.11.26).
const knownModules = {
  ...nativeModules,
  'wahl.php',
  'oberstufenwahl.php',
  'videokonferenz.php',
  'dateiverteilung.php',
  'schulradeln.php',
  'usesheets.php',
  'Weiterleitung',
};

/// Angebote der Schule je Rubrik, in der Reihenfolge des Portals.
///
/// Ursache (Wunsch 14.11.26: „immer alles anzeigen“): Statt fester Einträge
/// kommt die Liste aus dem App-Menü des Portals, das die Anmeldung ohnehin
/// lädt – neue Angebote einer Schule erscheinen ohne neue App-Version. Je
/// Adresse einmal (das Portal führt manche in zwei Rubriken, z. B. „Start“
/// und „Schule“); die Rubrik „Start“ ist nur eine Auswahl und zählt nicht.
/// Ohne die Module der App ([nativeModules]) und ohne Moodle (eigener
/// Eintrag „Lernplattform“, offersMoodle).
/// Grenze: Eine Rubrik ohne Namen landet unter [otherFolder].
Map<String, List<SchoolApp>> schoolApps(
  List<dynamic> travelMenu, {
  String otherFolder = 'Sonstiges',
}) {
  final out = <String, List<SchoolApp>>{};
  final seen = <String>{};
  for (final e in travelMenu) {
    if (e is! Map) continue;
    final name = '${e['Name'] ?? ''}'.trim();
    // Absoluter Link ins Portal selbst wird relativ: so greift der Filter
    // der App-Module, und das Angebot öffnet angemeldet in der App statt
    // ohne Anmeldung im Browser. Ursache (Prüfbefund 14.11.26); ob das
    // Portal solche Links liefert, ist offen – die Exporte (16.–28.10.26)
    // enthalten keine absoluten Links.
    final raw = '${e['link'] ?? ''}'.trim();
    final portal = RegExp(
      r'^https?://start\.schulportal\.hessen\.de/',
      caseSensitive: false,
    );
    final link = raw.replaceFirst(portal, '');
    // Absolute Links (https://…) zählen mit (Wunsch „immer alles anzeigen“,
    // Nachprüfung 14.11.26); sie öffnen direkt im Browser (more/
    // portal_app_page.dart ist nur fürs Portal).
    if (name.isEmpty || link.isEmpty) continue;
    if (offersMoodle([e])) continue;
    final folders = [
      for (final f in (e['Ordner'] is List ? e['Ordner'] as List : const []))
        '$f'.trim(),
    ].where((f) => f.isNotEmpty && f != 'Start').toList();
    final app = SchoolApp(
      name: name,
      link: link,
      folder: folders.isEmpty ? otherFolder : folders.first,
    );
    if (nativeModules.contains(app.module) || !seen.add(link)) continue;
    (out[app.folder] ??= []).add(app);
  }
  return out;
}

/// Symbol je Modul; fremde Angebote ein Globus.
IconData schoolAppIcon(SchoolApp a) => switch (a.module) {
  'wahl.php' => Icons.how_to_vote_outlined,
  'oberstufenwahl.php' => Icons.checklist,
  'videokonferenz.php' => Icons.videocam_outlined,
  'dateiverteilung.php' => Icons.file_copy_outlined,
  'schulradeln.php' => Icons.pedal_bike,
  'usesheets.php' => Icons.help_outline,
  'Weiterleitung' => Icons.public,
  _ => Icons.apps_outlined,
};

/// Symbol je Rubrik (Namen der Schulen frei, die üblichen bekannt).
IconData schoolFolderIcon(String folder) => switch (folder.toLowerCase()) {
  'organisation' => Icons.business_center_outlined,
  'unterricht' => Icons.menu_book_outlined,
  'allgemein' => Icons.info_outline,
  'schule' => Icons.school_outlined,
  'sonstiges' => Icons.category_outlined,
  _ => Icons.folder_outlined,
};
