import 'package:liblanis/liblanis.dart';

import 'ui/plan/plan_model.dart' show portalNameToDisplay;

/// Ersatzzeichen, das das Portal selbst statt eines Umlauts schickt.
const replacementChar = '�';

final _letter = RegExp(r'^\p{L}$', unicode: true);

bool _nonAsciiLetter(String c) =>
    c.codeUnitAt(0) >= 0x80 && _letter.hasMatch(c);

/// Nachname im Portal-Namen „Nachname, Vorname“ mit dem Kürzel reparieren.
///
/// Ursache (Rückmeldung 09.11.26, Bildschirmfoto der Portalseite im
/// Browser): Das Portal schickt bei manchen Lehrkräften selbst „�“ statt des
/// Umlauts („M�we, Anna“), das Kürzel derselben Lehrkraft aber richtig
/// („Mö“). Der Decoder (portal_decoder.dart) kann das nicht retten, weil
/// das Zeichen schon beim Portal kaputt ist.
///
/// Regel: Das Kürzel muss Buchstabe für Buchstabe der Anfang des Nachnamens
/// sein (Groß-/Kleinschreibung egal). Steht an einer Stelle „�“ und im
/// Kürzel dort ein Nicht-ASCII-Buchstabe, kommt er hinein. Mindestens ein
/// weiterer Buchstabe muss übereinstimmen – sonst wäre es geraten. Beginnt
/// der Vorname mit einem Buchstaben, der im Kürzel hinter der ersten Stelle
/// steht, könnte das Kürzel „Nachname + Vorname“ sein („YÜ“ für „Y�lmaz,
/// Ümit“, Prüfbefund 09.11.26) – dann nicht. Das sperrt auch harmlose
/// Fälle („K�hn, Hans“ mit „KÜH“); lieber „�“ als ein falscher Umlaut.
/// Grenzen: Kürzel nach anderem Schema („ABC“, „ae“ statt „ä“) und „�“
/// hinter dem Kürzel bzw. im Vornamen bleiben, wie sie sind; dafür gibt es
/// den eigenen Namen (PlanPage „Name eintragen“).
String repairWithKuerzel(String portal, String? kuerzel) {
  if (!portal.contains(replacementChar)) return portal;
  final kz = kuerzel?.trim() ?? '';
  if (kz.length < 2) return portal;
  final comma = portal.indexOf(',');
  final head = comma < 0 ? portal : portal.substring(0, comma);
  final first = comma < 0 ? '' : portal.substring(comma + 1).trim();
  final lead = head.length - head.trimLeft().length;
  final last = head.trim();
  if (kz.length > last.length) return portal;
  if (first.isNotEmpty &&
      kz.substring(1).toLowerCase().contains(first[0].toLowerCase())) {
    return portal;
  }
  // Nachname ganz in Großbuchstaben („M�WE“) bekommt einen großen Umlaut.
  final upper = last == last.toUpperCase();
  final fixed = last.split('');
  var confirmed = 0;
  var changed = false;
  for (var i = 0; i < kz.length; i++) {
    final k = kz[i];
    final s = last[i];
    if (s == replacementChar) {
      if (!_nonAsciiLetter(k)) return portal;
      // Kein Name beginnt mit „ß“. Eigens geprüft: Ohne diese Zeile setzte
      // Dart „ß“ groß unverändert ein (Test „kein Raten“, 09.11.26).
      if (i == 0 && k.toLowerCase() == 'ß') return portal;
      final c = i == 0 || upper ? k.toUpperCase() : k.toLowerCase();
      if (c.length != 1) return portal;
      fixed[i] = c;
      changed = true;
    } else if (s.toLowerCase() == k.toLowerCase()) {
      confirmed++;
    } else {
      return portal;
    }
  }
  if (!changed || confirmed == 0) return portal;
  return portal.substring(0, lead) +
      fixed.join() +
      portal.substring(lead + last.length);
}

/// Gleich bis auf „�“: dieselbe Länge, jedes Zeichen gleich
/// (Groß-/Kleinschreibung egal) oder auf einer Seite „�“ und auf der
/// anderen ein Nicht-ASCII-Zeichen – das Portal zerstört nur solche.
/// Grenze: Namen in zerlegter Unicode-Form (NFD) haben eine andere Länge
/// und passen nie.
bool sameNameIgnoringBroken(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] == y[i]) continue;
    final other = x[i] == replacementChar
        ? y[i]
        : (y[i] == replacementChar ? x[i] : null);
    if (other == null || other.codeUnitAt(0) < 0x80) return false;
  }
  return true;
}

/// Regulärer Ausdruck für [word], in dem „�“ (in [word] oder im Text) für
/// einen Nicht-ASCII-Buchstaben steht. ASCII-Buchstaben bleiben fest, weil
/// das Portal nur Umlaute u. Ä. zerstört.
String brokenTolerantPattern(String word) {
  final b = StringBuffer();
  for (final c in word.split('')) {
    if (c == replacementChar) {
      b.write('[^\\x00-\\x7F]');
    } else if (_nonAsciiLetter(c)) {
      b.write('(?:${RegExp.escape(c)}|$replacementChar)');
    } else {
      b.write(RegExp.escape(c));
    }
  }
  return b.toString();
}

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

class _Learned {
  _Learned(this.lessons, this.ownNames, this.whole);
  final Lessons lessons;
  final Map<String, String> ownNames;
  final Map<String, String> whole;
}

/// Gelernte ganze Namen für Stellen, an denen das Portal nur den Namen
/// zeigt (Absender in „Nachrichten“, Verfasser im Verlauf).
///
/// Ursache (Rückmeldung 09.11.26): Absender erscheinen mit „�“, obwohl die
/// App dieselbe Lehrkraft über das Kürzel ([repairWithKuerzel]) oder einen
/// eigenen Namen kennt. Gelernt wird je Lehrkraft aus „Mein Unterricht“:
/// Portal-Name in beiden Formen („M�we, Anna“, „Anna M�we“) → eigener Name,
/// sonst → reparierter Name.
///
/// Nie raten: Nur GANZE Namen werden ersetzt, keine einzelnen Wörter – ein
/// „M�ller“ kann bei einer anderen Person „Möller“ heißen (Prüfbefund
/// 09.11.26). Ein Name mit zwei Lösungen (über Lehrkräfte oder Konten
/// hinweg) wird gar nicht ersetzt.
/// Grenzen: [global] mischt alle Konten, weil der Verlauf (liblanis,
/// authorNameHook) sein Konto nicht kennt – dieselbe Schreibweise an zwei
/// Schulen gilt als dieselbe Person. Absender ohne Kurs beim Kind
/// (Schulleitung, Sekretariat) und Namen in anderer Form („Herr M�we“)
/// bleiben, wie sie sind. Abgemeldete Konten bleiben bis zum Neustart.
class NameRepairs {
  NameRepairs();

  /// Für alle Konten; gefüllt von live_data.dart bei jedem Aufbau.
  static final global = NameRepairs();

  final _byAccount = <String, _Learned>{};
  Map<String, String> _whole = const {};

  /// Lernt neu für [account] aus dessen Kursen und eigenen Namen. Gleiche
  /// Eingaben (identical) kosten nichts.
  void learnFor(String account, Lessons lessons, Map<String, String> ownNames) {
    final had = _byAccount[account];
    if (had != null &&
        identical(had.lessons, lessons) &&
        identical(had.ownNames, ownNames)) {
      return;
    }
    final whole = <String, Set<String>>{};
    for (final l in lessons) {
      for (final t in l.teachers) {
        final raw = _norm(t.teacher ?? '');
        if (raw.isEmpty) continue;
        final kz = t.teacherKuerzel?.trim() ?? '';
        final own = ownNames[kz]?.trim() ?? '';
        final fixed = repairWithKuerzel(raw, kz);
        if (own.isEmpty && fixed == raw) continue;
        for (final (from, to) in [
          (raw, own.isNotEmpty ? own : fixed),
          (
            _norm(portalNameToDisplay(raw)),
            own.isNotEmpty ? own : portalNameToDisplay(fixed),
          ),
          if (own.isNotEmpty) ...[
            (fixed, own),
            (_norm(portalNameToDisplay(fixed)), own),
          ],
        ]) {
          if (from != to) (whole[from] ??= {}).add(to);
        }
      }
    }
    _byAccount[account] = _Learned(lessons, ownNames, _unique(whole));
    _merge();
  }

  /// Der gelernte Name zu [text], sonst [text] unverändert. Mit [account]
  /// nur aus dessen Kursen und eigenen Namen (Nachrichtenliste kennt ihr
  /// Konto, der Verlauf nicht).
  String apply(String text, {int? account}) {
    final map = account == null
        ? _whole
        : (_byAccount['$account']?.whole ?? const {});
    return map[_norm(text)] ?? text;
  }

  void _merge() {
    final whole = <String, Set<String>>{};
    for (final l in _byAccount.values) {
      l.whole.forEach((k, v) => (whole[k] ??= {}).add(v));
    }
    _whole = _unique(whole);
  }

  static Map<String, String> _unique(Map<String, Set<String>> m) => {
    for (final e in m.entries)
      if (e.value.length == 1) e.key: e.value.single,
  };
}
