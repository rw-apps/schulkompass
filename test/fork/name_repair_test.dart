import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/plan/plan_model.dart';
import 'package:lanis/fork/ui/plan/plan_page.dart';
import 'package:lanis/fork/name_repair.dart';
import 'package:lanis/fork/ui/courses/courses_model.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/messages/compose_model.dart';
import 'package:liblanis/liblanis.dart';

// Erfundene Namen. „�“ = U+FFFD, wie das Portal es selbst schickt.
const x = replacementChar;

Lesson _l(String name, List<LessonTeacher> t) =>
    Lesson(courseID: name, name: name, teachers: t, courseURL: Uri.parse('x'));

void main() {
  group('repairWithKuerzel', () {
    test('Umlaut aus dem Kürzel an derselben Stelle', () {
      expect(repairWithKuerzel('M${x}we, Anna', 'Mö'), 'Möwe, Anna');
      expect(repairWithKuerzel('M${x}we, Anna', 'MÖW'), 'Möwe, Anna');
      expect(repairWithKuerzel('${x}lber, Ida', 'Öl'), 'Ölber, Ida');
      expect(repairWithKuerzel('Gro${x}, Ute', 'GROß'), 'Groß, Ute');
      expect(repairWithKuerzel('M${x}WE, Anna', 'Mö'), 'MÖWE, Anna');
    });

    test('kein Raten', () {
      // Kürzel nach anderem Schema / ae statt ä / zu kurz / ohne Bestätigung.
      expect(repairWithKuerzel('M${x}we, Anna', 'AMW'), 'M${x}we, Anna');
      expect(repairWithKuerzel('M${x}we, Anna', 'Moe'), 'M${x}we, Anna');
      expect(repairWithKuerzel('M${x}we, Anna', 'M'), 'M${x}we, Anna');
      expect(repairWithKuerzel('${x}lber, Ida', 'Ö'), '${x}lber, Ida');
      expect(repairWithKuerzel('M${x}we, Anna', null), 'M${x}we, Anna');
      // „�“ hinter dem Kürzel oder im Vornamen bleibt.
      expect(repairWithKuerzel('Hab${x}, Anna', 'Ha'), 'Hab${x}, Anna');
      expect(repairWithKuerzel('Alt, J${x}rg', 'Al'), 'Alt, J${x}rg');
      // ß am Wortanfang groß gibt „SS“ – nicht einsetzen.
      expect(repairWithKuerzel('${x}ab, Ute', 'ßa'), '${x}ab, Ute');
      expect(repairWithKuerzel('Alt, Anna', 'Al'), 'Alt, Anna');
      // Kürzel könnte Nachname + Vorname sein („YÜ“, Vorname Ü…).
      expect(repairWithKuerzel('Y${x}lmaz, Ümit', 'YÜ'), 'Y${x}lmaz, Ümit');
    });
  });

  test('gleich bis auf „�“', () {
    expect(sameNameIgnoringBroken('M${x}we', 'Möwe'), isTrue);
    expect(sameNameIgnoringBroken('möwe', 'M${x}WE'), isTrue);
    expect(sameNameIgnoringBroken('M${x}we', 'Mowen'), isFalse);
    expect(sameNameIgnoringBroken('M${x}we', 'Mowe'), isFalse);
    expect(sameNameIgnoringBroken('Alt', 'Alp'), isFalse);
  });

  group('NameRepairs', () {
    final lessons = [
      _l('Mathematik', [
        LessonTeacher(teacher: 'M${x}we, Anna', teacherKuerzel: 'Mö'),
      ]),
      _l('Deutsch', [
        LessonTeacher(teacher: 'Berg-Sch${x}ler, Jan', teacherKuerzel: 'BS'),
      ]),
      _l('Kunst', [
        LessonTeacher(teacher: 'Alt, J${x}rg', teacherKuerzel: 'AJ'),
        LessonTeacher(teacher: 'Bau, Clara', teacherKuerzel: 'BC'),
      ]),
    ];

    test('ganze Namen aus Kürzel und eigenem Namen, nichts Geratenes', () {
      final r = NameRepairs()
        ..learnFor('1', lessons, {'BS': 'Jan Berg-Schüler', 'BC': 'Frau Bau'});
      // Kürzel: beide Formen des Portal-Namens.
      expect(r.apply('Anna M${x}we'), 'Anna Möwe');
      expect(r.apply(' M${x}we,  Anna '), 'Möwe, Anna');
      // Eigener Name, auch für einen heilen Portal-Namen.
      expect(r.apply('Jan Berg-Sch${x}ler'), 'Jan Berg-Schüler');
      expect(r.apply('Berg-Sch${x}ler, Jan'), 'Jan Berg-Schüler');
      expect(r.apply('Clara Bau'), 'Frau Bau');
      // Keine einzelnen Wörter: andere Person mit gleichem Wort bleibt.
      expect(r.apply('Herr M${x}we'), 'Herr M${x}we');
      expect(r.apply('Bea M${x}we'), 'Bea M${x}we');
      // Unbekannt bleibt kaputt.
      expect(r.apply('J${x}rg Alt'), 'J${x}rg Alt');
    });

    test('je Konto und widersprüchlich über Konten', () {
      final r = NameRepairs()
        ..learnFor('1', lessons, const {})
        ..learnFor('2', [
          _l('Sport', [
            LessonTeacher(teacher: 'M${x}we, Anna', teacherKuerzel: 'Mä'),
          ]),
        ], const {});
      expect(r.apply('Anna M${x}we'), 'Anna M${x}we');
      expect(r.apply('Anna M${x}we', account: 1), 'Anna Möwe');
      expect(r.apply('Anna M${x}we', account: 2), 'Anna Mäwe');
      expect(r.apply('Anna M${x}we', account: 3), 'Anna M${x}we');
      // Neu lernen für Konto 2 ersetzt dessen alten Stand.
      r.learnFor('2', const [], const {});
      expect(r.apply('Anna M${x}we'), 'Anna Möwe');
    });
  });

  test('Plan, Kurse und Empfänger zeigen reparierte bzw. eigene Namen', () {
    final lessons = [
      _l('Mathematik', [
        LessonTeacher(teacher: 'M${x}we, Anna', teacherKuerzel: 'Mö'),
        LessonTeacher(teacher: 'Alt, J${x}rg', teacherKuerzel: 'AJ'),
      ]),
    ];
    final plan = livePlan(
      tt: TimeTable(),
      lessons: lessons,
      firstName: 'Kind',
    ).plan;
    expect(plan.teacherNames['Mö'], 'Anna Möwe');
    final courses = courseItemsFrom(lessons, ownNames: {'AJ': 'Jörg Alt'});
    expect(courses.single.teachers, ['Anna Möwe', 'Jörg Alt']);
    final c = candidatesFrom(lessons, ownNames: {'AJ': 'Jörg Alt'});
    expect(c.map((e) => e.display), ['Anna Möwe', 'Jörg Alt']);
    expect(c.first.lastName, 'M${x}we');
    expect(c.first.searchNames, ['Möwe', 'we']);
    expect(c.last.searchNames, ['Alt']);
  });

  test('Suchbegriffe: repariert, eigener Name, Stück ohne „�“', () {
    expect(searchQueries('Gro${x}e', own: 'Uta Große'), ['Große', 'Gro']);
    expect(searchQueries('K${x}hn'), ['hn']);
    expect(searchQueries('${x}z'), isEmpty);
    expect(searchQueries('Alt', repaired: 'Alt', own: 'Anna Alt'), ['Alt']);
  });

  test(
    'Portal-Treffer mit „�“: Auswahl tolerant, ohne Rückfrage nur genau',
    () {
      final c = candidatesFrom([
        _l('Mathematik', [
          LessonTeacher(teacher: 'M${x}we, Anna', teacherKuerzel: 'Mö'),
        ]),
      ]).single;
      final broken = ReceiverEntry('l-1', 'M${x}we, Anna', true);
      final ascii = ReceiverEntry('l-2', 'Mowe, Anna', true);
      final fixed = ReceiverEntry('l-3', 'Möwe, Anna', true);
      final other = ReceiverEntry('l-4', 'Mäwe, Anna', true);
      final hits = matchReceivers([broken, ascii, fixed, other], c);
      expect(hits.map((h) => h.id), ['l-1', 'l-3', 'l-4']);
      expect(isSureReceiver(broken, c), isTrue);
      expect(isSureReceiver(fixed, c), isTrue);
      // Prüfbefund 09.11.26: „Mäwe“ passt nur über den Platzhalter.
      expect(isSureReceiver(other, c), isFalse);
      // Ohne reparierten Nachnamen zählt „�“ nur gegen „�“.
      final u = candidatesFrom([
        _l('Kunst', [
          LessonTeacher(teacher: 'K${x}hn, Udo', teacherKuerzel: 'KU'),
        ]),
      ]).single;
      expect(
        isSureReceiver(ReceiverEntry('l-5', 'Kühn, Udo', true), u),
        isFalse,
      );
      expect(
        isSureReceiver(ReceiverEntry('l-6', 'K${x}hn, Udo', true), u),
        isTrue,
      );
    },
  );

  testWidgets('Stunden-Details: „Name korrigieren“ nur bei „�“', (t) async {
    Future<void> show(Map<String, String> names) => t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: LessonSheet(
            plan: KidPlan(
              firstName: 'Kind',
              colorIndex: 0,
              slots: const [],
              days: const [],
              teacherNames: names,
            ),
            lesson: const PlanLesson(
              subject: 'Chemie',
              short: 'CH',
              teacher: 'Lb',
            ),
            time: '1. Stunde',
            onNameTeacher: (_) {},
          ),
        ),
      ),
    );
    await show({'Lb': 'Lena L${x}ber'});
    expect(find.text('Name korrigieren'), findsOneWidget);
    await show({'Lb': 'Lena Lüber'});
    expect(find.text('Name korrigieren'), findsNothing);
  });
}
