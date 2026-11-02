import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../mensa_catalog.dart';
import '../../onboarding/onboarding_kit.dart';
import '../kit.dart';

/// Bestellseite der Mensa wählen (Wunsch 02.11.26): ein Auswahlfeld mit dem
/// Caterer der Schule (mensaCaterersForSchool) vorausgewählt; darin auch die
/// übrigen bekannten Caterer und „Andere Adresse eingeben…“ mit Textfeld.
/// Stehen bei einer Schule zwei Caterer (zwei Standorte), ist nichts
/// vorausgewählt.
///
/// Ursache: Bis 9464 ein Dialog nur mit Textfeld – die Adresse musste man
/// kennen und eintippen, und auf dem Tablet stapelten sich die drei Knöpfe
/// untereinander (Bildschirmfoto 02.11.26).
///
/// Zugang beim Caterer (Wunsch 02.11.26, „nur lokal gespeichert“): optional
/// Benutzername und Passwort gleich hier; der Aufrufer legt sie mit
/// saveMensaLogin nur im geschützten Speicher des Geräts ab (Keystore,
/// mensa_login.dart; App-Sicherung ist aus, allowBackup=false). Damit liest
/// Heute das Essen, ohne dass man vorher einmal die Seite des Caterers
/// öffnet. Grenze: Ob die Daten stimmen, zeigt erst die erste Anmeldung –
/// schlägt sie fehl, erscheint wie bisher die Anmeldeseite.
///
/// Rückgabe: null = abgebrochen; url '' = Eintrag löschen.
typedef MensaSheetResult = ({
  String url,
  String? user,
  String? pass,
  bool forgetLogin,

  /// Wochentage (1 = Montag) der Erinnerung an fehlende Bestellungen;
  /// null = unverändert.
  Set<int>? remind,
});

Future<MensaSheetResult?> showMensaSheet(
  BuildContext context, {
  String? current,
  String? childName,
  String school = '',
  String schoolId = '',
  String? suggestion,
  String? savedUser,
  Set<int>? remindDays,
  List<MensaCaterer> catalog = mensaCatalog,
}) => showModalBottomSheet<MensaSheetResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Kit.of(context).p.card,
  builder: (_) => MensaSheet(
    current: current,
    childName: childName,
    school: school,
    schoolId: schoolId,
    suggestion: suggestion,
    savedUser: savedUser,
    remindDays: remindDays,
    catalog: catalog,
  ),
);

class MensaSheet extends StatefulWidget {
  const MensaSheet({
    super.key,
    this.current,
    this.childName,
    this.school = '',
    this.schoolId = '',
    this.suggestion,
    this.savedUser,
    this.remindDays,
    this.catalog = mensaCatalog,
  });

  /// Benutzername einer schon gemerkten Anmeldung (readMensaLogin).
  final String? savedUser;

  /// Erinnerungstage (mealRemindDays); null = Abschnitt nicht zeigen.
  final Set<int>? remindDays;

  final String? current;
  final String? childName;
  final String school;
  final String schoolId;

  /// Aus der App-Liste der Schule (mensaSuggestion); nur ohne Eintrag.
  final String? suggestion;
  final List<MensaCaterer> catalog;

  @override
  State<MensaSheet> createState() => _MensaSheetState();
}

class _MensaSheetState extends State<MensaSheet> {
  /// Gewählter Caterer (key); null = eigene Adresse bzw. noch nichts.
  String? _pick;
  bool _own = false;
  final _text = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _login = false;
  bool _forget = false;
  bool _show = false;
  late Set<int>? _remind = widget.remindDays == null
      ? null
      : {...widget.remindDays!};

  List<MensaCaterer> get _forSchool =>
      mensaCaterersForSchool(widget.schoolId, widget.catalog);

  @override
  void initState() {
    super.initState();
    final cur = widget.current;
    if (cur != null) {
      final c = mensaCatererForUrl(cur, widget.catalog);
      if (c != null) {
        _pick = c.key;
      } else {
        _own = true;
      }
      // Auch bei bekanntem Caterer: die eingetragene Adresse bleibt im Feld
      // (z. B. eine Wochenseite), falls man „Andere Adresse“ wählt.
      _text.text = cur;
      return;
    }
    final s = _forSchool;
    final portal = widget.suggestion;
    if (s.length == 1) {
      _pick = s.single.key;
    } else if (s.isNotEmpty) {
      // Zwei Standorte mit verschiedenen Caterern: keine Vorauswahl.
    } else if (portal != null) {
      final c = mensaCatererForUrl(portal, widget.catalog);
      if (c != null) {
        _pick = c.key;
      } else {
        _own = true;
        _text.text = portal;
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? get _result {
    if (_own) {
      final v = _text.text.trim();
      return v.isEmpty ? null : v;
    }
    for (final c in widget.catalog) {
      if (c.key != _pick) continue;
      // Unverändert: die eingetragene Adresse behalten (sie kann eine
      // Wochenseite sein), statt sie durch die Startseite zu ersetzen.
      final cur = widget.current;
      return cur != null && c.matches(cur) ? cur : c.url;
    }
    return null;
  }

  static const _ownKey = '_own';

  /// Wochentag zum Antippen (wie ClassSheet, class_sheet.dart).
  Widget _dayChip(Kit k, String label, bool sel, VoidCallback onTap) =>
      Semantics(
        selected: sel,
        button: true,
        child: Material(
          color: sel ? k.p.strong : k.p.card,
          borderRadius: BorderRadius.circular(Rad.buttonSmall),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.buttonSmall),
            onTap: onTap,
            child: SizedBox(
              height: Sz.buttonSmall,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: k.tileTitle.copyWith(
                      color: sel ? k.p.onStrong : k.p.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// Umrandeter kleiner Knopf wie „Bestellen“ (meal_week_page).
  Widget _smallButton(Kit k, String label, Color c, VoidCallback onTap) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, Sz.buttonTiny),
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.l,
            vertical: Sp.xs,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: c),
        ),
        onPressed: onTap,
        child: Text(label, style: k.link.copyWith(color: c)),
      );

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final school = _forSchool;
    // Caterer der Schule zuerst, dann die übrigen, zuletzt eigene Adresse.
    final list = [
      ...school,
      for (final c in widget.catalog)
        if (!school.contains(c)) c,
    ];
    MensaCaterer? picked;
    for (final c in list) {
      if (!_own && c.key == _pick) picked = c;
    }
    final ofSchool = picked != null && school.contains(picked);
    final helper = _own
        ? null
        : picked != null
        ? picked.shortUrl
        : school.length > 1
        ? t.mensaTwoKnown
        : t.mensaNoneKnown;
    final result = _result;
    final user = _user.text.trim();
    final pass = _pass.text;
    // Angefangene Anmeldung: erst mit beiden Feldern speicherbar.
    final loginOk = !_login || (user.isEmpty == pass.isEmpty);
    final saved = widget.savedUser != null && !_forget && !_login;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Sp.xl,
          0,
          Sp.xl,
          Sp.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.childName == null
                  ? t.mensaDialogTitle
                  : t.mensaDialogTitleFor(widget.childName!),
              style: k.sheetTitle,
            ),
            if (widget.school.isNotEmpty)
              Text(widget.school, style: k.cardMeta),
            const SizedBox(height: Sp.l),
            // Ein Auswahlfeld statt Liste (Rückmeldung 02.11.26: „zu
            // umständlich“) – vorausgewählt ist der Caterer der Schule.
            DropdownButtonFormField<String>(
              initialValue: _own ? _ownKey : picked?.key,
              isExpanded: true,
              style: k.planSubject(k.p.ink),
              dropdownColor: k.p.card,
              borderRadius: BorderRadius.circular(Rad.row),
              hint: Text(t.mensaPick, style: k.planSubject(k.p.muted)),
              // Feldname zeigt, woher die Vorauswahl stammt.
              decoration:
                  onbInput(
                    k,
                    label: ofSchool ? t.mensaForSchool : t.mensaCatererLabel,
                    icon: Icons.restaurant_menu,
                  ).copyWith(
                    helperText: helper,
                    helperStyle: k.planMeta(k.p.muted),
                    helperMaxLines: 2,
                  ),
              items: [
                for (final c in list)
                  DropdownMenuItem(
                    value: c.key,
                    child: Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                      style: k.planSubject(k.p.ink),
                    ),
                  ),
                DropdownMenuItem(
                  value: _ownKey,
                  child: Text(t.mensaOwnItem, style: k.planSubject(k.p.ink)),
                ),
              ],
              onChanged: (v) => setState(() {
                _own = v == _ownKey;
                _pick = _own ? null : v;
              }),
            ),
            if (_own) ...[
              const SizedBox(height: Sp.m),
              TextField(
                controller: _text,
                autofocus: widget.current == null,
                autocorrect: false,
                keyboardType: TextInputType.url,
                style: k.body,
                decoration: onbInput(
                  k,
                  label: t.mensaUrlLabel,
                  icon: Icons.link,
                ).copyWith(hintText: t.mensaDialogHint),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.current == null && widget.suggestion != null)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.xs),
                  child: Text(t.mensaSuggested, style: k.planMeta(k.p.muted)),
                ),
            ],
            const SizedBox(height: Sp.l),
            // Erinnerung je Wochentag gleich hier (Wunsch 02.11.26) – bisher
            // nur über die Glocke auf „Essen“ (meal_remind_sheet.dart), die
            // kaum jemand fand. Gleicher Speicher (mealRemindDays).
            if (_remind case final days?) ...[
              Container(
                padding: const EdgeInsets.all(Sp.l),
                decoration: BoxDecoration(
                  color: k.p.inset,
                  borderRadius: BorderRadius.circular(Rad.panel),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: Sz.hintBadge,
                          height: Sz.hintBadge,
                          decoration: BoxDecoration(
                            color: k.p.card,
                            borderRadius: BorderRadius.circular(Rad.badge),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            size: Sz.hintBadgeIcon,
                            color: k.p.ink,
                          ),
                        ),
                        const SizedBox(width: Sp.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.mealRemindTitle,
                                style: k.planSubject(k.p.ink),
                              ),
                              Text(
                                days.isEmpty
                                    ? t.mealRemindNone
                                    : t.mealRemindDaysHint,
                                style: k.planMeta(k.p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.m),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++) ...[
                          if (i > 1) const SizedBox(width: Sp.xs + Sp.xxs),
                          Expanded(
                            child: _dayChip(
                              k,
                              formatDate(
                                t,
                                'EEE',
                                DateTime(2026, 10, 25 + i),
                              ).replaceAll('.', ''),
                              days.contains(i),
                              () => setState(
                                () => days.contains(i)
                                    ? days.remove(i)
                                    : days.add(i),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.m),
            ],
            // Zugang als eigene Fläche (Rückmeldung 02.11.26: „optisch
            // aufwerten“) – vorher nur eine Textzeile unter dem Auswahlfeld.
            Container(
              padding: const EdgeInsets.all(Sp.l),
              decoration: BoxDecoration(
                color: k.p.inset,
                borderRadius: BorderRadius.circular(Rad.panel),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: Sz.hintBadge,
                        height: Sz.hintBadge,
                        decoration: BoxDecoration(
                          color: k.p.card,
                          borderRadius: BorderRadius.circular(Rad.badge),
                        ),
                        child: Icon(
                          saved
                              ? Icons.verified_user_outlined
                              : Icons.key_outlined,
                          size: Sz.hintBadgeIcon,
                          color: k.p.ink,
                        ),
                      ),
                      const SizedBox(width: Sp.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              saved
                                  ? t.mensaLoginSavedTitle
                                  : t.mensaLoginTitle,
                              style: k.planSubject(k.p.ink),
                            ),
                            Text(
                              saved
                                  ? widget.savedUser!
                                  : _login
                                  ? t.mensaLoginLocal
                                  : t.mensaLoginWhy,
                              style: k.planMeta(k.p.muted),
                              maxLines: saved ? 1 : 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!saved && !_login) ...[
                        const SizedBox(width: Sp.s),
                        _smallButton(
                          k,
                          t.mensaLoginAddShort,
                          k.p.onNavSelected,
                          () => setState(() => _login = true),
                        ),
                      ],
                    ],
                  ),
                  if (saved) ...[
                    const SizedBox(height: Sp.m),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _smallButton(
                          k,
                          t.mensaLoginChange,
                          k.p.onNavSelected,
                          () => setState(() => _login = true),
                        ),
                        const SizedBox(width: Sp.s),
                        _smallButton(
                          k,
                          t.delete,
                          k.p.cancel.ink,
                          () => setState(() => _forget = true),
                        ),
                      ],
                    ),
                  ],
                  if (_login) ...[
                    const SizedBox(height: Sp.m),
                    TextField(
                      controller: _user,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      style: k.body,
                      decoration: onbInput(
                        k,
                        label: t.mensaLoginUser,
                        icon: Icons.person_outline,
                      ).copyWith(filled: true, fillColor: k.p.card),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: Sp.m),
                    TextField(
                      controller: _pass,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      style: k.body,
                      decoration:
                          onbInput(
                            k,
                            label: t.mensaLoginPass,
                            icon: Icons.lock_outline,
                          ).copyWith(
                            filled: true,
                            fillColor: k.p.card,
                            suffixIcon: IconButton(
                              tooltip: _show
                                  ? t.mensaLoginHide
                                  : t.mensaLoginShow,
                              icon: Icon(
                                _show
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(() => _show = !_show),
                            ),
                          ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Sp.l),
            OnbButton(
              label: t.save,
              onPressed: result == null || !loginOk
                  ? null
                  : () => Navigator.of(context).pop<MensaSheetResult>((
                      url: result,
                      user: _login && user.isNotEmpty ? user : null,
                      pass: _login && user.isNotEmpty ? pass : null,
                      forgetLogin: _forget,
                      remind: _remind,
                    )),
            ),
            if (widget.current != null)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop<MensaSheetResult>((
                    url: '',
                    user: null,
                    pass: null,
                    forgetLogin: true,
                    remind: null,
                  )),
                  child: Text(t.mensaRemove, style: k.link),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
