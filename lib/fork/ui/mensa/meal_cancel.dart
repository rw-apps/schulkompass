/// Abbestellen an Krankheitstagen (Vorschlag 1 vom 05.11.26): Frist lesen,
/// kurz anzeigen, und welche bestellten Tage dafür in Frage kommen – eine
/// Quelle für „Heute“ (live_today_page.dart) und die Krankmeldung
/// (absence_reminders.dart).
library;

import '../../l10n/l10n.dart';
import '../../mensa_store.dart' show MealEntry, mealStaleAfter;
import '../../mensa_week.dart' show MealDay, MealState;

final _until = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})\s+(\d{1,2}):(\d{2})$');

/// Frist aus „29.10.26 08:30“; null, wenn nicht lesbar.
DateTime? mealCancelDeadline(String? until) {
  final m = _until.firstMatch((until ?? '').trim());
  if (m == null) return null;
  final y = int.parse(m[3]!);
  return DateTime(
    y < 100 ? 2000 + y : y,
    int.parse(m[2]!),
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
  );
}

/// Frist kurz: „08:30“ am Tag [day] selbst, sonst mit Wochentag
/// („Do 08:30“); nicht lesbar = der Text wie geliefert bzw. „–“. Grenze:
/// Wochentag statt Datum, weil die Frist höchstens wenige Tage vor dem
/// Essen liegt.
String mealCancelLabel(ForkL10n t, String? until, DateTime day) {
  final d = mealCancelDeadline(until);
  if (d == null) return until?.trim().isNotEmpty == true ? until!.trim() : '–';
  final hm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == day.year && d.month == day.month && d.day == day.day) {
    return hm;
  }
  return '${formatDate(t, 'ccc', d)} $hm';
}

/// Bestellter, jetzt noch abbestellbarer Tag [day] aus [e]; sonst null.
///
/// Ursache (Prüfung 05.11.26): canCancel ist der Stand vom letzten Lesen –
/// um 10 Uhr stand „abbestellen bis 08:30“ sonst noch da. Darum zusätzlich
/// die Frist gegen [now] und ein frischer Stand (mealStaleAfter wie die
/// Erinnerungen, mealReminderDays). Grenze: Ohne lesbare Frist zählt nur
/// canCancel; abbestellt wird ohnehin erst nach Rückfrage, und
/// MealOrderRunner prüft auf der Seite des Caterers erneut.
MealDay? cancellableMeal(MealEntry? e, DateTime day, DateTime now) {
  if (e == null) return null;
  final read = e.readAt;
  if (read == null || now.difference(read) > mealStaleAfter) return null;
  final m = e.dayOf(day);
  if (m == null || m.state != MealState.ordered || !m.canCancel) return null;
  final dl = mealCancelDeadline(m.cancelUntil);
  if (dl != null && !now.isBefore(dl)) return null;
  return m;
}
