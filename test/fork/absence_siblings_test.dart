// „Daran denken“ je Kind eines Elternkontos und Vorschläge ohne Ferientage
// (Wunsch 05.11.26). Erfundene Kinder, Schule und Caterer.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_reminders.dart';
import 'package:lanis/fork/courses_scan.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/lessons_parent.dart';
import 'package:lanis/fork/mensa.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/mensa_week.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart';
import 'package:liblanis/liblanis.dart';

final de = forkL10nFor('de');
final _checkers = <ConnectionChecker>[];
const urlLena = 'https://bestellen.example/lena/2026/45/';
const urlJonas = 'https://bestellen.example/jonas/2026/45/';

LiveSnapshot parent({CourseScan? scan, List<ChildLessons>? kids}) {
  final c = ConnectionChecker();
  _checkers.add(c);
  final session = LanisSession(
    account: ClearTextAccount(
      localId: 1,
      schoolID: 9001,
      username: 'u1',
      password: '',
      schoolName: 'Beispielschule',
      accountType: AccountType.parent,
    ),
    config: const LanisConfig(),
    connectionChecker: c,
  );
  return LiveSnapshot(
    session: session,
    supported: const {},
    timetable: const Feed(),
    lessons: const Feed(),
    substitutions: const Feed(),
    calendar: const Feed(),
    conversations: const Feed(),
    userChoice: const {},
    ownNames: const {},
    setUserChoice: (_) {},
    setOwnNames: (_) {},
    nameTeacher: (_, _) {},
    refresh: () async {},
    refreshMessages: () async {},
    setMensaUrl: (_, _) {},
    accountKey: '1',
    mensa: const MensaAddresses({'11': urlLena, '12': urlJonas}),
    kids:
        kids ??
        [
          ChildLessons(
            pupilId: '11',
            pupilName: 'Beispiel, Lena',
            lessons: const [],
          ),
          ChildLessons(
            pupilId: '12',
            pupilName: 'Beispiel, Jonas',
            lessons: const [],
          ),
        ],
    courseScan: scan,
  );
}

MealWeek week(String url) => MealWeek(
  label: 'KW 45',
  url: url,
  days: [
    MealDay(
      day: DateTime(2026, 11, 6),
      state: MealState.ordered,
      ordered: const MealOption(line: 'A', name: 'Nudeln'),
      cancelUntil: '05.11.26 18:00',
      canCancel: true,
    ),
  ],
);

void main() {
  final now = DateTime(2026, 11, 5, 15);
  tearDown(() {
    for (final c in _checkers) {
      c.dispose();
    }
    _checkers.clear();
    MealCache.instance.reset();
  });

  test('Geschwister: Essen und Arbeit nur beim gemeldeten Kind', () {
    MealCache.instance.put('1:11', [week(urlLena)], at: now);
    MealCache.instance.put('1:12', [week(urlJonas)], at: now);
    final scan = CourseScan(
      day: DateTime(2026, 11, 5),
      marks: const {},
      exams: [
        ScanExam(
          course: '7&p=11',
          subject: 'Deutsch',
          day: DateTime(2026, 11, 6),
          text: 'Arbeit',
        ),
        ScanExam(
          course: '8&p=12',
          subject: 'Mathematik',
          day: DateTime(2026, 11, 6),
          text: 'Arbeit',
        ),
      ],
    );
    final r = absenceReminders(
      parent(scan: scan),
      const [
        AbsenceEntry(
          name: 'Jonas Beispiel',
          period: '06.11.2026',
          kind: 'krank',
          entered: '',
          comment: '',
        ),
      ],
      de,
      now,
    );
    final meal = r.singleWhere((x) => x.kind == AbsenceReminderKind.meal);
    expect(meal.kid, '12');
    expect(meal.title, de.absenceRemindMealFor('Jonas'));
    final exam = r.singleWhere((x) => x.kind == AbsenceReminderKind.exam);
    expect(exam.kid, '12');
    expect(exam.title, contains('Mathematik'));
    expect(exam.title, contains('Jonas'));
  });

  test('ein Kind im Elternkonto: ohne Namen, Arbeit ohne Filter', () {
    MealCache.instance.put('1:11', [week(urlLena)], at: now);
    final one = parent(
      scan: CourseScan(
        day: DateTime(2026, 11, 5),
        marks: const {},
        exams: [
          ScanExam(
            course: '7',
            subject: 'Deutsch',
            day: DateTime(2026, 11, 6),
            text: 'Arbeit',
          ),
        ],
      ),
      kids: [
        ChildLessons(
          pupilId: '11',
          pupilName: 'Beispiel, Lena',
          lessons: const [],
        ),
      ],
    );
    final r = absenceReminders(
      one,
      const [
        AbsenceEntry(
          name: 'Lena Beispiel',
          period: '06.11.2026',
          kind: 'krank',
          entered: '',
          comment: '',
        ),
      ],
      de,
      now,
    );
    expect(r.map((x) => x.title), [de.absenceRemindMeal, contains('Deutsch')]);
    expect(r.last.title, isNot(contains('Lena')));
  });

  test('nächster Schultag überspringt Ferientage', () {
    final fri = DateTime(2026, 11, 6, 15);
    expect(nextSchoolDayFree(fri, const {}), DateTime(2026, 11, 9));
    expect(
      nextSchoolDayFree(fri, {
        DateTime(2026, 11, 9): 'Studientag',
        DateTime(2026, 11, 10): 'Studientag',
      }),
      DateTime(2026, 11, 11),
    );
  });
}
