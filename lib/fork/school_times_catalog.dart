import 'ui/plan/lesson_times.dart';

/// Stundenzeiten bekannter Schulen, deren Stundenplan im Portal keine
/// Uhrzeiten zeigt (KidPlan.timed = false) – damit jedes Gerät dieser Schule
/// „Jetzt“, „Danach“ und die Zeitlinie hat, ohne dass die Familie Zeiten
/// eintragen muss (lesson_times.dart).
///
/// Ursache (Wunsch 09.11.26): Die Zeiten lagen nur je Gerät; jede Familie
/// derselben Schule musste sie selbst eintragen, und ein Eintrag mit dem
/// Vorschlagsraster stimmte nicht. Schulen stehen nur als Schulnummer
/// darin (Session.account.schoolID), keine Schulnamen – Freigabe 09.11.26,
/// gleiche Regel wie im Caterer-Katalog (mensa_catalog.dart); ship.sh prüft
/// diese Datei nur auf Namen.
///
/// Grenze: Stand der Angabe der Familie; ändert eine Schule ihre Zeiten,
/// stimmt der Eintrag nicht mehr. Selbst eingetragene Zeiten des Geräts
/// gehen vor (effectiveLessonTimes, live_data.dart) – außer solchen von vor
/// dem Katalogeintrag, die ownLessonTimes einmal verwirft. Uhrzeiten
/// aus dem Portal gehen beidem vor (kidPlanFromTimetable).
const schoolTimesCatalog = <String, LessonTimes>{
  // Angabe der Familie 09.11.26: 1. 08:00, 3. 09:50–10:35, 4. –11:20,
  // 5. 11:40–12:25, 6. 12:30–13:15, 7. 13:25–14:10, 8. 14:10–14:55.
  '5106': LessonTimes(
    start: 8 * 60,
    length: 45,
    pauses: {2: 20, 4: 20, 5: 5, 6: 10},
  ),
};

/// Zeiten aus [schoolTimesCatalog] für die Schulnummer [schoolId].
LessonTimes? catalogLessonTimes(String schoolId) =>
    schoolTimesCatalog[schoolId];
