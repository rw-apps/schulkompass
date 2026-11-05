// Auswertung der Meldungsliste für „Heute“/„Nachrichten“. Erfundene Daten.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_today.dart';

AbsenceEntry e(String name, String period, {String kind = 'krank'}) =>
    AbsenceEntry(
      name: name,
      period: period,
      kind: kind,
      entered: '05.11.2026 07:40',
      comment: '',
    );

void main() {
  final now = DateTime(2026, 11, 5, 8, 20);

  test('Zeitraum: ein Tag, Spanne, mit Wochentag und Blöcken', () {
    expect(absencePeriodDays('05.11.2026')!.from, DateTime(2026, 11, 5));
    final p = absencePeriodDays('Do, 05.11.2026 - Fr, 06.11.2026')!;
    expect((p.from, p.to), (DateTime(2026, 11, 5), DateTime(2026, 11, 6)));
    expect(
      absencePeriodDays('5.11.2026 (1. - 2. Block)')!.to,
      DateTime(2026, 11, 5),
    );
    expect(absencePeriodDays('heute'), isNull);
    // Ohne oder mit zweistelligem Jahr.
    expect(
      absencePeriodDays('Do, 05.11.', now: now)!.from,
      DateTime(2026, 11, 5),
    );
    expect(absencePeriodDays('05.11.26')!.from, DateTime(2026, 11, 5));
    expect(
      absencePeriodDays('05.01.', now: DateTime(2026, 12, 30))!.from,
      DateTime(2027, 1, 5),
    );
  });

  test('Kind, Tag, Art, Eintragszeit', () {
    final x = e('Jonas Beispiel', '05.11.2026');
    expect(absenceIsFor(x, 'Jonas'), isTrue);
    expect(absenceIsFor(x, 'jonas'), isTrue);
    expect(absenceIsFor(x, 'Lena'), isFalse);
    expect(absenceIsFor(x, ''), isFalse);
    final rev = e('Beispiel, Jonas', '05.11.2026');
    expect(absenceIsFor(rev, 'Jonas'), isTrue);
    expect(absenceFirstName(rev), 'Jonas');
    expect(absenceFirstName(x), 'Jonas');
    expect(absenceCovers(x, now), isTrue);
    expect(absenceCovers(x, DateTime(2026, 11, 6)), isFalse);
    expect(absenceIsLate(e('A B', '05.11.2026', kind: 'verspätet')), isTrue);
    expect(absenceIsLate(x), isFalse);
    expect(absenceEnteredTime('05.11.2026 7:40'), '07:40');
    expect(absenceEnteredTime(''), isNull);
  });

  test('aktuelle Meldungen: vergangene weg, nach Beginn sortiert', () {
    final list = currentAbsences([
      e('Jonas Beispiel', '09.11.2026'),
      e('Jonas Beispiel', '03.11.2026'),
      e('Lena Beispiel', '04.11.2026 - 06.11.2026'),
      e('Lena Beispiel', 'unlesbar'),
    ], now);
    expect(list.map((x) => x.period), [
      '04.11.2026 - 06.11.2026',
      '09.11.2026',
    ]);
  });
}
