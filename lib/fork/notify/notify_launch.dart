/// Tipp auf eine Benachrichtigung öffnet die passende Seite (Wunsch
/// 06.11.26: „neue Klassenarbeit eingetragen“ führte immer nach Heute).
///
/// Ursache: Keine Benachrichtigung trug ein Ziel (BackgroundTaskToolkit.
/// sendMessage, summary.dart ohne `payload`), und die App hörte nicht auf
/// Tipps – Android startete sie einfach auf der Startseite. Jetzt trägt jede
/// Meldung dieselbe Adresse wie ein Tipp im Startbildschirm-Widget
/// (`schulportal-widget://open?account=<id>&target=<ziel>`,
/// widget_launch.dart), und WidgetLaunchHandler führt beide gleich aus.
///
/// Grenze: Nur Android (wie das Widget). Eine Meldung, die vor diesem Stand
/// verschickt wurde, hat kein Ziel und öffnet weiter Heute.
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../widget/launch_target.dart';

/// Adresse für das Feld `payload` einer Benachrichtigung. [account]:
/// localId des Kontos (FamilyMember.accountId); null = keins wählen (die
/// Sammelmeldung nennt mehrere Kinder).
String notifyPayload(WidgetTarget target, {int? account}) => Uri(
  scheme: widgetLaunchScheme,
  host: 'open',
  queryParameters: {'account': ?account?.toString(), 'target': target.name},
).toString();

final _taps = StreamController<String?>.broadcast();

/// Tipps bei laufender App (onDidReceiveNotificationResponse).
Stream<String?> get notificationTaps => _taps.stream;

/// Für FlutterLocalNotificationsPlugin.initialize. Bewusst eine Funktion auf
/// oberster Ebene und in JEDEM initialize: Der Hintergrundlauf in der
/// offenen App (callbackDispatcher, inApp) ruft initializeNotifications
/// erneut auf – ohne diesen Rückruf hätte er den der App überschrieben.
@pragma('vm:entry-point')
void onNotificationTap(NotificationResponse r) => _taps.add(r.payload);

bool _launchTaken = false;

/// Ziel der Benachrichtigung, mit der die App gestartet wurde – genau
/// einmal je Isolat. Ursache: getNotificationAppLaunchDetails liest den
/// Intent der Activity, und das Plugin setzt ihn nach einem Tipp bei
/// laufender App neu (FlutterLocalNotificationsPlugin.java, onNewIntent →
/// setIntent). Ein neu aufgebauter Rahmen (main.dart `_relaunch`) meldete
/// den Tipp sonst erneut.
Future<String?> takeNotificationLaunch() async {
  if (_launchTaken) return null;
  _launchTaken = true;
  try {
    final d = await FlutterLocalNotificationsPlugin()
        .getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return d.notificationResponse?.payload;
  } catch (_) {
    return null;
  }
}
