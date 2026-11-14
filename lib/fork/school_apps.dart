import 'package:flutter/material.dart';

import 'report_terms.dart';
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
      RegExp(r'^index\.php\?(?:.*&)?a=f(?:&|$)').hasMatch(link);

  /// Technische Kennung ohne Namen („wahl.php“, „Weiterleitung“) – nur sie
  /// geht in Berichte, der Name könnte die Schule verraten.
  String get module => external ? 'Weiterleitung' : link.split('?').first;

  /// Zieladresse; null bei kaputtem Link (z. B. „%“ ohne Hexzahl).
  Uri? get uri => Uri.tryParse('https://start.schulportal.hessen.de/$link');
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
/// Schulen der Familie). Andere meldet [schoolApps] als Begriff
/// (TermLog, nur mit erweiterter Zustimmung), damit neue Angebote anderer
/// Schulen auffallen – etwa ein Klausurenplaner.
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
    final link = '${e['link'] ?? ''}'.trim();
    if (name.isEmpty || link.isEmpty || link.startsWith('http')) continue;
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
    if (!knownModules.contains(app.module)) {
      TermLog.instance.note('startseite.php', 'App', app.module);
    }
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
