import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/anon/anon_export.dart';
import 'package:lanis/view/settings/subsettings/debug_export_presets.dart';

/// Erfundenes Portal: antwortet je Pfad mit synthetischen Seiten und merkt
/// sich alle Abrufe.
class _FakePortal implements HttpClientAdapter {
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${o.method} ${o.uri.path}?${o.uri.query}');
    final path = o.uri.path;
    final (String body, String type) = switch (path) {
      '/vertretungsplan.php' when o.method == 'GET' => (
        '<html><body><div data-tag="27.10.2026"></div>'
            '<p>Schule 9999 · Frau Sommer</p></body></html>',
        'text/html',
      ),
      '/vertretungsplan.php' => (
        '<table><tr><th>Vertreter</th></tr><tr><td>Tim Muster</td></tr></table>',
        'text/html',
      ),
      '/kalender.php' when o.method == 'POST' => (
        jsonEncode([
          {'title': 'Elternabend', 'Verantwortlich': 'Herr Sommer'},
        ]),
        'application/json',
      ),
      _ => ('<html><body><h1>Anna Beispiel</h1></body></html>', 'text/html'),
    };
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [type],
        'set-cookie': ['sid=GEHEIM; i=9999'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Elternkonto mit zwei Kindern: „mein Unterricht“ nennt beide, der Plan
/// für Kind 2 leitet auf Kind 1 um (so könnte das Portal antworten).
class _ParentPortal implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final q = o.uri.query;
    if (o.uri.path == '/meinunterricht.php') {
      return ResponseBody.fromString(
        '<h2 data-pupil="555111">Lena</h2><h2 data-pupil="555222">Jonas</h2>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }
    if (o.uri.path == '/stundenplan.php' && q == 'p=555222') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['stundenplan.php?a=detail_klasse&k=G5b&p=555111'],
        },
      );
    }
    return ResponseBody.fromString(
      '<html><body><h1>Plan</h1></body></html>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Lehrkraft: nur lesende Seiten, alles anonym, nichts doppelt', () async {
    final portal = _FakePortal();
    final dio = Dio()..httpClientAdapter = portal;
    final r = await runAnonExport(
      dio: dio,
      type: AccountType.teacher,
      schoolId: 9999,
      travelMenu: const [],
      version: '4.1.0+1',
      now: DateTime(2026, 10, 26),
    );
    for (final real in [
      'Anna',
      'Beispiel',
      'Sommer',
      'Muster',
      'Elternabend',
      '9999',
      'GEHEIM',
      'sid=',
    ]) {
      expect(r.text, isNot(contains(real)), reason: real);
    }
    expect(r.text, contains('Konto: Lehrkraft'));
    expect(r.text, contains('<th>Vertreter</th>'));
    expect(r.text, contains('=== substitutionsAjax@27.10.2026'));
    // Lehrkraft: Übersicht ja, Schülerkursseiten und Nachrichten nein.
    expect(portal.calls.where((c) => c.contains('meinunterricht.php')), [
      'GET /meinunterricht.php?jump=no',
    ]);
    expect(portal.calls.any((c) => c.contains('nachrichten')), isFalse);
    // Vertretungsplan nur einmal abgerufen, obwohl zwei Abschnitte ihn
    // brauchen.
    expect(
      portal.calls.where((c) => c == 'GET /vertretungsplan.php?'),
      hasLength(1),
    );
    expect(r.kept, contains('vertreter'));
  });

  test('Schülerkonto: Kursseiten aus der Übersicht', () {
    expect(
      anonPresetsFor(AccountType.student),
      contains(DebugExportPresetId.lessonsCourseDetail),
    );
    expect(
      anonPresetsFor(AccountType.teacher),
      isNot(contains(DebugExportPresetId.lessonsCourseDetail)),
    );
  });

  test('Elternkonto: Stundenplan je Kind dabei, sonst nicht', () {
    // Die Reihenfolge des Abrufs prüft debug_export_filter_test (zuletzt).
    expect(
      anonPresetsFor(AccountType.parent),
      contains(DebugExportPresetId.timetableKids),
    );
    expect(
      anonPresetsFor(AccountType.student),
      isNot(contains(DebugExportPresetId.timetableKids)),
    );
  });

  test(
    'Elternkonto: Plan je Kind mit Weiterleitung, Kennungen ersetzt',
    () async {
      final dio = Dio()..httpClientAdapter = _ParentPortal();
      final r = await runAnonExport(
        dio: dio,
        type: AccountType.parent,
        schoolId: 9999,
        travelMenu: const [
          {'link': 'meinunterricht.php'},
          {'link': 'stundenplan.php'},
        ],
        version: '4.1.0+1',
        now: DateTime(2026, 11, 5),
      );
      expect(r.text, contains('=== timetableKids#2:'));
      // Kind 2 wird auf Kind 1 umgeleitet – der Pfeil zeigt es.
      final kid2 = r.text.split('=== timetableKids#2:')[1].split('\n===')[0];
      expect(kid2, contains('→ '));
      expect(kid2, contains('KIND1'));
      // Ohne Weiterleitung kein Pfeil, Kennungen nirgends im Klartext.
      final kid1 = r.text.split('=== timetableKids#1:')[1].split('\n===')[0];
      expect(kid1, isNot(contains('→ ')));
      expect(r.text, isNot(contains('555111')));
      expect(r.text, isNot(contains('555222')));
      expect(r.text, isNot(contains('G5b')));
    },
  );
}
