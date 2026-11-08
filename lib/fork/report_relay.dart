import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:liblanis/liblanis.dart';

import 'demo/demo_mode.dart' show demoActive;
import 'error_log.dart';
import 'report_terms.dart';

/// Adresse des Weiterleitungsdiensts (Cloudflare Worker,
/// tools/report-relay/worker.js, eingerichtet 26.10.26, Probebericht
/// angekommen). Leer = kein Dienst: Dann bietet die App kein automatisches
/// Melden an, und „Anonym senden“ öffnet das Teilen-Menü.
///
/// Ursache: Die App hat bewusst keinen eigenen Server (Entscheidung
/// 17.10.26), und ein GitHub-Schlüssel in der offenen App wäre öffentlich;
/// der Dienst hält den Schlüssel und legt ein Issue im privaten
/// Berichte-Repo an.
const reportRelayUrl =
    'https://schulportal-berichte.rideguide-family-2026.workers.dev';

bool get relayConfigured => reportRelayUrl.isNotEmpty;

/// Zustimmung zum automatischen Melden: true/false, null = noch nicht
/// gefragt (Karte auf Heute, AutoReportPrompt).
const autoReportKey = 'fork/auto-report';

/// Schon gemeldete Einträge des Fehlerprotokolls: {ErrorRecord.key: count},
/// dazu gemeldete Begriffe als {„term:“ + TermEntry.key: 1}.
const autoReportSentKey = 'fork/auto-report-sent';

/// Umfang der Zustimmung (report_terms.dart): fehlt oder 1 = nur das
/// Fehlerprotokoll (Zustimmung bis 9501); [autoReportScopeTerms] = auch
/// unbekannte Begriffe und Kontext. Ursache (Wunsch 08.11.26): Der
/// Datenschutzhinweis versprach „keine Portal-Inhalte“; Begriffe aus festen
/// Spalten sind Portal-Inhalte (ohne Personenbezug) – dafür braucht es die
/// neue Zustimmung, die Heute einmal erfragt (autoReportPromptDue).
const autoReportScopeKey = 'fork/auto-report-scope';

/// Einmal nach der erweiterten Zustimmung gefragt und „Nicht jetzt“
/// gewählt: nicht erneut fragen; das Fehlerprotokoll geht weiter.
const autoReportAskedTermsKey = 'fork/auto-report-asked-terms';

/// Schließt die Zustimmung Begriffe und Kontext ein?
bool autoReportTermsAllowed(TypedSettings settings) =>
    settings.getBool(autoReportKey) == true &&
    (settings.getInt(autoReportScopeKey) ?? 1) >= autoReportScopeTerms;

/// Zustimmung speichern; [allow] schließt Begriffe und Kontext ein.
void setAutoReport(TypedSettings settings, bool allow) {
  settings.setBool(autoReportKey, allow);
  settings.setInt(autoReportScopeKey, allow ? autoReportScopeTerms : 1);
}

/// Einen Bericht an den Dienst senden. true = angenommen.
///
/// [kind] „fehler“ (ErrorLog.report, ohne Inhalte) oder „seite“ (eine
/// anonymisierte Portalseite, Anonymizer). Grenze: Der Dienst begrenzt
/// Größe (400 KB) und Anzahl je Tag; abgelehnt heißt hier nur false, die
/// App versucht es beim nächsten Start erneut.
Future<bool> sendReport({
  required String kind,
  required String version,
  required String area,
  required String text,
  Dio? dio,
}) async {
  if (!relayConfigured) return false;
  final d = dio ?? Dio();
  try {
    final r = await d.post<String>(
      reportRelayUrl,
      data: jsonEncode({
        'kind': kind,
        'version': version,
        'area': area,
        'text': text,
      }),
      options: Options(
        contentType: Headers.jsonContentType,
        validateStatus: (_) => true,
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return r.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    if (dio == null) d.close();
  }
}

/// Neue Einträge des Fehlerprotokolls melden, wenn zugestimmt wurde.
/// Neu = Schlüssel unbekannt oder Anzahl gestiegen. Gemeldet wird der
/// ganze Bericht (ErrorLog.report) – derselbe Text, den „Teilen“ zeigt.
/// Mit erweiterter Zustimmung (autoReportTermsAllowed) dazu Kontext und
/// unbekannte Begriffe (termsReport); ein neuer Begriff allein löst den
/// Bericht auch aus.
///
/// Aufgerufen beim Start (PreviewShell) und gleich nach der Zustimmung.
Future<bool> flushErrorReports(
  TypedSettings settings, {
  required String os,
  ErrorLog? log,
  TermLog? terms,
  ReportContext? context,
  Dio? dio,
  Future<bool> Function({
    required String kind,
    required String version,
    required String area,
    required String text,
  })?
  send,
}) async {
  final l = log ?? ErrorLog.instance;
  final tl = terms ?? TermLog.instance;
  if (!relayConfigured && send == null) return false;
  // Demo (demo_mode.dart): keine Berichte, auch nicht die alten der echten
  // Konten – die gehen nach dem Beenden wie gewohnt raus.
  if (demoActive) return false;
  final withTerms = autoReportTermsAllowed(settings);
  if (settings.getBool(autoReportKey) != true ||
      (l.records.isEmpty && (!withTerms || tl.entries.isEmpty))) {
    return false;
  }
  Map<String, dynamic> sent;
  try {
    sent =
        jsonDecode(settings.getString(autoReportSentKey) ?? '{}')
            as Map<String, dynamic>;
  } catch (_) {
    sent = {};
  }
  final fresh = [
    for (final r in l.records)
      if (sent[r.key] != r.count) r,
  ];
  final freshTerms = withTerms
      ? [
          for (final e in tl.entries)
            if (sent['term:${e.key}'] == null) e,
        ]
      : const <TermEntry>[];
  if (fresh.isEmpty && freshTerms.isEmpty) return false;
  final head = fresh.isNotEmpty
      ? (
          version: fresh.first.version,
          area: '${fresh.first.area} · ${fresh.first.type}',
        )
      : (
          version: freshTerms.first.version,
          area:
              'Begriff · ${freshTerms.first.area} · ${freshTerms.first.column}',
        );
  final ok =
      await (send ??
          ({required kind, required version, required area, required text}) =>
              sendReport(
                kind: kind,
                version: version,
                area: area,
                text: text,
                dio: dio,
              ))(
        kind: 'fehler',
        version: head.version,
        area: head.area,
        text:
            l.report(os: os) +
            (withTerms ? termsReport(log: tl, context: context) : ''),
      );
  if (ok) {
    settings.setString(
      autoReportSentKey,
      jsonEncode({
        for (final r in l.records) r.key: r.count,
        if (withTerms)
          for (final e in tl.entries) 'term:${e.key}': 1,
      }),
    );
  }
  return ok;
}
