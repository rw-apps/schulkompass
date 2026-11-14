// Angebote der Schule aus der App-Liste des Portals (Wunsch 14.11.26).
// Erfundene Einträge im Aufbau von startseite.php?a=ajax&f=apps.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/school_apps.dart';
import 'package:lanis/fork/ui/more/more_page.dart';

Map<String, Object> _e(String name, String link, List<String> folders) => {
  'Name': name,
  'Farbe': '123456',
  'Logo': 'fa fa-x',
  'Ordner': folders,
  'link': link,
};

void main() {
  test('Rubriken wie im Portal, ohne Module der App, je Adresse einmal', () {
    final apps = schoolApps([
      _e('Kalender', 'kalender.php', ['Allgemein']),
      _e('Wahltool', 'wahl.php', ['Organisation']),
      _e('Mailprogramm', 'index.php?a=f&e=l1', ['Organisation']),
      _e('Notfall', 'index.php?a=f&e=l11', ['Schule', 'Start']),
      _e('Rechentrainer', 'index.php?a=f&e=t9-1', ['Unterricht']),
      _e('Radeln', 'schulradeln.php', ['Schule']),
      _e('Radeln', 'schulradeln.php', ['Sonstiges']),
      _e('Lernplattform', 'index.php?a=f&e=moodle', ['Unterricht']),
      _e('Ohne Ordner', 'usesheets.php', []),
      'kaputt',
    ], otherFolder: 'Sonstiges');
    expect(apps.keys, ['Organisation', 'Schule', 'Unterricht', 'Sonstiges']);
    expect(apps['Organisation']!.map((a) => a.name), [
      'Wahltool',
      'Mailprogramm',
    ]);
    expect(apps['Schule']!.map((a) => a.name), ['Notfall', 'Radeln']);
    expect(apps['Unterricht']!.map((a) => a.name), ['Rechentrainer']);
    expect(apps['Sonstiges']!.single.name, 'Ohne Ordner');
    final mail = apps['Organisation']![1];
    expect(mail.external, isTrue);
    expect(mail.module, 'Weiterleitung');
    expect(
      mail.uri.toString(),
      'https://start.schulportal.hessen.de/index.php?a=f&e=l1',
    );
    expect(apps['Organisation']!.first.module, 'wahl.php');
    const odd = SchoolApp(name: 'X', link: 'index.php?a=foo', folder: 'Y');
    expect(odd.external, isFalse);
  });

  testWidgets('Mehr: eine Zeile je Rubrik, Angebote auf der Unterseite', (
    t,
  ) async {
    var opened = '';
    MoreEntry e(String l, {bool ext = false}) => MoreEntry(
      icon: Icons.apps,
      label: l,
      external: ext,
      onTap: () => opened = l,
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: MorePage(
            sections: [
              MoreSection('Organisation', Icons.business_center, [
                e('Wahltool'),
                e('Mailprogramm', ext: true),
              ]),
              const MoreSection('Leer', Icons.folder, []),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Angebote der Schule'), findsOneWidget);
    expect(find.text('Wahltool, Mailprogramm'), findsOneWidget);
    expect(find.text('Leer'), findsNothing);
    await t.tap(find.text('Organisation'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    await t.tap(find.text('Wahltool'));
    expect(opened, 'Wahltool');
  });
}
