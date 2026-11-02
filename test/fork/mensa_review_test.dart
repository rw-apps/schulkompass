import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/mensa.dart';
import 'package:lanis/fork/mensa_login.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:liblanis/liblanis.dart' show MemorySecretStore, TypedSettings;

// Befunde der unabhängigen Prüfung 02.11.26 (Essen, 9464–9466).
void main() {
  TypedSettings mem([Map<String, String?>? m]) {
    final map = m ?? <String, String?>{};
    return TypedSettings(
      read: (k) => map[k],
      write: (k, v) => map[k] = v,
      delete: map.remove,
    );
  }

  test('Besitzer je Hauptdomain: www. und ohne sind eine Seite', () {
    final s = mem();
    setMensaLastOwner(s, 'caterer.example', '1:a');
    // Bestellung prüft den Host der Wochenseite nach Umleitung.
    expect(mensaLastOwner(s, 'www.caterer.example'), '1:a');
    expect(mensaLastOwner(s, 'anders.example'), isNull);
  });

  test('alte Einträge mit verschiedenen Kindern je Domain: unbekannt', () {
    final s = mem()
      ..setString(
        mensaLastKey,
        jsonEncode({
          'caterer.example': {'owner': '1:a', 'name': ''},
          'www.caterer.example': {'owner': '2:', 'name': ''},
        }),
      );
    final o = mensaLastOwner(s, 'www.caterer.example');
    expect(o, isNot('1:a'));
    expect(o, isNot('2:'));
    expect(o, isNotNull);
  });

  test('Zugang nur auf demselben Host (bis auf www.)', () {
    expect(
      mensaSameHost('https://www.essen.example/a', 'https://essen.example/b'),
      isTrue,
    );
    expect(
      mensaSameHost(
        'https://mandant1.plattform.example/',
        'https://mandant2.plattform.example/',
      ),
      isFalse,
    );
    expect(mensaSameHost(null, 'https://essen.example/'), isFalse);
  });

  test('andere Bestellseite: Host oder erster Pfadteil', () {
    const a = 'https://www.plattform.example/mandant-a/login';
    expect(
      mensaOtherPage(a, 'https://plattform.example/mandant-a/woche'),
      isFalse,
    );
    expect(
      mensaOtherPage(a, 'https://www.plattform.example/mandant-b/login'),
      isTrue,
    );
    expect(mensaOtherPage(a, 'https://anders.example/mandant-a/login'), isTrue);
    expect(mensaOtherPage(null, a), isTrue);
    expect(mensaOtherPage(null, null), isFalse);
  });

  test('readMensaLogin(site:) nur für denselben Host', () async {
    mensaSecrets = MemorySecretStore();
    await saveMensaLogin(
      '1:a',
      const MensaLogin(host: 'www.essen.example', user: 'u', pass: 'p'),
    );
    expect(
      await readMensaLogin('1:a', site: 'https://essen.example/x'),
      isNotNull,
    );
    expect(
      await readMensaLogin('1:a', site: 'https://anders.example/'),
      isNull,
    );
    expect(await readMensaLogin('1:a'), isNotNull);
  });

  test('Neu-Lesen erbitten und abholen', () {
    final c = MealCache.instance;
    c.requestRefresh('1:a');
    c.requestRefresh('1:b');
    expect(c.refreshRequests.value, {'1:a', '1:b'});
    c.takeRefresh('1:a');
    expect(c.refreshRequests.value, {'1:b'});
    c.takeRefresh('1:b');
  });
}
