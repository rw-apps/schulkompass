import 'dart:convert';

import 'school_links.dart' show normalizeMensaUrl;

/// Mensa-Bestellseite je Kind und Bestellwoche – reine Funktionen, ohne
/// Portal testbar (test/fork/mensa_test.dart).
///
/// Ursache (Wunsch 17.10.26): Eine Adresse je Konto reichte nicht, weil jedes
/// Kind beim Caterer ein eigenes Konto haben kann. Der Name des Caterers steht
/// bewusst nirgends im Code (öffentliches Repository) – die Familie trägt die
/// Adresse selbst ein.

/// Schlüssel eines Kindes: Schüler-ID des Elternkontos, '' im Schülerkonto
/// (bzw. solange die Kinder noch nicht geladen sind).
typedef MensaKidKey = String;

/// Gespeicherte Adressen je Kind (JSON {kidKey: url}).
///
/// [legacy] ist die bisherige eine Adresse je Konto (bis 9341); sie gilt für
/// jedes Kind ohne eigene Adresse weiter, damit nach dem Update nichts fehlt.
class MensaAddresses {
  const MensaAddresses(this.byKid, {this.legacy});

  factory MensaAddresses.decode(String? json, {String? legacy}) {
    final out = <String, String>{};
    try {
      final v = json == null || json.isEmpty ? null : jsonDecode(json);
      if (v is Map) {
        for (final e in v.entries) {
          final url = normalizeMensaUrl('${e.value}');
          if (url != null) out['${e.key}'] = url;
        }
      }
    } catch (_) {
      // Unlesbar – wie leer behandeln, die Familie trägt neu ein.
    }
    return MensaAddresses(out, legacy: normalizeMensaUrl(legacy));
  }

  final Map<MensaKidKey, String> byKid;
  final String? legacy;

  /// Adresse für das Kind: eigene, sonst die ohne Kind gespeicherte, sonst
  /// die alte Kontoadresse.
  String? of(MensaKidKey kid) => byKid[kid] ?? byKid[''] ?? legacy;

  /// Hat das Kind eine eigene Adresse (nicht nur geerbt)?
  bool ownFor(MensaKidKey kid) => byKid.containsKey(kid);

  /// Neue Adresse; null/leer löscht den Eintrag des Kindes. Ungültige
  /// Adressen ändern nichts (die Oberfläche meldet sie vorher).
  MensaAddresses withUrl(MensaKidKey kid, String? raw) {
    final next = {...byKid};
    final url = normalizeMensaUrl(raw);
    if (raw == null || raw.trim().isEmpty) {
      // Geerbte Adresse löschen = die gemeinsame ('' bzw. alte Kontoadresse)
      // löschen; sonst käme sie sofort als „geerbt“ zurück. Grenze: Andere
      // Kinder, die sie ebenfalls erbten, verlieren sie mit.
      final inherited = !next.containsKey(kid);
      next.remove(kid);
      if (inherited) next.remove('');
      return MensaAddresses(
        next,
        legacy: inherited || next.isEmpty ? null : legacy,
      );
    }
    if (url == null) return this;
    next[kid] = url;
    return MensaAddresses(next, legacy: legacy);
  }

  String encode() => jsonEncode(byKid);
}

/// ISO-Kalenderwoche (Montag als Wochenbeginn, Woche 1 enthält den ersten
/// Donnerstag) samt ISO-Jahr – am Jahreswechsel weicht es vom Kalenderjahr ab
/// (29.12.2025 gehört zu 2026/1).
({int year, int week}) isoWeek(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final first = DateTime.utc(thursday.year, 1, 1);
  final week = thursday.difference(first).inDays ~/ 7 + 1;
  return (year: thursday.year, week: week);
}

/// Woche, für die man bestellt: die laufende; ab Freitag 12 Uhr und am
/// Wochenende die nächste.
///
/// Ursache: Zum Wochenende ist die laufende Woche gegessen, geplant wird die
/// kommende. Grenze: Bestellfristen des Caterers kennt die App nicht – die
/// Seite zeigt sie selbst, und man kann dort jederzeit die Woche wechseln.
({int year, int week}) mensaOrderWeek(DateTime now) {
  final next =
      now.weekday >= DateTime.saturday ||
      (now.weekday == DateTime.friday && now.hour >= 12);
  return isoWeek(next ? DateTime(now.year, now.month, now.day + 7) : now);
}

/// Ersetzt eine fest eingetragene Woche „/JJJJ/WW/“ in der Adresse durch die
/// Bestellwoche – auch im Rücksprung nach der Anmeldung („?next=/…/2025/35/“,
/// roh oder als %2F kodiert).
///
/// Ursache: Die kopierte Adresse enthielt die Woche des Kopierens; ohne
/// Ersetzen öffnete die App ewig dieselbe alte Woche. Grenze: Nur das Muster
/// Jahr/Woche mit Schrägstrichen; andere Schreibweisen bleiben unverändert.
String mensaWeekUrl(String url, DateTime now) =>
    mensaUrlForWeek(url, mensaOrderWeek(now));

/// Adresse für die Kalenderwoche [w]: „/JJJJ/WW/“ bzw. „week=JJJJ_WW“
/// ersetzt. Grenze: Ohne eines der Muster bleibt die Adresse unverändert –
/// die Seite zeigt dann ihre eigene Standardwoche.
String mensaUrlForWeek(String url, ({int year, int week}) w) {
  final param = RegExp(r'([?&]week=)(20\d{2})_(\d{1,2})');
  if (param.hasMatch(url)) {
    return url.replaceAllMapped(param, (m) => '${m[1]}${w.year}_${w.week}');
  }
  final re = RegExp(
    r'(/|%2F)(20\d{2})(/|%2F)(\d{1,2})(?=/|%2F|$|\?|&|#)',
    caseSensitive: false,
  );
  return url.replaceAllMapped(re, (m) {
    final week = int.parse(m[4]!);
    if (week < 1 || week > 53) return m[0]!;
    return '${m[1]}${w.year}${m[3]}${w.week}';
  });
}

/// Darf die eingebettete Seite zu [target] wechseln? Nur https und nur zur
/// eingetragenen Seite (gleicher Host oder dessen Unterdomain) bzw. deren
/// Hauptdomain.
///
/// Ursache: Die Seite läuft mit gespeicherter Anmeldung in der App; fremde
/// Links (Zahlungsanbieter, Hilfe, Werbung) öffnen im Browser, damit dort
/// niemand eine echt wirkende Anmeldemaske in der App zeigen kann. Grenze:
/// Leitet der Caterer zur Anmeldung auf eine fremde Domain um, öffnet sie
/// im Browser – dann dort anmelden.
bool mensaAllows(Uri home, Uri target) {
  if (target.scheme != 'https' || target.userInfo.isNotEmpty) return false;
  final base = _registrable(home.host);
  final h = target.host.toLowerCase();
  return h == base || h.endsWith('.$base');
}

/// Dieselbe Seite eines Caterers? Gleiche Hauptdomain wie bei [mensaAllows]
/// („www.“ und Unterdomains zählen nicht als Wechsel).
///
/// Ursache (Rückmeldung 01.11.26, Tablet): Gemerkte Wochen, Anmeldung und
/// Bestellung eines Kindes gehören zur Seite, auf der sie gelesen bzw.
/// eingegeben wurden. War für ein Kind kurz die Adresse des Geschwisters
/// eingetragen, blieben dessen Wochen auch nach dem Korrigieren unter dem
/// Kind stehen – „Essen“ zeigte die Übersicht des Geschwisters, und
/// Bestellen lief gegen dessen Seite ins Leere. Grenze: Teilen sich zwei
/// Caterer eine Plattform unter derselben Domain, gelten sie als eine Seite.
bool mensaSameSite(String? a, String? b) {
  final x = Uri.tryParse(a?.trim() ?? '')?.host ?? '';
  final y = Uri.tryParse(b?.trim() ?? '')?.host ?? '';
  return x.isNotEmpty && y.isNotEmpty && _registrable(x) == _registrable(y);
}

/// Derselbe Host bis auf ein führendes „www.“?
///
/// Für das Einsetzen gemerkter Zugangsdaten (mensa_login.dart). Ursache
/// (unabhängige Prüfung 02.11.26): 9465 ließ dafür die ganze Hauptdomain
/// gelten (mensaSameSite) – auf Plattformen mit Mandanten als Unterdomain
/// (mandant.plattform.de) wären Zugangsdaten in die Maske eines anderen
/// Mandanten geraten. Grenze: Leitet ein Caterer auf eine andere Unterdomain
/// als „www.“ um, setzt die App den Zugang dort nicht ein (Anmeldeseite wie
/// ohne gemerkten Zugang).
bool mensaSameHost(String? a, String? b) {
  String h(String? u) {
    final x = (Uri.tryParse(u?.trim() ?? '')?.host ?? '').toLowerCase();
    return x.startsWith('www.') ? x.substring(4) : x;
  }

  final x = h(a), y = h(b);
  return x.isNotEmpty && x == y;
}

/// Andere Bestellseite als vorher (Anmeldung und Wochen gehören dann nicht
/// mehr dazu)? Anderer Host (bis auf „www.“) oder anderer erster Pfadteil –
/// auf Plattformen mit Mandanten im Pfad („/mandant/…“) ist das ein anderes
/// Kundenkonto. Ursache (unabhängige Prüfung 02.11.26): 9465 erkannte einen
/// Mandantenwechsel nur für Caterer aus dem Katalog. Grenze: Wechselt man
/// beim selben Caterer von der Anmelde- zur Wochenseite (anderer erster
/// Pfadteil), gilt auch das als Wechsel – dann fragt die App einmal neu nach
/// der Anmeldung.
bool mensaOtherPage(String? before, String? after) {
  if (before == null || after == null) return before != after;
  if (!mensaSameHost(before, after)) return true;
  String first(String u) {
    final segs = Uri.tryParse(u.trim())?.pathSegments ?? const <String>[];
    return segs.where((x) => x.isNotEmpty).firstOrNull?.toLowerCase() ?? '';
  }

  return first(before) != first(after);
}

/// Schlüssel einer Seite für „wer war zuletzt angemeldet“ (mensaLastOwner):
/// die Hauptdomain. Ursache (unabhängige Prüfung 02.11.26): Geführt wurde
/// der genaue Host der eingetragenen Adresse, geprüft beim Bestellen aber der
/// Host der Wochenseite nach der Umleitung („www.“) – dort stand niemand,
/// und der Runner bestellte in der Sitzung, die gerade lief (womöglich die
/// des Geschwisters). Die Hauptdomain ist auch der Bereich, in dem die
/// eingebetteten Ansichten Cookies teilen können.
String mensaSiteKey(String hostOrUrl) {
  final t = hostOrUrl.trim();
  final host = t.contains('://') ? (Uri.tryParse(t)?.host ?? t) : t;
  return _registrable(host);
}

/// Hauptdomain aus den letzten zwei Teilen („www.bestellung.example.de“ →
/// „example.de“). Grenze: zweiteilige Endungen (co.uk) gelten als Domain –
/// für deutsche Caterer ohne Belang, dann nur strenger.
String _registrable(String host) {
  final p = host.toLowerCase().split('.');
  return p.length <= 2 ? p.join('.') : p.sublist(p.length - 2).join('.');
}
