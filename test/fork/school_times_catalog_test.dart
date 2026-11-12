// Stundenzeiten aus dem Katalog (Wunsch 09.11.26).
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/school_times_catalog.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/plan/lesson_times.dart';
import 'package:lanis/utils/applet_settings.dart';
import 'package:liblanis/liblanis.dart';

void main() {
  // Schulnummer nur im Katalog selbst (ship.sh): hier über den Eintrag.
  test('Katalog-Eintrag ergibt die angegebenen Zeiten', () {
    final t = catalogLessonTimes(schoolTimesCatalog.keys.first)!;
    String at(int n) {
      final r = t.of(n);
      return '${LessonTimes.hm(r.start)}–${LessonTimes.hm(r.end)}';
    }

    expect(
      [for (var n = 1; n <= 8; n++) at(n)],
      [
        '08:00–08:45',
        '08:45–09:30',
        '09:50–10:35',
        '10:35–11:20',
        '11:40–12:25',
        '12:30–13:15',
        '13:25–14:10',
        '14:10–14:55',
      ],
    );
  });

  test('unbekannte Schule: nichts', () {
    expect(catalogLessonTimes('0000'), isNull);
  });

  test('jeder Eintrag: Schulnummer, gültige Zeiten', () {
    for (final e in schoolTimesCatalog.entries) {
      expect(RegExp(r'^[1-9]\d{3,5}$').hasMatch(e.key), isTrue, reason: e.key);
      expect(LessonTimes.fromMap(e.value.toMap()), isNotNull, reason: e.key);
    }
  });

  group('ownLessonTimes: alte eigene Zeiten an Katalogschulen', () {
    TypedSettings mem() {
      final m = <String, String?>{};
      return TypedSettings(
        read: (k) => m[k],
        write: (k, v) => m[k] = v,
        delete: m.remove,
      );
    }

    void store(TypedSettings s, LessonTimes t) => persistAppletSetting(
      s,
      'stundenplan.php/$lessonTimesSetting',
      t.toMap(),
    );

    const wrong = LessonTimes(start: 7 * 60 + 45);
    final school = schoolTimesCatalog.keys.first;

    test('einmal verworfen, danach Katalog; Neueintrag bleibt', () {
      final s = mem();
      store(s, wrong);
      final first = effectiveLessonTimes(s, school);
      expect(first.fromSchool, isTrue);
      expect(first.times, same(catalogLessonTimes(school)));
      store(s, wrong);
      expect(effectiveLessonTimes(s, school).times?.toMap(), wrong.toMap());
    });

    test('andere Schulen behalten ihre Zeiten', () {
      final s = mem();
      store(s, wrong);
      expect(ownLessonTimes(s, '0000')?.toMap(), wrong.toMap());
      expect(s.getString(lessonTimesCatalogSetting), isNull);
    });
  });
}
