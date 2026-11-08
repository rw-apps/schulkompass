import 'package:flutter/material.dart';

import '../kit.dart';

/// Hinweis oben auf einer Seite mit einer Aktion (neues Schuljahr, offene
/// Wahl, Portal nicht erreichbar). Ursache: Die Hinweise sahen verschieden
/// aus; ein Baustein hält sie einheitlich (Entwurf 20.10.26 k4).
///
/// Grau (KitPalette.todo) statt Gelb seit 21.10.26: Gelb heißt Vertretung,
/// Raumwechsel oder Essen; ein Hinweis zur App ist keine Abweichung vom
/// Plan.
///
/// Zwei Formen, nach Platz gewählt (LayoutBuilder, [_fitsCompact]):
/// - Kompakt in einer Zeile: Symbol im runden Feld, Titel und kurze Zeile,
///   Aktion als Pille rechts. Ursache (Rückmeldung 20.10.26: „Platz besser
///   nutzen und optisch aufwerten“): Die erste Fassung brauchte mit
///   Textblock und eigener Knopfzeile so viel Höhe wie eine halbe
///   Kinderkarte.
/// - Gestapelt, sobald Titel oder Text dort nicht je in eine Zeile passen
///   oder es eine zweite Aktion gibt: Symbol und Titel oben, der Text über
///   die ganze Breite, Aktionen unten rechts. Ursache (Rückmeldung
///   08.11.26, Zustimmungskarte): Längerer Text lief in einer schmalen
///   Spalte zwischen Symbol und Pille über zehn Zeilen, links und rechts
///   blieb Platz leer.
///
/// [secondary]/[onSecondary]: zweite, leise Aktion („Nicht jetzt“) links
/// neben der Pille, statt als Knopf unter der Karte.
class HintCard extends StatelessWidget {
  const HintCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  bool get _hasAction => action != null && onAction != null;
  bool get _hasSecondary => secondary != null && onSecondary != null;

  /// Passen Titel und Text je in eine Zeile neben Symbol und Pille?
  bool _fitsCompact(BuildContext context, Kit k, double width) {
    if (_hasSecondary) return false;
    final scaler = MediaQuery.textScalerOf(context);
    double w(String s, TextStyle st) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: st),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final out = tp.width;
      tp.dispose();
      return out;
    }

    var room = width - Sz.buttonSmall - Sp.m;
    if (_hasAction) {
      room -= Sp.s + 2 * Sp.l + w(action!, k.button(k.p.onStrong));
    }
    final tone = k.p.todo;
    return w(title, k.boxStrong(tone)) <= room &&
        w(text, k.boxText(tone)) <= room;
  }

  Widget _badge(Kit k) => Container(
    width: Sz.buttonSmall,
    height: Sz.buttonSmall,
    decoration: BoxDecoration(color: k.p.card, shape: BoxShape.circle),
    child: Icon(icon, size: Sz.navIcon, color: k.p.todo.ink),
  );

  Widget _pill(Kit k) => Material(
    color: k.p.strong,
    borderRadius: BorderRadius.circular(Rad.pill),
    child: InkWell(
      borderRadius: BorderRadius.circular(Rad.pill),
      onTap: onAction,
      // Nur so breit wie der Text: Container mit alignment füllte in der
      // gestapelten Form die ganze Breite (Entwurf 08.11.26).
      child: Container(
        height: Sz.buttonSmall,
        padding: const EdgeInsets.symmetric(horizontal: Sp.l),
        child: Center(
          widthFactor: 1,
          child: Text(action!, style: k.button(k.p.onStrong)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final tone = k.p.todo;
    return Container(
      padding: const EdgeInsets.all(Sp.m),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(Rad.signal),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          if (_fitsCompact(context, k, c.maxWidth)) {
            return Row(
              children: [
                _badge(k),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: k.boxStrong(tone)),
                      Text(text, style: k.boxText(tone)),
                    ],
                  ),
                ),
                if (_hasAction) ...[const SizedBox(width: Sp.s), _pill(k)],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _badge(k),
                  const SizedBox(width: Sp.m),
                  Expanded(child: Text(title, style: k.boxStrong(tone))),
                ],
              ),
              const SizedBox(height: Sp.s),
              Text(text, style: k.boxText(tone)),
              if (_hasAction || _hasSecondary) ...[
                const SizedBox(height: Sp.m),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Sp.s,
                  runSpacing: Sp.s,
                  children: [
                    if (_hasSecondary)
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(secondary!, style: k.link),
                      ),
                    if (_hasAction) _pill(k),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
