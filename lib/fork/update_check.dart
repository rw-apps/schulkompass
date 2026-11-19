import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/fork_identity.dart' show forkReleasesApiUrl;

/// Hinweis „Neue Version verfügbar“ (Wunsch 19.11.26).
///
/// Ursache: Ein Gerät der Familie lief am 18.11. noch mit 9499 (Bericht
/// Nr. 19), acht Versionen zurück – ohne Play Store merkt niemand, dass es
/// eine neue Version gibt. Die App fragt deshalb höchstens einmal am Tag
/// bei GitHub nach der neuesten Version ([attach]) und Heute zeigt dann
/// eine Karte (ui/today/update_card.dart).
///
/// Datenschutz: Das ist die einzige Verbindung der App zu GitHub, die nicht
/// der Nutzer antippt (PRIVACY.md Abschnitt 4, Stand 19.11.26); GitHub sieht
/// dabei die IP-Adresse. Abschaltbar ([updateCheckKey]). Gesendet wird
/// nichts außer der Anfrage selbst (kein Konto, keine Version). Nie im
/// Demo-Modus und nie vor der Zustimmung: Aufrufer ist nur Heute
/// (live_today_page.dart, außerhalb der Demo) und der Schalter.
///
/// Merkpunkt (Reinhard 19.11.26): Wird die App einmal über Google Play
/// verteilt, Datenschutzhinweis und diesen Hinweis neu prüfen – Play
/// aktualisiert selbst (die Abfrage wäre dann überflüssig oder nur für
/// APK-Nutzer), und Play verlangt eigene Datenschutzangaben.
class UpdateCheck extends ChangeNotifier {
  UpdateCheck._();
  static final instance = UpdateCheck._();

  /// Neueste bekannte Release-Nummer (9517), auch aus dem letzten Abruf
  /// gespeichert – die Karte erscheint also auch offline.
  int? get latest => _latest;
  int? _latest;

  TypedSettings? _settings;
  bool _running = false;

  /// Abruf über die öffentliche Schnittstelle, ohne Anmeldung (60 Anfragen
  /// je Stunde und IP – bei einem Abruf am Tag auch für ~40 Geräte hinter
  /// einem Anschluss kein Thema, Rückfrage 19.11.26).
  static const releaseApi = '$forkReleasesApiUrl/latest';

  /// Mit Einstellungen verbinden und – wenn erlaubt und seit 20 Stunden
  /// nicht versucht – nachsehen. 20 statt 24 Stunden: Wer die App jeden Tag
  /// zur selben Zeit öffnet, soll trotzdem täglich einen Abruf bekommen.
  /// Auch ein gescheiterter Versuch zählt (Prüfbefund 19.11.26: sonst fragte
  /// die App bei Störung bei jedem Öffnen von Heute erneut – mehr als „einmal
  /// am Tag“, wie PRIVACY.md sagt). Fehler bleiben still: Der Hinweis ist
  /// eine Bequemlichkeit, kein Pflichtweg.
  Future<void> attach(
    TypedSettings s, {
    DateTime? now,
    Future<String?> Function()? fetchTag,
  }) async {
    _settings = s;
    _set(int.tryParse(s.getString(_latestKey) ?? ''));
    if (!updateCheckEnabled(s) || _running) return;
    final t = now ?? DateTime.now();
    final last = DateTime.tryParse(s.getString(_checkedKey) ?? '');
    // Liegt der letzte Versuch in der Zukunft (Uhr war falsch gestellt),
    // gilt er nicht – sonst fragte die App tagelang nie.
    if (last != null &&
        !last.isAfter(t) &&
        t.difference(last) < const Duration(hours: 20)) {
      return;
    }
    _running = true;
    s.setString(_checkedKey, t.toIso8601String());
    try {
      final tag = await (fetchTag ?? _fetchTag)();
      final build = tag == null ? null : releaseBuild(tag);
      if (build != null) {
        s.setString(_latestKey, '$build');
        _set(build);
      }
    } catch (_) {
      // still – nächster Versuch frühestens in 20 Stunden.
    } finally {
      _running = false;
    }
  }

  void _set(int? v) {
    if (v == _latest) return;
    _latest = v;
    notifyListeners();
  }

  Future<String?> _fetchTag() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    try {
      final r = await dio.get<Map<String, dynamic>>(releaseApi);
      final tag = r.data?['tag_name'];
      return tag is String ? tag : null;
    } finally {
      dio.close();
    }
  }

  /// Karte für 7 Tage wegklicken („Später“), auch wenn inzwischen eine
  /// neuere Version erscheint. Ursache (Rückfrage 19.11.26, ~40 Nutzer):
  /// Es gibt oft mehrere Versionen am Tag; „bis zur nächsten Version“
  /// hätte fast täglich erneut gefragt.
  void dismiss({DateTime? now}) {
    final until = (now ?? DateTime.now()).add(const Duration(days: 7));
    _settings?.setString(_dismissedKey, until.toIso8601String());
    notifyListeners();
  }

  /// Schalter „Nach neuen Versionen suchen“; aus blendet eine sichtbare
  /// Karte sofort aus (Prüfbefund 19.11.26).
  /// [fetch] false im Demo-Modus: dort darf keine Anfrage das Gerät
  /// verlassen (about_page.dart, Prüfbefund 19.11.26).
  void setEnabled(TypedSettings s, bool on, {bool fetch = true}) {
    setUpdateCheck(s, on);
    notifyListeners();
    if (on && fetch) attach(s);
  }

  /// Zu zeigende neue Version, sonst null.
  ///
  /// Abgesichert: Nach einem Wechsel der Datenbank (Demo verlassen,
  /// main.dart _relaunch) könnte [_settings] schon geschlossen sein, bevor
  /// [attach] neu verbindet – dann lieber keine Karte als ein Fehlerbild
  /// auf Heute (Prüfbefund 19.11.26).
  int? offer(String installedVersion, {DateTime? now}) {
    final s = _settings;
    final l = _latest;
    final mine = installedBuild(installedVersion);
    if (s == null || l == null || mine == null || l <= mine) return null;
    try {
      if (!updateCheckEnabled(s)) return null;
      final until = DateTime.tryParse(s.getString(_dismissedKey) ?? '');
      if (until != null && (now ?? DateTime.now()).isBefore(until)) {
        return null;
      }
    } catch (_) {
      return null;
    }
    return l;
  }

  @visibleForTesting
  void reset() {
    _settings = null;
    _running = false;
    _latest = null;
  }
}

const updateCheckKey = 'fork-update-check';
const _checkedKey = 'fork-update-checked';
const _latestKey = 'fork-update-latest';
const _dismissedKey = 'fork-update-dismissed';

/// Nach neuen Versionen suchen (Standard: an).
bool updateCheckEnabled(TypedSettings s) => s.getString(updateCheckKey) != '0';

void setUpdateCheck(TypedSettings s, bool on) =>
    s.setString(updateCheckKey, on ? '1' : '0');

/// Release-Nummer aus dem Tag („v4.1.0+9517“ → 9517).
int? releaseBuild(String tag) {
  final m = RegExp(r'\+(\d+)$').firstMatch(tag.trim());
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Release-Nummer der installierten App aus dem Versionsnamen
/// („4.1.0+9517“, appVersionLabel; android/app/build.gradle versionName).
/// Grenze: Nicht aus PackageInfo.buildNumber – das ist auf Android der
/// versionCode mit ABI-Aufschlag (11517, fork_identity.dart).
int? installedBuild(String versionLabel) => releaseBuild(versionLabel);
