import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/settings/subsettings/debug_export.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

void main() {
  // App-Liste von Schule A (Elternkonto) laut Export 16.10.26,
  // nur die link-Felder; Namen der Module sind öffentlich, keine Personendaten.
  const jtsMenu = [
    {'link': 'abwesenheitsmeldung.php'},
    {'link': 'dateiverteilung.php'},
    {'link': 'kalender.php'},
    {'link': 'meinunterricht.php'},
    {'link': 'nachrichten.php'},
    {'link': 'index.php?a=f&e=l11'},
    {'link': 'schulradeln.php'},
    {'link': 'stundenplan.php'},
    {'link': 'vertretungsplan.php'},
    {'link': 'videokonferenz.php'},
  ];

  test(
    'Schule A: Dateispeicher, Lerngruppen und Wahltool werden übersprungen',
    () {
      final r = filterPresetsForSchool(
        selected: DebugExportPresetId.values.toSet(),
        travelMenu: jtsMenu,
      );
      expect(
        r.skipped.map((p) => p.id),
        unorderedEquals([
          DebugExportPresetId.dataStorage,
          DebugExportPresetId.dataStorageFolders,
          DebugExportPresetId.studyGroups,
          DebugExportPresetId.elections,
        ]),
      );
      final kept = r.kept.map((p) => p.id).toSet();
      expect(kept, contains(DebugExportPresetId.absences));
      expect(kept, contains(DebugExportPresetId.conversations));
      expect(kept, contains(DebugExportPresetId.appOverview));
      expect(kept, contains(DebugExportPresetId.profile));
    },
  );

  test('ohne App-Liste wird nichts gefiltert', () {
    final r = filterPresetsForSchool(
      selected: DebugExportPresetId.values.toSet(),
      travelMenu: const [],
    );
    expect(r.skipped, isEmpty);
  });

  test('Kurs-Links: zwei verschiedene, ohne Halbjahres-Varianten', () {
    // Muster wie im Eltern-Export (Ziffern ersetzt).
    const html =
        '<a href="meinunterricht.php?a=sus_view&amp;id=11&amp;p=7&amp;halb=1">'
        '<a href="meinunterricht.php?a=sus_view&amp;id=11&amp;p=7">'
        '<a href="meinunterricht.php?a=sus_view&amp;id=11&amp;p=7">'
        '<a href="meinunterricht.php?a=sus_view&amp;id=22&amp;p=7">'
        '<a href="meinunterricht.php?a=sus_view&amp;id=33&amp;p=7">';
    expect(parseCourseDetailLinks(html), [
      'meinunterricht.php?a=sus_view&id=11&p=7',
      'meinunterricht.php?a=sus_view&id=22&p=7',
    ]);
    expect(parseCourseDetailLinks(''), isEmpty);
  });

  test('Dateispeicher-Ordner aus dem Startordner', () {
    const html =
        '<a href="#" data-dir="0">Start</a><a data-dir="6"></a>'
        '<a data-dir="6"></a><a data-dir="2"></a>';
    expect(parseDataStorageFolders(html), [6, 2]);
  });

  test('Kinder-Kennungen und Stundenplan je Kind', () {
    const html =
        '<h2 data-pupil="7">A</h2><h2 data-pupil="7">A</h2>'
        '<h2 data-pupil="8">B</h2>';
    expect(parsePupilIds(html), ['7', '8']);
    final p = debugExportPresets.firstWhere(
      (p) => p.id == DebugExportPresetId.timetableKids,
    );
    final ctx = DebugExportPresetContext()..lessonsHtml = html;
    expect(
      [for (final s in p.buildSections(ctx)) s.request.url],
      [
        for (final id in ['7', '8']) ...[
          '$sphBase/stundenplan.php?p=$id',
          '$sphBase/stundenplan.php?a=detail_klasse&e=1&p=$id',
        ],
        '$sphBase/stundenplan.php',
      ],
    );
    expect(p.buildSections(DebugExportPresetContext()), isEmpty);
    // Nach lessonsStudent und als letztes Preset (Sitzungsrisiko).
    final ids = [for (final p in debugExportPresets) p.id];
    expect(
      ids.indexOf(DebugExportPresetId.lessonsStudent),
      lessThan(ids.indexOf(DebugExportPresetId.timetableKids)),
    );
    expect(ids.last, DebugExportPresetId.timetableKids);
    expect(parsePupilIds('<div data-pupil-id="9"></div>'), isEmpty);
  });
}
