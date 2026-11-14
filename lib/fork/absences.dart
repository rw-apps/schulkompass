import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'data/course_rules.dart';
import 'error_log.dart';
import 'ui/courses/courses_model.dart';

/// Eine Stunde, in der das Kind laut Kursmappe nicht anwesend war.
class AbsenceItem {
  const AbsenceItem({
    required this.course,
    required this.entry,
    required this.subject,
    required this.status,
    required this.excused,
    this.day,
    this.hours,
    this.teacherCodes = const [],
    this.alsoKeys = const [],
  });

  /// Kurs-ID (CourseItem.id) und Eintrag der Stunde (CurrentEntry.entryID).
  final String course;
  final String entry;
  final String subject;

  /// Wortlaut des Portals („fehlend“, „entschuldigt“ …).
  final String status;

  /// Entschuldigt laut Portal.
  final bool excused;
  final DateTime? day;

  /// „3.“ bzw. „3. - 4.“ (CurrentEntry.schoolHours).
  final String? hours;
  final List<String> teacherCodes;

  String get key => '$course|$entry';

  /// Schlüssel der Einträge, die [absencesFrom] als gleiche Stunde
  /// zusammengelegt hat. Ursache (Prüfung 08.11.26): Der Vermerk „gesendet“
  /// (absenceSentSetting) hängt am Schlüssel; war die verworfene Zeile schon
  /// entschuldigt, erschiene sonst wieder „Entschuldigen“ – genau der
  /// Doppelversand, den der Vermerk verhindern soll.
  final List<String> alsoKeys;

  /// [key] und [alsoKeys].
  List<String> get keys => [key, ...alsoKeys];

  /// Frühester Vermerk „gesendet“ über alle zusammengelegten Einträge.
  DateTime? sentIn(Map<String, DateTime> sent) {
    DateTime? out;
    for (final k in keys) {
      final d = sent[k];
      if (d != null && (out == null || d.isBefore(out))) out = d;
    }
    return out;
  }

  AbsenceItem _withAlso(String k) => AbsenceItem(
    course: course,
    entry: entry,
    subject: subject,
    status: status,
    excused: excused,
    day: day,
    hours: hours,
    teacherCodes: teacherCodes,
    alsoKeys: [...alsoKeys, if (k != key && !alsoKeys.contains(k)) k],
  );
}

/// Entschuldigt? Erst „unentschuldigt“/„fehl…“ prüfen – „unentschuldigt“
/// enthält „entschuldigt“ (CourseRules.missing vor excused, wie
/// attendanceCounts).
bool isExcused(String presence) {
  final p = presence.toLowerCase();
  if (CourseRules.missing.any(p.contains)) return false;
  return CourseRules.excused.any(p.contains);
}

/// Zahl der Unterrichtsstunden in „3.“ bzw. „2. - 3.“ (CurrentEntry.
/// schoolHours). Ursache (Rückmeldung 08.11.26): Die Übersicht zählte
/// Einträge als „Stunden“ – eine Doppelstunde ergab 1. Beleg, dass das Portal
/// ebenso zählt (Anwesenheitstabelle der Kursseite, Exporte Schule B): zehn
/// Einträge „3. - 4.“ = „anwesend 20“; 2+2+2+4 („1. - 4.“) + 1 („0.“) = 11.
/// Grenze: leer, unlesbar, vertauscht („5. - 4.“) oder mehr als 12 = 1;
/// Listen wie „2., 4.“ sind nicht belegt und zählten als Spanne.
int lessonCount(String? hours) {
  final n = RegExp(r'\d+').allMatches(hours ?? '').map((m) => int.parse(m[0]!));
  if (n.length < 2) return 1;
  final d = n.last - n.first + 1;
  return d >= 1 && d <= 12 ? d : 1;
}

/// Schlüssel „gleiche Stunde“ innerhalb eines Kurses: Tag, Stunden (ohne
/// Leerzeichen), Vermerk. Auch für absentEntries (course_detail_model.dart).
///
/// Ursache (Rückmeldung 08.11.26, Bildschirmfoto): Eine Fehlzeit stand
/// doppelt da – gleicher Kurs, Tag, Stunden, Vermerk. Eine doppelt gelesene
/// Seite scheidet aus (loadCoursePages: eine Seite je Kurs-ID; #history hat
/// in allen Exporten eine Tabelle). Bleibt: zwei Einträge der Lehrkraft für
/// dieselbe Stunde, oder dieselbe Kurs-ID zweimal in der Kursliste – das
/// unterscheidet [absencesFrom]; gemeldet wird nur noch der zweite Fall
/// (DuplicateAbsence sameEntry).
///
/// Grenze: Stunde „0.“ oder leer ist bei manchen Schulen ein Platzhalter
/// (Schule A: alle Einträge „0. Stunde“); dann zählt [entryId] mit, damit
/// zwei echte Stunden eines Tages nicht verschmelzen. Abweichender Vermerk
/// („fehlend“ und „entschuldigt“) bleibt getrennt. Doppelt eingetragene
/// Stunden zählt das Portal in seiner eigenen Statistik weiter doppelt
/// (Arbeiten & Noten, Kursseite).
String sameLessonKey(
  DateTime? day,
  String? hours,
  String? presence,
  String entryId,
) {
  final h = (hours ?? '').replaceAll(RegExp(r'\s+'), '');
  final placeholder = h.isEmpty || RegExp(r'^0\.?$').hasMatch(h);
  return [
    day?.toIso8601String() ?? '',
    h,
    (presence ?? '').trim().toLowerCase(),
    if (placeholder) entryId,
  ].join('|');
}

/// Alle Abwesenheiten aus den geladenen Kursseiten, neueste zuerst.
///
/// Quelle: Spalte „Anwesenheit“ im Verlauf jeder Kursmappe (CurrentEntry.
/// presence); „anwesend“ und „nicht erfasst“ zählen nicht
/// (CourseRules.presenceNeutral). Jede Stunde nur einmal (sameLessonKey);
/// die Schlüssel verworfener Einträge stehen in AbsenceItem.alsoKeys.
/// Grenze: nur das geladene Halbjahr, und nur Stunden, die die Lehrkraft in
/// die Kursmappe eingetragen hat.
List<AbsenceItem> absencesFrom(
  List<CourseItem> courses,
  Map<String, DetailedLesson> pages,
) {
  final out = <AbsenceItem>[];
  final at = <String, int>{};
  var sameEntry = 0;
  for (final c in courses) {
    final d = pages[c.id];
    if (d == null) continue;
    for (final e in d.history) {
      final p = (e.presence ?? '').trim();
      if (CourseRules.presenceNeutral.contains(p.toLowerCase())) continue;
      final k =
          '${c.id}|${sameLessonKey(e.topicDate, e.schoolHours, p, e.entryID)}';
      final i = at[k];
      if (i != null) {
        final first = out[i];
        if (first.entry == e.entryID) {
          sameEntry++; // Kurs-ID zweimal in der Kursliste
        } else {
          // Zwei Einträge der Lehrkraft: zusammengefasst, nicht gemeldet.
          out[i] = first._withAlso('${c.id}|${e.entryID}');
        }
        continue;
      }
      at[k] = out.length;
      out.add(
        AbsenceItem(
          course: c.id,
          entry: e.entryID,
          subject: c.title,
          status: p,
          excused: isExcused(p),
          day: e.topicDate,
          hours: e.schoolHours?.trim(),
          teacherCodes: c.teacherCodes,
        ),
      );
    }
  }
  // Nur Zählwerte, keine Inhalte (wie SkippedRows, lessons_student.dart).
  // Gemeldet wird nur noch derselbe Eintrag doppelt (sameEntry: Kurs-ID
  // zweimal gelesen, deutet auf einen Lesefehler). Zwei Einträge der
  // Lehrkraft für dieselbe Stunde sind geklärt und harmlos – die Anzeige
  // fasst sie zusammen. Ursache (Fehlerberichte 9506–9510, 14.11.26): Sie
  // kamen als otherEntry=1 bei jedem Laden erneut, bis 15× je Sitzung, ohne
  // neue Erkenntnis.
  if (sameEntry > 0) {
    ErrorLog.instance.notice('meinunterricht.php', 'DuplicateAbsence', {
      'sameEntry': sameEntry,
    });
  }
  out.sort(
    (a, b) => (b.day ?? DateTime(2000)).compareTo(a.day ?? DateTime(2000)),
  );
  return out;
}

/// Gesendete Entschuldigungen je Konto: Abwesenheit → Tag des Sendens.
/// Ursache: Bis die Lehrkraft im Portal „entschuldigt“ einträgt, vergehen
/// oft Tage; ohne Vermerk schriebe man doppelt. Grenze: Wurde außerhalb der
/// App entschuldigt, fehlt der Vermerk.
const absenceSentSetting = 'fork-absence/sent';

Map<String, DateTime> decodeSent(String? s) {
  if (s == null || s.isEmpty) return const {};
  try {
    final v = jsonDecode(s);
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (DateTime.tryParse('${e.value}') case final d?) '${e.key}': d,
    };
  } catch (_) {
    return const {};
  }
}

String encodeSent(Map<String, DateTime> m) =>
    jsonEncode({for (final e in m.entries) e.key: e.value.toIso8601String()});
