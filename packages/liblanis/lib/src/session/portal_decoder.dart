import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Fork: Antworten des Portals als UTF-8 lesen, einzelne Bytes in einer
/// anderen Kodierung aber als Windows-1252 retten.
///
/// Ursache (Rückmeldung 09.11.26, Bildschirmfoto „Neue Nachricht“): Namen
/// von Lehrkräften mit Umlaut erschienen als „L�cke“, während Fächer
/// derselben Antwort (meinunterricht.php, `h2` gegen `title` am Knopf der
/// Lehrkraft) richtig waren – Vermutung: gemischte Kodierung im Portal.
/// Exporte vom 17.10. und 28.10.26 zeigten die Namen noch richtig; geändert
/// hat sich das danach. Dio liest jede Antwort mit
/// `utf8.decode(allowMalformed: true)` (FusedTransformer) und macht aus
/// jedem solchen Byte ein „�“ – unwiderruflich. Folge über die Anzeige
/// hinaus: Die Suche nach „L�cke“ fand die Lehrkraft nicht.
///
/// Belegt wird die Vermutung über [onMixedEncoding] (Fork: Fehlerprotokoll,
/// nur Zahl der Bytes). Grenzen: Schickt das Portal selbst „�“ (EF BF BD),
/// hilft das nicht. Ein fremdes Byte, auf das zufällig 0x80–0xBF folgt,
/// wird als UTF-8 gelesen („Ü°“); nach einem Umlaut im Namen folgt ein
/// Buchstabe, das tritt dort nicht auf. Abgelegte Kurse (offline_store)
/// behalten „�“ bis zum nächsten Abruf.
FutureOr<String?> portalResponseDecoder(
  List<int> bytes,
  RequestOptions options,
  ResponseBody body,
) => decodePortalText(bytes);

/// Kern von [portalResponseDecoder], ohne Dio prüfbar.
String decodePortalText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    final (text, bad) = _mixed(bytes);
    onMixedEncoding?.call(bad);
    return text;
  }
}

/// Wie [decodePortalText], aber null, wenn mehr als jedes 20. Byte fremd
/// ist. Für entschlüsselte Inhalte (cryptor.dart): Mit falschem Schlüssel
/// kommt Zufall heraus; bisher fiel das am strengen UTF-8 auf und löste die
/// Neuanmeldung aus – das soll so bleiben (Prüfung 09.11.26).
String? decodeMostlyUtf8(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    final (text, bad) = _mixed(bytes);
    if (bad > bytes.length ~/ 20 + 2) return null;
    onMixedEncoding?.call(bad);
    return text;
  }
}

/// Meldet, wie viele Bytes einer Antwort nicht UTF-8 waren (nur die Zahl).
void Function(int bytes)? onMixedEncoding;

/// Windows-1252 für 0x80–0x9F (MySQL/PHP „latin1“ ist in Wahrheit 1252:
/// Š, ž, „ “, – …); undefinierte Stellen (81, 8D, 8F, 90, 9D) als Latin-1.
const _cp1252 = <int>[
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178, //
];

(String, int) _mixed(List<int> b) {
  final out = StringBuffer();
  var bad = 0;
  var run = 0; // Beginn des laufenden gültigen Abschnitts
  var i = 0;
  void flush(int end) {
    if (end > run) out.write(utf8.decode(b.sublist(run, end)));
  }

  while (i < b.length) {
    final c = b[i];
    if (c < 0x80) {
      i++;
      continue;
    }
    final n = c >= 0xC2 && c <= 0xDF
        ? 2
        : c >= 0xE0 && c <= 0xEF
        ? 3
        : c >= 0xF0 && c <= 0xF4
        ? 4
        : 0;
    if (n > 0 && i + n <= b.length && _validSeq(b, i, n)) {
      i += n;
      continue;
    }
    flush(i);
    out.writeCharCode(c >= 0x80 && c <= 0x9F ? _cp1252[c - 0x80] : c);
    bad++;
    i++;
    run = i;
  }
  flush(b.length);
  return (out.toString(), bad);
}

/// Gültige UTF-8-Folge der Länge [n] ab [i] (keine überlangen Formen, keine
/// Ersatzzeichen-Hälften, höchstens U+10FFFF).
bool _validSeq(List<int> b, int i, int n) {
  for (var j = 1; j < n; j++) {
    if (b[i + j] & 0xC0 != 0x80) return false;
  }
  final c = b[i], d = b[i + 1];
  if (n == 3) {
    if (c == 0xE0 && d < 0xA0) return false; // überlang
    if (c == 0xED && d >= 0xA0) return false; // Surrogat
  }
  if (n == 4) {
    if (c == 0xF0 && d < 0x90) return false; // überlang
    if (c == 0xF4 && d >= 0x90) return false; // > U+10FFFF
  }
  return true;
}
