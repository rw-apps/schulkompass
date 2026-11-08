import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:lanis/fork_identity.dart';

import '../../l10n/l10n.dart';
import '../kit.dart';

/// „App weitergeben“ (Wunsch 08.11.26): QR-Code und Link zur neuesten APK,
/// dazu Teilen mit Kurzanleitung. Ursache: Bisher ging das nur über die
/// Release-Seite im Browser; wer die App weitergeben wollte, musste den
/// Link selbst heraussuchen und erklären, welche Datei die richtige ist.
///
/// Der Link ([forkApkUrl]) zeigt auf die feste Kopie `schulkompass.apk`,
/// die der Release-Ablauf jedem Release beilegt (release-fork.yml, ab
/// 9503). Grenze: nur Android mit 64-Bit-System (arm64-v8a). Sehr alte
/// Geräte und manche günstige Handys mit Android Go laufen mit 32 Bit; dort
/// meldet Android „App nicht installiert“ – die Anleitung ([shareAppSteps])
/// verweist dann auf die armeabi-v7a-Datei der Release-Seite.
///
/// QR mit Fehlerkorrektur M (device_transfer_page.dart nutzt L für dichte
/// Daten): Die Adresse ist kurz, M bleibt bei abgegriffenem Display
/// lesbar.
class ShareAppPage extends StatelessWidget {
  const ShareAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final screen = MediaQuery.sizeOf(context);
    final size = (screen.width - 2 * Sp.page - 2 * Sp.l).clamp(180.0, 280.0);
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(t.shareAppTitle, style: k.section),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Sp.page, Sp.s, Sp.page, bottom + Sp.xl),
        children: [
          Text(t.shareAppIntro, style: k.meta),
          const SizedBox(height: Sp.l),
          Center(
            child: Container(
              padding: const EdgeInsets.all(Sp.l),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Rad.box),
              ),
              child: QrImageView(
                data: forkApkUrl,
                size: size,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: Sp.m),
          SelectableText(
            forkApkUrl,
            textAlign: TextAlign.center,
            style: k.meta,
          ),
          const SizedBox(height: Sp.l),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: t.shareAppMessage(forkAppName, forkApkUrl, forkRepoUrl),
                subject: forkAppName,
              ),
            ),
            icon: const Icon(Icons.share_outlined),
            label: Text(t.shareAppAction),
          ),
          const SizedBox(height: Sp.l),
          Text(t.shareAppSteps(forkRepoUrl), style: k.meta),
        ],
      ),
    );
  }
}
