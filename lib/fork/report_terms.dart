import 'dart:convert';
import 'dart:io';

import 'error_log.dart';

/// Unbekannte Fachbegriffe der Schule und Kontext ohne Namen (pseudonym) für die
/// automatischen Fehlerberichte (Zustimmung ab [autoReportScopeTerms],
/// report_relay.dart).
///
/// Ursache (Wunsch 08.11.26, Beleg Freisetzung 06.11.26): Die App meldete
/// nur, was sie selbst als Fehler erkennt. Eine Seite, die sie fehlerfrei
/// liest, aber falsch deutet – „Freisetzung“ galt als Ausfall –, fiel erst
/// durch ein Bildschirmfoto auf. Jede Schule füllt feste Spalten mit eigenen
/// Wörtern; bei neuen Schulen ist das das Hauptrisiko.
///
/// Was erfasst wird: Bereich, Spalte und das eine Wort, das die App nicht
/// kennt – aus der Spalte „Art“ des Vertretungsplans, den Spaltenköpfen der
/// Anwesenheit einer Kursmappe und den Kategorien des Kalenders. Diese
/// Spalten füllt die Schule mit ihren Wörtern; „Art“ ist dabei Freitext der
/// Schule (classifySubstitution), aber kein Text über ein Kind.
///
/// Bewusst NICHT (Prüfung 08.11.26): der Vermerk einer Stunde in der
/// Kursmappe („krank“, „beurlaubt“ – ein Wert über das Kind, womöglich
/// Gesundheit), Namen von Modulen aus der App-Liste (die Schule vergibt sie
/// frei, z. B. mit Schulnamen; Module stehen nur als Dateiname im Kontext),
/// Freitext-Spalten (Hinweis, Thema). Grenze: [safeTerm] filtert Ziffern,
/// Kommas, Anreden und Kürzel in Großbuchstaben; ein Wort, das eine Schule
/// wie einen Namen ohne Anrede schreibt („Sprechstunde Weber“), kommt
/// trotzdem durch – daher „pseudonym“, nicht „anonym“ im Datenschutzhinweis.
class TermLog {
  TermLog._();

  static final instance = TermLog._();

  /// Höchstens so viele Begriffe; ältere fallen aus der Liste, bleiben aber
  /// in [_seen] – sonst kämen sie beim nächsten Zeichnen wieder hinein und
  /// verdrängten einen anderen (Prüfung 08.11.26: Schleife mit Schreiben im
  /// UI-Thread und einem Bericht je Start). Grenze: Ein verdrängter Begriff
  /// wird bis zum nächsten Start nicht erneut erfasst.
  static const maxTerms = 40;

  File? _file;
  final List<TermEntry> _entries = [];
  final Set<String> _seen = {};

  List<TermEntry> get entries => List.unmodifiable(_entries);

  /// Neben fork_errors.json (lanis_bootstrap.dart).
  void attach(File file) {
    _file = file;
    final pending = List.of(_entries);
    _entries.clear();
    _seen.clear();
    try {
      if (file.existsSync()) {
        final v = jsonDecode(file.readAsStringSync());
        if (v is List) {
          for (final j in v.whereType<Map<String, dynamic>>()) {
            final e = TermEntry.fromJson(j);
            if (_seen.add(e.key)) _entries.add(e);
          }
        }
      }
    } catch (_) {}
    for (final e in pending) {
      if (_seen.add(e.key)) _entries.add(e);
    }
    _save();
  }

  /// Unbekanntes Wort [raw] aus Spalte [column] im Bereich [area] (fester
  /// Name aus dem Code) merken. Jedes Wort nur einmal, unabhängig von der
  /// Version; kein Schreiben, wenn es schon bekannt ist (Aufrufe kommen beim
  /// Zeichnen).
  void note(String area, String column, String? raw) {
    if (ErrorLog.instance.muted) return;
    final w = safeTerm(raw);
    if (w == null) return;
    final e = TermEntry(
      version: ErrorLog.instance.version,
      area: area,
      column: column,
      word: w,
      first: DateTime.now(),
    );
    if (!_seen.add(e.key)) return;
    _entries.insert(0, e);
    if (_entries.length > maxTerms) {
      _entries.removeRange(maxTerms, _entries.length);
    }
    _save();
  }

  void clear() {
    _entries.clear();
    _seen.clear();
    _save();
  }

  void _save() {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode([for (final e in _entries) e.toJson()]));
    } catch (_) {}
  }
}

class TermEntry {
  const TermEntry({
    required this.version,
    required this.area,
    required this.column,
    required this.word,
    required this.first,
  });

  factory TermEntry.fromJson(Map<String, dynamic> j) => TermEntry(
    version: '${j['version'] ?? ''}',
    area: '${j['area'] ?? ''}',
    column: '${j['column'] ?? ''}',
    word: '${j['word'] ?? ''}',
    first: DateTime.tryParse('${j['first']}') ?? DateTime(2000),
  );

  final String version;
  final String area;
  final String column;
  final String word;
  final DateTime first;

  /// Ohne Version (Prüfung 08.11.26): Sonst galt nach jedem Update jeder
  /// Begriff als neu – ein Bericht je Nutzer und Update.
  String get key => '$area|$column|${word.toLowerCase()}';

  Map<String, dynamic> toJson() => {
    'version': version,
    'area': area,
    'column': column,
    'word': word,
    'first': first.toIso8601String(),
  };
}

/// Darf [raw] als Fachbegriff gemeldet werden? Getrimmt, Leerraum
/// zusammengefasst; 2–30 Zeichen, nur Buchstaben (auch Umlaute), Leerzeichen,
/// Bindestrich, Punkt, Schrägstrich; höchstens drei Wörter. Ursache: Ziffern
/// würden Klassen und Räume („9C“, „M103“) durchlassen, Kommas Namen im
/// Portalformat („Nachname, Vorname“). Dazu kein Wort mit Anrede („Hr.“,
/// „Frau“) und keins, das wie ein Lehrerkürzel aussieht (2–4 Großbuchstaben,
/// „MÜL“; Prüfung 08.11.26). Grenze: Ein Kürzel in gemischter Schreibung
/// kommt durch. null = nicht melden.
String? safeTerm(String? raw) {
  final w = (raw ?? '').trim().replaceAll(_space, ' ');
  if (w.length < 2 || w.length > 30) return null;
  if (!_termShape.hasMatch(w)) return null;
  final words = w.split(' ');
  if (words.length > 3) return null;
  for (final x in words) {
    if (_honorific.hasMatch(x) || _kuerzel.hasMatch(x)) return null;
  }
  return w;
}

final _space = RegExp(r'\s+');
final _termShape = RegExp(r'^[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß .\-/]*$');
final _honorific = RegExp(r'^(herr|frau|hr|fr)\.?$', caseSensitive: false);
final _kuerzel = RegExp(r'^[A-ZÄÖÜ]{2,4}\.?$');

/// Kontext je Konto ohne Namen (Zustimmung ab [autoReportScopeTerms]):
/// Kontoart, Zahl der Kinder, angebotene Module (Dateinamen wie
/// „kalender“), Gerätesprache. Ursache (Wunsch 08.11.26): Beim Fehler mit
/// dem zweiten Kind im Elternkonto hätte das einen Export erspart. Grenze:
/// nie Schule, Schulnummer, Namen; Konten heißen im Bericht nur „Konto 1,
/// 2 …“ in der Reihenfolge, in der sie geladen wurden. Die Module machen
/// eine Schule wiedererkennbar – daher „pseudonym“ im Datenschutzhinweis.
///
/// In einer Datei gespeichert ([attach]). Ursache (Prüfung 08.11.26): Der
/// Bericht beim Start (PreviewShell) geht vor dem ersten Laden raus; nur im
/// Speicher stand dann nie eine Zeile „Konto N“ darin.
class ReportContext {
  ReportContext._();

  static final instance = ReportContext._();

  final Map<int, String> _lines = {};
  final List<int> _order = [];
  String language = '';
  File? _file;

  void attach(File file) {
    _file = file;
    try {
      if (!file.existsSync()) return;
      final v = jsonDecode(file.readAsStringSync());
      if (v is! List) return;
      for (final j in v.whereType<Map<String, dynamic>>()) {
        final a = j['a'], l = j['l'];
        if (a is! int || l is! String || _order.contains(a)) continue;
        _order.add(a);
        _lines[a] = l;
      }
    } catch (_) {}
  }

  void clear() {
    _lines.clear();
    _order.clear();
    _save();
  }

  void _save() {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(
        jsonEncode([
          for (final a in _order)
            if (_lines[a] case final l?) {'a': a, 'l': l},
        ]),
      );
    } catch (_) {}
  }

  void update({
    required int account,
    required String type,
    required int kids,
    required Iterable<String> modules,
  }) {
    if (ErrorLog.instance.muted) return;
    if (!_order.contains(account)) _order.add(account);
    final mods = [for (final m in modules) ?safeTerm(m.replaceAll('.php', ''))]
      ..sort();
    final line = [
      type,
      if (kids > 0) '$kids Kind${kids == 1 ? '' : 'er'}',
      if (mods.isNotEmpty) 'Module: ${mods.join(', ')}',
    ].join(' · ');
    if (_lines[account] == line) return;
    _lines[account] = line;
    _save();
  }

  /// Zeilen für den Bericht; leer, wenn nichts bekannt ist.
  List<String> lines() => [
    if (language.isNotEmpty) 'Gerätesprache: $language',
    for (final (i, a) in _order.indexed)
      if (_lines[a] case final l?) 'Konto ${i + 1}: $l',
  ];
}

/// Zustimmung, die Begriffe und Kontext einschließt (report_relay.dart,
/// autoReportScopeKey). 1 = nur Fehlerprotokoll (bis 9501).
const autoReportScopeTerms = 2;

/// Abschnitt für den Bericht: Kontext und Begriffe.
String termsReport({TermLog? log, ReportContext? context}) {
  final ctx = (context ?? ReportContext.instance).lines();
  final terms = (log ?? TermLog.instance).entries;
  if (ctx.isEmpty && terms.isEmpty) return '';
  final b = StringBuffer();
  if (ctx.isNotEmpty) {
    b.writeln();
    b.writeln('Kontext (ohne Namen):');
    for (final l in ctx) {
      b.writeln(l);
    }
  }
  if (terms.isNotEmpty) {
    b.writeln();
    b.writeln('Unbekannte Begriffe:');
    for (final e in terms) {
      b.writeln('${e.version} · ${e.area} · ${e.column} · ${e.word}');
    }
  }
  return b.toString();
}

/// Nach jedem vollen Durchgang (live_data.dart, _run): Kontext des Kontos
/// aktualisieren und unbekannte Kategorien im Kalender melden. Module nur
/// als Dateiname im Kontext, nie als Begriff (Prüfung 08.11.26: Namen
/// vergibt die Schule frei, auch mit Schulnamen; als Begriffe kam außerdem
/// fast jedes Konto über die Grenze von [TermLog.maxTerms]).
///
/// [knownCategory]: Kategorie, die die App deutet (PortalRules, frei/
/// Arbeit/übersprungen). [modules]: Einträge der App-Liste des Portals
/// (Session.travelMenu; nur `link` als Dateiname).
void noteLoadTerms({
  required int account,
  required String type,
  required int kids,
  required List<dynamic> modules,
  required Iterable<String> categories,
  required bool Function(String lower) knownCategory,
  TermLog? log,
  ReportContext? context,
}) {
  final l = log ?? TermLog.instance;
  final links = <String>[
    for (final m in modules)
      if (m is Map)
        ?RegExp(r'^([a-z_]+)\.php$').firstMatch('${m['link'] ?? ''}')?.group(1),
  ];
  (context ?? ReportContext.instance).update(
    account: account,
    type: type,
    kids: kids,
    modules: links,
  );
  for (final c in categories.toSet()) {
    if (c.trim().isEmpty || knownCategory(c.toLowerCase())) continue;
    l.note('kalender.php', 'Kategorie', c);
  }
}

/// Alles auf dem Gerät Gesammelte für Berichte löschen (Erkannte Probleme →
/// Löschen, error_report_page.dart).
void clearReportExtras() {
  TermLog.instance.clear();
  ReportContext.instance.clear();
}
