// Gemischte Kodierung im Portal (Rückmeldung 09.11.26): UTF-8-Seite mit
// Latin-1-Bytes in Namen. Synthetische Namen.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart'
    show decodeMostlyUtf8, decodePortalText, onMixedEncoding;

void main() {
  test('reines UTF-8 bleibt unverändert', () {
    expect(
      decodePortalText(utf8.encode('Französisch · Müller')),
      'Französisch · Müller',
    );
  });

  test('Latin-1-Bytes zwischen UTF-8 werden Umlaute statt �', () {
    final bytes = [
      ...utf8.encode('<td>Französisch</td><span title="'),
      ...latin1.encode('Mölle, Jürgen'),
      ...utf8.encode('">MÖL</span>'),
    ];
    expect(
      decodePortalText(bytes),
      '<td>Französisch</td><span title="Mölle, Jürgen">MÖL</span>',
    );
  });

  test('Byte am Ende, Windows-1252, ungültige Folgen', () {
    expect(decodePortalText([0x41, 0xE4]), 'Aä');
    expect(decodePortalText([0x80, 0x20, 0x35]), '€ 5');
    expect(decodePortalText([0x8A, 0x9E, 0x84, 0x96]), 'Šž„–');
    // überlang (C0 80), Surrogat (ED A0 80): als einzelne Zeichen
    expect(decodePortalText([0xC0, 0x80]).length, 2);
    expect(decodePortalText([0xED, 0xA0, 0x80]).length, 3);
    // 4-Byte-Folge bleibt, fremdes Byte direkt davor wird gerettet
    expect(decodePortalText([0xFC, ...utf8.encode('😀')]), 'ü😀');
  });

  test('Zufall bleibt für Entschlüsseltes ein Fehler', () {
    expect(decodeMostlyUtf8([...utf8.encode('Text '), 0xFC]), 'Text ü');
    expect(
      decodeMostlyUtf8([for (var i = 0; i < 64; i++) 0x80 + (i * 7) % 0x40]),
      isNull,
    );
  });

  test('meldet die Zahl fremder Bytes', () {
    final seen = <int>[];
    onMixedEncoding = seen.add;
    addTearDown(() => onMixedEncoding = null);
    decodePortalText([...latin1.encode('Jäger'), 0x20, ...utf8.encode('ü')]);
    decodePortalText(utf8.encode('Jäger'));
    expect(seen, [1]);
  });
}
