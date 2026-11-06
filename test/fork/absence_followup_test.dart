// Folgen einer Krankmeldung auf „Heute“, in der Krankmeldung und auf der
// Essensseite (Vorschläge 1, 2, 4 vom 05.11.26). Erfundene Kinder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_reminders.dart';
import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/mensa_week.dart';
import 'package:lanis/fork/ui/mensa/meal_week_page.dart';
import 'package:lanis/fork/ui/preview/demo_family.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart';
import 'package:lanis/fork/ui/today/live_today_page.dart' show mealUnorderedDay;
import 'package:lanis/fork/ui/mensa/meal_cancel.dart';
import 'package:lanis/fork/ui/today/today_model.dart';
import 'package:lanis/fork/ui/today/today_page.dart';

final de = forkL10nFor('de');
final thu = DateTime(2026, 11, 5);
final fri = DateTime(2026, 11, 6);

Widget app(Widget w) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  home: Scaffold(body: w),
);

ChildToday kid({
  Set<DateTime> sick = const {},
  List<({DateTime day, String until})> cancel = const [],
  ({String kind, String detail})? report,
  DateTime? unordered,
}) {
  final k = demoFamily().kids[0];
  return ChildToday(
    firstName: k.firstName,
    school: k.school,
    className: k.className,
    colorIndex: k.colorIndex,
    lessons: k.lessons,
    canReportAbsence: true,
    mensaUrl: 'https://essen.example/',
    changes: [
      ChangeItem(
        day: fri,
        slot: '3.',
        subject: 'Englisch',
        kind: ChangeKind.cancelled,
      ),
    ],
    mealUnordered: unordered,
    reportedAbsence: report,
    sickDays: sick,
    mealCancel: cancel,
  );
}

final exam = WeekItem(
  day: fri,
  title: 'Mathematik: Arbeit',
  kind: WeekKind.exam,
  childIndex: 0,
);

void main() {
  test('Hinweise an Krankheitstagen: ohne Änderungen, mit Abbestellen', () {
    final now = DateTime(2026, 11, 5, 7, 50);
    final normal = kidHints(kid(unordered: fri), now, de, exams: [exam]);
    expect(normal.any((h) => h.subject == 'Englisch'), isTrue);
    expect(normal.any((h) => h.what == de.hintMealUnordered), isTrue);

    final h = kidHints(
      kid(
        sick: {thu, fri},
        unordered: fri,
        cancel: [(day: thu, until: '08:30'), (day: fri, until: 'Do 08:30')],
      ),
      now,
      de,
      exams: [exam],
    );
    expect(h.any((x) => x.subject == 'Englisch'), isFalse);
    expect(h.any((x) => x.what == de.hintMealUnordered), isFalse);
    final cancels = h.where((x) => x.cancelMeal).toList();
    expect(cancels.map((x) => x.day), [thu, fri]);
    expect(cancels.first.what, 'abbestellen bis 08:30');
    // Ohne lesbare Frist kein „bis –“.
    final open = kidHints(
      kid(sick: {thu}, cancel: [(day: thu, until: '–')]),
      now,
      de,
    ).singleWhere((x) => x.cancelMeal);
    expect(open.what, de.hintMealCancelOpen);
    final missed = h.singleWhere((x) => x.kind == HintKind.exam);
    expect(missed.what, de.hintExamMissed);
    expect(missed.detail, de.hintExamMissedDetail);
  });

  test('Frist kurz: gleicher Tag nur Uhrzeit, sonst mit Wochentag', () {
    expect(mealCancelLabel(de, '06.11.26 08:30', fri), '08:30');
    expect(mealCancelLabel(de, '05.11.26 08:30', fri), 'Do 08:30');
    expect(mealCancelLabel(de, 'morgen früh', fri), 'morgen früh');
    expect(mealCancelLabel(de, null, fri), '–');
  });

  test('abbestellbar nur vor der Frist und mit frischem Stand', () {
    final e = MealEntry(
      at: DateTime(2026, 11, 5, 7),
      weeks: [
        MealWeek(
          label: 'KW 45',
          days: [
            MealDay(
              day: thu,
              state: MealState.ordered,
              cancelUntil: '05.11.26 08:30',
              canCancel: true,
            ),
          ],
        ),
      ],
    );
    expect(cancellableMeal(e, thu, DateTime(2026, 11, 5, 8)), isNotNull);
    expect(cancellableMeal(e, thu, DateTime(2026, 11, 5, 10)), isNull);
    expect(cancellableMeal(e, thu, DateTime(2026, 11, 8)), isNull);
  });

  test('Erinnerung „bestellen“ überspringt Krankheitstage', () {
    final e = MealEntry(
      at: DateTime(2026, 11, 5, 7),
      weeks: [
        MealWeek(
          label: 'KW 45',
          days: [
            MealDay(day: thu, state: MealState.ordered),
            MealDay(day: fri, state: MealState.open),
            MealDay(day: DateTime(2026, 11, 9), state: MealState.open),
          ],
        ),
      ],
    );
    final now = DateTime(2026, 11, 5, 9);
    final first = mealUnorderedDay(e, now);
    expect(first, isNotNull);
    expect(mealUnorderedDay(e, now, skip: {first!}), isNot(first));
  });

  testWidgets(
    'nach Schulschluss: Band und Dämpfung des nächsten Tages, Abbestellen',
    (t) async {
      t.view.physicalSize = const Size(1080, 5000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final now = DateTime(2026, 11, 5, 18);
      final cancelled = <DateTime>[];
      await t.pumpWidget(
        app(
          SingleChildScrollView(
            child: KidCard(
              kid: kid(sick: {fri}, cancel: [(day: fri, until: 'Do 18:30')]),
              now: now,
              nextDay: kid(report: (kind: 'krank', detail: 'Fr 6.11.')),
              nextDate: fri,
              onReportAbsence: (_) {},
              onCancelMeal: (_, d) => cancelled.add(d),
            ),
          ),
        ),
      );
      expect(find.text(de.absenceReportedOn(de.dayTomorrow)), findsOneWidget);
      expect(find.text(de.absenceReported), findsOneWidget);
      expect(
        t.widget<Opacity>(find.byType(Opacity).first).opacity,
        lessThan(1),
      );
      // Englisch-Ausfall am Krankheitstag fehlt, Abbestellen führt zum Tag.
      expect(find.textContaining('Englisch'), findsNothing);
      await t.tap(
        find.textContaining('abbestellen bis Do 18:30', findRichText: true),
      );
      expect(cancelled, [fri]);
    },
  );

  testWidgets('Verspätung morgen: Band, aber kein gedämpfter Plan', (t) async {
    t.view.physicalSize = const Size(1080, 5000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      app(
        SingleChildScrollView(
          child: KidCard(
            kid: kid(),
            now: DateTime(2026, 11, 5, 18),
            nextDay: kid(report: (kind: 'verspätet', detail: '')),
            nextDate: fri,
          ),
        ),
      ),
    );
    expect(find.text(de.absenceReportedLateOn(de.dayTomorrow)), findsOneWidget);
    expect(t.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
  });

  testWidgets('Krankmeldung: „Daran denken“ mit Abbestellen je Tag', (t) async {
    final days = <DateTime>[];
    final form = AbsenceForm(
      pupils: const [
        AbsencePupil(
          id: '1',
          name: 'Lena Beispiel',
          preselected: true,
          allowed: true,
        ),
      ],
      kinds: const [AbsenceChoice('krank', 'als abwesend melden')],
      blocks: const [],
      fromRange: DateRange(thu, DateTime(2026, 11, 10)),
      toRange: DateRange(thu, DateTime(2026, 11, 10)),
      defaultFrom: thu,
      defaultTo: thu,
      rules: const [],
    );
    await t.pumpWidget(
      app(
        AbsenceOverview(
          form: form,
          entries: const [
            AbsenceEntry(
              name: 'Lena Beispiel',
              period: '05.11.2026 - 06.11.2026',
              kind: 'krank',
              entered: '',
              comment: '',
            ),
          ],
          onRepeat: (_) {},
          onOther: () {},
          reminders: [
            AbsenceReminder(
              kind: AbsenceReminderKind.meal,
              day: thu,
              title: de.absenceRemindMeal,
              meals: [
                (
                  day: thu,
                  label: 'Do 5.11.: abbestellbar bis 08:30',
                  weekday: 'Do',
                ),
                (
                  day: fri,
                  label: 'Fr 6.11.: abbestellbar bis Do 08:30',
                  weekday: 'Fr',
                ),
              ],
            ),
          ],
          onCancelMeal: (_, d) => days.add(d),
        ),
      ),
    );
    expect(find.text(de.absenceRemindTitle), findsOneWidget);
    await t.tap(find.text(de.mealCancelAction).last);
    expect(days, [fri]);
  });

  testWidgets('Essensseite: Rückfrage für den Tag öffnet sich von selbst', (
    t,
  ) async {
    final week = MealWeek(
      label: 'KW 45',
      days: [
        MealDay(
          day: thu,
          state: MealState.ordered,
          ordered: const MealOption(line: 'Veggie', name: 'Linsencurry'),
          cancelUntil: '05.11.26 08:30',
          canCancel: true,
        ),
        MealDay(day: fri, state: MealState.closed),
      ],
    );
    MealCache.instance.demo = (_) => MealEntry(at: thu, weeks: [week]);
    addTearDown(() => MealCache.instance.demo = null);
    await t.pumpWidget(
      ProviderScope(
        child: app(
          MealWeekPage(
            url: 'https://essen.example/',
            owner: '1:11',
            now: DateTime(2026, 11, 5, 7),
            cancelDay: thu,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(de.mealCancelTitle), findsOneWidget);
    expect(find.text('Linsencurry'), findsWidgets);
  });
}
