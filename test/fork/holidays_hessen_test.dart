// Gesetzliche Feiertage in Hessen (06.11.26).
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart' show CalendarEvent;
import 'package:lanis/fork/data/holidays_hessen.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/today/kid_hints.dart'
    show nextSchoolDayFree, nextSchoolDayLegal;
import 'package:lanis/fork/ui/today/live_today_page.dart' show freeNote;
import 'package:lanis/fork/ui/today/today_from_lanis.dart';
import 'package:lanis/fork/widget/home_widget_data.dart' show widgetFreeDays;

void main() {
  test('Ostersonntag bekannter Jahre', () {
    expect(easterSunday(2024), DateTime(2024, 3, 31));
    expect(easterSunday(2025), DateTime(2025, 4, 20));
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(easterSunday(2027), DateTime(2027, 3, 28));
    expect(easterSunday(2038), DateTime(2038, 4, 25));
  });

  test('bewegliche Feiertage 2027', () {
    final h = hessenHolidays(2027);
    expect(h[DateTime(2027, 5, 6)], 'Christi Himmelfahrt');
    expect(h[DateTime(2027, 5, 17)], 'Pfingstmontag');
    expect(h[DateTime(2027, 5, 27)], 'Fronleichnam');
    expect(h[DateTime(2027, 3, 26)], 'Karfreitag');
    expect(h.length, 10);
  });

  test('freeDaysFrom kennt Feiertage ohne Kalender', () {
    final free = freeDaysFrom(const [], DateTime(2027, 5, 5, 15), days: 30);
    expect(free[DateTime(2027, 5, 6)], 'Christi Himmelfahrt');
    expect(free[DateTime(2027, 5, 27)], 'Fronleichnam');
  });

  test('Schule geht vor: Kalendername bleibt am Feiertag', () {
    final ev = CalendarEvent(
      startTime: DateTime(2027, 5, 6),
      endTime: DateTime(2027, 5, 7, 23, 59),
      secret: false,
      id: 'x',
      isNew: false,
      public: true,
      private: false,
      allDay: true,
      category: null,
      description: '',
      title: 'Unterrichtsfrei',
    );
    final free = freeDaysFrom([ev], DateTime(2027, 5, 5, 15), days: 10);
    expect(free[DateTime(2027, 5, 6)], 'Unterrichtsfrei');
    expect(free[DateTime(2027, 5, 7)], 'Unterrichtsfrei');
  });

  test('Feiertag am Wochenende zählt nicht, Jahreswechsel', () {
    // 1.5.2027 ist ein Samstag.
    final may = freeDaysFrom(const [], DateTime(2027, 4, 29, 15), days: 5);
    expect(may.containsKey(DateTime(2027, 5, 1)), isFalse);
    // 30.12.2026 (Mi): Neujahr 2027 (Fr) liegt im Folgejahr.
    final dec = freeDaysFrom(const [], DateTime(2026, 12, 30, 15), days: 5);
    expect(dec[DateTime(2027, 1, 1)], 'Neujahr');
    expect(
      nextSchoolDayFree(DateTime(2026, 12, 31, 15), dec),
      DateTime(2027, 1, 4),
    );
  });

  test('Widget-Datei kennt Feiertage bis Tag 7', () {
    // Mi 12.5.27: Pfingstmontag (17.5.) ist Tag 5, jenseits freeDaysAhead.
    final w = widgetFreeDays(const [], DateTime(2027, 5, 12, 15));
    expect(w[DateTime(2027, 5, 17)], 'Pfingstmontag');
  });

  test('Sammel-Benachrichtigung überspringt Feiertage', () {
    expect(nextSchoolDayLegal(DateTime(2027, 5, 5, 15)), DateTime(2027, 5, 7));
    expect(
      nextSchoolDayLegal(DateTime(2026, 10, 9, 15)),
      DateTime(2026, 10, 12),
    );
  });

  test('Hinweis unter „Nächster Schultag“', () {
    final de = forkL10nFor('de');
    final fri = DateTime(2026, 10, 9, 15);
    final ferien = {
      for (
        var d = DateTime(2026, 10, 12);
        d.isBefore(DateTime(2026, 10, 24));
        d = DateTime(d.year, d.month, d.day + 1)
      )
        if (d.weekday <= 5) d: 'Herbstferien',
    };
    final next = nextSchoolDayFree(fri, ferien);
    expect(next, DateTime(2026, 10, 26));
    expect(freeNote(de, ferien, fri, next), 'Herbstferien bis Fr 23.10.');
    // Mittwoch vor Himmelfahrt mit Brückentag: zwei Gründe.
    final wed = DateTime(2027, 5, 5, 15);
    final free = {
      ...freeDaysFrom(const [], wed, days: 10),
      DateTime(2027, 5, 7): 'Beweglicher Ferientag',
    };
    final n2 = nextSchoolDayFree(wed, free);
    expect(n2, DateTime(2027, 5, 10));
    expect(
      freeNote(de, free, wed, n2),
      'Christi Himmelfahrt · Beweglicher Ferientag bis Fr 7.5.',
    );
    // Heute Himmelfahrt (skip): nur der Brückentag danach.
    final thu = DateTime(2027, 5, 6, 15);
    expect(
      freeNote(de, free, thu, n2, skip: 'Christi Himmelfahrt'),
      'Beweglicher Ferientag am Fr 7.5.',
    );
    // In den Ferien selbst: kein doppelter Grund.
    expect(
      freeNote(
        de,
        ferien,
        DateTime(2026, 10, 14, 9),
        next,
        skip: 'Herbstferien',
      ),
      isNull,
    );
    // Nichts übersprungen: kein Hinweis.
    expect(freeNote(de, const {}, fri, DateTime(2026, 10, 12)), isNull);
  });
}
