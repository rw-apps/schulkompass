/// Gemeldete Abwesenheit im Startbildschirm-Widget (Abnahme 05.11.26).
///
/// Ursache (Frage 05.11.26: „Ist ein Kind krank, wird dann auch die Anzeige
/// in den Widgets angepasst?“): Das Widget zeigte ein krank gemeldetes Kind
/// mit vollem Zeitraum, Aufgaben und „Essen bestellen“ – anders als Heute,
/// das den Plan dämpft (today_page.dart, absentToday).
///
/// Dart schreibt je Tag der Datei (home_widget_data.dart, widgetDays) den
/// fertigen Text `absent` und `sick`; Kotlin (WidgetModel.kt) zeigt den
/// Text mit Haken statt des Zeitraums und an `sick`-Tagen alle Symbole
/// blass (Guthaben-„!“ bleibt). Verspätung: Text, Symbole bleiben – das
/// Kind geht ja zur Schule.
///
/// Grenze: Zuordnung über den Vornamen ([absenceIsFor]) wie auf Heute; zwei
/// gleichnamige Kinder in einem Elternkonto ließen sich nicht trennen.
library;

import 'package:intl/intl.dart';

import '../absence/absence_form.dart' show AbsenceEntry;
import '../absence/absence_today.dart';
import '../l10n/l10n.dart';

/// Höchstens so viele Schultage folgt [widgetDaysWithAbsences] einer Kette
/// von Meldungen, um das Ende („krank bis 16.11.“) zu finden. Ursache: Die
/// App meldet Folgetage einzeln („Auch Freitag melden“, absence_view.dart),
/// das Ende steht also oft erst im letzten Eintrag. Grenze: Längere Ketten
/// nennen das Ende nach 30 Schultagen.
const _maxChain = 30;

/// Nächster Schultag nach [d]: ohne Wochenende und ohne die freien Tage
/// der Datei ([free], ISO-Datum), damit ein Studientag zwischen zwei
/// Meldungen die Kette nicht beendet (Prüfung 05.11.26). Grenze: freie Tage
/// kennt die Datei nur bis heute + widgetDaysAhead.
DateTime _nextSchoolDay(DateTime d, Set<String> free) {
  var n = DateTime(d.year, d.month, d.day + 1);
  while (n.weekday > 5 || free.contains(_iso(n))) {
    n = DateTime(n.year, n.month, n.day + 1);
  }
  return n;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// [days] (widgetDays) mit `absent`/`sick` an den gemeldeten Schultagen.
/// Freie Tage (`free`) bleiben unverändert – Ferien gehen vor.
///
/// Krank (alles außer „verspätet“, wie today_page.dart „Heute krank
/// gemeldet“) geht vor Verspätung am selben Tag. Ende: letzter Schultag, an
/// dem eine Krankmeldung gilt, auch über mehrere Einträge und Wochenenden
/// hinweg; freie Tage der Datei überspringt die Kette ([_nextSchoolDay]).
/// Grenze: ein Feiertag, den der Kalender nicht als frei führt, beendet sie.
List<Map<String, Object?>> widgetDaysWithAbsences(
  List<Map<String, Object?>> days, {
  required List<AbsenceEntry> entries,
  required String firstName,
  required ForkL10n t,
}) {
  final mine = [
    for (final e in entries)
      if (absenceIsFor(e, firstName)) e,
  ];
  if (mine.isEmpty) return days;
  bool sickOn(DateTime d) =>
      mine.any((e) => !absenceIsLate(e) && absenceCovers(e, d));
  bool lateOn(DateTime d) =>
      mine.any((e) => absenceIsLate(e) && absenceCovers(e, d));
  final date = DateFormat(t.widgetAbsentDate, t.localeName);
  final free = {
    for (final d in days)
      if (d['free'] != null) '${d['date']}',
  };
  Map<String, Object?> mark(Map<String, Object?> day) {
    final d = DateTime.tryParse('${day['date'] ?? ''}');
    if (d == null || day['free'] != null) return day;
    if (sickOn(d)) {
      var end = d;
      for (var i = 0; i < _maxChain; i++) {
        final n = _nextSchoolDay(end, free);
        if (!sickOn(n)) break;
        end = n;
      }
      final text = end == d
          ? t.widgetAbsent
          : t.widgetAbsentUntil(date.format(end));
      return {...day, 'absent': text, 'sick': true};
    }
    if (lateOn(d))
      return {...day, 'absent': t.widgetLateReported, 'sick': false};
    return day;
  }

  return [for (final day in days) mark(day)];
}
