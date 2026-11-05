import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_parser.dart'
    show AbsenceSent, AbsenceSubmitResult;
import 'package:lanis/fork/absence/absence_view.dart';

/// Erfundene Formulardaten, Aufbau wie abwesenheitsmeldung.php von Schule A.
AbsenceForm _form({DateRange? to}) => AbsenceForm(
  pupils: const [
    AbsencePupil(
      id: '111',
      name: 'Anna Beispiel',
      preselected: true,
      allowed: true,
    ),
  ],
  kinds: const [
    AbsenceChoice('krank', 'als abwesend melden'),
    AbsenceChoice('verspätet', 'als verspätet melden'),
  ],
  blocks: const [
    AbsenceBlock(value: '0', label: '0. Block', start: '08:00', end: '08:45'),
    AbsenceBlock(value: '1', label: '1. Block', start: '09:00', end: '10:15'),
  ],
  fromRange: DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 19)),
  toRange: to ?? DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 22)),
  defaultFrom: DateTime(2026, 10, 16),
  defaultTo: DateTime(2026, 10, 16),
  rules: const ['spätestens bis 12:00 des aktuellen Tages'],
);

Future<void> _tall(WidgetTester t) async {
  t.view.physicalSize = const Size(1080, 4000);
  t.view.devicePixelRatio = 2.5;
  addTearDown(t.view.reset);
}

Widget _app(
  AbsenceForm f, {
  String lang = 'de',
  Future<AbsenceSubmitResult> Function(Map<String, String>)? onSubmit,
}) => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: Locale(lang),
  home: Scaffold(
    body: AbsenceFormView(form: f, onSubmit: onSubmit),
  ),
);

void main() {
  testWidgets('Vorgaben des Portals sind vorausgewählt, Senden gesperrt', (
    t,
  ) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    expect(find.textContaining('Anna – abwesend'), findsOneWidget);
    expect(find.textContaining('Fr 16.10., ganzer Tag'), findsOneWidget);
    expect(
      find.text('Von Block'),
      findsNothing,
      reason: 'Abwesend: keine Blöcke (wie im Portal)',
    );
    expect(find.text('Bitte keine Gesundheitsdaten eingeben.'), findsOneWidget);
    expect(find.textContaining('spätestens bis 12:00'), findsOneWidget);

    final send = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Abwesenheit melden'),
    );
    expect(
      send.onPressed,
      isNull,
      reason: 'ohne onSubmit (hier nicht übergeben) gesperrt',
    );

    await t.tap(find.text('Verspätet'));
    await t.pump();
    expect(find.textContaining('Anna – verspätet'), findsOneWidget);
    expect(find.text('Am'), findsOneWidget);
    expect(find.text('Von Block'), findsOneWidget);
    expect(find.text('Bis'), findsNothing);
  });

  testWidgets('Melden schickt die Portal-Felder ohne save', (t) async {
    await _tall(t);
    absenceLastSent.value = null;
    Map<String, String>? sent;
    await t.pumpWidget(
      _app(
        _form(),
        onSubmit: (f) async {
          sent = f;
          return const AbsenceSubmitResult(AbsenceSent.unconfirmed);
        },
      ),
    );
    await t.tap(find.text('Abwesenheit melden'));
    await t.pumpAndSettle();
    await t.tap(find.text('Jetzt melden'));
    await t.pumpAndSettle();
    expect(sent!['selectedPupils'], '111');
    expect(sent!['von'], '16.10.2026');
    expect(sent!.containsKey('save'), isFalse);
    expect(find.text('Beim Portal prüfen (sendet nichts)'), findsNothing);
    expect(find.text('Vorschau der Portal-Felder'), findsNothing);
  });

  testWidgets('ohne Kind kein Melden', (t) async {
    await _tall(t);
    await t.pumpWidget(
      _app(
        _form(),
        onSubmit: (_) async =>
            const AbsenceSubmitResult(AbsenceSent.unconfirmed),
      ),
    );
    await t.tap(find.text('Anna Beispiel'));
    await t.pump();
    expect(find.text('Bitte ein Kind auswählen.'), findsOneWidget);
    final send = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Abwesenheit melden'),
    );
    expect(send.onPressed, isNull);
  });

  testWidgets('Neuladen behält Eingaben', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    await t.tap(find.text('Verspätet'));
    await t.pump();
    await t.pumpWidget(
      _app(
        _form(to: DateRange(DateTime(2026, 10, 16), DateTime(2026, 10, 23))),
      ),
    );
    expect(find.textContaining('Anna – verspätet'), findsOneWidget);
  });

  testWidgets('letzter Knopf bleibt über der Navigationsleiste', (t) async {
    // Pixel-9a-ähnlich: schmal, Gestenleiste unten (randlose App).
    t.view.physicalSize = const Size(1080, 1500);
    t.view.devicePixelRatio = 2.5;
    t.view.padding = const FakeViewPadding(bottom: 120);
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(_form()));
    await t.drag(find.byType(ListView), const Offset(0, -3000));
    await t.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Abwesenheit melden');
    final screenH = 1500 / 2.5;
    final insetH = 120 / 2.5;
    expect(t.getBottomLeft(button).dy, lessThanOrEqualTo(screenH - insetH));
  });

  testWidgets('ohne Sende-Anbindung ist der Knopf gesperrt', (t) async {
    await _tall(t);
    await t.pumpWidget(_app(_form()));
    final send = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Abwesenheit melden'),
    );
    expect(send.onPressed, isNull, reason: 'ohne onSubmit gesperrt');
  });

  testWidgets('Melden: Rückfrage, Ergebnis, zweites Senden warnt', (t) async {
    await _tall(t);
    absenceLastSent.value = null;
    final sending = <String>[];
    var calls = 0;
    var result = AbsenceSubmitResult(
      AbsenceSent.confirmed,
      entry: const AbsenceEntry(
        name: 'Jonas Beispiel',
        period: '05.11.2026',
        kind: 'krank',
        entered: '05.11.2026 07:40',
        comment: '',
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AbsenceFormView(
            form: _form(),
            onSubmit: (fields) async {
              calls++;
              expect(fields.containsKey('check'), isFalse);
              return result;
            },
            onSending: (active, {sent = false}) => sending.add('$active/$sent'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abwesenheit melden'));
    await t.pumpAndSettle();
    expect(find.text('Verbindlich melden?'), findsOneWidget);
    // Abbrechen sendet nichts.
    await t.tap(find.text('Abbrechen'));
    await t.pumpAndSettle();
    expect(calls, 0);
    // Auto-Aktualisierung angehalten und wieder frei, ohne Neuladen.
    expect(sending, ['true/false', 'false/false']);

    await t.tap(find.text('Abwesenheit melden'));
    await t.pumpAndSettle();
    expect(find.textContaining('eben schon gesendet'), findsNothing);
    await t.tap(find.text('Jetzt melden'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Gemeldet'), findsOneWidget);
    expect(find.textContaining('Jonas Beispiel – krank'), findsOneWidget);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(sending.sublist(2), ['true/false', 'false/true']);

    // Maske neu aufgebaut (wie nach dem Neuladen): Warnung bleibt.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AbsenceFormView(
            form: _form(),
            onSubmit: (fields) async {
              calls++;
              return result;
            },
          ),
        ),
      ),
    );

    // Gleiche Angaben noch einmal: Warnung in der Rückfrage.
    result = const AbsenceSubmitResult(AbsenceSent.unconfirmed);
    await t.tap(find.text('Abwesenheit melden'));
    await t.pumpAndSettle();
    expect(find.textContaining('eben schon gesendet'), findsOneWidget);
    await t.tap(find.text('Jetzt melden'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Nicht sicher, ob gemeldet'), findsOneWidget);
    expect(find.text('Im Portal ansehen'), findsOneWidget);
  });

  for (final lang in ['en', 'tr']) {
    testWidgets('Krankmeldung $lang übersetzt, ohne Überlauf', (t) async {
      await _tall(t);
      await t.pumpWidget(_app(_form(), lang: lang));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final l = forkL10nFor(lang);
      expect(find.text(l.absenceSummary), findsOneWidget);
      expect(find.textContaining(l.absenceKindAbsent), findsWidgets);
      expect(find.text('Zusammenfassung'), findsNothing);
    });
  }

  testWidgets('Anzeige bestehender Meldung: Karte, „Auch … melden“ belegt vor', (
    t,
  ) async {
    await _tall(t);
    ({DateTime day, String pupilName, String kind})? got;
    var other = 0;
    const entry = AbsenceEntry(
      name: 'Anna Beispiel',
      period: '16.10.2026',
      kind: 'krank',
      entered: '16.10.2026 07:15',
      comment: 'Bleibt zu Hause.',
    );
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AbsenceOverview(
            form: _form(),
            entries: const [entry],
            onRepeat: (p) => got = p,
            onOther: () => other++,
          ),
        ),
      ),
    );
    expect(find.text('Anna Beispiel – krank'), findsOneWidget);
    expect(find.text('„Bleibt zu Hause.“'), findsOneWidget);
    // Kein Formular in der Anzeige.
    expect(find.byType(TextField), findsNothing);
    // 16.10.2026 ist ein Freitag → nächster Schultag Mo 19.10. (in fromRange).
    await t.tap(find.textContaining('Auch '));
    expect(got!.day, DateTime(2026, 10, 19));
    expect(got!.pupilName, 'Anna Beispiel');
    expect(got!.kind, 'krank');
    await t.tap(find.text('Andere Meldung (Tag, Verspätung)'));
    expect(other, 1);
  });

  testWidgets('Verspätung oder außerhalb des Portal-Zeitraums: kein „Auch …“', (
    t,
  ) async {
    await _tall(t);
    Future<void> show(AbsenceEntry e) => t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AbsenceOverview(
            form: _form(),
            entries: [e],
            onRepeat: (_) {},
            onOther: () {},
          ),
        ),
      ),
    );
    await show(
      const AbsenceEntry(
        name: 'Anna Beispiel',
        period: '16.10.2026',
        kind: 'verspätet',
        entered: '',
        comment: '',
      ),
    );
    expect(find.textContaining('Auch '), findsNothing);
    await show(
      const AbsenceEntry(
        name: 'Anna Beispiel',
        period: '19.10.2026',
        kind: 'krank',
        entered: '',
        comment: '',
      ),
    );
    expect(find.textContaining('Auch '), findsNothing);
  });

  testWidgets('Vorbelegung im Formular: Tag und Kind', (t) async {
    await _tall(t);
    Map<String, String>? sent;
    absenceLastSent.value = null;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AbsenceFormView(
            form: _form(),
            initialFrom: DateTime(2026, 10, 19),
            initialPupilName: 'Anna Beispiel',
            initialKind: 'krank',
            onSubmit: (f) async {
              sent = f;
              return const AbsenceSubmitResult(AbsenceSent.unconfirmed);
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('Abwesenheit melden'));
    await t.pumpAndSettle();
    await t.tap(find.text('Jetzt melden'));
    await t.pumpAndSettle();
    expect(sent!['von'], '19.10.2026');
    expect(sent!['bis'], '19.10.2026');
  });
}
