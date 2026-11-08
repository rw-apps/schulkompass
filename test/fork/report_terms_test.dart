// Unbekannte Begriffe und Kontext in Fehlerberichten (Wunsch 08.11.26).
// Synthetisch – keine echten Schulen, Namen oder Begriffe einer Schule.
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork/error_log.dart';
import 'package:lanis/fork/report_relay.dart';
import 'package:lanis/fork/report_terms.dart';
import 'package:lanis/fork/ui/today/auto_report_prompt.dart';

TypedSettings _mem() {
  final m = <String, String?>{};
  return TypedSettings(
    read: (k) => m[k],
    write: (k, v) => m[k] = v,
    delete: m.remove,
  );
}

void main() {
  setUp(() {
    ErrorLog.instance
      ..clear()
      ..version = '4.1.0+1';
    TermLog.instance.clear();
    ReportContext.instance
      ..clear()
      ..language = '';
  });

  test('safeTerm lässt nur kurze Wörter aus Buchstaben durch', () {
    expect(safeTerm('  Freisetzung '), 'Freisetzung');
    expect(safeTerm('Raum-Tausch'), 'Raum-Tausch');
    expect(safeTerm('nicht erfasst'), 'nicht erfasst');
    expect(safeTerm('9C'), isNull); // Klasse
    expect(safeTerm('M103'), isNull); // Raum
    expect(safeTerm('Muster, Max'), isNull); // Name im Portalformat
    expect(safeTerm('a'), isNull);
    expect(safeTerm('eins zwei drei vier'), isNull);
    expect(safeTerm('x' * 31), isNull);
    expect(safeTerm(null), isNull);
    expect(safeTerm('Hr. Muster'), isNull); // Anrede
    expect(safeTerm('Sprechstunde Frau Muster'), isNull);
    expect(safeTerm('MÜL'), isNull); // Kürzel
    expect(safeTerm('Vertretung'), 'Vertretung');
  });

  test('TermLog: jedes Wort einmal, Grenze maxTerms', () {
    final t = TermLog.instance
      ..note('vertretungsplan.php', 'Art', 'Freisetzung')
      ..note('vertretungsplan.php', 'Art', 'freisetzung')
      ..note('vertretungsplan.php', 'Art', 'Muster, Max');
    expect([for (final e in t.entries) e.word], ['Freisetzung']);
    for (var i = 0; i < TermLog.maxTerms + 5; i++) {
      t.note(
        'kalender.php',
        'Kategorie',
        'Wort${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + i ~/ 26)}',
      );
    }
    expect(t.entries.length, TermLog.maxTerms);
    // Verdrängte kommen beim nächsten Zeichnen nicht wieder (keine Schleife).
    final before = [for (final e in t.entries) e.key];
    for (var i = 0; i < TermLog.maxTerms + 5; i++) {
      t.note(
        'kalender.php',
        'Kategorie',
        'Wort${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + i ~/ 26)}',
      );
    }
    expect([for (final e in t.entries) e.key], before);
    // Ohne Version im Schlüssel: nach einem Update nicht erneut neu.
    ErrorLog.instance.version = '4.1.0+2';
    t.note('kalender.php', 'Kategorie', 'Wortaa');
    expect([for (final e in t.entries) e.key], before);
  });

  test('Kontext und Module ohne Namen', () {
    final ctx = ReportContext.instance..language = 'de';
    noteLoadTerms(
      account: 7,
      type: 'Eltern',
      kids: 2,
      modules: [
        {'Name': 'Kalender', 'link': 'kalender.php'},
        {'Name': 'Radeln', 'link': 'schulradeln.php'},
        {'Name': 'Moodle Musterschule', 'link': 'https://moodle.example/'},
        {'Name': 'Notruf', 'link': 'index.php?a=f&e=l11'},
      ],
      categories: ['Ferien', 'Elternabend', 'Elternabend', ''],
      knownCategory: (c) => c.contains('ferien'),
    );
    expect(ctx.lines(), [
      'Gerätesprache: de',
      'Konto 1: Eltern · 2 Kinder · Module: kalender, schulradeln',
    ]);
    expect(
      [for (final e in TermLog.instance.entries) '${e.area}|${e.word}'],
      ['kalender.php|Elternabend'], // Module nie als Begriff
    );
    final r = termsReport();
    expect(r, contains('Unbekannte Begriffe:'));
    expect(r, contains('4.1.0+1 · kalender.php · Kategorie · Elternabend'));
  });

  group('Zustimmung', () {
    late List<String> texts;
    Future<bool> send({
      required String kind,
      required String version,
      required String area,
      required String text,
    }) async {
      texts.add('$area\n$text');
      return true;
    }

    setUp(() => texts = []);

    test('alte Zustimmung: Begriffe bleiben auf dem Gerät', () async {
      final s = _mem()..setBool(autoReportKey, true);
      TermLog.instance.note('vertretungsplan.php', 'Art', 'Freisetzung');
      expect(await flushErrorReports(s, os: 't', send: send), isFalse);
      ErrorLog.instance.record('x.php', UnknownException('x'), null);
      expect(await flushErrorReports(s, os: 't', send: send), isTrue);
      expect(texts.single, isNot(contains('Freisetzung')));
      // Heute fragt einmal nach der Erweiterung.
      expect(autoReportPromptDue(s), isTrue);
      s.setBool(autoReportAskedTermsKey, true);
      expect(autoReportPromptDue(s), isFalse);
    });

    test('erweiterte Zustimmung: neuer Begriff allein meldet', () async {
      final s = _mem();
      setAutoReport(s, true);
      expect(autoReportTermsAllowed(s), isTrue);
      TermLog.instance.note('vertretungsplan.php', 'Art', 'Freisetzung');
      expect(await flushErrorReports(s, os: 't', send: send), isTrue);
      expect(texts.single, startsWith('Begriff · vertretungsplan.php · Art'));
      expect(texts.single, contains('Art · Freisetzung'));
      expect(await flushErrorReports(s, os: 't', send: send), isFalse);
      expect(autoReportPromptDue(s), isFalse);
      setAutoReport(s, false);
      expect(autoReportTermsAllowed(s), isFalse);
    });
  });
}
