import 'package:flutter/material.dart';

import '../../homework_ledger.dart';
import '../../l10n/l10n.dart';
import '../kit.dart';
import '../today/today_page.dart' show dayDiff;
import 'exam_card.dart' show KidLine, KidTag;

/// Eine Hausaufgabe in [HomeworkSection]; [kid] nur in „Alle“.
class HwEntry {
  const HwEntry({
    required this.item,
    required this.onDone,
    required this.onReopen,
    this.kid,
    this.onOpen,
  });

  final HomeworkItem item;

  final KidTag? kid;

  /// Kurs öffnen (Antippen der Karte); null = nur Anzeige.
  final VoidCallback? onOpen;
  final VoidCallback onDone;
  final VoidCallback onReopen;

  String get key => '${kid?.name ?? ''}|${item.key}';
}

/// Eine offene Abgabe über den Hausaufgaben (submissions.dart, Wunsch
/// 15.11.26); [kid] nur in „Alle“.
class SubEntry {
  const SubEntry({
    required this.subject,
    required this.name,
    required this.files,
    this.until,
    this.kid,
    this.onSubmit,
    this.onOpen,
  });

  final String subject;
  final String name;
  final DateTime? until;

  /// Schon abgegebene Dateien.
  final int files;

  /// Schon etwas hochgeladen: steht unter „Erledigt“ statt oben
  /// ([HomeworkSection.submissions]).
  bool get handedIn => files > 0;
  final KidTag? kid;

  /// Abgabeseite öffnen; null = nur Anzeige (Elternkonto, Vorschau).
  final VoidCallback? onSubmit;

  /// Kurs öffnen (Antippen der Karte).
  final VoidCallback? onOpen;
}

/// Offene Hausaufgaben mit sichtbarem Übergang beim Abhaken, darunter
/// „Erledigt (n)“ zum Aufklappen – gemeinsam für Unterricht eines Kindes
/// und „Alle“ (Entwurf abgenommen 20.10.26).
///
/// Ursache (Rückmeldung 20.10.26): Abgehakte Aufgaben verschwanden
/// schlagartig, wohin sie gingen, war nicht zu sehen; Zurückholen ging nur
/// über eine eigene Seite. Jetzt: Haken füllt sich, Text gestrichen
/// ([_hold]), Karte klappt zu ([_collapse]), „Erledigt (n)“ leuchtet auf.
/// Unter „Erledigt“ holt derselbe Haken die Aufgabe zurück; sie klappt dort
/// zu und leuchtet oben kurz auf.
///
/// Abläufe nur über Animationen (TweenAnimationBuilder.onEnd), keine
/// Zeitgeber. Ursache: Die Liste kommt erst einen Bildaufbau nach onDone
/// neu – eine Karte, die bis dahin wieder aufginge, flackerte. Deshalb
/// bleibt eine abgeschlossene Karte unsichtbar ([_gone]), bis sie in der
/// neuen Liste fehlt. Grenze: Unter „Erledigt“ stehen die [shownDone]
/// neuesten; alle zeigt die bisherige Seite ([onShowAll]).
class HomeworkSection extends StatefulWidget {
  const HomeworkSection({
    super.key,
    required this.open,
    required this.done,
    required this.emptyText,
    this.doneTotal,
    this.onShowAll,
    this.readOnly = false,
    this.now,
    this.expiredCount = 0,
    this.submissions = const [],
  });

  /// Abgaben, die noch möglich sind (früheste Frist zuerst). Ohne Datei
  /// oben vor den Hausaufgaben; mit mindestens einer Datei
  /// ([SubEntry.handedIn]) unter „Erledigt“, solange das Portal sie noch
  /// als möglich führt.
  ///
  /// Ursache (Rückmeldung 27.11.26 mit Bild): Eine schon hochgeladene
  /// Abgabe stand weiter unter „Offene Hausaufgaben“ und zählte im Abzeichen
  /// mit, obwohl die Kursseite „abgegeben: 1“ zeigte – das Portal führt die
  /// Abgabe bis zur Frist als „Abgabe aktuell möglich“. Ein eigener
  /// Erledigt-Knopf entfällt: Erledigt ist sie, sobald das Portal die Datei
  /// zählt. Grenze: Verlangt die Lehrkraft mehrere Dateien, erkennt die App
  /// das nicht – ab der ersten gilt die Abgabe als erledigt; „Ändern“ führt
  /// bis zur Frist zur Abgabeseite. Nach Fristende (oder wenn das Portal
  /// sie nicht mehr als möglich führt) fällt sie ganz heraus
  /// (openSubmissionsOf) – „Erledigt (n)“ wird dann um eins kleiner; das
  /// Archiv (onShowAll) kennt nur Hausaufgaben.
  final List<SubEntry> submissions;

  /// Abgelaufene, nicht abgehakte (homeworkLists.expired): eigener Link
  /// zum Archiv, auch ohne erledigte. Ursache (Prüfung 27.10.26): Der Weg
  /// ins Archiv erschien nur bei mehr als [shownDone] erledigten – „Nicht
  /// abgehakt“ und „Wieder offen“ waren sonst unerreichbar.
  final int expiredCount;

  /// Nur Tests/Entwürfe (Frist-Zeile).
  final DateTime? now;

  final List<HwEntry> open;

  /// Nur Anzeige (Vorschau ohne Daten): kein Abhaken.
  final bool readOnly;

  /// Neueste zuerst (homeworkLists).
  final List<HwEntry> done;

  /// Zahl aller erledigten; Standard [done].length.
  final int? doneTotal;
  final String emptyText;
  final VoidCallback? onShowAll;

  /// Ursache für 5 (Rückmeldung 20.10.26, „nicht zu groß, nicht zu
  /// unruhig“): Mit zehn erledigten wurde die Seite lang; ältere stehen auf
  /// der eigenen Seite (onShowAll).
  static const shownDone = 5;

  @override
  State<HomeworkSection> createState() => _HomeworkSectionState();
}

const _hold = Duration(milliseconds: 350);
const _collapse = Duration(milliseconds: 280);
const _flash = Duration(milliseconds: 1400);

class _HomeworkSectionState extends State<HomeworkSection> {
  /// Karten im Übergang, je Liste getrennt (dieselbe Aufgabe wechselt die
  /// Liste): 1 = markiert, 2 = klappt zu, 3 = weg (wartet auf die neue
  /// Liste).
  final _openStage = <String, int>{};
  final _doneStage = <String, int>{};
  bool _expanded = false;
  int _doneFlash = 0;
  String? _flashKey;
  int _keyFlash = 0;

  @override
  void didUpdateWidget(HomeworkSection old) {
    super.didUpdateWidget(old);
    // Abgeschlossene Übergänge vergessen, sobald die Liste nachgezogen hat.
    void prune(Map<String, int> stage, List<HwEntry> list) {
      final keys = {for (final e in list) e.key};
      stage.removeWhere((k, v) => v == 3 && !keys.contains(k));
    }

    prune(_openStage, widget.open);
    prune(_doneStage, widget.done);
  }

  void _start(Map<String, int> stage, HwEntry e) {
    if (stage.containsKey(e.key)) return;
    setState(() => stage[e.key] = 1);
  }

  void _finishTick(HwEntry e) {
    setState(() {
      _openStage[e.key] = 3;
      _doneFlash++;
    });
    e.onDone();
    final t = context.t;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(t.homeworkMarkedDone),
          action: SnackBarAction(label: t.undo, onPressed: () => _back(e)),
        ),
      );
  }

  void _finishReopen(HwEntry e) {
    setState(() => _doneStage[e.key] = 3);
    _back(e);
  }

  /// Wieder offen (auch „Rückgängig“); die Karte leuchtet oben kurz auf.
  void _back(HwEntry e) {
    e.onReopen();
    if (!mounted) return;
    setState(() {
      _openStage.remove(e.key);
      _flashKey = e.key;
      _keyFlash++;
    });
  }

  /// [child] mit Übergang: markiert (blasser), dann zuklappen.
  Widget _leaving(
    Map<String, int> stages,
    HwEntry e,
    Widget child,
    VoidCallback onEnd,
  ) {
    final stage = stages[e.key] ?? 0;
    if (stage == 3) return const SizedBox.shrink();
    Widget w = child;
    if (stage >= 1) {
      w = TweenAnimationBuilder<double>(
        key: const ValueKey('hold'),
        tween: Tween(begin: 1, end: 0.6),
        duration: _hold,
        onEnd: stage == 1 ? () => setState(() => stages[e.key] = 2) : null,
        builder: (c, v, ch) => Opacity(opacity: v, child: ch),
        child: w,
      );
    }
    if (stage >= 2) {
      w = TweenAnimationBuilder<double>(
        key: const ValueKey('collapse'),
        tween: Tween(begin: 1, end: 0),
        duration: _collapse,
        curve: Curves.easeInOut,
        onEnd: onEnd,
        builder: (c, v, ch) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: ch,
          ),
        ),
        child: w,
      );
    }
    return KeyedSubtree(key: ValueKey('hw-${e.key}'), child: w);
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final open = widget.open;
    final done = widget.done;
    final total = widget.doneTotal ?? done.length;
    final shown = done.take(HomeworkSection.shownDone).toList();
    final pending = [
      for (final e in widget.submissions)
        if (!e.handedIn) e,
    ];
    final handedIn = [
      for (final e in widget.submissions)
        if (e.handedIn) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: _SubmissionCard(entry: e, now: widget.now),
          ),
        if (open.isEmpty && pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: Sp.xs, bottom: Sp.s),
            child: Text(widget.emptyText, style: k.meta),
          ),
        for (final e in open)
          _leaving(
            _openStage,
            e,
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _OpenCard(
                entry: e,
                ticked: (_openStage[e.key] ?? 0) >= 1,
                flash: e.key == _flashKey ? _keyFlash : null,
                onTick: widget.readOnly ? null : () => _start(_openStage, e),
                now: widget.now,
              ),
            ),
            () => _finishTick(e),
          ),
        if (total + handedIn.length > 0)
          _DoneToggle(
            count: total + handedIn.length,
            open: _expanded,
            flash: _doneFlash,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        if (_expanded) ...[
          const SizedBox(height: Sp.s),
          for (final e in handedIn)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _HandedInCard(entry: e, now: widget.now),
            ),
          for (final e in shown)
            _leaving(
              _doneStage,
              e,
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: _DoneCard(
                  entry: e,
                  unticked: (_doneStage[e.key] ?? 0) >= 1,
                  onTick: () => _start(_doneStage, e),
                ),
              ),
              () => _finishReopen(e),
            ),
          if (total > shown.length && widget.onShowAll != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onShowAll,
                child: Text(t.homeworkShowAll(total), style: k.link),
              ),
            ),
        ],
        if (widget.expiredCount > 0 && widget.onShowAll != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onShowAll,
              child: Text(t.hwExpiredLink(widget.expiredCount), style: k.link),
            ),
          ),
      ],
    );
  }
}

/// Offene Hausaufgabe (Entwurf A, abgenommen 30.10.26): weiße Karte wie
/// die Fächer darunter; Kopf Fach · Kind | Frist, Lehrertext normal gesetzt
/// und höchstens [_lines] Zeilen („mehr“ klappt auf), Fuß „aufgegeben …“ |
/// „Erledigt“. [ticked] = Knopf gefüllt, Text gestrichen; [flash] lässt die
/// Karte nach dem Zurückholen aufleuchten.
///
/// Ursache (Rückmeldung 30.10.26 mit Bild aus „Alle“): Der Text stand
/// vollständig und fett in einer schmalen Spalte neben dem Knopf – ein
/// längerer Lehrertext ergab zehn Zeilen je Karte; das Fach stand klein
/// darunter. Dazu war die Karte grau (KitPalette.todo) statt weiß wie in
/// den anderen Reitern. Grenze: Der volle Text steht auch auf der Fachseite
/// (Antippen der Karte), „mehr“ ist nur die Abkürzung dorthin.
class _OpenCard extends StatefulWidget {
  const _OpenCard({
    required this.entry,
    required this.ticked,
    required this.onTick,
    this.flash,
    this.now,
  });

  /// Nur Tests/Entwürfe.
  final DateTime? now;

  final HwEntry entry;
  final bool ticked;

  /// null = nur Anzeige.
  final VoidCallback? onTick;
  final int? flash;

  @override
  State<_OpenCard> createState() => _OpenCardState();
}

/// Zeilen des Lehrertexts, bevor „mehr“ erscheint. Ursache für 3: Die
/// meisten Einträge (Seite, Nummer, kurzer Auftrag) passen ganz hinein;
/// gekürzt werden nur die Absätze.
const _lines = 3;

class _OpenCardState extends State<_OpenCard> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final entry = widget.entry;
    final item = entry.item;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    final style = k.body.merge(
      widget.ticked
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final card = Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          child: LayoutBuilder(
            builder: (c, box) {
              // Nur wenn der Text die Zeilen wirklich überschreitet, steht
              // „mehr“ da (gemessen, nicht nach Zeichenzahl: Schriftgröße
              // und Breite schwanken je Gerät).
              final long = (TextPainter(
                text: TextSpan(text: text, style: style),
                maxLines: _lines,
                textScaler: scaler,
                textDirection: Directionality.of(c),
              )..layout(maxWidth: box.maxWidth)).didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Fach und Kind nehmen den Rest neben der Frist; erst
                      // wenn der fehlt, wird das Fach gekürzt (nicht die
                      // Frist). Ein Spacer daneben teilte den Platz 1:1 und
                      // kürzte „Mathematik“ schon ohne Not (Bild 30.10.26).
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.subject,
                                style: k.tileTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (entry.kid != null) ...[
                              const SizedBox(width: Sp.s),
                              KidLine(kid: entry.kid!),
                            ],
                          ],
                        ),
                      ),
                      if (item.due case final due?) ...[
                        const SizedBox(width: Sp.s),
                        _DueLine(due: due, now: widget.now ?? DateTime.now()),
                      ],
                    ],
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    text,
                    style: style,
                    maxLines: _more ? null : _lines,
                    overflow: _more ? null : TextOverflow.ellipsis,
                  ),
                  if (item.given != null || long || widget.onTick != null) ...[
                    const SizedBox(height: Sp.s),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (item.given != null)
                                Flexible(
                                  child: Text(
                                    t.givenDate(
                                      formatDate(t, t.dateShort, item.given!),
                                    ),
                                    style: k.meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (long)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _more = !_more),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, Sz.buttonTiny),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Sp.s,
                                    ),
                                  ),
                                  child: Text(
                                    _more ? t.hwTextLess : t.hwTextMore,
                                    style: k.link,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.onTick != null)
                          _CardAction(
                            icon: Icons.check,
                            label: t.homeworkDoneButton,
                            color: k.p.ink,
                            side: k.p.faint,
                            fill: k.p.card,
                            active: widget.ticked,
                            onPressed: widget.ticked ? null : widget.onTick,
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    final f = widget.flash;
    if (f == null) return card;
    return TweenAnimationBuilder<double>(
      key: ValueKey('flash-$f'),
      tween: Tween(begin: 1, end: 0),
      duration: _flash,
      builder: (c, v, ch) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.signal),
          border: Border.all(
            color: k.p.onNavSelected.withValues(alpha: v),
            width: 2,
          ),
        ),
        child: ch,
      ),
      child: card,
    );
  }
}

/// Offene Abgabe als Karte wie eine Hausaufgabe (Entwurf 15.11.26): Kopf
/// Fach · Kind | „bis Fr 06.11. 10:15“ (kräftig ab dem Vortag), darunter
/// „Abgabe ‚Name‘“, Fuß „noch nicht abgegeben“ bzw. „N Dateien abgegeben“ |
/// „Abgeben“. Ursache (Rückmeldung 15.11.26): Die Abgabe stand nur auf der
/// Kursseite; in der Liste der offenen Aufgaben fehlte sie. Grenze: Ohne
/// [SubEntry.onSubmit] (Elternkonto) nur Anzeige.
class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.entry, this.now});

  final SubEntry entry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final e = entry;
    final until = e.until;
    final today = now ?? DateTime.now();
    final diff = until == null ? null : dayDiff(today, until);
    final soon = diff != null && diff <= 1;
    final when = until == null
        ? null
        : switch (diff) {
            0 => t.subUntilToday(formatTime(until)),
            1 => t.subUntilTomorrow(formatTime(until)),
            _ => t.subUntilOn(
              formatDate(t, t.dateShort, until),
              formatTime(until),
            ),
          };
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: e.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            e.subject,
                            style: k.tileTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (e.kid != null) ...[
                          const SizedBox(width: Sp.s),
                          KidLine(kid: e.kid!),
                        ],
                      ],
                    ),
                  ),
                  if (when != null) ...[
                    const SizedBox(width: Sp.s),
                    Text(
                      when,
                      style: soon
                          ? k.planTeacher(k.p.ink)
                          : k.planMeta(k.p.muted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Sp.xs),
              // Gelb wie der Hinweis auf Heute (k.hintKind, Farbregel: Gelb =
              // etwas zu tun) – Rückmeldung 15.11.26: Die Abgabe sollte sich
              // in der Liste klarer von den Hausaufgaben abheben.
              Row(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: Sz.iconSmall,
                    color: k.p.change.strong,
                  ),
                  const SizedBox(width: Sp.xs),
                  Expanded(
                    child: Text(
                      t.subTitle(e.name),
                      style: k.hintKind(k.p.change),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.s),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // Oben stehen nur Abgaben ohne Datei (SubEntry
                      // .handedIn); der zweite Zweig bleibt als Reserve.
                      e.files == 0 ? t.uploadNotYet : t.subFiles(e.files),
                      style: k.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (e.onSubmit != null)
                    _CardAction(
                      icon: Icons.upload,
                      label: t.subSubmit,
                      color: k.p.ink,
                      side: k.p.faint,
                      fill: k.p.card,
                      active: false,
                      onPressed: e.onSubmit,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abgabe mit hochgeladener Datei unter „Erledigt“ (Rückmeldung 27.11.26,
/// [HomeworkSection.submissions]): gebaut wie [_DoneCard] – Name blass
/// (nicht gestrichen: bis zur Frist lässt sich noch etwas ändern), darunter
/// Fach · „1 Datei abgegeben“ · Frist, rechts „Ändern“ (zur Abgabeseite,
/// nur Schülerkonto wie „Abgeben“).
class _HandedInCard extends StatelessWidget {
  const _HandedInCard({required this.entry, this.now});

  final SubEntry entry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final e = entry;
    final until = e.until;
    // Frist mit festen Leerzeichen: bricht als Ganzes um, sonst stand die
    // Uhrzeit allein in der nächsten Zeile (Entwurf 27.11.26).
    final meta = [
      e.subject,
      t.subFiles(e.files),
      if (until != null)
        switch (dayDiff(now ?? DateTime.now(), until)) {
          0 => t.subUntilToday(formatTime(until)),
          1 => t.subUntilTomorrow(formatTime(until)),
          _ => t.subUntilOn(
            formatDate(t, t.dateShort, until),
            formatTime(until),
          ),
        }.replaceAll(' ', '\u00a0'),
    ].join(' · ');
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: e.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.xxs),
                    child: Icon(
                      Icons.upload_file_outlined,
                      size: Sz.iconSmall,
                      color: k.p.muted,
                    ),
                  ),
                  const SizedBox(width: Sp.xs),
                  Expanded(
                    child: Text(
                      t.subTitle(e.name),
                      style: k.body.copyWith(color: k.p.muted),
                    ),
                  ),
                  if (e.onSubmit != null) ...[
                    const SizedBox(width: Sp.s),
                    _CardAction(
                      icon: Icons.edit_outlined,
                      label: t.changeAction,
                      outlined: false,
                      color: k.p.onNavSelected,
                      fill: k.p.card,
                      active: false,
                      onPressed: e.onSubmit,
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: Sp.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(meta, style: k.meta),
                  if (e.kid != null) KidLine(kid: e.kid!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Erledigte Hausaufgabe unter „Erledigt“: Haken antippen = wieder offen
/// ([unticked] = Kreis leer, Text ungestrichen).
class _DoneCard extends StatelessWidget {
  const _DoneCard({
    required this.entry,
    required this.unticked,
    required this.onTick,
  });

  final HwEntry entry;
  final bool unticked;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final item = entry.item;
    final text = item.text.isEmpty ? t.homeworkEntered : item.text;
    // Nur Fach und Erledigt-Tag – das Aufgabedatum steht auf der Seite
    // „Erledigte Hausaufgaben“. Ursache: drei Zeilen je erledigter Karte
    // machten die Liste lang und unruhig (Rückmeldung 20.10.26).
    final meta = [
      item.subject,
      if (item.done != null)
        t.homeworkDoneOn(formatDate(t, t.dateShort, item.done!)),
    ].join(' · ');
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.m, Sp.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: k.body.copyWith(
                        color: k.p.muted,
                        decoration: unticked
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  _CardAction(
                    icon: Icons.undo,
                    // Kurz („Unerledigt“): Oben rechts ließ der lange Text
                    // „Als unerledigt markieren“ der Aufgabe kaum Platz (Wörter
                    // brachen mitten im Wort, Bild 20.10.26); der lange steht
                    // für Bildschirmleser als Tooltip.
                    label: t.homeworkMarkOpenShort,
                    tooltip: t.homeworkMarkOpen,
                    outlined: false,
                    color: k.p.onNavSelected,
                    fill: k.p.card,
                    active: unticked,
                    onPressed: unticked ? null : onTick,
                  ),
                ],
              ),
              // Kind in derselben Zeile wie Fach und Tag („Alle“), damit
              // erledigte Karten zweizeilig bleiben; bricht nur bei
              // Platzmangel um.
              Wrap(
                spacing: Sp.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(meta, style: k.meta),
                  if (entry.kid != null) KidLine(kid: entry.kid!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Knopf mit Klartext oben rechts in der Karte („✓ Erledigt“, „↺ Als
/// unerledigt markieren“); [active] = gerade angetippt (gefüllt, während
/// die Karte wandert). Ursache (Rückmeldung 20.10.26): Ein Kreis links als
/// einziges Bedienelement war nicht selbsterklärend; er entfällt.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.fill,
    required this.active,
    required this.onPressed,
    this.tooltip,
    this.outlined = true,
    this.side,
  });

  /// Rahmenfarbe; Standard [color]. Auf weißer Karte leiser (KitPalette
  /// .faint), damit vier Knöpfe untereinander nicht unruhig wirken.
  final Color? side;

  final IconData icon;
  final String label;
  final String? tooltip;

  /// Rahmen nur für die Hauptaktion („Erledigt“); „Unerledigt“ ohne.
  /// Ursache (Bild der ganzen Seite, 20.10.26): Fünf gleiche Rahmen unter
  /// „Erledigt“ wirkten unruhig.
  final bool outlined;
  final Color color;

  /// Farbe der Schrift im gefüllten Zustand (Kartenfarbe).
  final Color fill;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final fg = active ? fill : color;
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: Sz.iconSmall, color: fg),
      label: Text(label, style: k.buttonTiny(fg)),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? color : null,
        disabledBackgroundColor: active ? color : null,
        // Klein (Sz.buttonTiny) und ohne unsichtbaren Rand, damit die Zeile
        // so hoch bleibt wie der Aufgabentext. Grenze: Die Trefferfläche ist
        // 28 dp statt 48 dp; ein Fehlgriff daneben öffnet die Kursseite.
        minimumSize: const Size(0, Sz.buttonTiny),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s),
        side: outlined
            ? BorderSide(color: active ? color : side ?? color, width: 1.5)
            : BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.pill),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}

/// „Erledigt (n)“ zum Auf- und Zuklappen; leuchtet nach dem Abhaken kurz
/// auf ([flash] zählt hoch).
class _DoneToggle extends StatelessWidget {
  const _DoneToggle({
    required this.count,
    required this.open,
    required this.flash,
    required this.onTap,
  });

  final int count;
  final bool open;
  final int flash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return TweenAnimationBuilder<double>(
      key: ValueKey('done-flash-$flash'),
      tween: Tween(begin: flash == 0 ? 0 : 1, end: 0),
      duration: _flash,
      builder: (c, v, ch) => Material(
        color: Color.lerp(
          k.p.navSelected.withValues(alpha: 0),
          k.p.navSelected,
          v,
        ),
        borderRadius: BorderRadius.circular(Rad.pill),
        child: ch,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: Sz.navIcon,
                color: k.p.onNavSelected,
              ),
              const SizedBox(width: Sp.xs),
              Text(t.homeworkArchive(count), style: k.link),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frist rechts im Kopf einer offenen Hausaufgabe (Entwurf 27.10.26, Ort
/// seit 30.10.26): „fällig Mi 28.10.“ (Nebenschrift), „fällig heute“/
/// „fällig morgen“ (kräftig), nach dem Tag gelb „war fällig Mi 22.10.“
/// (ohne „· erledigt?“: im Kopf zu lang, der Knopf darunter fragt es).
/// Gelb wie andere Hinweise, die etwas zu tun verlangen. Grenze: Die Frist
/// ist nur vermutet (HomeworkItem.due) – die App hakt nichts selbst ab.
class _DueLine extends StatelessWidget {
  const _DueLine({required this.due, required this.now});

  final DateTime due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // dayDiff rechnet in UTC (Zeitumstellung: sonst „heute“ statt „morgen“).
    final diff = dayDiff(now, due);
    final day = formatDate(t, t.dateShort, due);
    if (diff < 0) {
      final tone = k.p.change;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xxs),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(Rad.pill),
        ),
        child: Text(
          t.hwWasDue(day),
          style: k.tileCaption.copyWith(color: tone.ink),
        ),
      );
    }
    final text = switch (diff) {
      0 => t.hwDueToday,
      1 => t.hwDueTomorrow,
      _ => t.hwDueOn(day),
    };
    return Text(
      text,
      style: diff <= 1 ? k.planTeacher(k.p.ink) : k.planMeta(k.p.muted),
    );
  }
}
