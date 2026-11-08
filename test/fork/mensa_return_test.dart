// Rücksprung nach der Anmeldung beim Caterer (Rückmeldung 08.11.26).
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/mensa/mensa_page.dart' show mensaShouldReturn;

void main() {
  bool r({
    bool enabled = true,
    bool returned = false,
    int signedInAt = 2,
    int weekAt = 3,
    bool deciding = false,
    bool otherSession = false,
    bool onTop = true,
  }) => mensaShouldReturn(
    enabled: enabled,
    returned: returned,
    signedInAt: signedInAt,
    weekAt: weekAt,
    deciding: deciding,
    otherSession: otherSession,
    onTop: onTop,
  );

  test('nach Anmeldung und neu gelesener Woche zurück', () {
    expect(r(), isTrue);
  });

  test('sonst bleiben', () {
    expect(r(enabled: false), isFalse); // geöffnet über „Bestellen“
    expect(r(returned: true), isFalse); // nur einmal
    expect(r(signedInAt: -1), isFalse); // nie angemeldet (Cookie)
    expect(r(weekAt: 2), isFalse); // Woche vor bzw. auf der Anmeldeseite
    expect(r(weekAt: -1), isFalse); // falsches Passwort: keine Woche
    expect(r(deciding: true), isFalse); // Rückfrage „merken?“ offen
    expect(r(otherSession: true), isFalse); // Sitzung des Geschwisters
    expect(r(onTop: false), isFalse); // schon zurück bzw. Dialog oben
  });
}
