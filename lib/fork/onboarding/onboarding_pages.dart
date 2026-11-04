import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../class_choice.dart' show classLabel;
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/background_service.dart' show refreshBackgroundService;

import '../l10n/l10n.dart';
import '../ui/kit.dart';
import 'onboarding_kit.dart';

/// 1 – Willkommen (ersetzt die sechs Einführungsseiten der Vorlage).
///
/// Ursache: Jene nannten den Namen der Vorlage und „von Schülern entwickelt“
/// – beides trifft auf diese App nicht zu, und sechs Seiten bis zur Anmeldung
/// sind zu viel. Jetzt eine Seite: was die App kann, dann „Anmelden“.
class ForkWelcomePage extends StatelessWidget {
  const ForkWelcomePage({
    super.key,
    required this.onLogin,
    this.onTransfer,
    this.onFile,
    this.onDemo,
  });

  final VoidCallback onLogin;

  /// „Demo ansehen“ (fork/demo/demo_entry.dart).
  final VoidCallback? onDemo;

  /// „Von anderem Gerät übernehmen“ (device_transfer.dart).
  final VoidCallback? onTransfer;

  /// „Mit Sicherungsdatei einrichten“ (restore_backup.dart).
  final VoidCallback? onFile;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return PopScope(
      canPop: false,
      // Alles auf einer Seite (Entwurf B, 04.11.26 abgenommen). Ursache:
      // Auf dem Pixel mit großer Schrift lagen „Schon einmal eingerichtet?“
      // und die Übernahme-Wege unter dem Bildschirmrand – genau die Wege,
      // die man nach einer Neuinstallation sucht. Deshalb Symbol und Name
      // in einer Zeile, Funktionen als knappe Liste, beide Wege nebeneinander.
      // Grenze: Bei noch größerer Schrift scrollt OnbPage weiterhin.
      child: OnbPage(
        top: [
          const SizedBox(height: Sp.m),
          Row(
            children: [
              // App-Symbol (Kompass, seit 9471) statt des Doktorhuts der
              // Vorlage; dieselbe Datei wie das Startlogo (startup.dart).
              SvgPicture.asset(
                'assets/startup.svg',
                width: Sz.button,
                height: Sz.button,
              ),
              const SizedBox(width: Sp.m),
              Expanded(child: Text(t.onbAppName, style: k.pageTitle)),
            ],
          ),
          const SizedBox(height: Sp.l),
          Text(t.onbIntro, style: k.body),
          // Hinweis „inoffiziell, ohne Gewähr“ gleich am Anfang (Prüfung auf
          // Massentauglichkeit 03.11.26): Wer sich auf eine Meldung verlässt,
          // soll wissen, dass verbindlich das Schulportal ist.
          const SizedBox(height: Sp.s),
          Text(t.onbDisclaimer, style: k.meta),
          const SizedBox(height: Sp.l),
          _Feature(Icons.wb_sunny_outlined, t.navToday, t.onbToday),
          _Feature(Icons.calendar_month_outlined, t.navCalendar, t.onbCalendar),
          _Feature(Icons.menu_book_outlined, t.navCourses, t.onbCourses),
          _Feature(Icons.chat_bubble_outline, t.navMessages, t.onbMessages),
        ],
        bottom: [
          OnbButton(label: t.onbLogin, onPressed: onLogin),
          if (onTransfer != null || onFile != null) ...[
            const SizedBox(height: Sp.m),
            Text(
              OnbPage.upper(t.setupAlready),
              style: k.dateCaps,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.s),
            Row(
              children: [
                if (onFile != null)
                  Expanded(
                    child: _WayTile(
                      icon: Icons.upload_file,
                      label: t.setupFileTile,
                      semantics: t.setupWithFile,
                      onTap: onFile!,
                    ),
                  ),
                if (onFile != null && onTransfer != null)
                  const SizedBox(width: Sp.s),
                if (onTransfer != null)
                  Expanded(
                    child: _WayTile(
                      icon: Icons.qr_code_2,
                      label: t.setupDeviceTile,
                      semantics: t.devFromOther,
                      onTap: onTransfer!,
                    ),
                  ),
              ],
            ),
          ],
          if (onDemo != null)
            TextButton(
              onPressed: onDemo,
              child: Text(t.demoTitle, style: k.link),
            ),
        ],
      ),
    );
  }
}

/// Eine Zeile der Funktionsliste auf der Willkommensseite: Symbol, Name,
/// kurzer Zusatz (einzeilig, wird bei Platzmangel gekürzt).
class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Row(
        children: [
          Icon(icon, size: Sz.icon, color: k.p.muted),
          const SizedBox(width: Sp.m),
          Text(title, style: k.planSubject(k.p.ink)),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Text(
              text,
              style: k.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kachel für einen Übernahme-Weg (Symbol über zweizeiliger Aufschrift);
/// [semantics] ist der volle Name für Bildschirmleser.
class _WayTile extends StatelessWidget {
  const _WayTile({
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: k.p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.button),
          side: BorderSide(color: k.p.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.button),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: Sp.m,
              horizontal: Sp.s,
            ),
            child: Column(
              children: [
                Icon(icon, size: Sz.navIcon, color: k.p.ink),
                const SizedBox(height: Sp.xs),
                Text(
                  label,
                  style: k.button(k.p.ink),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3 – Konto eingerichtet: bisherige Konten und „Weiteres Konto
/// hinzufügen“ (ersetzt das Dialogfenster). Gibt true zurück = weiteres.
class AccountAddedPage extends StatefulWidget {
  const AccountAddedPage({
    super.key,
    required this.accounts,
    this.classes = const [],
    this.onEditClass,
  });

  /// „Schule · Benutzer“ je eingerichtetem Konto.
  final List<String> accounts;

  /// Klasse je Konto (Entwurf 20.10.26 k3): (Klasse, erkannt?); null = ohne
  /// Zeile (Lehrkraft). Leer = keine Zeilen (z. B. ältere Aufrufer).
  final List<({String value, bool detected})?> classes;

  /// Klasse ändern; liefert den neuen Stand oder null (abgebrochen).
  final Future<({String value, bool detected})?> Function(int index)?
  onEditClass;

  @override
  State<AccountAddedPage> createState() => _AccountAddedPageState();
}

class _AccountAddedPageState extends State<AccountAddedPage> {
  late final _classes = List.of(widget.classes);

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;
    final k = Kit.of(context);
    final t = context.t;
    Widget classLine(int i) {
      final c = i < _classes.length ? _classes[i] : null;
      if (c == null) return const SizedBox.shrink();
      final known = c.value.isNotEmpty;
      final text = !known
          ? t.classUnknown
          : '${t.classLine(classLabel(c.value))} · '
                '${c.detected ? t.classDetectedShort : t.classManualShort}';
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Sp.s,
        children: [
          Text(text, style: k.planMeta(known ? k.p.muted : k.p.change.ink)),
          if (widget.onEditClass != null)
            InkWell(
              onTap: () async {
                final r = await widget.onEditClass!(i);
                if (r != null && mounted) setState(() => _classes[i] = r);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                child: Text(
                  known ? t.changeAction : t.classEnter,
                  style: k.link,
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      child: OnbPage(
        step: t.onbStep(1, 2),
        top: [
          const SizedBox(height: Sp.l),
          Text(
            accounts.length == 1 ? t.onbAccountReady : t.onbAccountsReady,
            style: k.pageTitle,
          ),
          const SizedBox(height: Sp.l),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.s,
            ),
            decoration: BoxDecoration(
              color: k.p.card,
              borderRadius: BorderRadius.circular(Rad.box),
              boxShadow: k.cardShadow,
            ),
            child: Column(
              children: [
                for (final (i, a) in accounts.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.s),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: k.kid(i).accent,
                          size: Sz.navIcon,
                        ),
                        const SizedBox(width: Sp.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a, style: k.body),
                              classLine(i),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_classes.any((c) => c != null)) ...[
            const SizedBox(height: Sp.m),
            Text(t.classOnbHint, style: k.meta),
          ],
          const SizedBox(height: Sp.xl),
          Container(
            padding: const EdgeInsets.all(Sp.l),
            decoration: BoxDecoration(
              color: k.p.inset,
              borderRadius: BorderRadius.circular(Rad.panel),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.family_restroom, color: k.p.ink),
                const SizedBox(width: Sp.m),
                Expanded(child: Text(t.onbAnotherHint, style: k.body)),
              ],
            ),
          ),
        ],
        bottom: [
          OnbButton(
            label: t.addAnotherAccount,
            icon: Icons.add,
            strong: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Sp.m),
          OnbButton(
            label: t.onbContinue,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// 4 – Benachrichtigungen: erst erklären, dann fragen.
///
/// Ursache: Bisher kam die Frage von Android gleich beim ersten Start
/// (StartupScreen.requestPermissions), bevor man wusste, wofür. Grenze: Sagt
/// man hier „Später“, fragt die App nicht von selbst wieder; einschalten geht
/// in den Einstellungen unter „Benachrichtigungen“.
/// true, sobald die Einrichtung per QR-Code (device_transfer_page.dart)
/// selbst nach Benachrichtigungen gefragt hat. Ursache: Ihr Weg nach dem
/// Anmelden führt über StartupScreen, der sonst ein zweites Mal – ohne
/// Erklärung – fragte. Grenze: gilt nur bis zum Neustart der App.
bool notifyAskedDuringSetup = false;

class NotifyIntroPage extends StatelessWidget {
  const NotifyIntroPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    return PopScope(
      canPop: false,
      child: OnbPage(
        step: t.onbStep(2, 2),
        top: [
          const SizedBox(height: Sp.l),
          Text(t.onbNotifyTitle, style: k.pageTitle),
          const SizedBox(height: Sp.s),
          Text(t.onbNotifyIntro, style: k.meta),
          const SizedBox(height: Sp.xl),
          OnbFeature(
            icon: Icons.event_busy,
            title: t.onbNotifyChanges,
            text: t.onbNotifyChangesText,
            bg: k.p.cancel.bg,
            ink: k.p.cancel.ink,
          ),
          OnbFeature(
            icon: Icons.grading_outlined,
            title: t.onbNotifyGrades,
            text: t.onbNotifyGradesText,
            bg: k.plainTone.bg,
            ink: k.plainTone.ink,
          ),
          OnbFeature(
            icon: Icons.campaign_outlined,
            title: t.onbNotifyEvents,
            text: t.onbNotifyEventsText,
            bg: k.p.change.bg,
            ink: k.p.change.ink,
          ),
        ],
        bottom: [
          Text(t.onbNotifyLater, style: k.meta, textAlign: TextAlign.center),
          const SizedBox(height: Sp.l),
          OnbButton(
            label: t.onbNotifyAllow,
            icon: Icons.notifications_active_outlined,
            onPressed: () async {
              final status = await Permission.notification.request();
              // Fork: Hintergrundabfrage gleich einrichten, nicht erst beim
              // nächsten Start (setupBackgroundService, Prüfung 27.10.26).
              if (status.isGranted) unawaited(refreshBackgroundService());
              onDone();
            },
          ),
          const SizedBox(height: Sp.s),
          Center(
            child: TextButton(
              onPressed: onDone,
              child: Text(t.later, style: k.link),
            ),
          ),
        ],
      ),
    );
  }
}
