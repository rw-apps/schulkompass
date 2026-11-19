import 'dart:ffi' show Abi;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:lanis/fork_identity.dart' show forkApkUrl, forkLatestReleaseUrl;
import 'package:lanis/utils/safe_launch.dart';

import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../update_check.dart';
import 'hint_card.dart';

/// Karte „Neue Version verfügbar“ oben auf Heute (update_check.dart,
/// Entwurf 19.11.26). Abruf und Demo-Sperre liegen bei LiveTodayPage.
///
/// „Aktualisieren“ öffnet den festen Direktlink zur APK (forkApkUrl,
/// Release-Workflow) im Browser; Android fragt dann einmalig, ob der
/// Browser Apps installieren darf. Grenze: Der Direktlink ist die
/// arm64-APK. Auf 32-Bit-Systemen (Abi.androidArm, z. B. Android-Go-Handys)
/// ließe Android sie nicht installieren – dort öffnet die Karte die
/// Release-Seite und sagt, welche Datei (Prüfbefund 19.11.26). Die App
/// installiert nicht selbst (keine Installationsberechtigung).
/// „Später“ blendet sie 7 Tage aus (UpdateCheck.dismiss).
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, this.installed, this.arm32});

  /// Installierte Version („4.1.0+9517“); Standard: ErrorLog.version.
  final String? installed;

  /// 32-Bit-Gerät; Standard: Abi.current() (für Tests setzbar).
  final bool? arm32;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UpdateCheck.instance,
      builder: (context, _) {
        final mine = installed ?? ErrorLog.instance.version;
        final build = UpdateCheck.instance.offer(mine);
        if (build == null) return const SizedBox.shrink();
        final t = context.t;
        final v7 = arm32 ?? Abi.current() == Abi.androidArm;
        final now = '${installedBuild(mine)}';
        return HintCard(
          icon: Icons.system_update_outlined,
          title: t.updateTitle,
          text: v7
              ? t.updateText32('$build', now)
              : t.updateText('$build', now),
          action: t.updateAction,
          onAction: () => safeLaunchUrl(
            Uri.parse(v7 ? forkLatestReleaseUrl : forkApkUrl),
            context: context,
            mode: LaunchMode.externalApplication,
          ),
          secondary: t.updateLater,
          onSecondary: UpdateCheck.instance.dismiss,
        );
      },
    );
  }
}
