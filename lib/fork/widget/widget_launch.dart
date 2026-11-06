/// Klick-Ziele des Startbildschirm-Widgets (Entwurf 10, Vorschlag 6,
/// Abnahme 30.10.26): Name → Heute dieses Kindes, Arbeit → „Arbeiten &
/// Noten“, Aufgaben → Unterricht, Essen → Bestellung.
///
/// Ursache: Bisher öffnete jeder Tipp nur die App; wer die Arbeit sah, musste
/// Kind und Seite selbst suchen. Kotlin (SchoolWidget.kt) hängt je Element
/// eine Adresse `schulportal-widget://open?account=<id>&target=<ziel>` an
/// (home_widget: HomeWidgetLaunchIntent), die hier ankommt – beim Start
/// über [HomeWidget.initiallyLaunchedFromHomeWidget], bei laufender App über
/// [HomeWidget.widgetClicked].
///
/// Dieselbe Adresse tragen die Benachrichtigungen (notify_launch.dart,
/// Wunsch 06.11.26); der Handler führt beide gleich aus.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../demo/demo_mode.dart' show demoActive;
import '../notify/notify_launch.dart'
    show notificationTaps, takeNotificationLaunch;
import '../ui/live/family.dart';
import 'launch_target.dart';

export 'launch_target.dart';

/// Ein Tipp im Widget oder auf eine Benachrichtigung: Kind (localId, null =
/// keines) und Ziel.
class WidgetLaunch {
  const WidgetLaunch({required this.target, this.account});

  final int? account;
  final WidgetTarget target;

  /// Adresse lesen (Kotlin bzw. notify_launch.dart); null, wenn sie nicht
  /// von dort stammt.
  /// Unbekanntes Ziel → Heute (ältere/neuere Widget-Stände bleiben
  /// bedienbar).
  static WidgetLaunch? parse(Uri? u) {
    if (u == null || u.scheme != widgetLaunchScheme) return null;
    final target =
        WidgetTarget.values
            .where((t) => t.name == u.queryParameters['target'])
            .firstOrNull ??
        WidgetTarget.today;
    return WidgetLaunch(
      target: target,
      account: int.tryParse(u.queryParameters['account'] ?? ''),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetLaunch &&
      other.account == account &&
      other.target == target;

  @override
  int get hashCode => Object.hash(account, target);

  @override
  String toString() => 'WidgetLaunch($account, ${target.name})';
}

/// Hört auf Tipps im Widget und auf Benachrichtigungen und führt sie aus:
/// erst das Kind wählen
/// (FamilyData.onSelect – wie die Kind-Pillen), dann [onTarget] (Reiter
/// bzw. Seite öffnen, preview_shell.dart).
///
/// Liegt unter FamilyScope, damit es die Familie kennt. Grenze: Nicht in
/// der Demo (erfundene Kinder haben andere Konten) und nur auf Android.
class WidgetLaunchHandler extends StatefulWidget {
  const WidgetLaunchHandler({
    super.key,
    required this.onTarget,
    required this.child,
  });

  final void Function(BuildContext context, WidgetLaunch launch) onTarget;
  final Widget child;

  @override
  State<WidgetLaunchHandler> createState() => _WidgetLaunchHandlerState();
}

class _WidgetLaunchHandlerState extends State<WidgetLaunchHandler> {
  StreamSubscription<Uri?>? _sub;
  StreamSubscription<String?>? _notifySub;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    if (demoActive) {
      // Verbrauchen, damit der Rahmen nach der Demo nicht zum alten Ziel
      // springt (Prüfung 06.11.26).
      takeNotificationLaunch();
      return;
    }
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(
        _handle,
        onError: (_) {},
      );
      _sub = HomeWidget.widgetClicked.listen(_handle, onError: (_) {});
    } catch (_) {
      // Ohne Plattform (Tests) gibt es keine Tipps.
    }
    // Benachrichtigungen (notify_launch.dart): Start durch einen Tipp und
    // Tipps bei laufender App.
    takeNotificationLaunch().then(_handlePayload, onError: (_) {});
    _notifySub = notificationTaps.listen(_handlePayload);
  }

  void _handlePayload(String? p) => _handle(p == null ? null : Uri.tryParse(p));

  /// Tipp, dessen Kind FamilyData noch nicht kennt, und seit wann.
  WidgetLaunch? _pending;
  DateTime? _pendingSince;
  Timer? _pendingTimer;

  /// Höchstens so lange auf das Kind warten; danach das Ziel ohne Wahl.
  static const _waitForKid = Duration(seconds: 20);

  void _handle(Uri? u) {
    final l = WidgetLaunch.parse(u);
    if (l == null) return;
    _pending = l;
    _pendingSince = DateTime.now();
    _pendingTimer?.cancel();
    _pendingTimer = Timer(_waitForKid, () {
      if (mounted) setState(() {});
    });
    _schedule();
  }

  /// Nach dem nächsten Bild ausführen, sobald das Kind in FamilyData steht.
  /// Ursache (Prüfung 06.11.26): Beim Kaltstart kennt FamilyData zuerst nur
  /// das aktive Konto; die übrigen laden nach eigener Anmeldung
  /// (family.dart, FamilyScope._start). Ein Tipp für ein weiteres Kind wählte
  /// es sonst nicht, und Seiten je Kind (Dateispeicher, „Arbeiten & Noten“)
  /// öffneten beim falschen bzw. gar nicht. build läuft bei jeder Änderung
  /// der Familie erneut (FamilyData.scopeOf hängt von ihr ab). Grenze: Nach
  /// [_waitForKid] (Anmeldung scheitert, Konto entfernt) öffnet das Ziel
  /// ohne Kindwahl.
  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l = _pending;
      if (!mounted || l == null) return;
      final family = FamilyData.scopeOf(context);
      final id = l.account;
      final known =
          id == null ||
          (family?.members.any((m) => m.accountId == id) ?? false);
      final waited = DateTime.now().difference(_pendingSince!) >= _waitForKid;
      if (!known && !waited) return;
      _pending = null;
      _pendingTimer?.cancel();
      if (id != null && known) family?.onSelect?.call(id);
      widget.onTarget(context, l);
    });
    // addPostFrameCallback plant selbst kein Bild ein.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notifySub?.cancel();
    _pendingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Abhängigkeit von der Familie: neu, sobald ein Konto nachlädt.
    FamilyData.scopeOf(context);
    if (_pending != null) _schedule();
    return widget.child;
  }
}
