import 'package:flutter/material.dart';

import 'kid_chips.dart';
import 'kit.dart';

/// Seite mit feststehendem Kopf – EIN Baustein für alle Seiten mit eigener
/// Überschrift (Heute, Kalender, Unterricht, Fachseite, Nachrichten, Mehr,
/// Einstellungen und ihre Unterseiten).
///
/// Ursache (Rückmeldung 21.10.26: „auf jeder Seite muss die Überschrift
/// fixiert sein“): Die Überschrift lag im scrollenden Inhalt und verschwand
/// beim Scrollen; fest standen nur die Kind-Pillen (PinnedKidChips) und
/// Seiten mit Zurück-Leiste (AppBar). Der Kopf ([header]: Überschrift,
/// Unterzeile, Umschalter) steht jetzt außerhalb der Liste. Sobald Inhalt
/// unter ihm weggescrollt ist, trennt eine feine Linie (KitPalette.line),
/// damit man sieht, dass die Liste nicht am Anfang steht.
///
/// Grenze: Der Kopf nimmt seine Höhe dauerhaft ein. Deshalb gehören nur
/// Überschrift und Bedienelemente der Seite hinein, keine Hinweise oder
/// Inhalte.
class PinnedPage extends StatefulWidget {
  const PinnedPage({
    super.key,
    required this.header,
    this.children = const [],
    this.slivers,
    this.onRefresh,
    this.headerPadding = const EdgeInsets.fromLTRB(
      Sp.page,
      Sp.xl,
      Sp.page,
      Sp.m,
    ),
    this.bodyPadding = const EdgeInsets.fromLTRB(
      Sp.page,
      Sp.xs,
      Sp.page,
      Sp.xl,
    ),
    this.leading,
    this.placesChips = false,
  });

  /// Kopf von oben nach unten (Überschrift zuerst).
  final List<Widget> header;

  /// Zurück-Pfeil: hoch eine eigene Zeile über dem Kopf, quer (Handy und Tablet)
  /// links neben der ersten Kopfzeile ([compactHeader]).
  final Widget? leading;

  /// Die Seite setzt die Pillen selbst in ihre Kopfzeile ([TitleChips]),
  /// z. B. der Kalender direkt hinter die Überschrift statt hinter den
  /// Umschalter. Sonst stehen sie quer rechts in der ersten Kopfzeile.
  final bool placesChips;

  /// Inhalt als Liste …
  final List<Widget> children;

  /// … oder als Slivers (lange Listen wie die Nachrichten); dann gilt
  /// [children] nicht und [bodyPadding] umschließt die Slivers.
  final List<Widget>? slivers;

  /// Ziehen zum Aktualisieren; null = ohne.
  final Future<void> Function()? onRefresh;

  /// Rand um den Kopf. Die Statusleiste kommt oben hinzu (nicht unter den
  /// Kind-Pillen, PinnedKidChips entfernt sie dort schon – außer quer, wenn
  /// die Pillen in der Kopfzeile stehen). Quer (Handy und Tablet) oben höchstens
  /// [Sp.m] ([compactHeader]).
  final EdgeInsets headerPadding;

  /// Rand um den Inhalt. Unten kommt die Höhe der schwebenden Leiste hinzu
  /// (MediaQuery.padding.bottom bei Scaffold(extendBody: true)).
  final EdgeInsets bodyPadding;

  @override
  State<PinnedPage> createState() => _PinnedPageState();
}

class _PinnedPageState extends State<PinnedPage> {
  bool _under = false;

  bool _onScroll(ScrollNotification n) {
    // Nur die Liste selbst, nicht verschachtelte (z. B. waagrechte Pillen).
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final under = n.metrics.pixels > 0.5;
    if (under != _under) setState(() => _under = under);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final pad = MediaQuery.paddingOf(context);
    final body = widget.bodyPadding.copyWith(
      bottom: widget.bodyPadding.bottom + pad.bottom,
    );
    final slivers = widget.slivers;
    Widget list = slivers == null
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: body,
            children: widget.children,
          )
        : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: body,
                sliver: SliverMainAxisGroup(slivers: slivers),
              ),
            ],
          );
    final refresh = widget.onRefresh;
    if (refresh != null) {
      list = RefreshIndicator(onRefresh: refresh, child: list);
    }
    // Quer (Handy und Tablet): Zurück und Pillen in die erste Kopfzeile, weniger
    // Abstand oben (Rückmeldung 14.11.26, compactHeader).
    final compact = compactHeader(context);
    final slot = HeaderChips.of(context);
    var header = widget.header;
    final chips =
        slot != null && slot.active && !widget.placesChips && header.isNotEmpty;
    // Zurück aus der Pillenzeile nur zusammen mit den Pillen (beide fallen
    // dort weg, sobald ClaimedChips sich anmeldet).
    final lead = widget.leading ?? (chips ? slot.leading : null);
    if (compact && header.isNotEmpty && (lead != null || chips)) {
      header = [
        Row(
          children: [
            ?lead,
            if (lead != null) const SizedBox(width: Sp.xs),
            Expanded(child: header.first),
            // Pillen in natürlicher Breite, höchstens 45 % – sonst bekäme die
            // Überschrift neben einem Flexible fest nur die halbe Breite
            // (Prüfbefund 14.11.26).
            if (chips) ...[
              const SizedBox(width: Sp.m),
              // FittedBox: auf EINER Zeile bleiben und notfalls verkleinern
              // statt untereinander umzubrechen (Bildschirmfoto Kalender
              // quer, 14.11.26).
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: ClaimedChips(),
                ),
              ),
            ],
          ],
        ),
        ...header.skip(1),
      ];
    } else if (!compact && widget.leading != null) {
      header = [
        Row(children: [widget.leading!]),
        const SizedBox(height: Sp.xs),
        ...header,
      ];
    }
    final top = compact && widget.headerPadding.top > Sp.m
        ? Sp.m
        : widget.headerPadding.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: widget.headerPadding.copyWith(top: top + pad.top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: header,
          ),
        ),
        // Immer 1 dp hoch, damit der Inhalt beim Erscheinen nicht springt.
        ColoredBox(
          color: _under ? k.p.line : Colors.transparent,
          child: const SizedBox(height: 1),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: list,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pillen für eine Kopfzeile, die sie selbst platziert
/// (PinnedPage.placesChips): quer (Handy und Tablet) die Kind-Pillen aus
/// [HeaderChips], sonst nichts.
class TitleChips extends StatelessWidget {
  const TitleChips({super.key});

  /// Ob [TitleChips] hier etwas zeigt – der Aufrufer hängt es nur dann ein,
  /// damit hoch die Überschrift die ganze Breite behält.
  static bool shows(BuildContext context) =>
      HeaderChips.of(context)?.active ?? false;

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: Sp.m),
    child: ClaimedChips(),
  );
}
