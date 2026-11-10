import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';

/// Diagnose unlesbare App-Liste (session.dart, parseFastTravelMenu;
/// Fehlerbericht Nr. 13/14). Frei erfundene Antworten.
void main() {
  late List<List<int>> calls;
  setUp(() {
    calls = [];
    onUnreadableAppList = (s, l, k) => calls.add([s, l, k]);
  });
  tearDown(() => onUnreadableAppList = null);

  test('gültige Liste: gelesen, keine Meldung', () {
    final r = parseFastTravelMenu(200, '{"entrys":[{"link":"kalender.php"}]}');
    expect(r, hasLength(1));
    expect(calls, isEmpty);
  });

  test('leere Weiterleitung: Meldung mit Kennzahlen, Fehler bleibt', () {
    expect(() => parseFastTravelMenu(302, ''), throwsFormatException);
    expect(calls, [
      [302, 0, 0],
    ]);
  });

  test('abgeschnittenes JSON und HTML werden unterschieden', () {
    expect(
      () => parseFastTravelMenu(200, '{"entrys":[{"li'),
      throwsFormatException,
    );
    expect(
      () => parseFastTravelMenu(200, '  <html><body>x</body></html>'),
      throwsFormatException,
    );
    expect(calls.map((c) => c[2]), [2, 1]);
    expect(calls.first[1], 15);
  });
}
