import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/fork_identity.dart' show forkAppName;
import 'package:lanis/utils/privacy_policy.dart';

import '../l10n/l10n.dart';
import '../ui/language.dart' show languageKey;

/// Einmal je neuem Datenschutzhinweis daran erinnern, die App zu öffnen.
///
/// Ursache (Prüfbefund 19.11.26): Mit neuem privacyPolicyPublishedAt bricht
/// der Hintergrundlauf ab (shouldRunBackgroundFetch), bis der Nutzer in der
/// App zustimmt. Wer aktualisiert, ohne die App zu öffnen (Obtainium im
/// Hintergrund, Browser), bekäme sonst still keine Meldungen zu Vertretungen
/// und Nachrichten mehr. Grenze: Nur eine Erinnerung je Fassung
/// ([_sentKey]), ohne Inhalte; ohne Konten keine.
Future<void> remindPrivacyConsent(
  TypedSettings shared, {
  required bool hasAccounts,
  required String channelId,
}) async {
  if (!hasAccounts || isPrivacyPolicyAccepted(shared)) return;
  if (shared.getString(_sentKey) == privacyPolicyPublishedAt) return;
  // Merker vor der Anzeige: Scheitert show() (keine Berechtigung), wird
  // trotzdem nicht bei jedem Lauf erneut versucht – lieber eine fehlende
  // als eine wiederholte Erinnerung.
  shared.setString(_sentKey, privacyPolicyPublishedAt);
  final t = forkL10nFor(
    resolveLanguage(
      shared.getString(languageKey),
      PlatformDispatcher.instance.locale.languageCode,
    ),
  );
  try {
    await FlutterLocalNotificationsPlugin().show(
      id: _id,
      title: forkAppName,
      body: t.consentReminder,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          forkAppName,
          channelDescription: 'Applet notifications',
          // Wie sendMessage: Legt diese Meldung den Kanal als erste an,
          // bliebe er sonst dauerhaft auf Standard (kein Aufpoppen mehr).
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(t.consentReminder),
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  } catch (_) {}
}

const _sentKey = 'fork-privacy-reminder-sent';

/// Erinnerung entfernen, sobald zugestimmt ist (Heute erreichbar,
/// live_today_page.dart).
Future<void> clearPrivacyReminder() async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(id: _id);
  } catch (_) {}
}

/// Feste Nummer außerhalb der Konto-Bereiche (BackgroundTaskToolkit._seedId
/// beginnt bei Konto 1 mit 1 000 000).
const _id = 999001;
