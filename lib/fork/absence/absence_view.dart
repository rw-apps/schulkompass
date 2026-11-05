import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';

import '../demo/demo_mode.dart' show demoActive;
import '../ui/live/absence_live.dart' show absenceDetail;
import '../ui/live/live_data.dart' show LiveData;
import '../ui/messages/compose_model.dart' show candidatesFrom;
import '../ui/messages/compose_page.dart' show ComposePage, portalBackend;
import '../ui/nav.dart' show pushFullScreen;
import '../ui/today/kid_hints.dart' show nextSchoolDay;
import 'absence_today.dart';

import '../l10n/l10n.dart';
import 'absence_form.dart';
import 'absence_parser.dart';

String _shortDate(ForkL10n t, DateTime d) => formatDate(t, t.dateShort, d);

/// Felder der zuletzt gesendeten Meldung, solange die App läuft. Ursache
/// (Prüfung 05.11.26): Als Feld im State der Maske ging der Wert verloren,
/// sobald die Seite neu lud (CombinedAppletBuilder zeigt beim Laden nur den
/// Kreisel und baut die Maske neu) – die Warnung vor doppeltem Senden griff
/// dann nie.
final absenceLastSent = ValueNotifier<String?>(null);

/// Seite „Krankmeldung“ für Elternkonten.
class AbsencePage extends ConsumerWidget {
  const AbsencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Kein Menü-Knopf mehr: Die Seite öffnet über der neuen Oberfläche
    // (pushFullScreen), dort gibt es keine Schublade. Ursache (Fehlerbericht
    // 9346, symbolisiert: Scaffold.of in AbsencePage.build, 128×): Der alte
    // Knopf rief openDrawer ohne Scaffold mit Schublade auf. Jetzt der
    // übliche Zurück-Pfeil der AppBar.
    Widget? leading() => null;

    return CombinedAppletBuilder<AbsenceForm>(
      parser: ref.watch(absenceParserProvider),
      phpUrl: forkAbsenceApplet.appletPhpUrl,
      settingsDefaults: const {},
      accountType: AccountType.parent,
      showErrorAppBar: true,
      loadingAppBar: AppBar(leading: leading()),
      builder: (context, form, _, _, _, refresh) =>
          _AbsenceScreen(form: form, session: session, refresh: refresh),
    );
  }
}

/// Seite um Maske und Anzeige: Gibt es schon Meldungen ab heute, zeigt sie
/// diese zuerst nur an ([AbsenceOverview], Wunsch 05.11.26 – vorher sah
/// eine erledigte Meldung aus, als müsse man noch etwas ausfüllen). Das
/// Formular kommt über „Auch … melden“ (vorbelegt) oder „Andere Meldung“.
/// „Ändern“ steht oben rechts (Rückmeldung 05.11.26): Das Portal kennt für
/// gesendete Meldungen weder Ändern noch Zurückziehen (tbody#liste ohne
/// Aktionsspalte, meldungEltern.js ohne Löschen) – es bleibt der Weg über
/// die Schule.
class _AbsenceScreen extends ConsumerStatefulWidget {
  const _AbsenceScreen({
    required this.form,
    required this.session,
    required this.refresh,
  });

  final AbsenceForm form;
  final LanisSession session;
  final VoidCallback? refresh;

  @override
  ConsumerState<_AbsenceScreen> createState() => _AbsenceScreenState();
}

class _AbsenceScreenState extends ConsumerState<_AbsenceScreen> {
  /// Formular statt Anzeige; [_prefill] = vorbelegter Tag und Kind.
  bool _formMode = false;
  ({DateTime day, String pupilName, String kind})? _prefill;
  int _formRound = 0;

  void _openForm([({DateTime day, String pupilName, String kind})? p]) =>
      setState(() {
        _formMode = true;
        _prefill = p;
        _formRound++;
      });

  Future<void> _change(BuildContext context) async {
    final t = context.t;
    final live = LiveData.of(context);
    final canWrite = live != null && live.offers('nachrichten.php');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.absenceChangeTitle,
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(t.absenceChangeText),
              const SizedBox(height: 20),
              if (canWrite)
                FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(t.absenceWriteSchool),
                  onPressed: () {
                    Navigator.pop(c);
                    pushFullScreen<bool>(
                      context,
                      (_) => ComposePage(
                        candidates: candidatesFrom(
                          live.lessons.content ?? const [],
                        ),
                        backend: portalBackend(ref),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(t.absenceOpenPortal),
                onPressed: () => safeLaunchUrl(
                  Uri.parse(
                    'https://start.schulportal.hessen.de/abwesenheitsmeldung.php',
                  ),
                  context: c,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final form = widget.form;
    final refresh = widget.refresh;
    final session = widget.session;
    final current = currentAbsences(form.entries, DateTime.now());
    final overview = current.isNotEmpty && !_formMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.absenceTitle),
        leading: _formMode && current.isNotEmpty
            ? BackButton(onPressed: () => setState(() => _formMode = false))
            : null,
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => _change(context),
              child: Text(t.absenceChange),
            ),
          if (refresh != null)
            IconButton(
              tooltip: t.reload,
              icon: const Icon(Icons.refresh),
              onPressed: refresh,
            ),
        ],
      ),
      body: overview
          ? AbsenceOverview(
              form: form,
              entries: current,
              onRepeat: _openForm,
              onOther: () => _openForm(),
            )
          : AbsenceFormView(
              key: ValueKey(_formRound),
              form: form,
              initialFrom: _prefill?.day,
              initialPupilName: _prefill?.pupilName,
              initialKind: _prefill?.kind,
              // Demo: kein Senden (die Demo beantwortet Schreibaktionen ohnehin
              // mit Fehler; „unklar“ mit Link aufs echte Portal wäre irreführend).
              onSubmit: demoActive
                  ? null
                  : (fields) {
                      final parser = ref.read(absenceParserProvider);
                      return submitAbsence(
                        session,
                        fields,
                        before: form.entries,
                        reload: parser.getHome,
                      );
                    },
              // Ursache (Prüfung 05.11.26): Lud die Seite während Rückfrage,
              // Senden oder Ergebnis neu (alle 5 Minuten oder direkt nach dem
              // Senden), wurde die Maske abgebaut – „Jetzt melden“ tat nichts
              // oder das Ergebnis erschien nie. Daher: Auto-Aktualisierung
              // anhalten, solange gesendet wird, und erst nach dem
              // Ergebnis-Dialog neu laden.
              onSending: (active, {sent = false}) {
                final parser = ref.read(absenceParserProvider);
                if (active) {
                  parser.stopAutoRefresh();
                } else {
                  parser.startAutoRefresh();
                  if (sent) {
                    // Nach dem Senden wieder die Anzeige (mit der neuen Meldung).
                    if (mounted) setState(() => _formMode = false);
                    refresh?.call();
                    // „Heute“ und „Nachrichten“ zeigen die neue Meldung erst
                    // nach dem nächsten Durchgang (live_data.dart, _loadExtras).
                    LiveData.of(context)?.refresh();
                  }
                }
              },
            ),
    );
  }
}

/// Bestehende Meldungen als reine Anzeige mit den sinnvollen nächsten
/// Schritten: dasselbe für den nächsten Schultag oder eine andere Meldung.
class AbsenceOverview extends StatelessWidget {
  const AbsenceOverview({
    super.key,
    required this.form,
    required this.entries,
    required this.onRepeat,
    required this.onOther,
  });

  final AbsenceForm form;
  final List<AbsenceEntry> entries;
  final void Function(({DateTime day, String pupilName, String kind}) p)
  onRepeat;
  final VoidCallback onOther;

  /// Nächster Schultag nach der letzten Meldung dieses Kindes – sofern das
  /// Portal ihn noch annimmt (fromRange, z. B. „die nächsten 5 Tage“) und
  /// es keine Verspätung war.
  ({DateTime day, String pupilName, String kind})? _repeat() {
    final last = entries.last;
    DateTime? end;
    for (final e in entries) {
      if (e.name != last.name) continue;
      final p = absencePeriodDays(e.period);
      if (p != null && (end == null || p.to.isAfter(end))) end = p.to;
    }
    if (end == null || absenceIsLate(last)) return null;
    final day = nextSchoolDay(end);
    final r = form.fromRange;
    if (r != null && day.isAfter(r.last)) return null;
    if (!form.allowedPupils.any((p) => p.name == last.name)) return null;
    final kind = form.kinds
        .map((k) => k.value)
        .firstWhere((v) => v != absenceKindLate, orElse: () => '');
    return (day: day, pupilName: last.name, kind: kind);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final th = Theme.of(context);
    final cs = th.colorScheme;
    final repeat = _repeat();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(t.absenceSentTitle, style: th.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final e in entries)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.name} – ${e.kind}',
                          style: th.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Tag und Eintragszeit in einer Zeile (absenceDetail).
                  Text(absenceDetail(e, t), style: th.textTheme.bodyLarge),
                  if (e.comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '„${e.comment}“',
                      style: th.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (repeat != null) ...[
          FilledButton.icon(
            onPressed: () => onRepeat(repeat),
            icon: const Icon(Icons.event_repeat),
            label: Text(t.absenceRepeat(_shortDate(t, repeat.day))),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: onOther,
          icon: const Icon(Icons.add),
          label: Text(t.absenceOther),
        ),
      ],
    );
  }
}

/// Die eigentliche Maske; getrennt von [AbsencePage], damit sie ohne Portal
/// testbar ist.
class AbsenceFormView extends StatefulWidget {
  const AbsenceFormView({
    super.key,
    required this.form,
    this.now,
    this.onSubmit,
    this.onSending,
    this.initialFrom,
    this.initialPupilName,
    this.initialKind,
  });

  /// Vorbelegung aus „Auch … melden“ (AbsenceOverview): Tag, Kind (Name wie
  /// in der Liste), Art.
  final DateTime? initialFrom;
  final String? initialPupilName;
  final String? initialKind;

  /// Beginn (true) und Ende (false) eines Sendevorgangs – von der Rückfrage
  /// bis zum geschlossenen Ergebnis; [sent]: es wurde gesendet.
  final void Function(bool active, {bool sent})? onSending;

  final AbsenceForm form;

  /// Meldet wirklich ([submitAbsence]); null = Knopf gesperrt (Demo, Tests).
  final Future<AbsenceSubmitResult> Function(Map<String, String> fields)?
  onSubmit;

  /// Nur für Tests.
  final DateTime? now;

  @override
  State<AbsenceFormView> createState() => _AbsenceFormViewState();
}

class _AbsenceFormViewState extends State<AbsenceFormView> {
  late Set<String> _pupils;
  late String _kind;
  late DateTime _from;
  late DateTime _to;
  late String _blockFrom;
  late String _blockTo;
  final _comment = TextEditingController();
  bool _busy = false;

  AbsenceForm get f => widget.form;
  bool get _isLate => _kind == absenceKindLate;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant AbsenceFormView old) {
    super.didUpdateWidget(old);
    if (!identical(old.form, widget.form)) _clampToForm();
  }

  /// Nach dem Neuladen (alle paar Minuten) Eingaben behalten und nur an
  /// neue Portal-Grenzen anpassen, statt alles zurückzusetzen.
  void _clampToForm() {
    final allowed = {for (final p in f.allowedPupils) p.id};
    _pupils = _pupils.where(allowed.contains).toSet();
    if (!f.kinds.any((k) => k.value == _kind)) {
      _kind = f.kinds.isNotEmpty ? f.kinds.first.value : '';
    }
    DateTime clamp(DateTime d, DateRange? r) => r == null
        ? d
        : (d.isBefore(r.first) ? r.first : (d.isAfter(r.last) ? r.last : d));
    _from = clamp(_from, f.fromRange);
    _to = clamp(_to, f.toRange);
    if (_to.isBefore(_from)) _to = _from;
    if (!f.blocks.any((b) => b.value == _blockFrom)) {
      _blockFrom = f.blocks.isNotEmpty ? f.blocks.first.value : '';
    }
    if (!f.blocks.any((b) => b.value == _blockTo)) {
      _blockTo = f.blocks.isNotEmpty ? f.blocks.last.value : '';
    }
  }

  void _reset() {
    final allowed = f.allowedPupils;
    final pre = allowed.where((p) => p.preselected).map((p) => p.id).toSet();
    _pupils = pre.isNotEmpty
        ? pre
        : (allowed.length == 1 ? {allowed.single.id} : <String>{});
    _kind = f.kinds.isNotEmpty ? f.kinds.first.value : '';
    final today = widget.now ?? DateTime.now();
    _from = f.defaultFrom ?? f.fromRange?.first ?? today;
    _to = f.defaultTo ?? _from;
    _blockFrom = f.blocks.isNotEmpty ? f.blocks.first.value : '';
    _blockTo = f.blocks.isNotEmpty ? f.blocks.last.value : '';
    if (widget.initialFrom case final d?) {
      _from = d;
      _to = d;
      _clampToForm();
    }
    if (widget.initialPupilName case final n?) {
      final p = allowed.where((p) => p.name == n);
      if (p.isNotEmpty) _pupils = {p.first.id};
    }
    if (widget.initialKind case final k?
        when f.kinds.any((x) => x.value == k)) {
      _kind = k;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  AbsenceDraft get _draft => AbsenceDraft(
    pupilIds: _pupils.toList(),
    kind: _kind,
    from: _from,
    to: _to,
    blockFrom: _blockFrom,
    blockTo: _blockTo,
    comment: _comment.text.trim(),
  );

  Future<void> _pickDate({required bool isFrom}) async {
    final range = isFrom ? f.fromRange : f.toRange;
    final current = isFrom ? _from : _to;
    final first = range?.first ?? current;
    final last = range?.last ?? current;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first)
          ? first
          : (current.isAfter(last) ? last : current),
      firstDate: first,
      lastDate: last,
      helpText: isFrom ? context.t.absenceFirstDay : context.t.absenceLastDay,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  String _blockLabel(AbsenceBlock b) => b.start != null && b.end != null
      ? '${b.label}  ${b.start}–${b.end}'
      : b.label;

  /// Einträge der Block-Auswahl, je Wert einmal (doppelte Werte lösen in
  /// DropdownButton eine Prüfung aus).
  List<DropdownMenuItem<String>> _blockItems() {
    final seen = <String>{};
    return [
      for (final b in f.blocks)
        if (seen.add(b.value))
          DropdownMenuItem(value: b.value, child: Text(_blockLabel(b))),
    ];
  }

  /// [v], wenn es ihn in der Liste gibt, sonst null (Feld leer statt
  /// Prüffehler).
  String? _blockValue(String v) => f.blocks.any((b) => b.value == v) ? v : null;

  String _summary(ForkL10n t) {
    final names = f.pupils
        .where((p) => _pupils.contains(p.id))
        .map((p) => p.firstName)
        .join(' ${t.and} ');
    AbsenceBlock? block(String v) =>
        f.blocks.where((b) => b.value == v).firstOrNull;
    final String when;
    if (_isLate) {
      final bf = block(_blockFrom)?.label ?? '?';
      final bt = block(_blockTo)?.label ?? '?';
      when = bf == bt
          ? t.absenceBlockOne(_shortDate(t, _from), bf)
          : t.absenceBlockRange(_shortDate(t, _from), bf, bt);
    } else {
      when = DateUtils.isSameDay(_from, _to)
          ? t.absenceWholeDay(_shortDate(t, _from))
          : t.absenceDayRange(_shortDate(t, _from), _shortDate(t, _to));
    }
    final kind = _isLate ? t.absenceKindLate : t.absenceKindAbsent;
    return '${names.isEmpty ? t.absenceNoChild : names} – $kind\n$when';
  }

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null || _busy) return;
    widget.onSending?.call(true);
    var sent = false;
    try {
      sent = await _submitInner(onSubmit);
    } finally {
      widget.onSending?.call(false, sent: sent);
    }
  }

  /// Rückfrage, Senden, Ergebnis; true, wenn gesendet wurde.
  Future<bool> _submitInner(
    Future<AbsenceSubmitResult> Function(Map<String, String>) onSubmit,
  ) async {
    final t = context.t;
    final fields = _draft.toFields(f);
    final key = fields.entries.map((e) => '${e.key}=${e.value}').join('&');
    final comment = _comment.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.absenceConfirmTitle),
        content: Text(
          [
            if (key == absenceLastSent.value) t.absenceAlreadySent,
            t.absenceConfirmText,
            _summary(t),
            if (comment.isNotEmpty) '„$comment“',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.absenceConfirmSend),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    setState(() => _busy = true);
    AbsenceSubmitResult r;
    try {
      r = await onSubmit(fields);
    } catch (_) {
      r = const AbsenceSubmitResult(AbsenceSent.unconfirmed);
    }
    if (r.state != AbsenceSent.rejected) absenceLastSent.value = key;
    if (!mounted) return true;
    setState(() => _busy = false);
    final e = r.entry;
    final (title, text) = switch (r.state) {
      AbsenceSent.confirmed => (
        t.absenceSentTitle,
        '${t.absenceSentText}\n\n${e!.name} – ${e.kind}\n${e.period}',
      ),
      AbsenceSent.unconfirmed => (t.absenceUnclearTitle, t.absenceUnclearText),
      AbsenceSent.rejected => (t.absenceRejected, r.errors.join('\n\n')),
    };
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          if (r.state == AbsenceSent.unconfirmed)
            TextButton(
              onPressed: () => safeLaunchUrl(
                Uri.parse(
                  'https://start.schulportal.hessen.de/abwesenheitsmeldung.php',
                ),
                context: c,
              ),
              child: Text(t.absenceOpenPortal),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return r.state != AbsenceSent.rejected;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final errors = validateAbsenceDraft(f, _draft, t);
    final allowed = f.allowedPupils;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    return ListView(
      // Unterkante = 32 + Höhe der System-Navigationsleiste. Ursache: Die App
      // läuft randlos (SystemUiMode.edgeToEdge, main.dart), und ein ListView
      // mit eigenem `padding` übernimmt die MediaQuery-Ränder NICHT selbst.
      // Ohne den Zuschlag lag der letzte Knopf auf dem Pixel 9a halb unter
      // der Gestenleiste (Screenshot 16.10.26, 9311).
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (f.rules.isNotEmpty)
          Card(
            color: theme.colorScheme.secondaryContainer,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.absenceRules(f.rules.join(' ${t.and} ')),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (allowed.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(t.absenceNoneAllowed),
          )
        else ...[
          if (f.kinds.length > 1)
            section(
              t.absenceKind,
              SegmentedButton<String>(
                segments: [
                  for (final k in f.kinds)
                    ButtonSegment(
                      value: k.value,
                      // „Verspätet“ nur für absenceKindLate, „Abwesend“ nur
                      // für „krank“; jede andere Art mit dem Text des
                      // Portals. Ursache (Prüfung 27.10.26): Alles außer
                      // „krank“ hieß „Verspätet“ – auch Arten, die als
                      // Abwesenheit gesendet werden (AbsenceDraft.isLate).
                      label: Text(
                        k.value == 'krank'
                            ? t.absenceAbsent
                            : k.value == absenceKindLate
                            ? t.absenceLate
                            : k.label,
                      ),
                      icon: Icon(
                        k.value == absenceKindLate
                            ? Icons.schedule
                            : Icons.sick_outlined,
                      ),
                    ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.single),
              ),
            ),
          section(
            t.absenceChild,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in f.pupils)
                  FilterChip(
                    label: Text(p.name),
                    selected: _pupils.contains(p.id),
                    onSelected: p.allowed
                        ? (v) => setState(
                            () => v ? _pupils.add(p.id) : _pupils.remove(p.id),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          // Wie im Portal (meldungEltern.js): abwesend = Von/Bis-Tag ohne
          // Blöcke; verspätet = ein Tag („Am“) mit Block von–bis.
          if (_isLate) ...[
            section(
              t.absenceDay,
              _DateTile(
                label: t.absenceOn,
                date: _from,
                onTap: () => _pickDate(isFrom: true),
              ),
            ),
            section(
              t.absenceLessons,
              Column(
                children: [
                  // Schlüssel = Wert: Ändert _clampToForm den Block nach dem
                  // Neuladen (alle 5 Minuten), baut das Feld neu auf. Ursache
                  // (Prüfung 27.10.26): initialValue gilt nur beim ersten Bau
                  // – die Anzeige blieb beim alten Block, gesendet wurde der
                  // neue; fehlte der alte in der neuen Liste, schlug die
                  // Prüfung „genau ein Eintrag mit diesem Wert“ fehl.
                  DropdownButtonFormField<String>(
                    key: ValueKey('absence-block-from-$_blockFrom'),
                    initialValue: _blockValue(_blockFrom),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.absenceFromBlock,
                      border: const OutlineInputBorder(),
                    ),
                    items: _blockItems(),
                    onChanged: (v) {
                      if (v != null) setState(() => _blockFrom = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('absence-block-to-$_blockTo'),
                    initialValue: _blockValue(_blockTo),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t.absenceToBlock,
                      border: const OutlineInputBorder(),
                    ),
                    items: _blockItems(),
                    onChanged: (v) {
                      if (v != null) setState(() => _blockTo = v);
                    },
                  ),
                ],
              ),
            ),
          ] else
            section(
              t.absencePeriod,
              Column(
                children: [
                  _DateTile(
                    label: t.absenceFrom,
                    date: _from,
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTile(
                    label: t.absenceTo,
                    date: _to,
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ],
              ),
            ),
          section(
            t.absenceComment,
            TextField(
              controller: _comment,
              maxLength: 200,
              // Warnung des Portals immer sichtbar (dort erst beim Antippen).
              // Vorher stand hier „z. B. Arzttermin“ – genau die Art Angabe,
              // vor der das Portal warnt.
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                helperText: f.commentWarning ?? t.absenceNoHealthData,
                helperMaxLines: 2,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.absenceSummary, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(_summary(t), style: theme.textTheme.bodyLarge),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        e,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Echtes Absenden seit 05.11.26 (submitAbsence): Rückfrage, dann
          // Prüfung + Speichern wie im Portal, danach Abgleich mit der Liste.
          FilledButton(
            onPressed: errors.isEmpty && !_busy && widget.onSubmit != null
                ? _submit
                : null,
            child: Text(_isLate ? t.absenceSendLate : t.absenceSend),
          ),
          // „Beim Portal prüfen“ und „Vorschau der Portal-Felder“ (Probephase
          // bis 9477) entfallen: Rückmeldung 05.11.26 – man sah erst die
          // Felder, dann die Rückfrage, und hielt beides für nötig. Die
          // Prüfung (check=1) läuft in submitAbsence ohnehin vor jedem Senden.
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (f.entries.isNotEmpty)
            section(
              t.absenceEntries,
              Column(
                children: [
                  for (final e in f.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${e.name} – ${e.kind}'),
                        subtitle: Text(
                          [
                            e.period,
                            if (e.comment.isNotEmpty) e.comment,
                          ].join('\n'),
                        ),
                        trailing: Text(
                          e.entered,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          formatDate(context.t, context.t.dateShortYear, date),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
