// Krankmeldung → „An die Schule schreiben“: Vorlage und Kind bei
// Geschwistern im Elternkonto (Prüfbefund 14.11.26). Erfundene Namen.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_view.dart';
import 'package:lanis/fork/lessons_parent.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:liblanis/liblanis.dart';

final _checkers = <ConnectionChecker>[];

LiveSnapshot _parent() {
  final c = ConnectionChecker();
  _checkers.add(c);
  return LiveSnapshot(
    session: LanisSession(
      account: ClearTextAccount(
        localId: 1,
        schoolID: 9001,
        username: 'u1',
        password: '',
        schoolName: 'Beispielschule',
        accountType: AccountType.parent,
      ),
      config: const LanisConfig(),
      connectionChecker: c,
    ),
    supported: const {},
    timetable: const Feed(),
    lessons: const Feed(),
    substitutions: const Feed(),
    calendar: const Feed(),
    conversations: const Feed(),
    userChoice: const {},
    ownNames: const {},
    setUserChoice: (_) {},
    setOwnNames: (_) {},
    nameTeacher: (_, _) {},
    refresh: () async {},
    refreshMessages: () async {},
    setMensaUrl: (_, _) {},
    accountKey: '1',
    kids: [
      ChildLessons(
        pupilId: '11',
        pupilName: 'Beispiel, Lena',
        lessons: const [],
      ),
      ChildLessons(
        pupilId: '12',
        pupilName: 'Beispiel, Jonas',
        lessons: const [],
      ),
    ],
  );
}

AbsenceEntry _e(String name, String period, {String kind = 'krank'}) =>
    AbsenceEntry(
      name: name,
      period: period,
      kind: kind,
      entered: '',
      comment: '',
    );

void main() {
  tearDown(() {
    for (final c in _checkers) {
      c.dispose();
    }
    _checkers.clear();
  });
  final now = DateTime(2026, 11, 16, 7);

  test(
    'Vorlage: Meldungen desselben Kindes zusammen, Geschwister getrennt',
    () {
      final r = absenceRecipients(_parent(), [
        _e('Jonas Beispiel', '18.11.2026'),
        _e('Lena Beispiel', '16.11.2026'),
        _e('Lena Beispiel', '17.11.2026'),
        _e('Lena Beispiel', '16.11.2026', kind: 'verspätet'),
        _e('Lena Beispiel', '10.11.2026'), // vorbei
      ], now: now);
      expect(
        r.templates.single.subject,
        'Krankmeldung Lena – vom Mo 16.11. bis Di 17.11.',
      );
    },
  );

  test('nur ein Geschwisterkind gemeldet: Vorlage für dieses', () {
    final r = absenceRecipients(_parent(), [
      _e('Jonas Beispiel', '18.11.2026'),
    ], now: now);
    expect(r.templates.single.subject, 'Krankmeldung Jonas – am Mi 18.11.');
    expect(r.focus, isEmpty);
  });

  test('gemischte Arten: neutrale Vorlage, nie „krank“', () {
    final r = absenceRecipients(_parent(), [
      _e('Jonas Beispiel', '16.11.2026'),
      _e('Jonas Beispiel', '18.11.2026', kind: 'beurlaubt'),
    ], now: now);
    final tpl = r.templates.single;
    expect(tpl.subject, 'Abwesenheit Jonas – am Mo 16.11. und Mi 18.11.');
    expect(tpl.text, contains('Jonas fehlt am Mo 16.11. und Mi 18.11. Die'));
    expect(tpl.text, isNot(contains('krank')));
  });
}
