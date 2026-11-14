import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/ui/courses/course_detail_page.dart';
import 'package:lanis/fork/ui/preview/preview_shell.dart';

Widget _app() => MaterialApp(
  localizationsDelegates: ForkL10n.localizationsDelegates,
  supportedLocales: ForkL10n.supportedLocales,
  locale: const Locale('de'),
  home: const PreviewShell(),
);

Finder _nav(String label) => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.text(label),
);

void main() {
  testWidgets('Leiste bleibt auf der Kursseite, Reiter merken ihren Verlauf', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2424);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mathematik').first);
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsOneWidget);

    // Anderer Reiter und zurück: Kursseite ist noch offen.
    await t.tap(_nav('Heute'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);

    // Erneut antippen: an den Anfang des Reiters.
    await t.tap(_nav('Unterricht'));
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);

    // Android-Zurück: erst im Reiter, dann nach „Heute“.
    await t.tap(find.text('Mathematik').first);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsNothing);
    expect(find.text('Mathematik'), findsWidgets);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(FloatingNavBar), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // Entwurf 14.11.26: Telefon quer → Leiste links, Tablet quer → unten.
  for (final (size, vertical) in [
    (const Size(2424, 1080), true),
    (const Size(2560, 1600), false),
  ]) {
    for (final scale in [1.0, 1.4 * 1.3]) {
      testWidgets('Leiste quer ${size.width}x${size.height} Schrift $scale', (
        t,
      ) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = size.width > 2500 ? 2 : 2.625;
        t.view.padding = const FakeViewPadding(left: 120, bottom: 63);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(_app());
        await t.pumpAndSettle();
        final bar = t.widget<FloatingNavBar>(find.byType(FloatingNavBar));
        expect(bar.axis, vertical ? Axis.vertical : Axis.horizontal);
        await t.tap(_nav('Kalender'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // Tastatur quer: Die Leiste liegt außerhalb des Scaffold und wird
        // überdeckt statt gestaucht (Prüfbefund 14.11.26: bis 31 px Überlauf).
        t.view.viewInsets = const FakeViewPadding(bottom: 230 * 2.625);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        if (vertical) {
          // Inhalt rechts neben der Leiste, nicht unter der Kamera.
          final left = t.getTopLeft(find.text('Kalender').last).dx;
          expect(left, greaterThan(120 / 2.625 + 76));
        }
      });
    }
  }
}
