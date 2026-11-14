import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/kid_chips.dart';
import 'package:lanis/fork/ui/pinned_page.dart';

// Querformat am Telefon (Wunsch 14.11.26): Pillen und Zurück in der
// Überschriftzeile, ohne PinnedPage weiter darüber, Zustand übersteht das
// Drehen.
const phone = Size(1080, 2424);
const land = Size(2424, 1080);

KidChips _chips() => KidChips(
  kids: const [(name: 'Lena', color: 0), (name: 'Jonas', color: 1)],
  selected: 0,
  onSelect: (_) {},
);

Future<void> _pump(WidgetTester t, Size size, Widget child) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 2.625;
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PinnedKidChips(chips: _chips(), child: child),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  tearDown(() {
    final v = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    v.resetPhysicalSize();
    v.resetDevicePixelRatio();
  });

  testWidgets('quer: Pillen neben der Überschrift, hoch darüber', (t) async {
    final page = PinnedPage(
      header: const [Text('Titel')],
      children: const [TextField()],
    );
    await _pump(t, land, page);
    final title = t.getCenter(find.text('Titel')).dy;
    expect((t.getCenter(find.text('Lena')).dy - title).abs(), lessThan(4));
    expect(find.text('Lena'), findsOneWidget);

    // Drehen: Getipptes bleibt, Pillen wieder über der Überschrift.
    await t.enterText(find.byType(TextField), 'Entwurf');
    t.view.physicalSize = phone;
    await t.pumpAndSettle();
    expect(find.text('Entwurf'), findsOneWidget);
    expect(
      t.getCenter(find.text('Lena')).dy,
      lessThan(t.getCenter(find.text('Titel')).dy - 20),
    );
    expect(find.text('Lena'), findsOneWidget);
  });

  testWidgets('quer ohne PinnedPage: Pillenzeile bleibt', (t) async {
    await _pump(t, land, const Center(child: Text('Lädt …')));
    expect(find.text('Lena'), findsOneWidget);
  });

  testWidgets('quer: eigener Zurück-Pfeil neben der Überschrift', (t) async {
    t.view.physicalSize = land;
    t.view.devicePixelRatio = 2.625;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedPage(
            leading: const Icon(Icons.arrow_back),
            header: const [Text('Fach')],
          ),
        ),
      ),
    );
    final arrow = t.getCenter(find.byIcon(Icons.arrow_back)).dy;
    expect((arrow - t.getCenter(find.text('Fach')).dy).abs(), lessThan(4));
    t.view.physicalSize = phone;
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byIcon(Icons.arrow_back)).dy,
      lessThan(t.getCenter(find.text('Fach')).dy - 20),
    );
  });

  testWidgets('quer: Pillen von TitleChips ohne PinnedPage nicht doppelt', (
    t,
  ) async {
    // Wie die Wochenansicht des Kalenders: Kopfzeile mit TitleChips, aber
    // keine PinnedPage (Prüfbefund 14.11.26).
    await _pump(
      t,
      land,
      Builder(
        builder: (c) => Row(
          children: [
            const Text('Kalender'),
            if (TitleChips.shows(c)) const Flexible(child: TitleChips()),
          ],
        ),
      ),
    );
    expect(find.text('Lena'), findsOneWidget);
    // Hoch: TitleChips hängt nicht, Pillen darüber genau einmal.
    t.view.physicalSize = phone;
    await t.pumpAndSettle();
    expect(find.text('Lena'), findsOneWidget);
  });
}
