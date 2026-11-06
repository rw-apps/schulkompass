// Tipp auf eine Benachrichtigung: Ziel und Konto (Wunsch 06.11.26).
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/notify/notify_launch.dart';
import 'package:lanis/fork/widget/widget_launch.dart';

void main() {
  test('Adresse der Benachrichtigung liest sich wie ein Widget-Tipp', () {
    for (final t in WidgetTarget.values) {
      final l = WidgetLaunch.parse(Uri.parse(notifyPayload(t, account: 7)));
      expect(l, WidgetLaunch(target: t, account: 7), reason: t.name);
    }
    expect(
      WidgetLaunch.parse(Uri.parse(notifyPayload(WidgetTarget.today))),
      const WidgetLaunch(target: WidgetTarget.today),
    );
  });

  test('ohne Ziel oder fremde Adresse', () {
    expect(WidgetLaunch.parse(Uri.tryParse('')), isNull);
    expect(WidgetLaunch.parse(Uri.parse('https://example.org')), isNull);
  });
}
