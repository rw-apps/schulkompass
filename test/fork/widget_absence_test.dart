// Gemeldete Abwesenheit im Startbildschirm-Widget (Abnahme 05.11.26):
// Texte und Kennzeichen je Tag der Datei, die Kotlin (WidgetModel.kt) liest.
// Erfundene Daten (Lena, Jonas).
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/live/absence_live.dart';
import 'package:lanis/fork/widget/home_widget_data.dart';
import 'package:lanis/fork/widget/widget_absence.dart';

final de = forkL10nFor('de');

AbsenceEntry e(String name, String period, {String kind = 'krank'}) =>
    AbsenceEntry(
      name: name,
      period: period,
      kind: kind,
      entered: '05.11.2026 07:40',
      comment: '',
    );

Map<String, Object?> d(String iso) => {'date': iso, 'timed': true};

List<Map<String, Object?>> mark(
  List<AbsenceEntry> entries, {
  String name = 'Lena',
  List<Map<String, Object?>>? days,
}) => widgetDaysWithAbsences(
  days ??
      [
        d('2026-11-05'),
        d('2026-11-06'),
        d('2026-11-09'),
        {'date': '2026-11-10', 'free': 'Studientag bis Di 10.11.'},
      ],
  entries: entries,
  firstName: name,
  t: de,
);

void main() {
  test('ein Tag krank: „krank gemeldet“, Symbole blass', () {
    final r = mark([e('Lena Beispiel', '05.11.2026')]);
    expect(r[0]['absent'], 'krank gemeldet');
    expect(r[0]['sick'], true);
    expect(r[1].containsKey('absent'), isFalse);
  });

  test('mehrere Tage: Ende mit Datum, auch über Wochenende und Einträge', () {
    // Wie „Auch Freitag melden“: Folgetage als eigene Einträge.
    final r = mark([
      e('Lena Beispiel', 'Do, 05.11.2026 - Fr, 06.11.2026'),
      e('Lena Beispiel', '09.11.2026'),
    ]);
    expect(r[0]['absent'], 'krank bis 9.11.');
    expect(r[1]['absent'], 'krank bis 9.11.');
    // Letzter Tag der Kette: kein „bis“ mehr.
    expect(r[2]['absent'], 'krank gemeldet');
    // Freier Tag bleibt unverändert (Ferien gehen vor).
    expect(r[3], {'date': '2026-11-10', 'free': 'Studientag bis Di 10.11.'});
  });

  test('Verspätung: Text, Symbole bleiben; krank geht vor', () {
    final r = mark([
      e('Lena Beispiel', '05.11.2026', kind: 'verspätet'),
      e('Lena Beispiel', '06.11.2026', kind: 'verspätet'),
      e('Lena Beispiel', '06.11.2026'),
    ]);
    expect(r[0]['absent'], 'verspätet gemeldet');
    expect(r[0]['sick'], false);
    expect(r[1]['absent'], 'krank gemeldet');
    expect(r[1]['sick'], true);
  });

  test('nur das eigene Kind; ohne Meldung unverändert', () {
    final days = [d('2026-11-05')];
    expect(mark([e('Jonas Beispiel', '05.11.2026')], days: days), same(days));
    expect(mark(const [], days: days), same(days));
  });

  test('Englisch: Datum M/d', () {
    final r = widgetDaysWithAbsences(
      [d('2026-11-05')],
      entries: [e('Lena Beispiel', '05.11.2026 - 16.11.2026')],
      firstName: 'Lena',
      t: forkL10nFor('en'),
    );
    expect(r[0]['absent'], 'sick until 11/16');
  });

  test('Kette überspringt freie Tage der Datei', () {
    final r = mark(
      [e('Lena Beispiel', '05.11.2026'), e('Lena Beispiel', '09.11.2026')],
      days: [
        d('2026-11-05'),
        {'date': '2026-11-06', 'free': 'Studientag'},
        d('2026-11-09'),
      ],
    );
    expect(r[0]['absent'], 'krank bis 9.11.');
  });

  test('Heute: Krankmeldung vor Verspätung am selben Tag', () {
    final r = reportedAbsenceFor(
      [
        e('Lena Beispiel', '05.11.2026', kind: 'verspätet'),
        e('Lena Beispiel', '05.11.2026'),
      ],
      'Lena',
      DateTime(2026, 11, 5, 8),
      de,
    );
    expect(r!.kind, 'krank');
  });

  group('Meldungen getrennt vom Plan (Prüfung 05.11.26)', () {
    Map<String, Object?> kid(
      String stand, {
      String? absStand,
      bool sick = false,
    }) => {
      'account': 3,
      'name': 'Lena',
      'stand': stand,
      'absStand': ?absStand,
      'days': [
        {
          'date': '2026-11-05',
          'timed': true,
          'from': stand,
          if (sick) 'absent': 'krank gemeldet',
          if (sick) 'sick': true,
        },
      ],
    };
    Map<String, Object?> day0(Map<String, Object?> k) =>
        (k['days'] as List).first as Map<String, Object?>;

    test('App mit neuerer Meldung, Datei mit neuerem Plan', () {
      final r = newerWidgetKid(
        kid('2026-11-05T07:20:00', absStand: '2026-11-05T07:26:00', sick: true),
        kid('2026-11-05T07:22:00', absStand: '2026-11-05T07:22:00'),
      )!;
      // Plan aus der Datei, Meldung aus der App.
      expect(day0(r)['from'], '2026-11-05T07:22:00');
      expect(day0(r)['absent'], 'krank gemeldet');
      expect(r['absStand'], '2026-11-05T07:26:00');
    });

    test('App kennt die Liste noch nicht: Meldung der Datei bleibt', () {
      final r = newerWidgetKid(
        kid('2026-11-05T07:30:00'),
        kid('2026-11-05T07:22:00', absStand: '2026-11-05T07:22:00', sick: true),
      )!;
      expect(day0(r)['from'], '2026-11-05T07:30:00');
      expect(day0(r)['sick'], true);
    });

    test('Hintergrund ohne Liste behält die Meldung der Datei', () {
      final old = {
        'v': homeWidgetVersion,
        'kids': [
          kid(
            '2026-11-05T07:20:00',
            absStand: '2026-11-05T07:26:00',
            sick: true,
          ),
        ],
      };
      final fresh = [
        {'date': '2026-11-05', 'timed': true, 'from': 'neu'},
      ];
      final keep = mergeWidgetKid(
        old,
        account: 3,
        days: fresh,
        stand: DateTime(2026, 11, 5, 7, 40),
      )!;
      expect(day0(keep.single)['absent'], 'krank gemeldet');
      expect(day0(keep.single)['from'], 'neu');
      // Mit neuerer (leerer) Liste: Meldung weg, neuer Stempel.
      final gone = mergeWidgetKid(
        old,
        account: 3,
        days: fresh,
        stand: DateTime(2026, 11, 5, 7, 40),
        absStand: DateTime(2026, 11, 5, 7, 40),
      )!;
      expect(day0(gone.single).containsKey('absent'), isFalse);
      expect(gone.single['absStand'], '2026-11-05T07:40:00.000');
    });
  });
}
