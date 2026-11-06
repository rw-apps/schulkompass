// Krank gemeldete Tage für die Sammel-Benachrichtigung (Wunsch 05.11.26).
// Erfundene Daten.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_days.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/lessons_parent.dart';
import 'package:liblanis/liblanis.dart';

AbsenceEntry e(
  String period, {
  String kind = 'krank',
  String name = 'Lena Beispiel',
}) => AbsenceEntry(
  name: name,
  period: period,
  kind: kind,
  entered: '05.11.2026 07:40',
  comment: '',
);

void main() {
  final now = DateTime(2026, 11, 5, 14);

  test('Tage ab heute; Verspätung und andere Kinder zählen nicht', () {
    final days = absenceSickDays(
      [
        e('04.11.2026 - 06.11.2026'),
        e('09.11.2026', kind: 'verspätet'),
        e('10.11.2026', name: 'Jonas Beispiel'),
      ],
      'Lena',
      now,
    );
    expect(days, [DateTime(2026, 11, 5), DateTime(2026, 11, 6)]);
    expect(
      absenceSickOn(
        [e('09.11.2026', kind: 'verspätet')],
        'Lena',
        DateTime(2026, 11, 9),
      ),
      isFalse,
    );
  });

  test('je Kind: Geschwister im selben Elternkonto getrennt', () {
    final kids = [
      ChildLessons(
        pupilId: '11',
        pupilName: 'Beispiel, Lena Marie',
        lessons: const [],
      ),
      ChildLessons(
        pupilId: '12',
        pupilName: 'Beispiel, Jonas',
        lessons: const [],
      ),
    ];
    final m = absenceSickDaysByKid([e('05.11.2026')], kids, now);
    // Plan-Kind (kids.first) zusätzlich unter absencePlanKidKey.
    expect(m, {
      '11': [DateTime(2026, 11, 5)],
      absencePlanKidKey: [DateTime(2026, 11, 5)],
    });
    // Nur das zweite Kind krank: kein Plan-Eintrag.
    final m2 = absenceSickDaysByKid(
      [e('05.11.2026', name: 'Jonas Beispiel')],
      kids,
      now,
    );
    expect(m2.keys, ['12']);
  });

  test('Ablage: ersetzen, alte Tage fallen heraus, kaputt = keine', () {
    final store = <String, String>{};
    final s = TypedSettings(
      read: (k) => store[k],
      write: (k, v) => store[k] = v!,
      delete: store.remove,
    );
    storeSickDays(s, {
      '11': [DateTime(2026, 11, 4), DateTime(2026, 11, 6)],
    });
    expect(readSickDays(s, now), {
      '11': {DateTime(2026, 11, 6)},
    });
    storeSickDays(s, const {});
    expect(store.containsKey(absenceSickDaysSetting), isFalse);
    store[absenceSickDaysSetting] = '{kaputt';
    expect(readSickDays(s, now), isEmpty);
  });
}
