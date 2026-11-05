import 'package:flutter/foundation.dart' show VoidCallback;

import '../../absence/absence_form.dart';
import '../../absence/absence_today.dart';
import '../../l10n/l10n.dart';
import '../messages/messages_page.dart' show AbsenceReportItem;
import 'live_data.dart';

/// Band „Heute krank gemeldet“ (KidCard): Eintrag dieses Kindes, der heute
/// gilt – eine Krankmeldung vor einer Verspätung am selben Tag, wie im
/// Widget (widget_absence.dart; Prüfung 05.11.26: vorher galt der erste
/// Eintrag der Liste, Heute und Widget konnten sich widersprechen). Ohne
/// passenden Eintrag null.
({String kind, String detail})? reportedAbsenceFor(
  List<AbsenceEntry> entries,
  String firstName,
  DateTime now,
  ForkL10n t,
) {
  AbsenceEntry? late;
  for (final e in entries) {
    if (!absenceIsFor(e, firstName) || !absenceCovers(e, now)) continue;
    if (!absenceIsLate(e)) return (kind: e.kind, detail: absenceDetail(e, t));
    late ??= e;
  }
  return late == null
      ? null
      : (kind: late.kind, detail: absenceDetail(late, t));
}

/// „Do 5.11. · eingetragen 07:40“ bzw. „Do 5.11. bis Fr 6.11. · …“.
String absenceDetail(AbsenceEntry e, ForkL10n t) {
  final p = absencePeriodDays(e.period, now: DateTime.now());
  final time = absenceEnteredTime(e.entered);
  String day(DateTime d) => formatDate(t, t.dateShort, d);
  return [
    if (p == null)
      e.period
    else if (p.from == p.to)
      day(p.from)
    else
      t.absenceDayRange(day(p.from), day(p.to)),
    if (time != null) t.absenceEnteredAt(time),
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// Zeilen „Krankmeldungen“ über dem Postfach (MessagesPage.reports): alle
/// Meldungen des Kontos, die heute oder später gelten.
List<AbsenceReportItem> absenceReportsOf(
  LiveSnapshot s,
  DateTime now,
  ForkL10n t, {
  int colorIndex = 0,
  String? kidName,
  VoidCallback? onTap,
}) => [
  for (final e in currentAbsences(s.absences ?? const [], now))
    AbsenceReportItem(
      title: '${absenceFirstName(e)} – ${e.kind}',
      meta: absenceDetail(e, t),
      kidColor: colorIndex,
      kidName: kidName,
      onTap: onTap,
    ),
];
