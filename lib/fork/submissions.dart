import 'package:html/dom.dart';
import 'package:liblanis/liblanis.dart';

/// Offene Abgaben aus „Mein Unterricht → Abgaben“ (Wunsch 15.11.26).
///
/// Ursache: Die Übersicht `meinunterricht.php` nennt eine Abgabe nur als
/// Zähler („1 offene Abgabe“), ohne Namen und Frist; die Kursseite kennt sie
/// zwar (CurrentEntry.uploads, Kursseite „Als Nächstes“), aber Unterricht-
/// Liste und Heute lesen nur die Übersicht. Deshalb liest die App zusätzlich
/// die Sammelseite `meinunterricht.php?a=sus_abgaben` (Menüpunkt „Abgaben“,
/// lessons_parent.dart _loadSubmissions).
///
/// Aufbau (Sammelseite und Kursseite „Alle Abgaben“, beide gespeichert
/// 15.11.26, gleiches Markup): je Kurs eine `h2` mit Link `sus_view&id=…`,
/// danach `table.abgaben`; je Abgabe eine Zelle mit Link
/// `sus_abgabe&b=…&e=…&id=…` (Name), Marke „N Dateien“, Zeile `<small>`
/// „Montag, 02.11.26 bis Freitag, 06.11.26, um 10:15 Uhr“ und – nur solange
/// abgegeben werden kann – Marke „Abgabe aktuell möglich“.
/// Grenze: Belegt ist nur ein Kurs mit einer Abgabe; mehrere Kurse stehen
/// vermutlich hintereinander (der Parser liest h2/Tabelle in Folge).
class OpenSubmission {
  const OpenSubmission({
    required this.courseId,
    required this.name,
    required this.url,
    this.until,
    this.files = 0,
    this.open = true,
  });

  /// Kurs-ID wie Lesson.courseID (`sus_view&id=…`).
  final String courseId;

  /// Name wie im Portal („Referat Kapitel 3“).
  final String name;

  /// Abgabeseite (`meinunterricht.php?a=sus_abgabe&…`), absolut.
  final Uri url;

  /// Ende der Abgabe; ohne Uhrzeit 23:59. null = Zeile nicht lesbar.
  final DateTime? until;

  /// Schon abgegebene Dateien („0 Dateien“ → 0).
  final int files;

  /// Abgabe gerade möglich (Marke „Abgabe aktuell möglich“).
  final bool open;
}

final _date = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})');
final _time = RegExp(r'(\d{1,2}):(\d{2})');

/// Ende aus „Montag, 02.11.26 bis Freitag, 06.11.26, um 10:15 Uhr“: letztes
/// Datum, Uhrzeit nach „bis“ (sonst 23:59). Zweistellige Jahre als 20xx.
DateTime? submissionUntil(String text) {
  // Ohne „bis“ keine Frist (z. B. „ab Montag, …“ – sonst gälte der Beginn
  // als Ende und die Abgabe schon als vorbei; Prüfbefund 15.11.26).
  final bis = RegExp(r'(?:^|\s)bis\s');
  if (!bis.hasMatch(text)) return null;
  final part = text.split(bis).last;
  final d = _date.allMatches(part).lastOrNull;
  if (d == null) return null;
  var y = int.parse(d.group(3)!);
  if (y < 100) y += 2000;
  final tm = _time.firstMatch(part.substring(d.end));
  final h = tm == null ? 23 : int.parse(tm.group(1)!);
  final m = tm == null ? 59 : int.parse(tm.group(2)!);
  final day = int.parse(d.group(1)!), month = int.parse(d.group(2)!);
  if (month < 1 || month > 12 || day < 1 || day > 31 || h > 23 || m > 59) {
    return null;
  }
  return DateTime(y, month, day, h, m);
}

String? _idOf(String? href) {
  if (href == null) return null;
  final u = Uri.tryParse(href.replaceAll('&amp;', '&'));
  final id = u?.queryParameters['id'];
  return id == null || id.isEmpty ? null : id;
}

/// Alle Abgaben der Seite, in Reihenfolge des Portals. Eine unlesbare Zeile
/// wird übersprungen ([skipped] zählt sie, ohne Inhalte), nicht die Seite.
({List<OpenSubmission> items, int skipped}) parseSubmissions(Document doc) {
  final out = <OpenSubmission>[];
  var skipped = 0;
  final root = doc.getElementById('content') ?? doc.body;
  if (root == null) return (items: out, skipped: 0);
  String? course;
  for (final el in root.querySelectorAll('h2, table.abgaben')) {
    if (el.localName == 'h2') {
      course = _idOf(
        el.querySelector('a[href*="sus_view"]')?.attributes['href'],
      );
      continue;
    }
    for (final td in el.querySelectorAll('tbody > tr > td')) {
      final a = td.querySelector('a[href*="sus_abgabe"]');
      final href = a?.attributes['href']?.replaceAll('&amp;', '&');
      final name = a?.text.trim() ?? '';
      final url = href == null
          ? null
          : Uri.tryParse('https://start.schulportal.hessen.de/')?.resolve(href);
      if (course == null || name.isEmpty || url == null) {
        skipped++;
        continue;
      }
      final files = RegExp(r'(\d+)\s*Datei').firstMatch(td.text);
      out.add(
        OpenSubmission(
          courseId: course,
          name: name,
          url: url,
          until: submissionUntil(td.querySelector('small')?.text ?? ''),
          files: files == null ? 0 : int.parse(files.group(1)!),
          // Nach dem Text, nicht nach `label-success`: Auch die Marke
          // „N Dateien“ ist vermutlich grün, sobald etwas abgegeben ist
          // (bei 0 rot, Seite 15.11.26).
          open: RegExp(r'Abgabe\s+aktuell\s+möglich').hasMatch(td.text),
        ),
      );
    }
  }
  return (items: out, skipped: skipped);
}

/// Abgaben je Kurs, angeheftet an die Lesson-Objekte des letzten Abrufs.
///
/// Ursache: Lesson (liblanis) hat kein Feld dafür, und CurrentEntry.uploads
/// gehört zum neuesten Eintrag (Kursseite). Ein Expando hängt die Liste an
/// genau die Objekte, die LiveSnapshot.lessons weiterreicht. Grenze: Aus
/// dem Offline-Speicher (offline_store.dart) gelesene Kurse sind neue
/// Objekte – offline erscheinen keine Abgaben.
final submissionsOfLesson = Expando<List<OpenSubmission>>('submissions');

/// Kurs-ID wie auf der Abgaben-Seite: Parameter `id` der Kursadresse,
/// sonst Lesson.courseID.
String courseIdOf(Lesson l) =>
    l.courseURL.queryParameters['id'] ?? l.courseID.split('&').first;

/// Hängt [items] an die passenden Kurse ([Lesson.courseID]); gibt zurück,
/// wie viele keinem Kurs zugeordnet werden konnten.
int attachSubmissions(List<Lesson> lessons, List<OpenSubmission> items) {
  // Kurs-ID aus der Kursadresse (`id=`), nicht Lesson.courseID: Die bildet
  // liblanis als `href.split('id=')[1]` – mit `&halbjahr=…` o. Ä. dahinter
  // passte sie nie (Prüfbefund 15.11.26).
  final byId = {for (final l in lessons) courseIdOf(l): l};
  var orphans = 0;
  for (final l in lessons) {
    submissionsOfLesson[l] = const [];
  }
  for (final s in items) {
    final l = byId[s.courseId];
    if (l == null) {
      orphans++;
      continue;
    }
    submissionsOfLesson[l] = [...?submissionsOfLesson[l], s];
  }
  return orphans;
}

/// Eine offene Abgabe mit Fach – für Unterricht, Heute und „Alle“.
typedef SubmissionItem = ({
  String courseId,
  String subject,
  OpenSubmission submission,
});

/// Offene Abgaben aller [lessons], früheste Frist zuerst. Nur solche, die
/// noch möglich sind und deren Frist nicht vorbei ist ([now]).
///
/// [handedIn] false lässt Abgaben mit schon hochgeladener Datei weg – für
/// Heute und das Abzeichen (homework_due.dart liveOpenSubmissions). Ursache
/// (Rückmeldung 27.11.26): Das Portal führt eine Abgabe bis zur Frist als
/// „Abgabe aktuell möglich“, auch wenn die Datei schon da ist; sie zählte
/// deshalb weiter als offene Aufgabe. Unterricht zeigt sie unter „Erledigt“
/// (homework_section.dart SubEntry.handedIn).
List<SubmissionItem> openSubmissionsOf(
  List<Lesson> lessons, {
  required String Function(Lesson l) subjectOf,
  required DateTime now,
  bool handedIn = true,
}) {
  final out = <SubmissionItem>[
    for (final l in lessons)
      for (final s in submissionsOfLesson[l] ?? const <OpenSubmission>[])
        if (s.open &&
            (handedIn || s.files == 0) &&
            (s.until == null || s.until!.isAfter(now)))
          (courseId: l.courseID, subject: subjectOf(l), submission: s),
  ];
  out.sort((a, b) {
    final x = a.submission.until, y = b.submission.until;
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return x.compareTo(y);
  });
  return out;
}
