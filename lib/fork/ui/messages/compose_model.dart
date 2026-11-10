import 'package:liblanis/liblanis.dart';

import '../../name_repair.dart';
import '../courses/courses_model.dart' show courseTitle;
import '../plan/plan_model.dart' show portalNameToDisplay;

/// Eine Lehrkraft aus dem Unterricht des Kindes als mögliche Empfängerin.
class RecipientCandidate {
  const RecipientCandidate({
    required this.kuerzel,
    required this.display,
    required this.lastName,
    required this.subjects,
    this.firstName,
    this.knownLastName,
    this.searchNames = const [],
  });

  final String kuerzel;

  /// „Anna Alt“ – eigener Name, sonst der Portal-Name (repariert).
  final String display;

  /// Nachname, wie das Portal ihn schickt (auch mit „�“).
  final String lastName;

  /// Über das Kürzel reparierter Nachname (repairWithKuerzel); null, wenn
  /// nichts zu reparieren war oder nicht ging.
  final String? knownLastName;
  final String? firstName;

  /// Suchbegriffe für die Portal-Suche, in dieser Reihenfolge (searchQueries).
  final List<String> searchNames;

  /// „Mathematik, Training“ – woher das Kind sie kennt.
  final List<String> subjects;
}

/// Lehrkräfte aus „Mein Unterricht“, je Kürzel einmal, mit ihren Fächern.
///
/// Ursache (Konzept 17.10.26): Statt das Lehrerverzeichnis der ganzen Schule
/// zu durchsuchen, wählt man aus dem Unterricht des eigenen Kindes
/// („Mathematik – Herr …“). Grenze: Wer keinen Kurs in „Mein Unterricht“
/// hat (Schule A: Ästhetik), fehlt hier – dafür bleibt die freie Suche.
///
/// [ownNames] (Kürzel → eigener Name, PlanPage „Name eintragen“) gehen vor
/// (Wunsch 09.11.26: der eigene Name gilt überall); sonst wird der
/// Portal-Name über das Kürzel repariert (repairWithKuerzel).
List<RecipientCandidate> candidatesFrom(
  Lessons lessons, {
  Map<String, String> ownNames = const {},
}) {
  final byK = <String, RecipientCandidate>{};
  final order = <String>[];
  // Kleinste Teamgröße je Kürzel: Wer nur in großen Teams vorkommt (Schule A:
  // Ganztagsangebot mit sechs Lehrkräften, Export 16.10.26), kommt ans Ende –
  // die Fachlehrkräfte sollen oben stehen.
  final team = <String, int>{};
  for (final l in lessons) {
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim() ?? '';
      final n = l.teachers.length;
      if ((team[k] ?? 1 << 30) > n) team[k] = n;
    }
  }
  for (final l in lessons) {
    final subject = courseTitle(l.name);
    for (final t in l.teachers) {
      final k = t.teacherKuerzel?.trim();
      final raw = t.teacher?.trim();
      if (k == null || k.isEmpty || raw == null || raw.isEmpty) continue;
      final had = byK[k];
      if (had != null) {
        if (!had.subjects.contains(subject)) had.subjects.add(subject);
        continue;
      }
      final parts = raw.split(',');
      final fixed = repairWithKuerzel(raw, k);
      final own = ownNames[k]?.trim() ?? '';
      final lastName = parts.first.trim();
      byK[k] = RecipientCandidate(
        kuerzel: k,
        display: own.isNotEmpty ? own : portalNameToDisplay(fixed),
        lastName: lastName,
        knownLastName:
            ownLastName(own, lastName) ??
            (fixed == raw ? null : fixed.split(',').first.trim()),
        firstName: parts.length > 1 ? parts.sublist(1).join(',').trim() : null,
        subjects: [subject],
        searchNames: searchQueries(
          lastName,
          repaired: fixed.split(',').first.trim(),
          own: own,
        ),
      );
      order.add(k);
    }
  }
  final big = <String>[
    for (final k in order)
      if ((team[k] ?? 0) > 3) k,
  ];
  return [
    for (final k in order)
      if (!big.contains(k)) byK[k]!,
    for (final k in big) byK[k]!,
  ];
}

/// Letztes Wort des eigenen Namens, wenn es dem Portal-Nachnamen bis auf
/// „�“ gleicht („Lena Lüber“ zu „L�ber“), sonst null. Der eigene Name ist
/// eingetippt, nicht geraten – daher darf er wie eine Kürzel-Reparatur
/// zählen (isSureReceiver, Prüfbefund 10.11.26).
String? ownLastName(String own, String lastName) {
  final words = own.trim().split(RegExp(r'\s+'));
  final last = words.last;
  return last.isNotEmpty &&
          !last.contains(replacementChar) &&
          lastName.contains(replacementChar) &&
          sameNameIgnoringBroken(last, lastName)
      ? last
      : null;
}

/// Suchbegriffe für einen Nachnamen mit möglichem „�“.
///
/// Ursache (Rückmeldung 09.11.26): Das Portal schickt manche Nachnamen mit
/// „�“. Wie seine Suche (searchRecipt) solche Namen findet, ist nicht
/// belegt – mit Umlaut, mit „�“ oder gar nicht. Daher nacheinander: der
/// reparierte Nachname, der Nachname aus dem eigenen Namen (letztes Wort,
/// wenn es dem Portal-Namen bis auf „�“ gleicht), dann das längste Stück
/// ohne „�“. Treffer prüft immer [matchReceivers]; ein kurzes Stück findet
/// mehr, wählt aber nicht selbst (compose_page.dart, _toggle: nur der
/// erste Begriff darf ohne Rückfrage wählen). Grenze: Das Stück ohne „�“
/// ist breit („we“); kappt das Portal seine Trefferliste, fehlt die
/// gesuchte Lehrkraft womöglich – dann bleibt die freie Suche. Unter 2
/// Zeichen sucht die App nicht (searchTeacher in liblanis).
List<String> searchQueries(
  String lastName, {
  String? repaired,
  String own = '',
}) {
  final out = <String>[];
  void add(String q) {
    final v = q.trim();
    if (v.length >= 2 && !v.contains(replacementChar) && !out.contains(v)) {
      out.add(v);
    }
  }

  add(repaired ?? lastName);
  final ownLast = own.trim().split(RegExp(r'\s+')).last;
  if (sameNameIgnoringBroken(ownLast, lastName)) add(ownLast);
  add(lastName);
  if (lastName.contains(replacementChar)) {
    final pieces = lastName.split(replacementChar)
      ..sort((a, b) => b.trim().length.compareTo(a.trim().length));
    add(pieces.first);
  }
  return out;
}

/// Kommt [word] in [text] als ganzes Wort vor (Groß-/Kleinschreibung egal)?
///
/// Wortgrenze ist alles außer Buchstaben, Ziffern und Bindestrich. Ursache
/// (Prüfung 27.10.26): Mit `contains` traf der Nachname „Alt“ auch „Altmann“
/// und „Walther“. Der Bindestrich zählt zum Wort, damit „Alt“ nicht den
/// Doppelnamen „Bau-Alt“ trifft. Grenze: Mehrteilige Namen („von Alt“)
/// müssen als Ganzes in derselben Schreibweise (Leerzeichen) vorkommen.
/// Mit [tolerant] steht „�“ auf einer der beiden Seiten für einen Umlaut
/// u. Ä. (brokenTolerantPattern, Rückmeldung 09.11.26), sonst nur für sich.
bool _hasWord(String text, String word, {bool tolerant = true}) {
  final w = word.trim();
  if (w.isEmpty) return false;
  final body = tolerant ? brokenTolerantPattern(w) : RegExp.escape(w);
  return RegExp(
    '(^|[^\\p{L}\\p{N}\uFFFD-])$body(\$|[^\\p{L}\\p{N}\uFFFD-])',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(text);
}

/// Nachname des Portal-Treffers stimmt mit dem der Lehrkraft überein.
///
/// Steht ein Komma im Treffer, gilt die Form „Nachname, Vorname“ des Portals
/// (Lehrkraft im Unterricht: „Alt, Anna“, candidatesFrom): Dann muss der Teil
/// VOR dem Komma der ganze Nachname sein – sonst träfe „Alt“ auch „Bau, Alt“
/// (Vorname Alt). Ohne Komma („Anna Alt“) reicht der Nachname als ganzes Wort.
///
/// Verglichen wird mit dem Portal-Namen und dem reparierten Nachnamen
/// (knownLastName). [tolerant]: „�“ zählt als beliebiger Nicht-ASCII-
/// Buchstabe (sameNameIgnoringBroken) – gut für die Auswahl, aber nicht
/// eindeutig: „M�we“ passt dann auch auf „Mäwe“. Ohne [tolerant] muss der
/// Treffer genau so heißen wie im Unterricht (mit „�“ an derselben Stelle)
/// oder wie repariert (Prüfbefund 09.11.26).
bool _lastNameMatches(
  String portal,
  RecipientCandidate c, {
  bool tolerant = true,
}) {
  final names = [c.lastName, ?c.knownLastName];
  final comma = portal.indexOf(',');
  if (comma >= 0) {
    final last = portal.substring(0, comma).trim();
    return names.any(
      (n) => tolerant
          ? sameNameIgnoringBroken(last, n)
          : last.toLowerCase() == n.trim().toLowerCase(),
    );
  }
  return names.any((n) => _hasWord(portal, n, tolerant: tolerant));
}

/// Vorname (erster Teil) oder Kürzel der Lehrkraft als ganzes Wort im
/// Portal-Treffer.
bool _firstOrCodeMatches(
  String portal,
  RecipientCandidate c, {
  bool tolerant = true,
}) {
  final first = c.firstName?.trim().split(RegExp(r'\s+')).first ?? '';
  return (first.isNotEmpty && _hasWord(portal, first, tolerant: tolerant)) ||
      _hasWord(portal, c.kuerzel, tolerant: tolerant);
}

/// Passende Einträge der Portal-Suche (nachrichten.php?a=searchRecipt) zu
/// einer Lehrkraft.
///
/// Gesucht wird mit dem Nachnamen; die Treffer kommen als Text, dessen Form
/// das Portal vorgibt (nicht dokumentiert). Lehrkraft (`isTeacher`), der
/// Nachname als ganzes Wort ([_lastNameMatches]) und – bei mehreren – Vorname
/// oder Kürzel. Grenze: Ob ein einzelner Treffer ohne Rückfrage genommen
/// wird, entscheidet [isSureReceiver]; nie raten.
List<ReceiverEntry> matchReceivers(
  List<ReceiverEntry> results,
  RecipientCandidate c,
) {
  final teachers = [
    for (final r in results)
      if (r.isTeacher && _lastNameMatches(r.name, c)) r,
  ];
  if (teachers.length <= 1) return teachers;
  final narrowed = [
    for (final r in teachers)
      if (_firstOrCodeMatches(r.name, c)) r,
  ];
  return narrowed.isEmpty ? teachers : narrowed;
}

/// Darf [hit] ohne Rückfrage als Empfänger für [c] gelten?
///
/// Ursache (Prüfung 27.10.26): Der einzige Treffer wurde bisher immer
/// genommen – fand das Portal nur „Alt, Bernd“, ging die Nachricht an ihn
/// statt an Anna Alt. Jetzt nur, wenn neben dem Nachnamen auch der Vorname
/// (oder das Kürzel) passt; kennt der Unterricht keinen Vornamen, reicht der
/// ganze Nachname. Sonst fragt die Seite nach (compose_page.dart, _choose)
/// und zeigt den Namen, wie das Portal ihn nennt. Namen mit „�“ zählen hier
/// nur genau (ohne Platzhalter), siehe [_lastNameMatches].
bool isSureReceiver(ReceiverEntry hit, RecipientCandidate c) {
  if (!hit.isTeacher || !_lastNameMatches(hit.name, c, tolerant: false)) {
    return false;
  }
  final first = c.firstName?.trim() ?? '';
  if (first.isEmpty) return true;
  return _firstOrCodeMatches(hit.name, c, tolerant: false);
}
