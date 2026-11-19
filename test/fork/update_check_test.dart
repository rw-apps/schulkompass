// Hinweis „Neue Version verfügbar“ (Wunsch 19.11.26) – ohne Netz:
// fetchTag liefert erfundene Tags.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/notify/consent_reminder.dart';
import 'package:lanis/fork/ui/today/update_card.dart';
import 'package:lanis/fork/update_check.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

void main() {
  TypedSettings settings() {
    final c = ProviderContainer(overrides: testLanisOverrides());
    addTearDown(c.dispose);
    return c.read(sharedOverAccountSettingsProvider);
  }

  setUp(() => UpdateCheck.instance.reset());
  tearDown(() => UpdateCheck.instance.reset());

  test('Nummern aus Tag und Versionsname', () {
    expect(releaseBuild('v4.1.0+9517'), 9517);
    expect(releaseBuild('4.1.0'), isNull);
    expect(installedBuild('4.1.0+9499'), 9499);
  });

  test(
    'höchstens alle 20 Stunden, auch nach Fehlern; „Später“ 7 Tage',
    () async {
      final s = settings();
      final u = UpdateCheck.instance;
      var asked = 0;
      var fail = true;
      Future<String?> tag() async {
        asked++;
        if (fail) throw StateError('offline');
        return 'v4.1.0+9520';
      }

      final t0 = DateTime(2026, 11, 19, 8);
      await u.attach(s, now: t0, fetchTag: tag);
      expect((asked, u.latest), (1, null));
      // Gescheitert zählt als Versuch: kein zweiter vor 20 Stunden.
      fail = false;
      await u.attach(s, now: t0.add(const Duration(hours: 5)), fetchTag: tag);
      expect(asked, 1);
      await u.attach(s, now: t0.add(const Duration(hours: 21)), fetchTag: tag);
      expect((asked, u.latest), (2, 9520));
      final t1 = t0.add(const Duration(hours: 21));
      expect(u.offer('4.1.0+9499', now: t1), 9520);
      expect(u.offer('4.1.0+9520', now: t1), isNull, reason: 'schon aktuell');
      u.dismiss(now: t1);
      expect(
        u.offer('4.1.0+9499', now: t1.add(const Duration(days: 6))),
        isNull,
      );
      expect(u.offer('4.1.0+9499', now: t1.add(const Duration(days: 8))), 9520);
      // Neuer Start ohne Netz: gespeicherte Nummer, keine Anfrage.
      u.reset();
      await u.attach(s, now: t1.add(const Duration(hours: 1)), fetchTag: tag);
      expect((asked, u.latest), (2, 9520));
      // Uhr war vorgestellt: letzter Versuch in der Zukunft zählt nicht.
      await u.attach(
        s,
        now: t0.subtract(const Duration(days: 3)),
        fetchTag: tag,
      );
      expect(asked, 3);
      // Abgeschaltet: keine Anfrage, keine Karte.
      var notified = 0;
      void count() => notified++;
      u.addListener(count);
      u.setEnabled(s, false);
      u.removeListener(count);
      expect(notified, 1, reason: 'sichtbare Karte verschwindet sofort');
      await u.attach(s, now: t1.add(const Duration(days: 30)), fetchTag: tag);
      expect(asked, 3);
      expect(
        u.offer('4.1.0+9499', now: t1.add(const Duration(days: 8))),
        isNull,
      );
    },
  );

  Future<void> pumpCard(WidgetTester t, {bool arm32 = false}) async {
    final c = ProviderContainer(overrides: testLanisOverrides());
    addTearDown(c.dispose);
    final s = c.read(sharedOverAccountSettingsProvider);
    s.setString('fork-update-latest', '9517');
    s.setString('fork-update-checked', DateTime.now().toIso8601String());
    await UpdateCheck.instance.attach(s);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: UpdateCard(installed: '4.1.0+9499', arm32: arm32),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Karte mit beiden Nummern, „Später“ blendet aus', (t) async {
    await pumpCard(t);
    expect(find.text('Neue Version verfügbar'), findsOneWidget);
    expect(find.textContaining('9517'), findsOneWidget);
    expect(find.textContaining('9499'), findsOneWidget);
    expect(find.textContaining('armeabi'), findsNothing);
    await t.tap(find.text('Später'));
    await t.pumpAndSettle();
    expect(find.text('Neue Version verfügbar'), findsNothing);
  });

  testWidgets('32-Bit-Gerät: Hinweis auf die richtige Datei', (t) async {
    await pumpCard(t, arm32: true);
    expect(find.textContaining('armeabi-v7a'), findsOneWidget);
  });

  test('Erinnerung an die Zustimmung nur einmal je Fassung', () async {
    final s = settings();
    expect(isPrivacyPolicyAccepted(s), isFalse);
    // Ohne Plattform wirft show(); die Markierung steht trotzdem.
    await remindPrivacyConsent(s, hasAccounts: false, channelId: 'x');
    expect(s.getString('fork-privacy-reminder-sent'), isNull);
    await remindPrivacyConsent(s, hasAccounts: true, channelId: 'x');
    expect(s.getString('fork-privacy-reminder-sent'), privacyPolicyPublishedAt);
    acceptPrivacyPolicy(s);
    s.setString('fork-privacy-reminder-sent', null);
    await remindPrivacyConsent(s, hasAccounts: true, channelId: 'x');
    expect(s.getString('fork-privacy-reminder-sent'), isNull);
  });
}
