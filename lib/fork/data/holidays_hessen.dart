/// Gesetzliche Feiertage in Hessen (Hessisches Feiertagsgesetz §1): an
/// ihnen ist keine Schule – egal, ob die Schule sie im Kalender führt.
///
/// Ursache (Prüfung 06.11.26): freeDaysFrom kannte nur Kalendereinträge
/// der Schule und ließ allgemeine Feiertage bewusst aus (PortalRules.
/// plainHoliday – „Reformationstag“ ist in Hessen ein Schultag). Am
/// Mittwoch vor Christi Himmelfahrt zeigte Heute deshalb den Plan für
/// Donnerstag, „Krank melden“ schlug ihn vor, und an Fronleichnam stand
/// der Stundenplan da. Grenze: nur die landesweiten Feiertage; bewegliche
/// Ferientage und Brückentage kommen weiter aus dem Kalender der Schule.
/// Schulportal Hessen gibt es nur in Hessen, daher keine Länderwahl.
/// Namen nur deutsch, wie die Einträge im Kalender der Schule – auch
/// englische und türkische Oberflächen zeigen „Christi Himmelfahrt“.
library;

/// Ostersonntag nach der Gaußschen Osterformel (Ergänzung von Lichtenberg),
/// gültig für den gregorianischen Kalender.
DateTime easterSunday(int year) {
  final k = year ~/ 100;
  final m = 15 + (3 * k + 3) ~/ 4 - (8 * k + 13) ~/ 25;
  final s = 2 - (3 * k + 3) ~/ 4;
  final a = year % 19;
  final d = (19 * a + m) % 30;
  final r = (d + a ~/ 11) ~/ 29;
  final og = 21 + d - r;
  final sz = 7 - (year + year ~/ 4 + s) % 7;
  final oe = 7 - (og - sz) % 7;
  final os = og + oe; // Tag im März (32 = 1. April)
  return DateTime(year, 3, os);
}

/// Feiertage des Jahres [year] → Name (ohne Uhrzeit).
Map<DateTime, String> hessenHolidays(int year) {
  final e = easterSunday(year);
  DateTime plus(int days) => DateTime(e.year, e.month, e.day + days);
  return {
    DateTime(year, 1, 1): 'Neujahr',
    plus(-2): 'Karfreitag',
    plus(1): 'Ostermontag',
    DateTime(year, 5, 1): 'Tag der Arbeit',
    plus(39): 'Christi Himmelfahrt',
    plus(50): 'Pfingstmontag',
    plus(60): 'Fronleichnam',
    DateTime(year, 10, 3): 'Tag der Deutschen Einheit',
    DateTime(year, 12, 25): '1. Weihnachtstag',
    DateTime(year, 12, 26): '2. Weihnachtstag',
  };
}
