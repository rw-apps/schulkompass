// Echtes Absenden der Krankmeldung (05.11.26): Prüfung zuerst, genau ein
// Speichern ohne `check`, danach Abgleich mit der Liste. Erfundene Daten.
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/absence/absence_form.dart';
import 'package:lanis/fork/absence/absence_parser.dart';

AbsenceForm form(List<AbsenceEntry> entries) => AbsenceForm(
  pupils: const [],
  kinds: const [],
  blocks: const [],
  fromRange: null,
  toRange: null,
  defaultFrom: null,
  defaultTo: null,
  rules: const [],
  entries: entries,
);

const old = AbsenceEntry(
  name: 'Jonas Beispiel',
  period: '01.11.2026',
  kind: 'krank',
  entered: '01.11.2026 07:10',
  comment: '',
);
const added = AbsenceEntry(
  name: 'Jonas Beispiel',
  period: '05.11.2026',
  kind: 'krank',
  entered: '05.11.2026 07:40',
  comment: '',
);

void main() {
  final fields = {'selectedPupils': '111', 'art': 'krank', 'von': '05.11.2026'};

  test(
    'bestanden: genau ein Speichern ohne check, neue Meldung erkannt',
    () async {
      final saved = <Map<String, String>>[];
      final r = await submitAbsenceWith(
        fields: {...fields, 'check': '1', 'save': 'x'},
        before: const [old],
        check: (_) async => const AbsenceCheck(true, []),
        save: (b) async {
          saved.add(b);
          return (status: 200, data: '<html></html>');
        },
        reload: () async => form(const [old, added]),
      );
      expect(r.state, AbsenceSent.confirmed);
      expect(r.entry!.period, '05.11.2026');
      expect(saved, hasLength(1));
      expect(saved.single.containsKey('check'), isFalse);
      expect(saved.single.containsKey('save'), isFalse);
      expect(saved.single['von'], '05.11.2026');
    },
  );

  test('abgelehnt: nichts gespeichert', () async {
    var saves = 0;
    final r = await submitAbsenceWith(
      fields: fields,
      before: const [],
      check: (_) async => const AbsenceCheck(false, ['nur bis 12:00']),
      save: (_) async {
        saves++;
        return (status: 200, data: '');
      },
      reload: () async => form(const []),
    );
    expect(r.state, AbsenceSent.rejected);
    expect(r.errors, ['nur bis 12:00']);
    expect(saves, 0);
  });

  test(
    'Abbruch beim Speichern oder keine neue Meldung: unklar, kein zweites Senden',
    () async {
      var saves = 0;
      Future<AbsencePostResult> boom(Map<String, String> _) async {
        saves++;
        throw Exception('Verbindung weg');
      }

      final a = await submitAbsenceWith(
        fields: fields,
        before: const [old],
        check: (_) async => const AbsenceCheck(true, []),
        save: boom,
        reload: () async => form(const [old]),
      );
      expect(a.state, AbsenceSent.unconfirmed);
      expect(saves, 1);

      // Trotz Abbruch steht sie in der Liste: bestätigt.
      final b = await submitAbsenceWith(
        fields: fields,
        before: const [old],
        check: (_) async => const AbsenceCheck(true, []),
        save: boom,
        reload: () async => form(const [old, added]),
      );
      expect(b.state, AbsenceSent.confirmed);
      expect(saves, 2);

      // Neuladen scheitert: unklar.
      final c = await submitAbsenceWith(
        fields: fields,
        before: const [old],
        check: (_) async => const AbsenceCheck(true, []),
        save: (_) async => (status: 200, data: ''),
        reload: () async => throw Exception('weg'),
      );
      expect(c.state, AbsenceSent.unconfirmed);
    },
  );
}
