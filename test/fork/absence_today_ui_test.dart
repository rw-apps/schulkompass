// Krankmeldung auf „Heute“ (Band, Knopf, gedämpfter Plan) und über dem
// Postfach (Abschnitt „Krankmeldungen“). Erfundene Kinder.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/live/absence_live.dart';
import 'package:lanis/fork/ui/messages/messages_page.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

Widget app(Widget w) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  home: Scaffold(body: w),
);

ChildToday kid({({String kind, String detail})? reported}) {
  final k = demoFamily().kids[0];
  return ChildToday(
    firstName: k.firstName,
    school: k.school,
    className: k.className,
    colorIndex: k.colorIndex,
    lessons: k.lessons,
    canReportAbsence: true,
    mealUnordered: DateTime(2026, 11, 5),
    mensaUrl: 'https://essen.example/',
    reportedAbsence: reported,
  );
}

void main() {
  final de = forkL10nFor('de');
  final now = DateTime(2026, 11, 5, 8, 20);

  testWidgets(
    'gemeldet: Band, Knopf „Gemeldet“, Plan gedämpft, kein Essens-Hinweis',
    (t) async {
      t.view.physicalSize = const Size(1080, 4000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        app(
          SingleChildScrollView(
            child: KidCard(kid: kid(), now: now),
          ),
        ),
      );
      expect(find.text(de.reportSick), findsOneWidget);
      expect(find.text(de.absenceReportedToday), findsNothing);
      final hintsBefore = find.text(de.hintsTitle).evaluate().length;

      await t.pumpWidget(
        app(
          SingleChildScrollView(
            child: KidCard(
              kid: kid(
                reported: (
                  kind: 'krank',
                  detail: 'Do 5.11. · eingetragen 07:40',
                ),
              ),
              now: now,
            ),
          ),
        ),
      );
      expect(find.text(de.absenceReportedToday), findsOneWidget);
      expect(find.text('Do 5.11. · eingetragen 07:40'), findsOneWidget);
      expect(find.text(de.absenceReported), findsOneWidget);
      expect(find.text(de.reportSick), findsNothing);
      final op = t.widget<Opacity>(find.byType(Opacity).first);
      expect(op.opacity, lessThan(1));
      // Heutiger Essens-Hinweis entfällt.
      expect(
        find.text(de.hintsTitle).evaluate().length,
        lessThanOrEqualTo(hintsBefore),
      );

      // Verspätung: Band, aber Plan nicht gedämpft.
      await t.pumpWidget(
        app(
          SingleChildScrollView(
            child: KidCard(
              kid: kid(reported: (kind: 'verspätet', detail: '')),
              now: now,
            ),
          ),
        ),
      );
      expect(find.text(de.absenceReportedLateToday), findsOneWidget);
      expect(t.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
    },
  );

  test('Band-Daten aus der Liste: Kind, Tag, Eintragszeit', () {
    const entries = [
      AbsenceEntry(
        name: 'Lena Beispiel',
        period: '05.11.2026',
        kind: 'krank',
        entered: '05.11.2026 07:40',
        comment: '',
      ),
    ];
    final r = reportedAbsenceFor(entries, 'Lena', now, de)!;
    expect(r.kind, 'krank');
    expect(r.detail, contains('eingetragen 07:40'));
    expect(reportedAbsenceFor(entries, 'Jonas', now, de), isNull);
    expect(
      reportedAbsenceFor(entries, 'Lena', DateTime(2026, 11, 6), de),
      isNull,
    );
  });

  testWidgets('Nachrichten: Abschnitt Krankmeldungen über dem Postfach', (
    t,
  ) async {
    var opened = 0;
    await t.pumpWidget(
      app(
        MessagesPage(
          items: const [
            MessageItem(
              id: '1',
              subject: 'Elternabend',
              sender: 'Frau Beispiel',
              date: 'gestern 18:02',
            ),
          ],
          reports: const [
            AbsenceReportItem(
              title: 'Lena – krank',
              meta: 'Do 5.11. · eingetragen 07:40',
            ),
          ],
          onOpenReports: () => opened++,
        ),
      ),
    );
    expect(find.text(de.absenceReportsTitle.toUpperCase()), findsOneWidget);
    expect(find.text('Lena – krank'), findsOneWidget);
    expect(find.textContaining('Krankmeldung · Do 5.11.'), findsOneWidget);
    await t.tap(find.text('Lena – krank'));
    expect(opened, 1);

    await t.pumpWidget(app(const MessagesPage(items: [])));
    expect(find.text(de.absenceReportsTitle.toUpperCase()), findsNothing);
  });
}
