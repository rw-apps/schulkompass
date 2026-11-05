import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' show parse;
import 'package:liblanis/liblanis.dart';

import 'absence_form.dart';

/// Modul „Abwesenheiten“ (Krankmeldung), das liblanis nicht kennt.
///
/// Beleg: App-Liste von Schule A für Eltern (Export 16.10.26)
/// enthält `abwesenheitsmeldung.php`; die Seite trägt den Hinweis „Die Schule
/// erlaubt für dieses Kind Meldungen.“ Grenze: Nur Elternkonten; für Schüler-
/// konten liegt keine Antwort vor.
const forkAbsenceApplet = AppletMeta(
  appletPhpUrl: 'abwesenheitsmeldung.php',
  supportedAccountTypes: [AccountType.parent],
  // Die Datumsgrenzen ändern sich mit der Uhrzeit (12-Uhr-Regel), daher
  // kurz; die Maske lädt beim Öffnen ohnehin neu.
  refreshInterval: Duration(minutes: 5),
);

/// Module des Forks, die zusätzlich zu Applets.all geprüft werden.
const forkApplets = [forkAbsenceApplet];

/// Lädt das Formular samt bestehender Meldungen.
class AbsenceParser extends AppletParser<AbsenceForm> {
  AbsenceParser(
    AppletContext ctx, {
    required Future<bool> Function() isConnected,
  }) : super(ctx, forkAbsenceApplet, isConnected: isConnected);

  @override
  Future<AbsenceForm> getHome() async {
    final response = await ctx.session.dio.get(
      'https://start.schulportal.hessen.de/abwesenheitsmeldung.php'
      '?cacheBreaker=${DateTime.now().millisecondsSinceEpoch}',
    );
    final form = parseAbsenceForm(parse(response.data.toString()));
    // Kein Formular heißt fast immer: Sitzung verloren. Werfen, damit
    // AppletParser.fetchData einmal neu anmeldet und es erneut versucht.
    if (form == null) {
      throw UnknownException('abwesenheitsmeldung.php: kein meldungForm');
    }
    return form;
  }
}

final absenceParserProvider = Provider<AbsenceParser>((ref) {
  final ctx = ref.watch(appletContextProvider);
  final parser = AbsenceParser(
    ctx,
    isConnected: () => ref.read(connectionCheckerProvider).connected,
  );
  ref.onDispose(parser.dispose);
  return parser;
});

/// Antwort der Portal-Prüfung.
class AbsenceCheck {
  const AbsenceCheck(this.ok, this.errors);
  final bool ok;
  final List<String> errors;
}

/// Liest die JSON-Antwort der Prüfung `{success: bool, errors: [..]}`
/// (Portal-Skript meldungEltern.js). Fehlertexte können HTML enthalten,
/// die Tags werden entfernt. Unlesbare Antwort = nicht ok, mit Hinweis.
AbsenceCheck parseAbsenceCheck(Object? data) {
  Object? json = data;
  if (data is String) {
    try {
      json = jsonDecode(data);
    } on FormatException {
      return const AbsenceCheck(false, [
        'Das Portal hat die Prüfung nicht wie erwartet beantwortet.',
      ]);
    }
  }
  if (json is! Map) {
    return const AbsenceCheck(false, [
      'Das Portal hat die Prüfung nicht wie erwartet beantwortet.',
    ]);
  }
  if (json['success'] == true) return const AbsenceCheck(true, []);
  final raw = json['errors'];
  final errors = raw is List
      ? [
          for (final e in raw)
            e
                .toString()
                .replaceAll(RegExp(r'<[^>]+>'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
        ].where((e) => e.isNotEmpty).toList()
      : <String>[];
  return AbsenceCheck(
    false,
    errors.isEmpty ? ['Das Portal hat die Meldung abgelehnt.'] : errors,
  );
}

const _absenceUrl =
    'https://start.schulportal.hessen.de/abwesenheitsmeldung.php';

/// Fragt das Portal, ob es die Meldung annehmen würde. Speichert nichts.
///
/// Beleg: Portal-Skript meldungEltern.js (Export 16.10.26) schickt das
/// Formular zuerst mit `check=1` per Ajax und erwartet JSON
/// `{success, errors}`; erst bei Erfolg sendet es das Formular ein zweites Mal
/// OHNE `check` – erst das ist die Meldung. Dieses zweite Senden ist in der
/// App bewusst nicht eingebaut (Entscheidung 16.10.26: vorerst nur prüfen).
///
/// Abgelaufene Sitzung: einmal neu anmelden und die PRÜFUNG wiederholen
/// ([checkAbsenceWith]). Weiterleitungen folgt Dio hier nicht, damit eine
/// 302 auf die Anmeldung als solche erkennbar bleibt.
Future<AbsenceCheck> checkAbsence(
  LanisSession session,
  Map<String, String> fields,
) => checkAbsenceWith(
  fields: fields,
  post: (body) async {
    final r = await session.dio.post(
      _absenceUrl,
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'X-Requested-With': 'XMLHttpRequest'},
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    return (status: r.statusCode, data: r.data);
  },
  reauth: () => session.authenticate(),
);

/// Antwort einer Prüf-Anfrage (HTTP-Status und Rumpf).
typedef AbsencePostResult = ({int? status, Object? data});

/// Sieht die Antwort nach verlorener Sitzung aus? Weiterleitung (3xx) oder
/// kein JSON-Objekt (Anmeldeseite als HTML).
bool _looksLoggedOut(AbsencePostResult r) {
  final s = r.status;
  if (s != null && s >= 300 && s < 400) return true;
  final d = r.data;
  if (d is Map) return false;
  if (d is! String) return true;
  try {
    return jsonDecode(d) is! Map;
  } on FormatException {
    return true;
  }
}

/// Kern von [checkAbsence], ohne Portal testbar.
///
/// Ursache (Prüfung 27.10.26): Nach längerer Pause antwortete das Portal
/// auf `check=1` mit der Anmeldeseite bzw. einer Weiterleitung; die Maske
/// meldete „nicht wie erwartet beantwortet“, ohne neu anzumelden. Jetzt:
/// einmal [reauth], dann dieselbe Prüfung noch einmal. Grenze: höchstens ein
/// zweiter Versuch; scheitert auch er, gilt die Antwort wie bisher
/// (parseAbsenceCheck). Sicherheit: JEDE Anfrage hier trägt `check=1` – auch
/// die Wiederholung –, und `save` ist ausgeschlossen; eine Meldung kann so
/// nie entstehen (siehe [checkAbsence]).
Future<AbsenceCheck> checkAbsenceWith({
  required Map<String, String> fields,
  required Future<AbsencePostResult> Function(Map<String, String> body) post,
  required Future<void> Function() reauth,
}) async {
  assert(!fields.containsKey('save'));
  final body = {
    for (final e in fields.entries)
      if (e.key != 'save' && e.key != 'check') e.key: e.value,
    'check': '1',
  };
  var r = await post(Map.of(body));
  if (_looksLoggedOut(r)) {
    await reauth();
    r = await post(Map.of(body));
  }
  final s = r.status;
  if (s != null && s >= 300 && s < 400) {
    return const AbsenceCheck(false, [
      'Das Portal hat die Prüfung nicht wie erwartet beantwortet.',
    ]);
  }
  return parseAbsenceCheck(r.data);
}

/// Ergebnis des echten Absendens.
enum AbsenceSent {
  /// Danach steht eine neue Meldung in der Liste des Portals.
  confirmed,

  /// Abgeschickt, aber die neue Meldung ist (noch) nicht zu sehen – oder die
  /// Verbindung brach beim Absenden ab. Bewusst KEIN zweiter Versuch.
  unconfirmed,

  /// Die Prüfung (`check=1`) hat abgelehnt; gespeichert wurde nichts.
  rejected,
}

class AbsenceSubmitResult {
  const AbsenceSubmitResult(this.state, {this.errors = const [], this.entry});
  final AbsenceSent state;

  /// Gründe der Ablehnung ([AbsenceSent.rejected]).
  final List<String> errors;

  /// Die neue Meldung aus der Liste ([AbsenceSent.confirmed]).
  final AbsenceEntry? entry;
}

String _entryKey(AbsenceEntry e) =>
    [e.name, e.period, e.kind, e.entered, e.comment].join('\u0001');

/// Meldet die Abwesenheit wirklich (freigeschaltet 05.11.26, erster echter
/// Fall gemeinsam mit dem Auftraggeber).
///
/// Ablauf wie das Portal-Skript meldungEltern.js (Export 16.10.26): erst
/// `check=1` per Ajax ([checkAbsence], mit einer Neuanmeldung bei verlorener
/// Sitzung); nur bei `success` dieselben Felder OHNE `check` als normales
/// Formular an `abwesenheitsmeldung.php` (`$form.submit()` – ohne
/// Speichern-Knopf, daher kein `save`). Danach liest die App die Seite neu
/// und sucht in „Aktuelle und zukünftige Meldungen“ (`tbody#liste`) einen
/// Eintrag, der vorher nicht da war.
///
/// Grenze, bewusst: Das zweite Senden wird NIE wiederholt – auch nicht nach
/// Neuanmeldung oder Verbindungsabbruch. Eine Wiederholung könnte eine
/// doppelte Meldung bei der Schule erzeugen; bei Unklarheit lautet das
/// Ergebnis [AbsenceSent.unconfirmed], und die Maske verweist aufs Portal.
Future<AbsenceSubmitResult> submitAbsence(
  LanisSession session,
  Map<String, String> fields, {
  required List<AbsenceEntry> before,
  required Future<AbsenceForm?> Function() reload,
}) => submitAbsenceWith(
  fields: fields,
  before: before,
  check: (f) => checkAbsence(session, f),
  save: (body) async {
    final r = await session.dio.post(
      _absenceUrl,
      data: body,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    return (status: r.statusCode, data: r.data);
  },
  reload: reload,
);

/// Kern von [submitAbsence], ohne Portal testbar.
Future<AbsenceSubmitResult> submitAbsenceWith({
  required Map<String, String> fields,
  required List<AbsenceEntry> before,
  required Future<AbsenceCheck> Function(Map<String, String> fields) check,
  required Future<AbsencePostResult> Function(Map<String, String> body) save,
  required Future<AbsenceForm?> Function() reload,
}) async {
  final c = await check(fields);
  if (!c.ok) return AbsenceSubmitResult(AbsenceSent.rejected, errors: c.errors);
  final body = {
    for (final e in fields.entries)
      if (e.key != 'save' && e.key != 'check') e.key: e.value,
  };
  // Genau EIN Speichern-Aufruf; ein Fehler hier heißt nur „unklar“.
  try {
    await save(body);
  } catch (_) {}
  final known = {for (final e in before) _entryKey(e)};
  try {
    final after = await reload();
    // Neue Zeile UND passender erster Tag (TT.MM. aus `von`). Ursache
    // (Prüfung 05.11.26): Eine Meldung, die zeitgleich jemand anderes
    // einträgt (zweites Elternkonto, Schule), hätte sonst als „gemeldet“
    // gegolten. Grenze: Der Aufbau einer gefüllten Liste ist noch nicht
    // belegt (alle Exporte leer); passt das Datum nicht, lautet das Ergebnis
    // lieber „unklar“ als „gemeldet“.
    final von = fields['von'] ?? '';
    final day = von.length >= 6 ? von.substring(0, 6) : von;
    final added = after?.entries.where(
      (e) => !known.contains(_entryKey(e)) && e.period.contains(day),
    );
    if (added != null && added.isNotEmpty) {
      return AbsenceSubmitResult(AbsenceSent.confirmed, entry: added.first);
    }
  } catch (_) {}
  return const AbsenceSubmitResult(AbsenceSent.unconfirmed);
}
