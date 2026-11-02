import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/mensa_catalog.dart';
import 'package:lanis/fork/onboarding/onboarding_kit.dart' show OnbButton;
import 'package:lanis/fork/school_links.dart' show normalizeMensaUrl;
import 'package:lanis/fork/ui/mensa/mensa_sheet.dart';

// Vorauswahl des Caterers (Wunsch 02.11.26). Erfundene Kataloge, damit die
// Tests nicht an der Recherche hängen; nur die Form des echten Katalogs
// wird geprüft.
const _a = MensaCaterer(
  key: 'a',
  name: 'Caterer A',
  url: 'https://www.a-essen.example/login',
  schools: {'1001'},
);
const _b = MensaCaterer(
  key: 'b',
  name: 'Plattform B',
  url: 'https://www.plattform.example/b-mandant/login.php',
  prefix: '/b-mandant',
  schools: {'1002', '1003'},
);
const _c = MensaCaterer(
  key: 'c',
  name: 'Plattform C',
  url: 'https://www.plattform.example/b/login.php',
  prefix: '/b',
  schools: {'1003'},
);
const _cat = [_a, _b, _c];

void main() {
  test('Zuordnung über Schulnummer, auch zwei Caterer', () {
    expect(mensaCaterersForSchool('1001', _cat), [_a]);
    expect(mensaCaterersForSchool('1003', _cat), [_b, _c]);
    expect(mensaCaterersForSchool('9999', _cat), isEmpty);
  });

  test('Adresse gehört zum Caterer: Domain und Mandant', () {
    expect(mensaCatererForUrl('https://a-essen.example/kunden/1', _cat), _a);
    expect(
      mensaCatererForUrl('https://www.plattform.example/b-mandant/x', _cat),
      _b,
    );
    // „/b“ ist nicht „/b-mandant“.
    expect(mensaCatererForUrl('https://plattform.example/b/login', _cat), _c);
    expect(mensaCatererForUrl('https://plattform.example/zz/', _cat), isNull);
    expect(mensaCatererForUrl(null, _cat), isNull);
  });

  test('echter Katalog: gültige Adressen, eindeutige Kennungen', () {
    final keys = {for (final c in mensaCatalog) c.key};
    expect(keys, hasLength(mensaCatalog.length));
    for (final c in mensaCatalog) {
      expect(normalizeMensaUrl(c.url), isNotNull, reason: c.key);
      expect(mensaCatererForUrl(c.url), same(c), reason: c.key);
      for (final s in c.schools) {
        expect(int.tryParse(s), isNotNull, reason: '${c.key} $s');
      }
    }
  });

  Future<MensaSheetResult?> open(
    WidgetTester t,
    MensaSheet sheet, {
    Future<void> Function()? act,
  }) async {
    MensaSheetResult? result = (
      url: 'offen',
      user: null,
      pass: null,
      forgetLogin: false,
      remind: null,
    );
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<MensaSheetResult>(
                  MaterialPageRoute(builder: (_) => Scaffold(body: sheet)),
                );
              },
              child: const Text('los'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('los'));
    await t.pumpAndSettle();
    await act?.call();
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    return result;
  }

  testWidgets('Caterer der Schule vorausgewählt – ein Tipp', (t) async {
    final r = await open(t, const MensaSheet(schoolId: '1001', catalog: _cat));
    expect(r?.url, _a.url);
    expect(r?.user, isNull);
  });

  testWidgets('Zwei Caterer: nichts vorausgewählt, Speichern gesperrt', (
    t,
  ) async {
    final r = await open(t, const MensaSheet(schoolId: '1003', catalog: _cat));
    expect(r?.url, 'offen');
  });

  testWidgets('Andere Adresse aus dem Menü', (t) async {
    final r = await open(
      t,
      const MensaSheet(schoolId: '1001', catalog: _cat),
      act: () async {
        await t.tap(find.byType(DropdownButtonFormField<String>));
        await t.pumpAndSettle();
        await t.tap(find.text('Andere Adresse eingeben …').last);
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'bestellung.example.de');
        await t.pump();
      },
    );
    expect(r?.url, 'bestellung.example.de');
  });

  testWidgets('Eingetragene Adresse eines bekannten Caterers erkannt', (
    t,
  ) async {
    final r = await open(
      t,
      const MensaSheet(
        schoolId: '9999',
        current: 'https://www.plattform.example/b-mandant/login',
        catalog: _cat,
      ),
    );
    // Unverändert gespeichert: die eingetragene Adresse bleibt.
    expect(r?.url, 'https://www.plattform.example/b-mandant/login');
  });

  testWidgets('Zugang optional: beide Felder nötig', (t) async {
    final r = await open(
      t,
      const MensaSheet(schoolId: '1001', catalog: _cat),
      act: () async {
        await t.tap(find.text('Hinterlegen'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField).at(0), 'eltern@example.de');
        await t.pump();
        // Nur Benutzername: Speichern gesperrt.
        final save = t.widget<OnbButton>(find.byType(OnbButton));
        expect(save.onPressed, isNull);
        await t.enterText(find.byType(TextField).at(1), 'geheim');
        await t.pump();
      },
    );
    expect(r?.url, _a.url);
    expect(r?.user, 'eltern@example.de');
    expect(r?.pass, 'geheim');
  });

  testWidgets('Gespeicherter Zugang: Löschen', (t) async {
    final r = await open(
      t,
      const MensaSheet(
        schoolId: '1001',
        savedUser: 'eltern@example.de',
        current: 'https://www.a-essen.example/login',
        catalog: _cat,
      ),
      act: () async {
        expect(find.text('Zugang gespeichert'), findsOne);
        expect(find.text('eltern@example.de'), findsOne);
        await t.tap(find.text('Löschen'));
        await t.pump();
      },
    );
    expect(r?.forgetLogin, isTrue);
    expect(r?.user, isNull);
  });

  testWidgets('Erinnerung je Wochentag', (t) async {
    final r = await open(
      t,
      const MensaSheet(
        schoolId: '1001',
        remindDays: {1, 2, 3, 4, 5},
        catalog: _cat,
      ),
      act: () async {
        await t.tap(find.text('Mi'));
        await t.pump();
      },
    );
    expect(r?.remind, {1, 2, 4, 5});
  });
}
