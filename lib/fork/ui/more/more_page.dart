import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../nav.dart' show pushInTab;
import '../kid_chips.dart' show BackInChips;
import '../pinned_page.dart';

/// Ein Eintrag unter „Mehr“: Dienste und Aktionen, die keinen eigenen
/// Bereich brauchen (Konzept 17.10.26).
class MoreEntry {
  const MoreEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.external = false,
    this.open,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  /// Fremdes Angebot (Weiterleitung des Portals): Symbol „öffnet extern“
  /// statt des Pfeils.
  final bool external;

  /// Öffnen mit dem Kontext der Zeile (statt [onTap]). Ursache (Prüfbefund
  /// 14.11.26): Auf der Rubrik-Unterseite hing [onTap] am Kontext von
  /// „Mehr“, den FamilySwitch beim Kindwechsel neu aufbaut – der Tipp lief
  /// dann ins Leere. Der Kontext der Zeile liegt im Rahmen des Kindes
  /// (pushInTab), pushInTab von dort bindet die nächste Seite an dasselbe.
  final void Function(BuildContext context)? open;
}

/// Rubrik der Angebote der Schule (Ordner des Portals, school_apps.dart).
class MoreSection {
  const MoreSection(this.title, this.icon, this.entries);

  final String title;
  final IconData icon;
  final List<MoreEntry> entries;
}

/// Bereich „Mehr“: Dienste und Aktionen; Einstellungen als eigener Eintrag.
class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.entries = const [],
    this.sections = const [],
  });

  final List<MoreEntry> entries;

  /// Angebote der Schule je Rubrik: eine Zeile je Rubrik, die Angebote auf
  /// einer Unterseite. Ursache (Rückmeldung 14.11.26 zum Entwurf als Liste
  /// und als Kacheln: „möglichst wenig scrollen“, „Unterseite je Rubrik“):
  /// Alle Angebote untereinander füllten fast drei Bildschirme.
  final List<MoreSection> sections;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    // Überschrift fest (PinnedPage).
    return PinnedPage(
      header: [Text(context.t.navMore, style: k.pageTitle)],
      bodyPadding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.xl),
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.s),
            child: _EntryTile(entry: e),
          ),
        if (sections.any((s) => s.entries.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.l, Sp.xs, Sp.s),
            child: Text(context.t.schoolOffers, style: k.section),
          ),
        for (final sec in sections)
          if (sec.entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _EntryTile(
                entry: MoreEntry(
                  icon: sec.icon,
                  label: sec.title,
                  // Vorschau der Namen, damit man ohne Öffnen sieht, wo ein
                  // Angebot steckt.
                  detail: sec.entries.map((e) => e.label).join(', '),
                  // Über pushInTab mit Kind-Pillen: Die Rubrik gehört einem
                  // Kind (Angebote seiner Schule) und zeigt, welchem; ein
                  // anderes Kind führt zurück zu „Mehr“ (SubpageKidChips).
                  // Ursache (Nachprüfung 14.11.26): Mit einfachem push fehlte
                  // jede Kindbindung.
                  onTap: () => pushInTab<void>(
                    context,
                    (_) => MoreSectionPage(section: sec),
                    kidChips: true,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final MoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Material(
      color: k.p.card,
      borderRadius: BorderRadius.circular(Rad.signal),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.signal),
        onTap: entry.open == null ? entry.onTap : () => entry.open!(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.m),
          child: Row(
            children: [
              Icon(entry.icon, size: Sz.navIcon, color: k.p.ink),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label, style: k.planSubject(k.p.ink)),
                    if (entry.detail != null)
                      Text(
                        entry.detail!,
                        style: k.planMeta(k.p.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                entry.external ? Icons.open_in_new : Icons.chevron_right,
                size: Sz.icon,
                color: k.p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unterseite einer Rubrik: die Angebote der Schule als Liste. Fremde
/// Angebote (Weiterleitung des Portals) zeigen statt des Pfeils das Symbol
/// „öffnet extern“.
class MoreSectionPage extends StatelessWidget {
  const MoreSectionPage({super.key, required this.section});

  final MoreSection section;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Scaffold(
      backgroundColor: k.p.bg,
      body: PinnedPage(
        // Mit Kind-Pillen steht Zurück dort (BackInChips).
        leading: BackInChips.of(context)
            ? null
            : IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back, color: k.p.ink),
                tooltip: context.t.back,
              ),
        header: [Text(section.title, style: k.pageTitle)],
        bodyPadding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.xl),
        children: [
          for (final e in section.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _EntryTile(entry: e),
            ),
        ],
      ),
    );
  }
}
