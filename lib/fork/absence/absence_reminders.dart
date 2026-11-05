/// „Daran denken“ in der Anzeige der gesendeten Krankmeldung
/// (AbsenceOverview; Vorschläge 1 und 2 vom 05.11.26).
///
/// Ursache: Nach dem Melden fehlt der Blick auf die Folgen – bestelltes
/// Essen kostet weiter, wenn man es nicht abbestellt, und für eine
/// versäumte Arbeit kann die Schule ein Attest verlangen. Beides weiß die
/// App schon (MealCache, Kursmappen/Kalender), es stand nur nicht hier.
///
/// Grenze: Kalender-Arbeiten nur beim Kind des Plans; Arbeiten aus den
/// Kursmappen und Essen je Kind. Geschwister mit gleichem kurzen Vornamen
/// („Anna Lena“, „Anna Sophie“) lassen sich nicht trennen (absenceIsFor) –
/// eine Meldung gilt dann für beide. Abbestellt wird nie
/// von selbst; „Abbestellen“ je Tag öffnet die Essensseite mit der
/// Rückfrage für diesen Tag.
library;

import '../courses_scan.dart' show ScanExam;
import '../exams.dart';
import '../lessons_parent.dart' show kidOfCourseId;
import '../l10n/l10n.dart';
import '../mensa_store.dart' show MealCache;
import '../ui/courses/live_courses_page.dart' show examCalendarOf;
import '../ui/live/live_data.dart' show LiveSnapshot, shortFirstName;
import '../ui/mensa/meal_cancel.dart';
import 'absence_days.dart';
import 'absence_form.dart' show AbsenceEntry;

enum AbsenceReminderKind { meal, exam }

/// Ein Punkt „Daran denken“: [title] fett, [detail] darunter.
class AbsenceReminder {
  const AbsenceReminder({
    required this.kind,
    required this.day,
    required this.title,
    this.kid = '',
    this.detail = '',
    this.meals = const [],
  });

  final AbsenceReminderKind kind;
  final DateTime day;

  /// Kind des Elternkontos (ChildLessons.pupilId, '' = Schülerkonto) – für
  /// die Essensseite dieses Kindes (openMensa).
  final String kid;
  final String title;
  final String detail;

  /// Essen: je bestelltem Krankheitstag [label] („Do 5.11.: abbestellbar
  /// bis 08:30“) und [weekday] für die Ansage des Knopfs („Do abbestellen“;
  /// sichtbar steht nur „Abbestellen“).
  final List<({DateTime day, String label, String weekday})> meals;
}

/// Punkte für die Meldungen [entries] (currentAbsences) des Kontos [s] –
/// je Kind des Elternkontos (Wunsch 05.11.26: vorher nur das erste Kind).
/// Essen: bestellt und jetzt noch abbestellbar (cancellableMeal); nicht mehr
/// abbestellbar entfällt – da ist nichts mehr zu tun. Arbeiten bis heute +
/// absenceSickDaysAhead: aus den Kursmappen des Kindes (Kurs-ID mit
/// `&p=<Kind>`, kidOfCourseId), Kalender-Arbeiten nur beim Kind des Plans
/// (examCalendarOf gilt seiner Klasse). Bei mehreren Kindern nennt jeder
/// Punkt den Namen.
List<AbsenceReminder> absenceReminders(
  LiveSnapshot s,
  List<AbsenceEntry> entries,
  ForkL10n t,
  DateTime now,
) {
  String day(DateTime d) => formatDate(t, t.dateShort, d);
  final out = <AbsenceReminder>[];
  // Schülerkonto bzw. Kinder noch nicht geladen: ein Eintrag ohne Schlüssel
  // (wie mealKids in meal_hub_page.dart).
  final kids = s.kids.isEmpty
      ? [(id: s.mensaKid, name: s.firstName, plan: true)]
      : [
          for (final (i, k) in s.kids.indexed)
            (id: k.pupilId, name: shortFirstName(k.firstName), plan: i == 0),
        ];
  final many = kids.length > 1;
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final horizon = DateTime(monday.year, monday.month, monday.day + 14);
  final scan = s.courseScan?.upcoming(now) ?? const <ScanExam>[];

  for (final k in kids) {
    if (k.name.isEmpty) continue;
    final sick = absenceSickDays(entries, k.name, now);
    if (sick.isEmpty) continue;

    // Alle bestellten Krankheitstage in EINEM Punkt (Mockup 05.11.26: je
    // Tag eine Karte wiederholte sich), je Tag ein Knopf zum Abbestellen
    // (Wunsch 05.11.26: direkt zur Rückfrage dieses Tages).
    final url = s.mensa.of(k.id);
    final meals = url == null
        ? null
        : MealCache.instance.ofSite(s.mensaOwner(k.id), url);
    if (meals != null) {
      final days = <({DateTime day, String label, String weekday})>[];
      for (final d in sick) {
        // Nur bis Ende der nächsten Schulwoche: Weiter liest die
        // Essensseite beim Öffnen nicht (MealWeekPage._refresh, zwei
        // Wochen), die Rückfrage fände den Tag sonst nicht (Prüfung
        // 05.11.26).
        if (!d.isBefore(horizon)) continue;
        final m = cancellableMeal(meals, d, now);
        if (m == null) continue;
        days.add((
          day: d,
          label: t.absenceRemindMealDay(
            day(d),
            mealCancelLabel(t, m.cancelUntil, d),
          ),
          weekday: formatDate(t, 'ccc', d),
        ));
      }
      if (days.isNotEmpty) {
        out.add(
          AbsenceReminder(
            kind: AbsenceReminderKind.meal,
            day: days.first.day,
            kid: k.id,
            title: many ? t.absenceRemindMealFor(k.name) : t.absenceRemindMeal,
            meals: days,
          ),
        );
      }
    }

    final sickSet = sick.toSet();
    final exams = upcomingExamsOf(
      scan: [
        for (final e in scan)
          // Ohne `&p=` (alte gespeicherte Auswertung) beim Kind des Plans.
          if (!many || (kidOfCourseId(e.course) ?? kids.first.id) == k.id) e,
      ],
      calendar: k.plan ? examCalendarOf(s, now) : const [],
      now: now,
      until: DateTime(now.year, now.month, now.day + absenceSickDaysAhead),
    );
    for (final e in exams) {
      if (!sickSet.contains(DateTime(e.day.year, e.day.month, e.day.day))) {
        continue;
      }
      final what = [e.subject, e.kind].where((x) => x.isNotEmpty).join(' – ');
      out.add(
        AbsenceReminder(
          kind: AbsenceReminderKind.exam,
          day: e.day,
          kid: k.id,
          title: many
              ? t.absenceRemindExamFor(day(e.day), what, k.name)
              : t.absenceRemindExam(day(e.day), what),
          detail: t.absenceRemindExamDetail,
        ),
      );
    }
  }
  out.sort((a, b) => a.day.compareTo(b.day));
  return out;
}
