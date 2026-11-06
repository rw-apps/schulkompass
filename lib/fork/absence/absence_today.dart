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

// Jahr optional (zwei- oder vierstellig): Das Format der gefüllten Liste
// ist noch nicht belegt (Rückmeldung 05.11.26, kein Band trotz Meldung).
final _date = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})?(?!\d)');
final _time = RegExp(r'\b(\d{1,2}):(\d{2})\b');

/// Erster und letzter Tag des Zeitraums; null, wenn kein Datum lesbar ist.
/// Ohne Jahr gilt das Jahr von [now] (Meldungen liegen heute oder später;
/// ein Januar-Datum im Dezember zählt zum nächsten Jahr, ein Dezember-Datum
/// im Januar zum Vorjahr).
({DateTime from, DateTime to})? absencePeriodDays(
  String period, {
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final days = <DateTime>[];
  for (final m in _date.allMatches(period)) {
    final d = int.parse(m[1]!), mo = int.parse(m[2]!);
    if (d < 1 || d > 31 || mo < 1 || mo > 12) continue;
    var y = m[3] == null
        ? ref.year
        : m[3]!.length == 2
        ? 2000 + int.parse(m[3]!)
        : int.parse(m[3]!);
    if (m[3] == null && ref.month == 12 && mo == 1) y++;
    // Umgekehrt im Januar: ein Dezember-Datum ohne Jahr gehört zum Vorjahr
    // („21.12.–08.01.“ am 04.01.; Prüfung 05.11.26, sonst 21.12. als Ende
    // nach dem 08.01. und die Meldung galt nicht mehr).
    if (m[3] == null && ref.month == 1 && mo == 12) y--;
    days.add(DateTime(y, mo, d));
  }
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
  // Jedes Wort zählt: „Vorname Nachname“ wie auch „Nachname, Vorname“.
  return e.name.toLowerCase().split(RegExp(r'[\s,]+')).any((w) => w == f);
}

/// Vorname für die Zeile „Lena – krank“: bei „Nachname, Vorname“ das Wort
/// nach dem Komma, sonst das erste.
String absenceFirstName(AbsenceEntry e) {
  final n = e.name.trim();
  final i = n.indexOf(',');
  final part = i >= 0 ? n.substring(i + 1).trim() : n;
  return part.split(RegExp(r'\s+')).first;
}

/// Gilt der Eintrag an [day]?
bool absenceCovers(AbsenceEntry e, DateTime day) {
  final p = absencePeriodDays(e.period, now: day);
  if (p == null) return false;
  final d = DateTime(day.year, day.month, day.day);
  return !d.isBefore(p.from) && !d.isAfter(p.to);
}

/// Verspätung statt Abwesenheit (Art im Portal „verspätet“).
bool absenceIsLate(AbsenceEntry e) => absenceKindIsLate(e.kind);

/// Art „verspätet“ (Portal: „als verspätet melden“); alles andere gilt als
/// krank/abwesend. Eine Regel für Widget, Heute, Benachrichtigung und
/// Krankmeldung (Prüfung 06.11.26: dreifach im Text geprüft, Driftgefahr).
bool absenceKindIsLate(String kind) => kind.toLowerCase().contains('versp');

/// Einträge, die heute oder später noch gelten, nach Beginn sortiert.
List<AbsenceEntry> currentAbsences(List<AbsenceEntry> all, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final out = [
    for (final e in all)
      if (absencePeriodDays(e.period, now: now) case final p?
          when !p.to.isBefore(today))
        e,
  ];
  out.sort(
    (a, b) => absencePeriodDays(
      a.period,
      now: now,
    )!.from.compareTo(absencePeriodDays(b.period, now: now)!.from),
  );
  return out;
}
