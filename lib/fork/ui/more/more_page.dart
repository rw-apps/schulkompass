import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';
import '../pinned_page.dart';

/// Ein Eintrag unter „Mehr“: Dienste und Aktionen, die keinen eigenen
/// Bereich brauchen (Konzept 17.10.26).
class MoreEntry {
  const MoreEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
}

/// Bereich „Mehr“: Dienste und Aktionen; Einstellungen als eigener Eintrag.
class MorePage extends StatelessWidget {
  const MorePage({super.key, this.entries = const []});

  final List<MoreEntry> entries;

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
        onTap: entry.onTap,
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
                      Text(entry.detail!, style: k.planMeta(k.p.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: Sz.icon, color: k.p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
