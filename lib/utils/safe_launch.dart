import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../generated/l10n.dart';
import 'logger.dart';

typedef LaunchUrlFn = Future<bool> Function(Uri url, {LaunchMode mode});

Future<bool> _defaultLaunchUrl(
  Uri url, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(url, mode: mode);
}

/// Override in tests to throw or return `false` without plugins.
@visibleForTesting
LaunchUrlFn launchUrlImpl = _defaultLaunchUrl;

/// Schemata, die [safeLaunchUrl] öffnet.
const safeLaunchSchemes = {'http', 'https', 'mailto', 'tel'};

/// Opens [url] without throwing. Returns `false` if the OS cannot handle it.
Future<bool> safeLaunchUrl(
  Uri url, {
  BuildContext? context,
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  // Nur Web, E-Mail und Telefon (Sicherheitsprüfung 03.11.26): Links aus
  // Portal, Nachrichten oder Caterer-Seiten sollen keine `intent:`-,
  // `file:`- oder `javascript:`-Adressen auslösen können. Heute erreichbar war
  // das nicht (Text wird vor der Darstellung maskiert), das ist die
  // Absicherung dahinter. Grenze: Andere Schemata öffnen nicht, sondern
  // zeigen „Link ließ sich nicht öffnen“.
  if (!safeLaunchSchemes.contains(url.scheme.toLowerCase())) {
    logger.w('Blocked URL scheme: ${url.scheme}');
    _maybeShowSnackBar(context);
    return false;
  }
  try {
    final launched = await launchUrlImpl(url, mode: mode);
    if (launched) return true;
    logger.w('Could not open URL: $url');
    if (context != null && !context.mounted) return false;
    _maybeShowSnackBar(context);
    return false;
  } catch (e, s) {
    logger.w('Could not open URL: $url');
    logger.e(e, stackTrace: s);
    if (context != null && !context.mounted) return false;
    _maybeShowSnackBar(context);
    return false;
  }
}

void _maybeShowSnackBar(BuildContext? context) {
  if (context == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final message =
      AppLocalizations.maybeOf(context)?.couldNotOpenUrl ??
      'Could not open this link.';
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
