/// „Daran denken“ in der Anzeige der gesendeten Krankmeldung
/// (AbsenceOverview; Vorschläge 1 und 2 vom 05.11.26).
///
/// Ursache: Nach dem Melden fehlt der Blick auf die Folgen – bestelltes
/// Essen kostet weiter, wenn man es nicht abbestellt, und für eine
/// versäumte Arbeit kann die Schule ein Attest verlangen. Beides weiß die
/// App schon (MealCache, Kursmappen/Kalender), es stand nur nicht hier.
///
/// Grenze: Essen nur für das Kind mit Bestellseite (LiveSnapshot.mensaKid),
/// Arbeiten nur für das Kind des Plans (firstName) – bei Geschwistern in
/// einem Elternkonto fehlen die des zweiten Kindes. Abbestellt wird nie
/// von selbst; „Abbestellen“ je Tag öffnet die Essensseite mit der
/// Rückfrage für diesen Tag.
library;

import '../exams.dart';
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
    this.detail = '',
    this.meals = const [],
  });

  final AbsenceReminderKind kind;
  final DateTime day;
  final String title;
  final String detail;

  /// Essen: je bestelltem Krankheitstag [label] („Do 5.11.: abbestellbar
  /// bis 08:30“) und [weekday] für die Ansage des Knopfs („Do abbestellen“;
  /// sichtbar steht nur „Abbestellen“).
  final List<({DateTime day, String label, String weekday})> meals;
}

/// Punkte für die Meldungen [entries] (currentAbsences) des Kontos [s].
/// Essen: bestellt und noch abbestellbar (MealDay.canCancel); bestellt,
/// aber nicht mehr abbestellbar, entfällt – da ist nichts mehr zu tun.
/// Arbeiten bis heute + absenceSickDaysAhead.
List<AbsenceReminder> absenceReminders(
  LiveSnapshot s,
  List<AbsenceEntry> entries,
  ForkL10n t,
  DateTime now,
) {
  String day(DateTime d) => formatDate(t, t.dateShort, d);
  final out = <AbsenceReminder>[];

  final mealKid = s.kids.where((k) => k.pupilId == s.mensaKid).firstOrNull;
  final mealName = shortFirstName(mealKid?.firstName ?? s.firstName);
  final meals = MealCache.instance.ofSite(s.mensaOwner(s.mensaKid), s.mensaUrl);
  // Alle bestellten Krankheitstage in EINEM Punkt (Mockup 05.11.26: je Tag
  // eine Karte wiederholte sich), je Tag ein Knopf zum Abbestellen
  // (Wunsch 05.11.26: direkt zur Rückfrage dieses Tages).
  if (meals != null && mealName.isNotEmpty) {
    final days = <({DateTime day, String label, String weekday})>[];
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final horizon = DateTime(monday.year, monday.month, monday.day + 14);
    DateTime? first;
    for (final d in absenceSickDays(entries, mealName, now)) {
      // Nur bis Ende der nächsten Schulwoche: Weiter liest die Essensseite
      // beim Öffnen nicht (MealWeekPage._refresh, zwei Wochen), die
      // Rückfrage fände den Tag sonst nicht (Prüfung 05.11.26).
      if (!d.isBefore(horizon)) continue;
      final m = cancellableMeal(meals, d, now);
      if (m == null) continue;
      first ??= d;
      days.add((
        day: d,
        label: t.absenceRemindMealDay(
          day(d),
          mealCancelLabel(t, m.cancelUntil, d),
        ),
        weekday: formatDate(t, 'ccc', d),
      ));
    }
    if (first != null) {
      out.add(
        AbsenceReminder(
          kind: AbsenceReminderKind.meal,
          day: first,
          title: t.absenceRemindMeal,
          meals: days,
        ),
      );
    }
  }

  final name = s.firstName;
  if (name.isNotEmpty) {
    final sick = absenceSickDays(entries, name, now).toSet();
    final exams = upcomingExamsOf(
      scan: s.courseScan?.upcoming(now) ?? const [],
      calendar: examCalendarOf(s, now),
      now: now,
      until: DateTime(now.year, now.month, now.day + absenceSickDaysAhead),
    );
    for (final e in exams) {
      if (!sick.contains(DateTime(e.day.year, e.day.month, e.day.day))) {
        continue;
      }
      final what = [e.subject, e.kind].where((x) => x.isNotEmpty).join(' – ');
      out.add(
        AbsenceReminder(
          kind: AbsenceReminderKind.exam,
          day: e.day,
          title: t.absenceRemindExam(day(e.day), what),
          detail: t.absenceRemindExamDetail,
        ),
      );
    }
  }
  out.sort((a, b) => a.day.compareTo(b.day));
  return out;
}
