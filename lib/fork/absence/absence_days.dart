/// Krank gemeldete Tage eines Kontos, gemerkt für die Sammel-Benachrichtigung
/// (Wunsch 05.11.26, Vorschlag 3: keine Ausfälle, Vertretungen und
/// Essens-Erinnerungen für ein krank gemeldetes Kind).
///
/// Ursache des Merkens: Die Essens-Zeilen baut showForkSummary
/// (notify_task.dart) NACH allen Konten aus den gespeicherten Wochen, ohne
/// Sitzung – die Meldungsliste kennt dort niemand. Darum legen App
/// (live_data.dart _loadExtras) und Hintergrund-Lauf die krank gemeldeten
/// Tage ab Heute im Konto ab; jeder neue Abruf ersetzt sie.
///
/// Grenze: Verspätungen zählen nicht – das Kind geht zur Schule, Ausfälle
/// und Essen gelten weiter. Ohne erfolgreichen Abruf bleibt die letzte
/// Liste stehen; alte Tage fallen beim Lesen heraus.
library;

import 'dart:convert';

import 'package:liblanis/liblanis.dart' show TypedSettings;

import '../kid_name.dart' show shortFirstName;
import '../lessons_parent.dart' show ChildLessons;
import 'absence_form.dart' show AbsenceEntry;
import 'absence_today.dart';

/// Konto-Einstellung: JSON-Objekt Kind (pupilId) → ISO-Daten („2026-11-05“).
const absenceSickDaysSetting = 'fork-absence/sick-days';

/// So viele Tage ab heute werden gemerkt. Ursache: Die Sammelmeldung blickt
/// nur auf heute und den nächsten Schultag, Essens-Erinnerungen auf die
/// Bestelltage der kommenden Woche (mealReminderDays). Grenze: Längere
/// Meldungen werden ab dem 15. Tag erst nach einem neuen Abruf bekannt.
const absenceSickDaysAhead = 14;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Krank gemeldet (nicht nur verspätet) an [day]? Zuordnung über den
/// Vornamen wie auf Heute ([absenceIsFor]).
bool absenceSickOn(
  List<AbsenceEntry> entries,
  String firstName,
  DateTime day,
) => entries.any(
  (e) =>
      !absenceIsLate(e) && absenceIsFor(e, firstName) && absenceCovers(e, day),
);

/// Krank gemeldete Tage von heute bis heute + [absenceSickDaysAhead].
List<DateTime> absenceSickDays(
  List<AbsenceEntry> entries,
  String firstName,
  DateTime now,
) {
  final today = _day(now);
  return [
    for (var i = 0; i <= absenceSickDaysAhead; i++)
      if (DateTime(today.year, today.month, today.day + i) case final d
          when absenceSickOn(entries, firstName, d))
        d,
  ];
}

/// Krankheitstage je Kind des Elternkontos ([ChildLessons.pupilId] →
/// Tage), Zuordnung über den kurzen Vornamen wie in der App
/// (shortFirstName). Ursache (Prüfung 05.11.26): Je Konto gemerkt galten
/// die Tage von Lena auch für Jonas' Essens-Erinnerungen, wenn beide über
/// ein Elternkonto bestellen (meal_hub_page.dart mealKids). Kinder ohne
/// Krankheitstag fehlen in der Map.
///
/// Zusätzlich [absencePlanKidKey] für das Kind des Plans (kids.first):
/// Scheitern im Hintergrund Unterricht UND Meldungsabruf im selben Lauf,
/// kennt notify_task.dart keine Kinder-Kennung – ohne diesen Eintrag kämen
/// die unterdrückten Ausfälle für einen Lauf mit Ton zurück (Prüfung
/// 06.11.26).
Map<String, List<DateTime>> absenceSickDaysByKid(
  List<AbsenceEntry> entries,
  List<ChildLessons> kids,
  DateTime now,
) {
  final out = <String, List<DateTime>>{
    for (final k in kids)
      if (absenceSickDays(entries, shortFirstName(k.firstName), now)
          case final days when days.isNotEmpty)
        k.pupilId: days,
  };
  if (kids.isNotEmpty && out[kids.first.pupilId] != null) {
    out[absencePlanKidKey] = out[kids.first.pupilId]!;
  }
  return out;
}

/// Schlüssel der Tage des Plan-Kindes in der Ablage. Mit Doppelpunkt, weil
/// Kinder-Kennungen aus `h2[data-pupil]` kommen (lessons_parent.dart) und
/// im Portal nur Ziffern sind – ungeprüft, darum ein Zeichen, das in einer
/// Kennung nicht vorkommt.
const absencePlanKidKey = ':plan';

/// Ablegen (ersetzt die vorige Liste, je Kind); leer löscht den Eintrag.
/// Schreibt nur bei Änderung.
void storeSickDays(TypedSettings account, Map<String, List<DateTime>> byKid) {
  final value = byKid.isEmpty
      ? null
      : jsonEncode({
          for (final e in byKid.entries)
            e.key: [for (final d in e.value) _iso(d)],
        });
  if (account.getString(absenceSickDaysSetting) == value) return;
  account.setString(absenceSickDaysSetting, value);
}

/// Gemerkte Tage je Kind ab heute; kaputter oder fehlender Eintrag = keine.
Map<String, Set<DateTime>> readSickDays(TypedSettings account, DateTime now) {
  final today = _day(now);
  try {
    final raw = account.getString(absenceSickDaysSetting);
    if (raw == null) return const {};
    final m = jsonDecode(raw);
    if (m is! Map) return const {};
    return {
      for (final e in m.entries)
        if (e.value is List)
          '${e.key}': {
            for (final s in e.value as List)
              if (DateTime.tryParse('$s') case final d? when !d.isBefore(today))
                _day(d),
          },
    };
  } catch (_) {
    return const {};
  }
}
