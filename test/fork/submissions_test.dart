// Offene Abgaben (Wunsch 15.11.26) – erfundene Seite im Aufbau von
// meinunterricht.php?a=sus_abgaben&t=offene.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:lanis/fork/submissions.dart';
import 'package:liblanis/liblanis.dart';

Lesson _l(String id, String name) => Lesson(
  courseID: id,
  name: name,
  teachers: const [],
  courseURL: Uri.parse('meinunterricht.php?a=sus_view&id=$id'),
);

void main() {
  final page = parseSubmissions(
    parse(File('test/fork/fixtures/submissions_open.html').readAsStringSync()),
  );

  test('liest Kurs, Name, Frist, Dateien und „möglich“', () {
    expect(page.skipped, 1, reason: 'Zeile ohne Link');
    expect(page.items.map((s) => s.name), [
      'Poster Thema A',
      'Bericht B',
      'Referat C',
    ]);
    final a = page.items[0];
    expect(a.courseId, '1001');
    expect(a.until, DateTime(2026, 11, 17, 10, 15));
    expect((a.files, a.open), (0, true));
    expect(
      a.url.toString(),
      'https://start.schulportal.hessen.de/meinunterricht.php?a=sus_abgabe&b=1001&e=3&id=2',
    );
    final b = page.items[1];
    expect(b.until, DateTime(2026, 11, 20, 23, 59), reason: 'ohne Uhrzeit');
    expect((b.files, b.open), (2, false));
    final c = page.items[2];
    expect(c.courseId, '1002');
    expect(c.until, DateTime(2026, 11, 18, 12, 15), reason: 'Zeit nach „bis“');
  });

  test('Frist: kaputte Angaben ergeben null', () {
    expect(submissionUntil(''), isNull);
    expect(submissionUntil('ab Montag, 09.11.26, um 08:00 Uhr'), isNull);
    expect(submissionUntil('bis 31.13.26'), isNull);
    expect(
      submissionUntil('bis 01.12.2026, um 7:05 Uhr'),
      DateTime(2026, 12, 1, 7, 5),
    );
  });

  test('an Kurse gehängt, nur offene mit laufender Frist, früheste zuerst', () {
    final lessons = [
      _l('1002', 'Zweitfach'),
      _l('1001', 'Beispielfach'),
      _l('9', 'X'),
    ];
    expect(attachSubmissions(lessons, page.items), 0);
    final open = openSubmissionsOf(
      lessons,
      subjectOf: (l) => l.name,
      now: DateTime(2026, 11, 15, 16),
    );
    expect(open.map((o) => o.submission.name), ['Poster Thema A', 'Referat C']);
    expect(open.first.subject, 'Beispielfach');
    // Nach Fristende weg.
    expect(
      openSubmissionsOf(
        lessons,
        subjectOf: (l) => l.name,
        now: DateTime(2026, 11, 17, 11),
      ).map((o) => o.submission.name),
      ['Referat C'],
    );
    // Neuer Abruf ohne Abgaben leert die Kurse wieder.
    attachSubmissions(lessons, const []);
    expect(
      openSubmissionsOf(lessons, subjectOf: (l) => l.name, now: DateTime(2026)),
      isEmpty,
    );
    // Kurs fehlt in der Übersicht: gezählt, nicht angehängt.
    expect(attachSubmissions([_l('1', 'Y')], page.items), 3);
  });

  // Rückmeldung 27.11.26: Datei hochgeladen, Abgabe laut Portal noch
  // möglich – für Heute und das Abzeichen nicht mehr offen.
  test('hochgeladen: nur mit handedIn, nicht für Heute', () {
    final lessons = [_l('1001', 'Beispielfach')];
    OpenSubmission sub(String name, int files) => OpenSubmission(
      courseId: '1001',
      name: name,
      url: Uri.parse('https://example.org/'),
      until: DateTime(2026, 12, 1, 9, 50),
      files: files,
    );
    attachSubmissions(lessons, [sub('Poster', 1), sub('Bericht', 0)]);
    final now = DateTime(2026, 11, 27, 8);
    List<String> names({required bool handedIn}) => [
      for (final o in openSubmissionsOf(
        lessons,
        subjectOf: (l) => l.name,
        now: now,
        handedIn: handedIn,
      ))
        o.submission.name,
    ];
    expect(names(handedIn: true), ['Poster', 'Bericht']);
    expect(names(handedIn: false), ['Bericht']);
  });
}
