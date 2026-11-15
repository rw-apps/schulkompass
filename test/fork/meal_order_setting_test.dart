// „In der App bestellen“ übersteht einen Neustart bzw. ein Update
// (Rückfrage 15.11.26): Die Einstellung liegt in shared_settings der
// Datenbankdatei lanis.db (lanis_bootstrap.dart, App-Datenordner) – ein
// Update mit derselben Signatur behält diesen Ordner. Hier: dieselbe Datei
// zweimal öffnen wie zwei App-Starts.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/mensa_store.dart';
import 'package:liblanis/liblanis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('eingeschaltet bleibt eingeschaltet, auch ohne gelesene Wochen', () {
    final dir = Directory.systemTemp.createTempSync('meal-setting');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/lanis.db';

    // Erster Start: neu eingerichtet → aus; Nutzer schaltet ein.
    var db = LanisDatabase.open(path: path, secretStore: MemorySecretStore());
    var s = TypedSettings.shared(db);
    MealCache.instance.attach(s);
    expect(mealOrderInApp(s), isFalse);
    setMealOrderInApp(s, true);
    db.dispose();
    MealCache.instance.reset();

    // Zweiter Start (nach Update): Voreinstellung darf nichts überschreiben.
    db = LanisDatabase.open(path: path, secretStore: MemorySecretStore());
    addTearDown(db.dispose);
    s = TypedSettings.shared(db);
    MealCache.instance.attach(s);
    expect(mealOrderInApp(s), isTrue);
    MealCache.instance.reset();
  });
}
