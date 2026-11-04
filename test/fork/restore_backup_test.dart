// „Mit Sicherungsdatei einrichten“ (04.11.26): Dateiformat mit Schulnamen,
// Zerlegen der Kontoschlüssel und die Kontenseite der Anmeldung.
// Erfundene Konten und Schulen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/onboarding/onboarding_kit.dart';
import 'package:lanis/fork/onboarding/restore_backup.dart';
import 'package:lanis/fork/settings_transfer.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/school_selector.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

String enc(String s) => LanisDatabase.encodeValue(s);

void main() {
  final now = DateTime(2026, 11, 4, 20, 30);

  test('Datei trägt Schulnamen; ältere Dateien ohne Namen bleiben lesbar', () {
    final text = buildTransfer(
      {
        '9999:jonas.beispiel': {
          'stundenplan.php/fork-lesson-times': enc('{"start":"08:00"}'),
        },
        '9998:lena:zwei': {},
      },
      now: now,
      names: {
        '9999:jonas.beispiel': ' Muster-Gesamtschule ',
        // Name ohne Konto in der Datei fällt weg.
        '1:fremd': 'Andere Schule',
      },
    );
    final b = parseBackup(text)!;
    expect(b.names, {'9999:jonas.beispiel': 'Muster-Gesamtschule'});
    expect(b.created, now);
    expect(b.accounts.map((a) => (a.schoolId, a.username)), [
      (9999, 'jonas.beispiel'),
      // Nur am ersten „:“ getrennt.
      (9998, 'lena:zwei'),
    ]);
    // Konto ohne Eingaben bleibt in der Datei – es soll trotzdem
    // eingerichtet werden können.
    expect(b.data['9998:lena:zwei'], isEmpty);

    final old = parseBackup(
      '{"format":"schulportal-eingaben","version":1,'
      '"accounts":{"9999:jonas.beispiel":{}}}',
    )!;
    expect(old.names, isEmpty);
    expect(old.created, isNull);
    expect(old.accounts.single.schoolId, 9999);
  });

  test('Fremde oder kaputte Einträge werden nicht übernommen', () {
    final b = parseBackup(
      '{"format":"schulportal-eingaben","accounts":{'
      '"9999:a":{},"keine-nummer":{},"0:b":{},"12:":{}},'
      '"names":{"9999:a":{"x":1},"12:":"y"}}',
    )!;
    expect(b.accounts.map((a) => a.key), ['9999:a']);
    expect(b.names, isEmpty);
    final long = parseBackup(
      '{"format":"schulportal-eingaben","accounts":{"9999:a":{}},'
      '"names":{"9999:a":"${'x' * 121}"}}',
    )!;
    expect(long.names, isEmpty);
    expect(parseBackup('{"format":"anderes"}'), isNull);
  });

  test('Schlüssel kanonisch, Dubletten und Grenzen', () {
    final b = parseBackup(
      '{"format":"schulportal-eingaben","accounts":{'
      '"9999:Jonas.Beispiel":{},"9999:jonas.beispiel":{},'
      '"+9998:a":{},"09997:b":{},"9996:${'x' * 101}":{}},'
      '"names":{"9999:Jonas.Beispiel":"Muster\\u202eSchule\\u0007"}}',
    )!;
    expect(b.accounts.map((a) => a.key), ['9999:jonas.beispiel', '9997:b']);
    expect(b.names, {'9999:jonas.beispiel': 'MusterSchule'});
    final many = {for (var i = 1; i <= 30; i++) '"$i:k$i"': '{}'};
    final big = parseBackup(
      '{"format":"schulportal-eingaben","accounts":{'
      '${many.entries.map((e) => '${e.key}:${e.value}').join(',')}}}',
    )!;
    expect(big.accounts, hasLength(maxBackupAccounts));
  });

  test('Bestellseiten: ohne Schema und als nackter JSON-Text erkannt', () {
    final data = {
      'k': {
        'fork/fork-mensa-url': LanisDatabase.encodeValue('Essen.Example/x'),
        'fork/fork-mensa-urls': '"{\\"1:A\\":\\"nackt.example/y\\"}"',
      },
    };
    expect(transferMensaHosts(data, ['k']), ['essen.example', 'nackt.example']);
  });

  test('collectTransferNames: nur Konten mit Schulnamen', () {
    final names = collectTransferNames([
      AccountSummary(
        localId: 1,
        schoolID: 9999,
        username: 'Jonas.Beispiel',
        schoolName: 'Muster-Gesamtschule',
        creationDate: DateTime(2026),
      ),
      AccountSummary(
        localId: 2,
        schoolID: 9998,
        username: 'lena',
        schoolName: '',
        creationDate: DateTime(2026),
      ),
    ]);
    expect(names, {'9999:jonas.beispiel': 'Muster-Gesamtschule'});
  });

  group('Anmeldung aus der Sicherung', () {
    setUp(() => SchoolSelector.skipNetworkLoad = true);
    tearDown(() {
      SchoolSelector.skipNetworkLoad = false;
      LanisClient.reset();
    });

    final backup = TransferBackup(
      data: const {'9999:jonas.beispiel': {}, '9998:lena.beispiel': {}},
      names: const {
        '9999:jonas.beispiel': 'Muster-Gesamtschule',
        '9998:lena.beispiel': 'Beispiel-Gymnasium',
      },
      created: DateTime(2026, 11, 4),
    );

    testWidgets('zeigt Konten, Passwort nur beim ersten; überspringen', (
      t,
    ) async {
      await pumpTestApp(
        t,
        child: Scaffold(
          body: LoginForm(showBackButton: false, restore: backup),
        ),
      );
      final l = forkL10nFor('en');
      expect(find.text(l.restoreTitle), findsOneWidget);
      expect(find.text('Muster-Gesamtschule · 9999'), findsOneWidget);
      expect(find.text('Beispiel-Gymnasium · 9998'), findsOneWidget);
      // Ein Passwortfeld, beim aktiven Konto.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l.restoreNext), findsOneWidget);
      // Anmelden erst mit Zustimmung und Passwort.
      OnbButton login() => t.widget<OnbButton>(find.byType(OnbButton));
      expect(login().label, l.restoreLogin(1, 2));
      expect(login().onPressed, isNull);
      await t.enterText(find.byType(TextField), 'geheim');
      await t.ensureVisible(find.byType(Checkbox));
      await t.tap(find.byType(Checkbox));
      await t.pump();
      expect(login().onPressed, isNotNull);

      // Überspringen: das zweite Konto ist dran.
      await t.ensureVisible(find.text(l.restoreSkip));
      await t.tap(find.text(l.restoreSkip));
      await t.pump();
      expect(find.text(l.restoreSkipped), findsOneWidget);
      expect(login().label, l.restoreLogin(2, 2));
      // Passwort wurde geleert.
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');

      // Alle übersprungen, keines angemeldet: zurück zum normalen Formular.
      await t.ensureVisible(find.text(l.restoreSkip));
      await t.tap(find.text(l.restoreSkip));
      await t.pumpAndSettle();
      expect(find.text(l.restoreTitle), findsNothing);
      expect(find.text(l.setupWithFile), findsOneWidget);
    });

    testWidgets('Formular bietet Datei und QR bei der Ersteinrichtung', (
      t,
    ) async {
      await pumpTestApp(
        t,
        child: const Scaffold(body: LoginForm(showBackButton: false)),
      );
      final l = forkL10nFor('en');
      expect(find.text(l.setupWithFile), findsOneWidget);
      expect(find.text(l.devFromOther), findsOneWidget);
      expect(find.byType(OnbOrDivider), findsOneWidget);
    });
  });
}
