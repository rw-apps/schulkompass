import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../error_log.dart';
import '../l10n/l10n.dart';
import '../settings_transfer.dart';
import '../ui/kit.dart';
import 'onboarding_kit.dart';

/// „Mit Sicherungsdatei einrichten“ (Entwurf 04.11.26, abgenommen): Nach
/// einer Neuinstallation – etwa beim Wechsel auf den neuen Signierschlüssel
/// in 9473 – liegt oft nur die Datei aus „Nur Eingaben per Datei“ vor.
///
/// Ursache: Diese Datei ließ sich erst NACH der Anmeldung übernehmen, weil
/// applyTransferValues (settings_transfer.dart) über Schulnummer und
/// Benutzername zuordnet. Die Einrichtung musste also jedes Konto von Hand
/// neu suchen und eintippen und danach die Datei ein zweites Mal öffnen.
/// Jetzt liest die Anmeldung (auth.dart, LoginForm.restore) die Konten aus
/// der Datei, fragt nur das Passwort und übernimmt die Eingaben gleich nach
/// jeder Anmeldung.
///
/// Grenze: Passwörter stehen bewusst NICHT in der Datei – sie wird per Mail
/// oder Messenger verschickt. Wer auch die Passwörter mitnehmen will, nutzt
/// die verschlüsselte QR-Übertragung zwischen zwei Geräten
/// (device_transfer_page.dart).

/// Datei wählen und lesen. null bei Abbruch oder unbrauchbarer Datei; die
/// Meldung zeigt diese Funktion selbst (Snackbar), damit Willkommen und
/// Anmeldung gleich reagieren.
Future<TransferBackup?> pickBackup(BuildContext context) async {
  final t = context.t;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void snack(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  String text;
  try {
    final files = await FilePicker.pickFiles(type: FileType.any);
    final path = files.firstOrNull?.path;
    if (path == null) return null;
    text = await File(path).readAsString();
  } catch (e, st) {
    ErrorLog.instance.record('fork/sicherung-lesen', e, st);
    snack(t.transferFailed);
    return null;
  }
  final b = parseBackup(text);
  if (b == null) {
    snack(t.transferNotOurs);
    return null;
  }
  if (b.accounts.isEmpty) {
    snack(t.restoreEmpty);
    return null;
  }
  return b;
}

enum RestoreStep { pending, done, skipped }

/// Ein Konto der Sicherung: Schule und Benutzername fest, beim aktiven Konto
/// das Passwortfeld (vom Formular übergeben, damit Autofill und Prüfung wie
/// bei der normalen Anmeldung laufen).
class RestoreAccountCard extends StatelessWidget {
  const RestoreAccountCard({
    super.key,
    required this.school,
    required this.username,
    required this.step,
    this.password,
  });

  final String school;
  final String username;
  final RestoreStep step;

  /// Nur beim gerade anzumeldenden Konto gesetzt.
  final Widget? password;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final active = password != null;
    final done = step == RestoreStep.done;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.m),
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        color: k.p.card,
        borderRadius: BorderRadius.circular(Rad.box),
        border: Border.all(color: active ? k.p.ink : k.p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.account_balance_outlined,
                size: Sz.navIcon,
                color: done ? k.p.ink : k.p.muted,
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school, style: k.cardName),
                    Text(username, style: k.cardMeta),
                  ],
                ),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: Sp.m),
            password!,
          ] else ...[
            const SizedBox(height: Sp.s),
            Text(switch (step) {
              RestoreStep.done => t.restoreDone,
              RestoreStep.skipped => t.restoreSkipped,
              RestoreStep.pending => t.restoreNext,
            }, style: k.planMeta(done ? k.p.ink : k.p.muted)),
          ],
        ],
      ),
    );
  }
}

/// „ODER“ zwischen Formular und den beiden Übernahme-Wegen.
class OnbOrDivider extends StatelessWidget {
  const OnbOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: k.p.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.m),
          child: Text(OnbPage.upper(context.t.loginOr), style: k.dateCaps),
        ),
        Expanded(child: Divider(color: k.p.line)),
      ],
    );
  }
}
