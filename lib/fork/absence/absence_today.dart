import 'absence_form.dart';

/// Meldungen aus „Aktuelle und zukünftige Meldungen“ (abwesenheitsmeldung.php,
/// tbody#liste) für „Heute“ und „Nachrichten“ (Wunsch 05.11.26).
///
/// Grenze: Den Aufbau einer GEFÜLLTEN Liste kennen wir nur aus dem ersten
/// echten Fall (05.11.26); alle früheren Exporte waren leer. Die Auswertung
/// liest deshalb nur, was sicher ist: alle Daten TT.MM.JJJJ im Zeitraum
/// (erstes = Beginn, letztes = Ende) und eine Uhrzeit HH:MM in „eingetragen“.
/// Passt ein Eintrag nicht, zeigt die App ihn nicht als „heute gemeldet“ –
/// die Liste auf der Krankmeldungs-Seite bleibt die verlässliche Quelle.

final _date = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})');
final _time = RegExp(r'\b(\d{1,2}):(\d{2})\b');

/// Erster und letzter Tag des Zeitraums; null, wenn kein Datum lesbar ist.
({DateTime from, DateTime to})? absencePeriodDays(String period) {
  final days = [
    for (final m in _date.allMatches(period))
      DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)),
  ];
  if (days.isEmpty) return null;
  days.sort();
  return (from: days.first, to: days.last);
}

/// Uhrzeit aus „eingetragen“ („05.11.2026 07:40“ → „07:40“), sonst null.
String? absenceEnteredTime(String entered) {
  final m = _time.firstMatch(entered);
  return m == null ? null : '${m[1]!.padLeft(2, '0')}:${m[2]}';
}

/// Gehört der Eintrag zu diesem Kind? Das Portal nennt „Vorname Nachname“;
/// die App kennt vom Kind den Vornamen (ChildToday.firstName). Grenze: Zwei
/// Kinder gleichen Vornamens in einem Elternkonto ließen sich nicht trennen –
/// dann gilt der Eintrag für beide.
bool absenceIsFor(AbsenceEntry e, String firstName) {
  final f = firstName.trim().toLowerCase();
  if (f.isEmpty) return false;
  final first = e.name.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return first == f;
}

/// Gilt der Eintrag an [day]?
bool absenceCovers(AbsenceEntry e, DateTime day) {
  final p = absencePeriodDays(e.period);
  if (p == null) return false;
  final d = DateTime(day.year, day.month, day.day);
  return !d.isBefore(p.from) && !d.isAfter(p.to);
}

/// Verspätung statt Abwesenheit (Art im Portal „verspätet“).
bool absenceIsLate(AbsenceEntry e) => e.kind.toLowerCase().contains('versp');

/// Einträge, die heute oder später noch gelten, nach Beginn sortiert.
List<AbsenceEntry> currentAbsences(List<AbsenceEntry> all, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final out = [
    for (final e in all)
      if (absencePeriodDays(e.period) case final p? when !p.to.isBefore(today))
        e,
  ];
  out.sort(
    (a, b) => absencePeriodDays(
      a.period,
    )!.from.compareTo(absencePeriodDays(b.period)!.from),
  );
  return out;
}
