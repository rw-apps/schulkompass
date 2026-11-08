import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../../demo/demo_mode.dart' show demoActive;
import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../report_relay.dart';
import '../../report_terms.dart';
import 'hint_card.dart';

String reportOs() {
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    return '';
  }
}

/// Soll Heute fragen, ob Fehler automatisch gemeldet werden dürfen? Nur
/// mit eingerichtetem Dienst, noch nicht entschieden und erst, wenn es
/// etwas zu melden gibt. Ursache (Entwurf 26.10.26): Eine Frage ohne
/// Anlass wirkt wie Werbung; mit einem erkannten Fehler ist sie verständlich.
///
/// Nicht in der Demo. Ursache (Bildschirmfoto 30.10.26): Die Frage
/// erschien in der Schüler-Demo, weil das Fehlerprotokoll der echten App
/// Einträge hatte – in einer erfundenen Schule wirkt sie fehl am Platz.
///
/// Erweiterte Zustimmung (Wunsch 08.11.26, report_terms.dart): Wer bis 9501
/// zugestimmt hat, wird EINMAL neu gefragt, sobald es etwas zu melden gibt
/// (Fehler oder unbekannter Begriff). „Nicht jetzt“ behält die alte
/// Zustimmung (nur Fehlerprotokoll) und fragt nicht wieder
/// (autoReportAskedTermsKey). Ursache: Der Datenschutzhinweis versprach
/// „keine Portal-Inhalte“; Begriffe brauchen eine eigene Zustimmung.
bool autoReportPromptDue(
  TypedSettings settings, {
  ErrorLog? log,
  TermLog? terms,
}) {
  if (demoActive || !relayConfigured) return false;
  final hasErrors = (log ?? ErrorLog.instance).records.isNotEmpty;
  final hasTerms = (terms ?? TermLog.instance).entries.isNotEmpty;
  final v = settings.getBool(autoReportKey);
  if (v == null) return hasErrors || hasTerms;
  return v &&
      !autoReportTermsAllowed(settings) &&
      settings.getBool(autoReportAskedTermsKey) != true &&
      (hasErrors || hasTerms);
}

/// Karte „Fehler automatisch melden?“ mit „Erlauben“ und „Nicht jetzt“
/// (abgenommen 26.10.26). Beides wird gespeichert; ändern lässt es sich
/// unter Über die App → Fehlersuche.
class AutoReportPrompt extends ConsumerStatefulWidget {
  const AutoReportPrompt({super.key});

  @override
  ConsumerState<AutoReportPrompt> createState() => _AutoReportPromptState();
}

class _AutoReportPromptState extends ConsumerState<AutoReportPrompt> {
  bool _done = false;

  void _decide(bool allow) {
    final s = ref.read(sharedOverAccountSettingsProvider);
    if (!allow && s.getBool(autoReportKey) == true) {
      // Erweiterung abgelehnt: alte Zustimmung bleibt, nicht wieder fragen.
      s.setBool(autoReportAskedTermsKey, true);
    } else {
      setAutoReport(s, allow);
    }
    setState(() => _done = true);
    if (allow) flushErrorReports(s, os: reportOs());
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final t = context.t;
    return HintCard(
      icon: Icons.outgoing_mail,
      // Alte Zustimmung (nur Fehlerprotokoll): Erweiterung erfragen.
      title:
          ref.read(sharedOverAccountSettingsProvider).getBool(autoReportKey) ==
              true
          ? t.autoReportMoreTitle
          : t.autoReportTitle,
      text: t.autoReportText,
      action: t.autoReportAllow,
      onAction: () => _decide(true),
      // „Nicht jetzt“ in der Karte (HintCard.secondary, Rückmeldung
      // 08.11.26) statt als Knopf darunter.
      secondary: t.autoReportLater,
      onSecondary: () => _decide(false),
    );
  }
}
