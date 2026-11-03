import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/mensa_login.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/notify/notify_task.dart' show courseScanOffset;
import 'package:lanis/fork/security/device_auth.dart';
import 'package:lanis/fork/settings_transfer.dart';
import 'package:lanis/fork/ui/live/live_data.dart'
    show mensaUrlSetting, mensaUrlsSetting;
import 'package:liblanis/liblanis.dart' show MemorySecretStore, TypedSettings;

// Härtung vor einem Pilot (Prüfungen 03.11.26).
void main() {
  TypedSettings mem() {
    final m = <String, String?>{};
    return TypedSettings(
      read: (k) => m[k],
      write: (k, v) => m[k] = v,
      delete: m.remove,
    );
  }

  test('Geräte-Anmeldung: Ergebnisse und fehlender Kanal', () async {
    final old = deviceAuthImpl;
    addTearDown(() => deviceAuthImpl = old);
    deviceAuthImpl = (_, _) async => 'ok';
    expect(await confirmDevice('t', 'x'), DeviceAuth.ok);
    deviceAuthImpl = (_, _) async => 'cancel';
    expect(await confirmDevice('t', 'x'), DeviceAuth.cancelled);
    deviceAuthImpl = (_, _) async => 'none';
    expect(await confirmDevice('t', 'x'), DeviceAuth.noLock);
    deviceAuthImpl = (_, _) async => throw MissingPluginException();
    expect(await confirmDevice('t', 'x'), DeviceAuth.noLock);
  });

  test(
    'Abgelehnter Caterer-Zugang wird nicht mehr selbst eingesetzt',
    () async {
      mensaSecrets = MemorySecretStore();
      const l = MensaLogin(host: 'essen.example', user: 'u', pass: 'p');
      await saveMensaLogin('1:', l);
      expect(await readMensaLogin('1:', auto: true), isNotNull);
      await markMensaLoginFailed('1:');
      expect(await mensaLoginFailed('1:'), isTrue);
      expect(await readMensaLogin('1:', auto: true), isNull);
      // Anzeige („gespeichert, abgelehnt“) sieht ihn weiter.
      expect(await readMensaLogin('1:'), isNotNull);
      await saveMensaLogin('1:', l);
      expect(await mensaLoginFailed('1:'), isFalse);
    },
  );

  test('In der App bestellen: neu aus, bisherige Nutzer an, gemerkt', () {
    final fresh = mem();
    settleMealOrderInApp(fresh);
    expect(mealOrderInApp(fresh), isFalse);
    final used = mem()
      ..setString(
        mealCacheKey,
        '{"1:":{"at":"2026-11-02T08:00:00.000","weeks":[]}}',
      );
    settleMealOrderInApp(used);
    expect(mealOrderInApp(used), isTrue);
    setMealOrderInApp(used, false);
    settleMealOrderInApp(used);
    expect(mealOrderInApp(used), isFalse);
  });

  test('Kursmappen-Versatz: einmal gewählt, gemerkt, im Rahmen', () {
    final s = mem();
    final a = courseScanOffset(s);
    expect(a, inInclusiveRange(0, 239));
    expect(courseScanOffset(s), a);
  });

  test('Import nennt die Bestellseiten der Datei', () {
    final data = {
      'k1': {
        'fork/$mensaUrlsSetting': '{"":"https://essen.example/login"}',
        'fork/$mensaUrlSetting': 'https://alt.example/',
      },
      'k2': {'fork/$mensaUrlsSetting': '{"x":"https://fremd.example/"}'},
    };
    expect(transferMensaHosts(data, ['k1']), ['alt.example', 'essen.example']);
    expect(transferMensaHosts(data, ['k1', 'k2']), hasLength(3));
  });
}
