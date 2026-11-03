import 'package:flutter/services.dart';

/// Ergebnis der Geräte-Anmeldung.
enum DeviceAuth { ok, cancelled, noLock }

/// Austauschbar für Tests.
Future<String?> Function(String title, String text) deviceAuthImpl =
    (title, text) => const MethodChannel(
      'schulportal/device_auth',
    ).invokeMethod<String>('confirm', {'title': title, 'text': text});

/// Fragt Geräte-PIN, Muster oder Biometrie ab (MainActivity, Kanal
/// `schulportal/device_auth`).
///
/// Ursache (Sicherheitsprüfung 03.11.26): Die Geräteübertragung gab alle
/// gespeicherten Passwörter ohne erneute Bestätigung heraus – wer das
/// entsperrte Handy kurz hatte, holte sich alle Zugänge. Grenze: Ohne
/// eingerichtete Displaysperre gibt es nichts abzufragen ([DeviceAuth.noLock]);
/// der Aufrufer entscheidet dann (die Übertragung warnt und fragt nach).
/// Fehlt der Kanal (Tests, andere Plattform), gilt das wie keine Sperre.
Future<DeviceAuth> confirmDevice(String title, String text) async {
  try {
    final r = await deviceAuthImpl(title, text);
    return switch (r) {
      'ok' => DeviceAuth.ok,
      'none' => DeviceAuth.noLock,
      _ => DeviceAuth.cancelled,
    };
  } on MissingPluginException {
    return DeviceAuth.noLock;
  } catch (_) {
    return DeviceAuth.cancelled;
  }
}
