import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'class_choice.dart' show classSetting;
import 'kid_colors.dart' show kidColorSetting;
import 'absences.dart' show absenceSentSetting, decodeSent, encodeSent;
import 'homework_ledger.dart';
import 'school_links.dart' show normalizeMensaUrl;
import 'ui/live/live_data.dart'
    show
        groupChoiceSetting,
        lessonTimesSetting,
        mensaUrlSetting,
        mensaUrlsSetting,
        teacherNamesSetting;

/// Eingaben der Familie von einem Gerät aufs andere übertragen (Wunsch
/// 18.10.26: „die Daten ändern sich ja nur selten“).
///
/// Ursache für Datei statt Abgleich: Die App hat bewusst keinen eigenen
/// Server; ein laufender Abgleich bräuchte einen. Grenze: Was danach auf
/// einem Gerät geändert wird, kommt erst mit der nächsten Übertragung mit.
///
/// Was übertragen wird – je Konto, nur Eingaben der Familie, keine
/// Zugangsdaten und nichts aus dem Portal:
const transferKeys = [
  'stundenplan.php/$groupChoiceSetting', // Gruppenwahl im Stundenplan
  'stundenplan.php/$teacherNamesSetting', // selbst benannte Lehrkräfte
  'stundenplan.php/$lessonTimesSetting', // Stundenzeiten
  'fork/$mensaUrlsSetting', // Mensa je Kind
  'fork/$mensaUrlSetting', // Mensa (alte Form)
  homeworkLedgerSetting, // abgehakte Hausaufgaben
  absenceSentSetting, // gesendete Entschuldigungen
  classSetting, // eingetragene Klasse
  kidColorSetting, // Farbe des Kindes
];

/// Konto über Geräte hinweg: Schulnummer und Benutzername. Ursache: Die
/// lokale Kontonummer (localId) vergibt jedes Gerät selbst.
String transferAccountKey(int schoolId, String username) =>
    '$schoolId:${username.trim().toLowerCase()}';

const _format = 'schulportal-eingaben';

/// Datei-Inhalt aus den rohen gespeicherten Werten je Konto.
/// [values]: Kontoschlüssel → (Einstellung → roher Wert, null = fehlt).
///
/// [names]: Kontoschlüssel → Schulname (seit 9474). Ursache: „Mit
/// Sicherungsdatei einrichten“ (restore_backup.dart) zeigt die Konten vor
/// der Anmeldung; ohne Namen stünde dort nur die Schulnummer. Grenze:
/// Ältere Dateien haben keine Namen – dort lädt die Einrichtung die
/// öffentliche Schulliste nach (fetchSchoolNames).
String buildTransfer(
  Map<String, Map<String, String?>> values, {
  required DateTime now,
  Map<String, String> names = const {},
}) => const JsonEncoder.withIndent(' ').convert({
  'format': _format,
  'version': 1,
  'created': now.toIso8601String(),
  if (names.isNotEmpty)
    'names': {
      for (final e in names.entries)
        if (values.containsKey(e.key) && e.value.trim().isNotEmpty)
          e.key: e.value.trim(),
    },
  'accounts': {
    for (final a in values.entries)
      a.key: {
        for (final e in a.value.entries)
          if (e.value != null && transferKeys.contains(e.key)) e.key: e.value,
      },
  },
});

/// Gelesene Datei: Kontoschlüssel → (Einstellung → roher Wert); null, wenn
/// es keine Übertragungsdatei dieser App ist.
Map<String, Map<String, String>>? parseTransfer(String text) {
  try {
    final v = jsonDecode(text);
    if (v is! Map || v['format'] != _format) return null;
    final acc = v['accounts'];
    if (acc is! Map) return null;
    return {
      for (final a in acc.entries)
        if (a.value is Map)
          '${a.key}': {
            for (final e in (a.value as Map).entries)
              // Nur bekannte Schlüssel – eine fremde Datei schreibt nichts
              // anderes in die Einstellungen.
              if (transferKeys.contains('${e.key}') && e.value is String)
                '${e.key}': e.value as String,
          },
    };
  } catch (_) {
    return null;
  }
}

/// Konto aus einer Sicherungsdatei, noch nicht auf diesem Gerät.
typedef BackupAccount = ({String key, int schoolId, String username});

/// Ganze Sicherungsdatei für „Mit Sicherungsdatei einrichten“: Eingaben
/// ([data], wie [parseTransfer]), Schulnamen ([names], nur neuere Dateien)
/// und Erstellzeit.
class TransferBackup {
  const TransferBackup({
    required this.data,
    this.names = const {},
    this.created,
  });

  final Map<String, Map<String, String>> data;
  final Map<String, String> names;
  final DateTime? created;

  /// Konten in Dateireihenfolge. Ursache für das Zerlegen des Schlüssels
  /// (transferAccountKey: „Schulnummer:benutzername“): Die Datei trägt
  /// keine eigenen Felder dafür; der Benutzername darf selbst „:“ enthalten,
  /// deshalb wird nur am ersten getrennt. Einträge ohne gültige
  /// Schulnummer oder Namen fallen weg.
  List<BackupAccount> get accounts => [
    for (final k in data.keys)
      if (_split(k) case final a?) a,
  ];

  static BackupAccount? _split(String key) {
    final i = key.indexOf(':');
    if (i <= 0 || !RegExp(r'^[0-9]{1,9}$').hasMatch(key.substring(0, i))) {
      return null;
    }
    final id = int.parse(key.substring(0, i));
    final user = key.substring(i + 1).trim();
    if (id <= 0 || user.isEmpty || user.length > maxBackupUsername) {
      return null;
    }
    return (key: key, schoolId: id, username: user);
  }
}

/// Grenzen gegen fremde oder kaputte Dateien (Prüfung 04.11.26): eine
/// echte Datei hat wenige Konten mit kurzen Namen und ist wenige KB groß.
const maxBackupBytes = 2 * 1024 * 1024;
const maxBackupAccounts = 20;
const maxBackupUsername = 100;

/// Sicherungsdatei lesen; null, wenn es keine Übertragungsdatei dieser App
/// ist. Gleiche Prüfung wie [parseTransfer] – Namen nur als Text, höchstens
/// 120 Zeichen, ohne Steuer- und Richtungszeichen (Anzeige und schoolName
/// des Kontos).
///
/// Schlüssel werden auf transferAccountKey gebracht. Ursache (Prüfung
/// 04.11.26): Die Anmeldung rechnet den Schlüssel neu aus; „1234:Max“ in
/// einer bearbeiteten Datei hätte dann still keine Eingaben übernommen und
/// das Konto nie als erledigt markiert. Doppelte Konten fallen weg, mehr
/// als [maxBackupAccounts] ebenso.
TransferBackup? parseBackup(String text) {
  if (text.length > maxBackupBytes) return null;
  final raw = parseTransfer(text);
  if (raw == null) return null;
  final data = <String, Map<String, String>>{};
  final canon = <String, String>{}; // Schlüssel in der Datei → kanonisch
  for (final e in raw.entries) {
    final a = TransferBackup._split(e.key);
    if (a == null || data.length >= maxBackupAccounts) continue;
    final key = transferAccountKey(a.schoolId, a.username);
    if (data.containsKey(key)) continue;
    data[key] = e.value;
    canon[e.key] = key;
  }
  final names = <String, String>{};
  final hidden = RegExp(
    '[\u0000-\u001f\u007f\u200e\u200f\u202a-\u202e\u2066-\u2069]',
  );
  DateTime? created;
  try {
    final v = jsonDecode(text) as Map;
    created = DateTime.tryParse('${v['created'] ?? ''}');
    final n = v['names'];
    if (n is Map) {
      for (final e in n.entries) {
        final name = e.value is String
            ? (e.value as String).replaceAll(hidden, '').trim()
            : '';
        final key = canon['${e.key}'];
        if (key != null && name.isNotEmpty && name.length <= 120) {
          names[key] = name;
        }
      }
    }
  } catch (_) {}
  return TransferBackup(data: data, names: names, created: created);
}

/// Wert, der nach dem Übernehmen gilt.
///
/// Abgehakte Hausaufgaben und gesendete Entschuldigungen werden
/// zusammengeführt (je Eintrag der neuere Stand), damit auf beiden Geräten
/// Abgehaktes nicht verloren geht; alles andere übernimmt die Datei.
/// [incoming] und [current] sind gespeicherte Rohwerte (LanisDatabase.
/// encodeValue); [decode]/[encode] wandeln in den Text dahinter.
String mergeValue(
  String key,
  String incoming,
  String? current, {
  required String? Function(String raw) decode,
  required String Function(String text) encode,
}) {
  if (current == null) return incoming;
  if (key == homeworkLedgerSetting) {
    final a = HomeworkLedger.decode(decode(current));
    final b = HomeworkLedger.decode(decode(incoming));
    final merged = {...a.byKey};
    for (final r in b.byKey.values) {
      final old = merged[r.key];
      if (old == null || r.changed.isAfter(old.changed)) merged[r.key] = r;
    }
    return encode(HomeworkLedger(merged).encode());
  }
  if (key == absenceSentSetting) {
    final a = decodeSent(decode(current));
    final b = decodeSent(decode(incoming));
    final merged = {...a};
    for (final e in b.entries) {
      final old = merged[e.key];
      if (old == null || e.value.isAfter(old)) merged[e.key] = e.value;
    }
    return encode(encodeSent(merged));
  }
  return incoming;
}

/// Übernommene Eingaben in die Konten dieses Geräts schreiben (Zuordnung
/// über Schulnummer und Benutzername, nur [transferKeys]). Rückgabe: Konten,
/// für die etwas übernommen wurde. Gemeinsam für Datei (transfer_page.dart)
/// und QR-Code (device_transfer_page.dart).
List<AccountSummary> applyTransferValues(
  LanisDatabase db,
  Map<String, Map<String, String>> data,
  List<AccountSummary> accounts,
) {
  final out = <AccountSummary>[];
  for (final a in accounts) {
    final incoming = data[transferAccountKey(a.schoolID, a.username)];
    if (incoming == null || incoming.isEmpty) continue;
    for (final e in incoming.entries) {
      if (!transferKeys.contains(e.key)) continue;
      db.setAccountSetting(
        a.localId,
        e.key,
        mergeValue(
          e.key,
          e.value,
          db.getAccountSetting(a.localId, e.key),
          decode: (raw) => LanisDatabase.decodeValue(raw)?.toString(),
          encode: LanisDatabase.encodeValue,
        ),
      );
    }
    out.add(a);
  }
  return out;
}

/// Rohwerte der übertragbaren Eingaben aller [accounts].
Map<String, Map<String, String?>> collectTransferValues(
  LanisDatabase db,
  List<AccountSummary> accounts,
) => {
  for (final a in accounts)
    transferAccountKey(a.schoolID, a.username): {
      for (final k in transferKeys) k: db.getAccountSetting(a.localId, k),
    },
};

/// Schulnamen der [accounts] je Kontoschlüssel (für [buildTransfer]).
Map<String, String> collectTransferNames(List<AccountSummary> accounts) => {
  for (final a in accounts)
    if (a.schoolName.trim().isNotEmpty)
      transferAccountKey(a.schoolID, a.username): a.schoolName,
};

/// Hosts der Bestellseiten, die eine Eingaben-Datei für [keys] setzen würde
/// (je Kind und alte Kontoadresse), sortiert.
///
/// Ursache (Sicherheitsprüfung 03.11.26): Ein Import schrieb Mensa-Adressen
/// ohne Hinweis. Eine in einem Klassenchat geteilte „Einrichtungsdatei“ hätte
/// „Essen“ auf eine nachgemachte Anmeldeseite lenken können; der Dialog
/// nennt die Seiten jetzt, damit man sie vor dem Übernehmen sieht.
List<String> transferMensaHosts(
  Map<String, Map<String, String>> data,
  Iterable<String> keys,
) {
  final out = <String>{};
  // Host so bestimmen, wie die App die Adresse später öffnet
  // (normalizeMensaUrl, school_links.dart: ohne Schema mit https://).
  // Ursache (Prüfung 04.11.26): „evil.example/x“ ergab mit Uri.tryParse
  // keinen Host – kein Hinweis, die App hätte die Seite aber geöffnet.
  void add(String? url) {
    final n = normalizeMensaUrl(url);
    final h = n == null ? '' : (Uri.tryParse(n)?.host ?? '');
    if (h.isNotEmpty) out.add(h.toLowerCase());
  }

  // Werte stehen in der Datei so, wie die Datenbank sie speichert
  // (LanisDatabase.encodeValue: {"v": …}). Ursache (04.11.26): Bis 9473
  // las diese Funktion den rohen Text als Adresse – bei echten Dateien kam
  // nie ein Host heraus, der Hinweis blieb immer leer. Grenze: Ein Wert
  // ohne Hülle (ältere Tests, Handarbeit) wird unverändert gelesen.
  // Wie getString liest (LanisDatabase.decodeValue): Hülle {"v": …} oder
  // ein nackter JSON-Wert; nur wenn beides nicht passt, der Rohtext.
  String? plain(String? raw) {
    if (raw == null) return null;
    try {
      final d = LanisDatabase.decodeValue(raw);
      if (d is String) return d;
      if (d is Map && !d.containsKey('v')) return raw;
      if (d != null) return jsonEncode(d);
    } catch (_) {}
    return raw;
  }

  for (final k in keys) {
    final v = data[k];
    if (v == null) continue;
    add(plain(v['fork/$mensaUrlSetting']));
    try {
      final m = jsonDecode(plain(v['fork/$mensaUrlsSetting']) ?? '');
      if (m is Map) {
        for (final u in m.values) {
          add('$u');
        }
      }
    } catch (_) {}
  }
  return out.toList()..sort();
}
