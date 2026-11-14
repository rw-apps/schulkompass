import 'package:flutter/material.dart';

import 'kit.dart';

/// Auswahl der Kinder als Pillen (Kalender, Bereiche mit [FamilySwitch]).
///
/// Mit [allLabel] steht vorn eine Pille „Alle“ ohne Farbpunkt; sie meldet
/// [onSelect] mit -1 und ist bei [selected] = -1 gewählt. Ursache
/// (Rückmeldung 18.10.26): In „Termine“ fehlte ein Filter je Kind; die
/// gemeinsame Liste bleibt dort der Normalfall.
class KidChips extends StatelessWidget {
  const KidChips({
    super.key,
    required this.kids,
    required this.selected,
    required this.onSelect,
    this.allLabel,
  });

  final List<({String name, int color})> kids;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Gewählt: volle Farbe (Kind) bzw. dunkel („Alle“) mit Haken; nicht
    // gewählt: weiß mit Rand und Farbpunkt. Ursache (Rückmeldung 20.10.26,
    // Bildschirmfoto Nachrichten: „schwer erkennbar, welches Profil
    // ausgewählt ist“): Vorher war „Alle“ gewählt grau auf grauem Grund und
    // die NICHT gewählten Kinder weiß – die Hervorhebung wirkte verkehrt.
    Widget chip({
      required bool sel,
      required VoidCallback onTap,
      required String label,
      required Color fill,
      required Color onFill,
      Color? dot,
    }) => Semantics(
      selected: sel,
      button: true,
      child: Material(
        color: sel ? fill : k.p.card,
        shape: StadiumBorder(
          side: sel ? BorderSide.none : BorderSide(color: k.p.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: Sz.buttonSmall,
            padding: const EdgeInsets.symmetric(horizontal: Sp.l),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Icon(Icons.check, size: Sz.icon, color: onFill),
                  )
                else if (dot != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Sp.s),
                    child: Container(
                      width: Sz.dot + Sp.xxs,
                      height: Sz.dot + Sp.xxs,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(label, style: k.chipLabel(sel, onFill)),
              ],
            ),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        if (allLabel != null)
          chip(
            sel: selected < 0,
            onTap: () => onSelect(-1),
            label: allLabel!,
            fill: k.p.strong,
            onFill: k.p.onStrong,
          ),
        for (final (i, kid) in kids.indexed)
          chip(
            sel: i == selected,
            onTap: () => onSelect(i),
            label: kid.name,
            fill: k.kid(kid.color).accent,
            onFill: k.p.card,
            dot: k.kid(kid.color).accent,
          ),
      ],
    );
  }
}

/// Telefon quer: Kopf verdichten (Leiste links in PreviewShell, Pillen und
/// Zurück in der Zeile der Überschrift, PinnedPage).
///
/// Ursache (Rückmeldung 14.11.26 zum Entwurf Querformat: „Der Platz oben
/// kann besser genutzt werden“): Quer bleiben am Pixel 9a rund 411 dp Höhe;
/// Pillenzeile und eigener Zurück-Pfeil über der Überschrift kosteten je
/// eine Zeile. Tablets (kürzere Seite ab Sz.phoneShortestSide) behalten den
/// gewohnten Aufbau. Grenze: Über Systemschrift ×1,3 bleibt es beim
/// gewohnten Aufbau – Überschrift, Pillen und Umschalter passten dann
/// nicht mehr in eine Zeile (shell_nav_test, Kalender bei ×1,82: 169 px
/// Überlauf). Liest nur Größe und Schrift (sizeOf, textScalerOf), damit
/// die Tastatur keine Neuaufbauten auslöst.
bool compactHeader(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width > size.height &&
      size.shortestSide < Sz.phoneShortestSide &&
      MediaQuery.textScalerOf(context).scale(10) <= 13;
}

/// Pillen (und Zurück) für die Überschriftzeile, von [PinnedKidChips] im
/// Querformat an die Seite darunter gereicht. Wer sie zeichnet
/// ([ClaimedChips] in PinnedPage bzw. TitleChips), meldet sich über
/// [claims] an; ohne Anmeldung (Lade- oder Fehlerzustand, Seiten ohne
/// PinnedPage wie die Wochenansicht) zeigt PinnedKidChips die Pillenzeile
/// wie gewohnt, damit die Kinderwahl nie fehlt und nie doppelt steht.
class HeaderChips extends InheritedWidget {
  const HeaderChips({
    super.key,
    required this.chips,
    required this.claims,
    required this.active,
    this.leading,
    required super.child,
  });

  final Widget chips;
  final Widget? leading;
  final ValueNotifier<int> claims;

  /// Quer am Telefon ([compactHeader]); sonst stehen die Pillen darüber.
  final bool active;

  static HeaderChips? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeaderChips>();

  @override
  bool updateShouldNotify(HeaderChips old) =>
      old.active != active || old.chips != chips || old.leading != leading;
}

/// Kind-Pillen fest oben über einer Seite – EIN Baustein für alle Reiter
/// (Heute, Kalender, Unterricht, Nachrichten, Mehr).
///
/// Ursache (Rückmeldung 20.10.26, „zentrale Logik für identisches
/// Aussehen“): Der Kalender setzte die Pillen selbst unter die Überschrift
/// und ließ sie mitscrollen; die übrigen Reiter (FamilySwitch) oben fest.
/// Abstand oben [Sp.m] unter der Statusleiste, seitlich [Sp.page]; die
/// Seite darunter bekommt keinen oberen Rand mehr (sie liegt schon unter
/// der Statusleiste).
///
/// Quer am Telefon ([compactHeader]) wandern Pillen und [leading] in die
/// Überschriftzeile der Seite (HeaderChips, PinnedPage, TitleChips).
/// Grenzen: Beim ersten Aufbau quer fehlt die Pillenzeile, bis sich
/// ClaimedChips nach dem Bild angemeldet hat; meldet sich keiner an,
/// erscheint sie ein Bild später. Beim Drehen nach quer steht sie für ein
/// Bild zusätzlich (ClaimedChips hängt hoch nicht und meldet sich erst
/// danach an).
class PinnedKidChips extends StatefulWidget {
  const PinnedKidChips({
    super.key,
    required this.chips,
    required this.child,
    this.leading,
  });

  final KidChips chips;
  final Widget child;

  /// Links in derselben Zeile (Zurück auf Unterseiten, SubpageKidChips).
  final Widget? leading;

  @override
  State<PinnedKidChips> createState() => _PinnedKidChipsState();
}

class _PinnedKidChipsState extends State<PinnedKidChips> {
  final _claims = ValueNotifier<int>(0);

  /// Erst nach dem ersten Bild entscheiden, ob eine Seite die Pillen
  /// übernommen hat (Anmeldung in ClaimedChips nach dem Bild).
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _claims.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _settled = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _claims
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Immer derselbe Baum (Column → Expanded → HeaderChips → Seite), damit
    // beim Drehen kein Zustand der Seite verloren geht (Scrollstand,
    // Getipptes); quer und angemeldet entfällt nur die Pillenzeile.
    final compact = compactHeader(context);
    final inTitle = compact && (_claims.value > 0 || !_settled);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inTitle)
          const SizedBox.shrink()
        else
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.page, Sp.m, Sp.page, 0),
              child: widget.leading == null
                  ? widget.chips
                  : Row(
                      children: [
                        widget.leading!,
                        const SizedBox(width: Sp.xs),
                        Expanded(child: widget.chips),
                      ],
                    ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            // In der Überschriftzeile: Die Seite liegt wieder direkt unter
            // der Statusleiste und nimmt deren Höhe selbst (PinnedPage).
            removeTop: !inTitle,
            child: HeaderChips(
              chips: widget.chips,
              leading: widget.leading,
              claims: _claims,
              active: compact,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Markiert eine Seite, deren Zurück-Pfeil schon in der Pillenzeile steht
/// (SubpageKidChips). Die Seite zeigt dann keinen eigenen.
///
/// Ursache (Rückmeldung 21.10.26: „Warum ist der Pfeil zurück nicht auf
/// gleicher Höhe wie die Schülerauswahl?“): Pillen und Pfeil standen in zwei
/// Zeilen übereinander. Grenze: Ohne Pillen (ein Kind, Einstellungen) bleibt
/// der Pfeil im Kopf der Seite.
class BackInChips extends InheritedWidget {
  const BackInChips({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackInChips>() != null;

  @override
  bool updateShouldNotify(BackInChips old) => false;
}

/// Die Kind-Pillen aus [HeaderChips], gezeichnet in einer Kopfzeile – und
/// zugleich die Anmeldung, dass PinnedKidChips die eigene Zeile weglässt.
///
/// Ursache (Prüfbefund 14.11.26): Meldete sich die Seite an, zeichnete die
/// Pillen aber nicht (leerer Kopf) oder zeichnete sie ohne Anmeldung
/// (Wochenansicht des Kalenders ohne PinnedPage), fehlten sie oder standen
/// doppelt. Jetzt hängen Zeichnen und Anmelden an demselben Baustein.
/// Grenze: Melden nach dem Bild (die Meldung baut den Vorfahren neu, im Bau
/// verboten) – beim Wechsel Laden → Seite steht für ein Bild beides.
class ClaimedChips extends StatefulWidget {
  const ClaimedChips({super.key});

  @override
  State<ClaimedChips> createState() => _ClaimedChipsState();
}

class _ClaimedChipsState extends State<ClaimedChips> {
  ValueNotifier<int>? _claims;

  /// Erst zählen, wenn das Hochzählen wirklich lief – sonst würde ein im
  /// selben Bild ein- und ausgehängter Baustein den Zähler negativ machen.
  bool _counted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final claims = HeaderChips.of(context)?.claims;
    if (identical(claims, _claims)) return;
    _release();
    _claims = claims;
    if (claims == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_claims, claims) || _counted) return;
      claims.value++;
      _counted = true;
    });
  }

  void _release() {
    final old = _claims;
    final counted = _counted;
    _claims = null;
    _counted = false;
    if (old == null || !counted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PinnedKidChips kann inzwischen fort sein (Notifier entsorgt).
      try {
        old.value--;
      } on FlutterError catch (_) {}
    });
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HeaderChips.of(context)?.chips ?? const SizedBox.shrink();
}
