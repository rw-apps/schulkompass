import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;

import '../../l10n/l10n.dart';
import '../../mensa.dart' show MensaKidKey;
import '../../mensa_catalog.dart';
import '../../mensa_login.dart';
import '../../mensa_store.dart';
import '../../mensa_week.dart';
import '../../school_links.dart' show normalizeMensaUrl, mensaSuggestion;
import '../kit.dart';
import '../live/family.dart';
import '../live/live_data.dart';
import '../nav.dart' show pushFullScreen;
import '../settings/settings_widgets.dart';
import '../today/live_today_page.dart' show openMensa, mealUnorderedDay;
import '../today/today_from_lanis.dart' show shortSchoolName;
import '../today/today_page.dart' show schoolWeek, dayDiff;
import 'mensa_page.dart';
import 'mensa_sheet.dart';

/// „Essen und Caterer“ (Entwurf 02.11.26, abgenommen): ein Eintrag unter
/// Mehr, dahinter je Kind eine Karte mit der Woche auf einen Blick, dem
/// nächsten offenen Tag, „Wochenplan & bestellen“ sowie Guthaben, Caterer,
/// Zugang, Erinnerung und der Seite des Caterers.
///
/// Ursache: Bis 9467 standen „Essen bestellen · Kind“ je Kind und „Mensa-
/// Adresse ändern“ als eigene Punkte unter Mehr; Erinnerung und Zugang lagen
/// verstreut (Glocke auf „Essen“, Blatt „Bestellseite“). Rückmeldung
/// 02.11.26: „alles unter Essen und Caterer zusammenfassen“.
///
/// Grenze: Die Seite liegt im Navigator des Reiters (pushInTab), damit sie
/// FamilyData sieht und nach Änderungen neu aufbaut; aus „Essen“ (Vollbild)
/// führt das Zahnrad deshalb direkt ins Blatt des Kindes (editMensa).

/// Ein Kind eines Kontos mit Essensbestellung.
typedef MealKid = ({FamilyMember member, MensaKidKey kid, String name});

/// Alle Kinder der Familie; Schülerkonto bzw. Kinder noch nicht geladen:
/// ein Eintrag mit dem Kontonamen (Schlüssel '').
List<MealKid> mealKids(List<FamilyMember> members) => [
  for (final m in members)
    if (m.snapshot.kids.isEmpty)
      (member: m, kid: '', name: m.snapshot.firstName)
    else
      for (final k in m.snapshot.kids)
        (member: m, kid: k.pupilId, name: k.firstName),
];

List<FamilyMember> _members(BuildContext context) {
  final f = FamilyData.of(context);
  if (f.isNotEmpty) return f;
  final s = LiveData.of(context);
  return s == null
      ? const []
      : [FamilyMember(accountId: -1, snapshot: s, colorIndex: 0)];
}

/// Kurzzeile für Mehr: wo etwas zu tun ist („Jonas: Mi noch nicht bestellt
/// · Lena: einrichten“), sonst der Caterer.
String mealHubSummary(ForkL10n t, List<MealKid> kids, DateTime now) {
  final named = kids.length > 1;
  String one(MealKid k) {
    final s = k.member.snapshot;
    final url = s.mensa.of(k.kid);
    final String text;
    if (url == null) {
      text = t.mealHubSetupShort;
    } else {
      final owner = s.mensaOwner(k.kid);
      final day = mealUnorderedDay(
        MealCache.instance.ofSite(owner, url),
        now,
        weekdays: mealRemindDays(MealCache.instance.settings, owner),
      );
      text = day != null
          ? t.mealHubOpen(formatDate(t, 'EE', day).replaceAll('.', ''))
          : (mensaCatererForUrl(url)?.name ?? Uri.parse(url).host);
    }
    return named && k.name.isNotEmpty ? '${k.name}: $text' : text;
  }

  return kids.map(one).join(' · ');
}

/// Blatt „Bestellseite“ für ein Kind öffnen und das Ergebnis speichern:
/// Adresse (setMensaUrl, löscht bei Wechsel die alte Anmeldung), danach
/// Zugang und Erinnerungstage. true = die Adresse hat sich geändert.
///
/// Reihenfolge: Erst wenn setMensaUrl die alte Anmeldung gelöscht hat, wird
/// die neue gespeichert – sonst könnte das Löschen sie treffen.
Future<bool> editMensa(
  BuildContext context,
  LiveSnapshot s,
  MensaKidKey kid, {
  String? name,
}) async {
  final owner = s.mensaOwner(kid);
  final current = s.mensa.of(kid);
  // Nur ein Zugang derselben Seite gilt als hinterlegt (Altlast einer früher
  // falsch eingetragenen Adresse sonst sichtbar).
  final saved = current == null
      ? null
      : await readMensaLogin(owner, site: current);
  if (!context.mounted) return false;
  final shared = MealCache.instance.settings;
  final r = await showMensaSheet(
    context,
    current: current,
    childName: name,
    school: shortSchoolName(s.schoolName),
    schoolId: s.schoolId,
    suggestion: current == null ? mensaSuggestion(s.session.travelMenu) : null,
    savedUser: saved?.user,
    remindDays: mealRemindDays(shared, owner),
  );
  if (r == null) return false;
  final raw = r.url;
  final url = normalizeMensaUrl(raw);
  if (raw.trim().isNotEmpty && url == null) return false;
  await s.setMensaUrl(kid, raw);
  if (r.remind case final days? when shared != null && url != null) {
    setMealRemindDays(shared, owner, days);
    MealCache.instance.touch();
  }
  if (r.user case final user? when url != null) {
    await saveMensaLogin(
      owner,
      MensaLogin(host: Uri.parse(url).host, user: user, pass: r.pass ?? ''),
    );
    // Heute gleich mit dem neuen Zugang lesen (MealRefresh).
    MealCache.instance.requestRefresh(owner);
  } else if (r.forgetLogin) {
    await forgetMensaLogin(owner);
  }
  return current != (raw.trim().isEmpty ? null : url);
}

/// Wochenplan eines Kindes öffnen; das Zahnrad dort führt ins Blatt
/// (editMensa), nach einem Wechsel des Caterers schließt sich die Woche.
Future<void> openMealWeek(
  BuildContext context,
  MealKid k, {
  bool named = true,
}) {
  final s = k.member.snapshot;
  return openMensa(
    context,
    s,
    k.kid,
    name: named && k.name.isNotEmpty ? k.name : null,
    colorIndex: k.member.colorIndex,
    onSettings: () => editMensa(context, s, k.kid, name: k.name),
  );
}

class MealHubPage extends StatefulWidget {
  const MealHubPage({super.key, this.now});

  /// Nur Tests.
  final DateTime? now;

  @override
  State<MealHubPage> createState() => _MealHubPageState();
}

class _MealHubPageState extends State<MealHubPage> {
  /// Erhöht nach jedem Bearbeiten: Zugänge neu lesen.
  int _round = 0;

  Future<void> _edit(MealKid k) async {
    await editMensa(context, k.member.snapshot, k.kid, name: k.name);
    if (mounted) setState(() => _round++);
  }

  @override
  void initState() {
    super.initState();
    try {
      MealCache.instance.attach(
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(sharedOverAccountSettingsProvider),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final kids = mealKids(_members(context));
    final now = widget.now ?? DateTime.now();
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(t.mealHubTitle, style: k.section),
      ),
      // Neu gelesene Wochen (MealCache) erneuern die Karten.
      body: ValueListenableBuilder(
        valueListenable: MealCache.instance.notifier,
        builder: (context, _, _) => ListView(
          padding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.xl),
          children: [
            for (final (i, kid) in kids.indexed) ...[
              if (i > 0) const SizedBox(height: Sp.m),
              _KidMealCard(
                key: ValueKey('${kid.member.accountId}:${kid.kid}:$_round'),
                kid: kid,
                now: now,
                named: kids.length > 1,
                onEdit: () => _edit(kid),
              ),
            ],
            // Bestellen in der App als Testfunktion (mealOrderInApp).
            if (MealCache.instance.settings case final st?) ...[
              const SizedBox(height: Sp.l),
              SettingsGroup(
                children: [
                  SettingsSwitchRow(
                    label: t.mealOrderInApp,
                    detail: t.mealOrderInAppDetail,
                    icon: Icons.science_outlined,
                    value: mealOrderInApp(st),
                    onChanged: (v) {
                      setMealOrderInApp(st, v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KidMealCard extends StatelessWidget {
  const _KidMealCard({
    super.key,
    required this.kid,
    required this.now,
    required this.named,
    required this.onEdit,
  });

  final MealKid kid;
  final DateTime now;
  final bool named;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final s = kid.member.snapshot;
    final tone = k.kid(kid.member.colorIndex);
    final url = s.mensa.of(kid.kid);
    final owner = s.mensaOwner(kid.kid);
    final school = shortSchoolName(s.schoolName);
    final name = kid.name.isEmpty ? t.yourChild : kid.name;
    final head = Row(
      children: [
        CircleAvatar(
          radius: Sz.avatar / 2,
          backgroundColor: tone.accent,
          child: Text(name.characters.first, style: k.avatarLetter),
        ),
        const SizedBox(width: Sp.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: k.cardName),
              if (school.isNotEmpty) Text(school, style: k.cardMeta),
            ],
          ),
        ),
      ],
    );
    final List<Widget> body;
    if (url == null) {
      final known = mensaCaterersForSchool(s.schoolId);
      body = [
        const SizedBox(height: Sp.m),
        Text(
          known.length == 1
              ? t.mealHubSetupKnown(known.single.name)
              : t.mealHubSetup,
          style: k.planMeta(k.p.muted),
        ),
        const SizedBox(height: Sp.m),
        OutlinedButton(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(Sz.buttonSmall),
            side: BorderSide(color: k.p.onNavSelected),
          ),
          child: Text(t.mealHubSetupAction, style: k.link),
        ),
      ];
    } else {
      final entry = MealCache.instance.ofSite(owner, url);
      final remind = mealRemindDays(MealCache.instance.settings, owner);
      final open = mealUnorderedDay(entry, now, weekdays: remind);
      final caterer = mensaCatererForUrl(url)?.name ?? Uri.parse(url).host;
      body = [
        const SizedBox(height: Sp.l),
        Text(upperFor(t, t.mealHubThisWeek), style: k.dateCaps),
        const SizedBox(height: Sp.s),
        _WeekStrip(entry: entry, now: now, tone: tone),
        if (open != null) ...[
          const SizedBox(height: Sp.s),
          Text(
            t.mealHubOpenLong(formatDate(t, 'EEEE', open)),
            style: k.planMeta(k.p.change.ink),
          ),
        ] else if (entry?.unreadable == true) ...[
          const SizedBox(height: Sp.s),
          Text(t.mealHubUnreadable, style: k.planMeta(k.p.muted)),
        ],
        const SizedBox(height: Sp.m),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: k.p.strong,
            foregroundColor: k.p.onStrong,
            minimumSize: const Size.fromHeight(Sz.buttonSmall),
          ),
          onPressed: () => openMealWeek(context, kid, named: named),
          icon: const Icon(Icons.restaurant_menu),
          label: Text(
            t.mealHubWeek,
            style: k.tileTitle.copyWith(color: k.p.onStrong),
          ),
        ),
        const SizedBox(height: Sp.s),
        if (entry?.balance case final b?) ...[
          _Row(
            icon: Icons.account_balance_wallet_outlined,
            label: t.mealHubBalance,
            value: '$b €',
            onTap: () => openMealWeek(context, kid, named: named),
          ),
          Divider(height: 1, color: k.p.inset),
        ],
        _Row(
          icon: Icons.storefront_outlined,
          label: t.mealHubCaterer,
          value: caterer,
          onTap: onEdit,
        ),
        Divider(height: 1, color: k.p.inset),
        FutureBuilder<(MensaLogin?, bool)>(
          future: _loginState(owner, url),
          builder: (context, snap) {
            final (login, failed) = snap.data ?? (null, false);
            return _Row(
              icon: Icons.key_outlined,
              label: t.mealHubLogin,
              // Abgelehnt (markMensaLoginFailed): neu eingeben.
              value: login == null
                  ? t.mealHubLoginNone
                  : failed
                  ? t.mealHubLoginRejected
                  : t.mealHubLoginSaved,
              valueColor: failed && login != null ? k.p.change.ink : null,
              onTap: onEdit,
            );
          },
        ),
        Divider(height: 1, color: k.p.inset),
        _Row(
          icon: Icons.notifications_active_outlined,
          label: t.mealRemindTitle,
          value: _days(t, remind),
          onTap: onEdit,
        ),
        Divider(height: 1, color: k.p.inset),
        _Row(
          icon: Icons.language,
          label: t.mealHubPage,
          value: t.mealHubPageOpen,
          external: true,
          onTap: () => pushFullScreen<void>(
            context,
            (_) => MensaPage(
              url: url,
              owner: owner,
              childName: named ? kid.name : null,
            ),
          ),
        ),
      ];
    }
    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        boxShadow: k.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [head, ...body],
      ),
    );
  }

  static Future<(MensaLogin?, bool)> _loginState(
    String owner,
    String url,
  ) async =>
      (await readMensaLogin(owner, site: url), await mensaLoginFailed(owner));

  /// „Mo–Fr“, „aus“ oder die Kurznamen („Mo, Di, Do“).
  static String _days(ForkL10n t, Set<int> d) {
    if (d.isEmpty) return t.mealHubRemindOff;
    if (d.containsAll(const {1, 2, 3, 4, 5})) return t.mealHubRemindAll;
    return [
      for (var i = 1; i <= 5; i++)
        if (d.contains(i))
          formatDate(t, 'EE', DateTime(2026, 10, 25 + i)).replaceAll('.', ''),
    ].join(', ');
  }
}

/// Woche auf einen Blick: bestellt (Haken), offen (Ausrufezeichen), sonst
/// Strich (zu, verpasst, unbekannt).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.entry,
    required this.now,
    required this.tone,
  });

  final MealEntry? entry;
  final DateTime now;
  final KidTone tone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final days = schoolWeek(now);
    return Row(
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(width: Sp.xs),
          Expanded(child: _cell(k, t, day)),
        ],
      ],
    );
  }

  Widget _cell(Kit k, ForkL10n t, DateTime day) {
    final d = entry?.dayOf(day);
    final past = dayDiff(now, day) < 0;
    final ordered = d?.state == MealState.ordered;
    final open =
        !past &&
        d?.state == MealState.open &&
        d!.options.any((o) => o.orderable);
    final bg = ordered
        ? tone.tint
        : open
        ? k.p.change.bg
        : k.p.inset;
    final fg = ordered
        ? tone.label
        : open
        ? k.p.change.ink
        : k.p.faint;
    return Semantics(
      label: formatDate(t, 'EEEE', day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Sp.xs + Sp.xxs),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Rad.buttonSmall),
        ),
        child: Column(
          children: [
            Text(
              formatDate(t, 'EE', day).replaceAll('.', ''),
              style: k.planMeta(k.p.muted),
            ),
            Icon(
              ordered
                  ? Icons.check
                  : open
                  ? Icons.priority_high
                  : Icons.remove,
              size: Sz.icon,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.external = false,
    this.valueColor,
  });

  final Color? valueColor;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.s + Sp.xxs),
        child: Row(
          children: [
            Icon(icon, size: Sz.icon, color: k.p.muted),
            const SizedBox(width: Sp.m),
            Text(label, style: k.planMeta(k.p.muted)),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: valueColor == null
                    ? k.hintSlot
                    : k.hintSlot.copyWith(color: valueColor),
              ),
            ),
            const SizedBox(width: Sp.xs),
            Icon(
              external ? Icons.open_in_new : Icons.chevron_right,
              size: Sz.icon,
              color: k.p.muted,
            ),
          ],
        ),
      ),
    );
  }
}
