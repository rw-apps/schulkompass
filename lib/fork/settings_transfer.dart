import 'dart:convert';

import 'package:liblanis/liblanis.dart';

import 'class_choice.dart' show classSetting;
import 'kid_colors.dart' show kidColorSetting;
import 'absences.dart' show absenceSentSetting, decodeSent, encodeSent;
import 'homework_ledger.dart';
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
    if (i <= 0) return null;
    final id = int.tryParse(key.substring(0, i));
    final user = key.substring(i + 1).trim();
    if (id == null || id <= 0 || user.isEmpty) return null;
    return (key: key, schoolId: id, username: user);
  }
}

/// Sicherungsdatei lesen; null, wenn es keine Übertragungsdatei dieser App
/// ist. Gleiche Prüfung wie [parseTransfer] – Namen nur als Text, höchstens
/// 120 Zeichen (Anzeige, kein Code).
TransferBackup? parseBackup(String text) {
  final data = parseTransfer(text);
  if (data == null) return null;
  final names = <String, String>{};
  final valid = {for (final a in TransferBackup(data: data).accounts) a.key};
  DateTime? created;
  try {
    final v = jsonDecode(text) as Map;
    created = DateTime.tryParse('${v['created'] ?? ''}');
    final n = v['names'];
    if (n is Map) {
      for (final e in n.entries) {
        final name = e.value is String ? (e.value as String).trim() : '';
        if (valid.contains('${e.key}') &&
            name.isNotEmpty &&
            name.length <= 120) {
          names['${e.key}'] = name;
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
  void add(String? url) {
    final h = Uri.tryParse(url?.trim() ?? '')?.host ?? '';
    if (h.isNotEmpty) out.add(h);
  }

  // Werte stehen in der Datei so, wie die Datenbank sie speichert
  // (LanisDatabase.encodeValue: {"v": …}). Ursache (04.11.26): Bis 9473
  // las diese Funktion den rohen Text als Adresse – bei echten Dateien kam
  // nie ein Host heraus, der Hinweis blieb immer leer. Grenze: Ein Wert
  // ohne Hülle (ältere Tests, Handarbeit) wird unverändert gelesen.
  String? plain(String? raw) {
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is Map && d.containsKey('v')) {
        final v = d['v'];
        return v is String ? v : jsonEncode(v);
      }
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
