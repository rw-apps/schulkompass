import 'package:flutter/material.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/messages/compose_model.dart';
import 'package:lanis/fork/ui/messages/compose_page.dart';
import 'package:lanis/fork/ui/messages/messages_page.dart';
import 'package:lanis/fork/ui/preview/demo_courses.dart';
import 'package:liblanis/liblanis.dart';

Lesson _l(String name, List<LessonTeacher> t) =>
    Lesson(courseID: name, name: name, teachers: t, courseURL: Uri.parse('x'));

/// Erfundenes Portal: Suche nach Nachnamen, Versand wird nur protokolliert.
class _FakeBackend implements ComposeBackend {
  final sent = <({List<String> receivers, String subject, String text})>[];
  final directory = <ReceiverEntry>[
    ReceiverEntry('l-1', 'Alt, Anna', true),
    ReceiverEntry('l-2', 'Alt, Bernd', true),
    ReceiverEntry('l-3', 'Bau, Clara', true),
    ReceiverEntry('s-9', 'Alt, Schüler', false),
  ];

  @override
  Future<List<ReceiverEntry>> search(String q) async => [
    for (final r in directory)
      if (r.name.toLowerCase().contains(q.toLowerCase())) r,
  ];

  @override
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  }) async {
    sent.add((receivers: receivers, subject: subject, text: text));
    return true;
  }
}

/// Protokolliert die Suchbegriffe und reicht weiter.
class _ProbeBackend implements ComposeBackend {
  _ProbeBackend(this.inner, this.queries);
  final _FakeBackend inner;
  final List<String> queries;

  @override
  Future<List<ReceiverEntry>> search(String q) {
    queries.add(q);
    return inner.search(q);
  }

  @override
  Future<bool> send({
    required List<String> receivers,
    required String subject,
    required String text,
  }) => inner.send(receivers: receivers, subject: subject, text: text);
}

void main() {
  final lessons = [
    _l('Mathematik 06 xy', [
      LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
    ]),
    _l('Training Klasse 6', [
      LessonTeacher(teacher: 'Alt, Anna', teacherKuerzel: 'AAA'),
      LessonTeacher(teacher: 'Bau, Clara', teacherKuerzel: 'CCC'),
    ]),
    _l('Sport', [LessonTeacher(teacher: 'Zett, Zora', teacherKuerzel: 'ZZZ')]),
  ];

  test('Empfänger aus dem Unterricht, je Kürzel einmal mit Fächern', () {
    final c = candidatesFrom(lessons);
    expect(c.map((x) => x.display), ['Anna Alt', 'Clara Bau', 'Zora Zett']);
    expect(c.first.subjects, ['Mathematik', 'Training Klasse']);
    expect(c.first.lastName, 'Alt');
    final big = candidatesFrom([
      _l('Ganztag', [
        for (final x in ['P', 'Q', 'R', 'S'])
          LessonTeacher(teacher: '$x, $x', teacherKuerzel: x),
      ]),
      ...lessons,
    ]);
    expect(big.first.display, 'Anna Alt', reason: 'große Teams ans Ende');
  });

  test(
    'Portal-Treffer: Lehrkraft mit Nachname, bei mehreren der Vorname',
    () async {
      final b = _FakeBackend();
      final anna = candidatesFrom(lessons).first;
      final hits = matchReceivers(await b.search(anna.lastName), anna);
      expect(hits.map((h) => h.id), [
        'l-1',
      ], reason: 'Bernd Alt und Schüler raus');
      final zora = candidatesFrom(lessons).last;
      expect(matchReceivers(await b.search(zora.lastName), zora), isEmpty);
    },
  );

  Future<void> pump(WidgetTester t, Widget w, {double scale = 1.0}) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),

        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: w,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Schreiben: Empfänger, Vorlage, Rückfrage, Versand', (t) async {
    final b = _FakeBackend();
    await pump(t, ComposePage(candidates: candidatesFrom(lessons), backend: b));
    expect(find.text('Erst Empfänger wählen'), findsOneWidget);
    await t.tap(find.text('Anna Alt'));
    await t.pumpAndSettle();
    await t.tap(find.text('Zora Zett'));
    await t.pumpAndSettle();
    expect(find.text('Über das Portal nicht erreichbar'), findsOneWidget);
    await t.tap(find.text('Frage zur Hausaufgabe'));
    await t.pumpAndSettle();
    final send = find.text('Senden an Anna Alt');
    await t.ensureVisible(send);
    await t.pumpAndSettle();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(find.text('Nachricht senden?'), findsOneWidget);
    expect(b.sent, isEmpty, reason: 'erst nach Bestätigung');
    await t.tap(find.text('Senden').last);
    await t.pumpAndSettle();
    expect(b.sent.single.receivers, ['l-1']);
    expect(b.sent.single.subject, 'Frage zur Hausaufgabe');
  });

  testWidgets('Nachname mit „�“: Suche über Teilstück, Versand an Treffer', (
    t,
  ) async {
    // Erfunden: Das Portal schickt „M\uFFFDwe“, seine Suche findet „Möwe“
    // nicht, das Stück „we“ aber schon (Rückmeldung 09.11.26).
    final b = _FakeBackend();
    b.directory.add(const ReceiverEntry('l-7', 'M\uFFFDwe, Ina', true));
    final queries = <String>[];
    final probe = _ProbeBackend(b, queries);
    await pump(
      t,
      ComposePage(
        candidates: candidatesFrom([
          _l('Musik', [
            LessonTeacher(teacher: 'M\uFFFDwe, Ina', teacherKuerzel: 'Mö'),
          ]),
        ]),
        backend: probe,
      ),
    );
    await t.tap(find.text('Ina Möwe'));
    // Die Zeile dreht, solange die Auswahl offen ist: kein pumpAndSettle.
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(queries, ['Möwe', 'we']);
    // Über das Teilstück gefunden: erst Auswahl, dann gewählt.
    expect(find.text('M\uFFFDwe, Ina'), findsOneWidget);
    await t.tap(find.text('M\uFFFDwe, Ina'));
    await t.pumpAndSettle();
    await t.tap(find.text('Frage zur Hausaufgabe'));
    await t.pumpAndSettle();
    final send = find.text('Senden an Ina Möwe');
    await t.ensureVisible(send);
    await t.tap(send);
    await t.pumpAndSettle();
    await t.tap(find.text('Senden').last);
    await t.pumpAndSettle();
    expect(b.sent.single.receivers, ['l-7']);
  });

  testWidgets('Name korrigieren: nur bei „�“, „�“ markiert, gilt sofort', (
    t,
  ) async {
    final saved = <(String, String)>[];
    final b = _FakeBackend();
    b.directory.add(const ReceiverEntry('l-9', 'L\uFFFDber, Lena', true));
    final queries = <String>[];
    final probe = _ProbeBackend(b, queries);
    await pump(
      t,
      ComposePage(
        candidates: candidatesFrom([
          _l('Chemie', [
            LessonTeacher(teacher: 'L\uFFFDber, Lena', teacherKuerzel: 'Lb'),
          ]),
          _l('Musik', [
            LessonTeacher(teacher: 'Rosen, Mia', teacherKuerzel: 'RO'),
          ]),
        ]),
        backend: probe,
        onNameTeacher: (kz, n) => saved.add((kz, n)),
      ),
    );
    expect(find.text('Name korrigieren'), findsOneWidget);
    await t.tap(find.text('Name korrigieren'));
    await t.pumpAndSettle();
    final field = t.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 6, extentOffset: 7),
    );
    await t.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Lena Lüber',
    );
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(saved, [('Lb', 'Lena Lüber')]);
    expect(find.text('Lena Lüber'), findsOneWidget);
    // Link bleibt für Tippfehler (Prüfbefund 10.11.26).
    expect(find.text('Name korrigieren'), findsOneWidget);
    // Suche nutzt sofort den korrigierten Nachnamen. Die Testsuche findet
    // ihn nicht (Portal führt „L�ber“), erst das Stück „ber“ – dann wählt
    // man selbst.
    await t.tap(find.text('Lena Lüber'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(queries, ['Lüber', 'ber']);
    await t.tap(find.text('L\uFFFDber, Lena'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await t.tap(find.text('Frage zur Hausaufgabe'));
    await t.pumpAndSettle();
    expect(find.text('Senden an Lena Lüber'), findsOneWidget);
    // Erneut korrigieren ändert auch den gewählten Empfänger.
    await t.tap(find.text('Name korrigieren'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Frau Lüber',
    );
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Senden an Frau Lüber'), findsOneWidget);
  });

  testWidgets('Nur über Platzhalter passender Treffer wird nicht selbst '
      'gewählt', (t) async {
    final b = _FakeBackend();
    b.directory.add(const ReceiverEntry('l-8', 'Mäwe, Ina', true));
    await pump(
      t,
      ComposePage(
        candidates: candidatesFrom([
          _l('Musik', [
            LessonTeacher(teacher: 'M\uFFFDwe, Ina', teacherKuerzel: 'Mö'),
          ]),
        ]),
        backend: b,
      ),
    );
    await t.tap(find.text('Ina Möwe'));
    // Die Zeile dreht, solange die Auswahl offen ist: kein pumpAndSettle.
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // Rückfrage zeigt den Portal-Namen, nichts ist gewählt.
    expect(find.text('Mäwe, Ina'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.textContaining('Senden an'), findsNothing);
  });

  for (final scale in [1.0, 1.4 * 1.3]) {
    testWidgets('Nachrichten und Schreiben ohne Überlauf ×$scale', (t) async {
      await pump(
        t,
        Scaffold(
          backgroundColor: KitPalette.light.bg,
          body: MessagesPage(items: demoMessages(), onCompose: () {}),
        ),
        scale: scale,
      );
      expect(t.takeException(), isNull);
      expect(find.text('1 ungelesen'), findsOneWidget);
      await pump(
        t,
        ComposePage(
          candidates: candidatesFrom(lessons),
          backend: _FakeBackend(),
        ),
        scale: scale,
      );
      expect(t.takeException(), isNull);
    });
  }
}
