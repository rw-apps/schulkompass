import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/mensa.dart';
import 'package:lanis/fork/mensa_login.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:lanis/fork/mensa_week.dart';
import 'package:lanis/fork/ui/live/family.dart';
import 'package:lanis/fork/ui/live/live_data.dart';
import 'package:lanis/fork/ui/mensa/meal_hub_page.dart';
import 'package:liblanis/liblanis.dart';

// „Essen und Caterer“ (Entwurf 02.11.26). Erfundene Konten und Caterer.
final _checkers = <ConnectionChecker>[];

LiveSnapshot _snap(int id, String first, {String? url}) {
  final c = ConnectionChecker();
  _checkers.add(c);
  final session = LanisSession(
    account: ClearTextAccount(
      localId: id,
      schoolID: 9000 + id,
      username: 'u$id',
      password: '',
      schoolName: 'Beispielschule $id',
      accountType: AccountType.student,
    ),
    config: const LanisConfig(),
    connectionChecker: c,
  )..userData = {'vorname': first};
  return LiveSnapshot(
    session: session,
    supported: const {},
    timetable: const Feed(),
    lessons: const Feed(),
    substitutions: const Feed(),
    calendar: const Feed(),
    conversations: const Feed(),
    userChoice: const {},
    ownNames: const {},
    setUserChoice: (_) {},
    setOwnNames: (_) {},
    refresh: () async {},
    refreshMessages: () async {},
    setMensaUrl: (_, _) {},
    accountKey: '$id',
    mensa: MensaAddresses({if (url != null) '': url}),
  );
}

void main() {
  tearDown(() {
    for (final c in _checkers) {
      c.dispose();
    }
    _checkers.clear();
    MealCache.instance.reset();
  });

  final now = DateTime(2026, 11, 3, 10); // Dienstag
  MealWeek week(String url) => MealWeek(
    label: 'KW 45',
    url: url,
    balance: '12,50',
    days: [
      for (var i = 0; i < 5; i++)
        MealDay(
          day: DateTime(2026, 11, 2 + i),
          state: i == 2 ? MealState.open : MealState.ordered,
          ordered: i == 2 ? null : const MealOption(line: 'A', name: 'Nudeln'),
          options: i == 2
              ? const [MealOption(line: 'A', name: 'Reis', orderable: true)]
              : const [],
        ),
    ],
  );

  test('Kurzzeile für Mehr: offen bzw. einrichten', () {
    const url = 'https://bestellen.example/k/2026/45/';
    MealCache.instance.put('1:', [week(url)], at: now);
    final kids = mealKids([
      FamilyMember(
        accountId: 1,
        snapshot: _snap(1, 'Jonas', url: url),
        colorIndex: 0,
      ),
      FamilyMember(accountId: 2, snapshot: _snap(2, 'Lena'), colorIndex: 1),
    ]);
    final t = forkL10nFor('de');
    expect(
      mealHubSummary(t, kids, now),
      'Jonas: Mi noch nicht bestellt · Lena: einrichten',
    );
  });

  testWidgets('Karten: eingerichtet mit Woche und Zeilen, sonst Einrichten', (
    tester,
  ) async {
    mensaSecrets = MemorySecretStore();
    const url = 'https://bestellen.example/k/2026/45/';
    MealCache.instance.put('1:', [week(url)], at: now);
    final a = _snap(1, 'Jonas', url: url);
    final b = _snap(2, 'Lena');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: ForkL10n.localizationsDelegates,
        supportedLocales: ForkL10n.supportedLocales,
        locale: const Locale('de'),
        home: LiveData(
          snapshot: a,
          child: FamilyData(
            members: [
              FamilyMember(accountId: 1, snapshot: a, colorIndex: 0),
              FamilyMember(accountId: 2, snapshot: b, colorIndex: 1),
            ],
            child: MealHubPage(now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jonas'), findsOne);
    expect(find.text('Mittwoch noch nicht bestellt'), findsOne);
    expect(find.text('Wochenplan & bestellen'), findsOne);
    expect(find.text('12,50 €'), findsOne);
    expect(find.text('bestellen.example'), findsOne);
    expect(find.text('nicht hinterlegt'), findsOne);
    expect(find.text('Mo–Fr'), findsOne);
    expect(find.text('Einrichten'), findsOne);
    expect(tester.takeException(), isNull);
  });
}
