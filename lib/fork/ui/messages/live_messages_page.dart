import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import 'package:lanis/applets/conversations/chat_pages.dart'
    show ConversationChatPage;

import '../../name_repair.dart' show NameRepairs;
import '../../l10n/l10n.dart';
import '../login_errors.dart';
import '../kit.dart';
import '../nav.dart';
import '../live/family.dart';
import '../../absence/absence_view.dart' show AbsencePage;
import '../live/absence_live.dart';
import '../live/live_data.dart';
import 'compose_model.dart';
import 'compose_page.dart';
import 'messages_page.dart';

/// „Nachrichten“ mit echten Daten. Lesen und Antworten laufen über die
/// bewährte Unterhaltungsseite der bisherigen Ansicht (ConversationChatPage),
/// neu ist die Liste und das Schreiben in drei Schritten (ComposePage).
class LiveMessagesPage extends ConsumerWidget {
  const LiveMessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveGate(
      needsTimetable: false,
      builder: (context, s) {
        final k = Kit.of(context);
        final t = context.t;
        if (!s.offers('nachrichten.php')) {
          // Ohne Postfach trotzdem die Krankmeldungen zeigen (Prüfung
          // 05.11.26: sie fehlten sonst ganz).
          final reports = absenceReportsOf(s, DateTime.now(), t);
          if (reports.isNotEmpty) {
            return MessagesPage(
              items: const [],
              reports: reports,
              onOpenReports: () =>
                  pushFullScreen<void>(context, (_) => const AbsencePage()),
            );
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Sp.xl),
              child: Text(t.noMessagesOffered, style: k.meta),
            ),
          );
        }
        if (s.conversations.failed) {
          return LiveMessage(
            text: withReason(t, t.messagesFailed, s.conversations.error),
            style: k.meta,
            action: TextButton(
              onPressed: s.refresh,
              child: Text(t.retry, style: k.link),
            ),
          );
        }
        final me = FamilyData.of(
          context,
        ).where((m) => identical(m.snapshot, s)).firstOrNull;
        // Ohne Familie (me == null) gilt der kontenübergreifende Stand.
        final entries = s.conversations.content ?? const <OverviewEntry>[];
        final items = [
          for (final e in entries)
            if (!e.hidden)
              MessageItem(
                id: e.id,
                subject: e.title,
                sender: NameRepairs.global.apply(
                  e.fullName,
                  account: me?.accountId,
                ),
                date: e.date,
                unread: e.unread,
              ),
        ];
        // Über den gemeinsamen Lader: Fehler landen im Feed („Erneut
        // versuchen“) statt unbehandelt, und kein zweiter Durchgang läuft
        // parallel (Prüfbefund 17.10.26).
        final reload = s.refreshMessages;
        return MessagesPage(
          // Krankmeldungen über dem Postfach (Wunsch 05.11.26).
          reports: absenceReportsOf(
            s,
            DateTime.now(),
            t,
            colorIndex: me?.colorIndex ?? 0,
          ),
          onOpenReports: () =>
              pushFullScreen<void>(context, (_) => const AbsencePage()),
          items: items,
          loading: s.conversations.content == null,
          onRefresh: reload,
          onOpen: (m) async {
            await pushInTab<void>(
              context,
              (_) => ConversationChatPage(id: m.id, title: m.subject),
            );
            await reload();
          },
          // Eingabe-Seite über der ganzen App (nav.dart, pushFullScreen).
          onCompose: () => pushFullScreen<bool>(
            context,
            (_) => ComposePage(
              candidates: candidatesFrom(
                s.lessons.content ?? const [],
                ownNames: s.ownNames,
              ),
              backend: portalBackend(ref),
            ),
          ),
        );
      },
    );
  }
}

/// Zeitpunkt aus dem Datum des Portals für die Reihenfolge über mehrere
/// Konten: „14.10.2026 13:27“, „heute 08:12“, „gestern 17:40“; unlesbar =
/// ganz ans Ende. Ursache: Jedes Konto liefert seine Liste schon sortiert,
/// gemischt muss die App selbst ordnen.
DateTime messageTimeOf(String date, DateTime now) {
  final s = date.trim().toLowerCase();
  final hm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
  final h = hm == null ? 0 : int.parse(hm[1]!);
  final m = hm == null ? 0 : int.parse(hm[2]!);
  final d = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(s);
  if (d != null) {
    return DateTime(int.parse(d[3]!), int.parse(d[2]!), int.parse(d[1]!), h, m);
  }
  if (s.startsWith('heute'))
    return DateTime(now.year, now.month, now.day, h, m);
  if (s.startsWith('gestern')) {
    return DateTime(now.year, now.month, now.day - 1, h, m);
  }
  return DateTime(1970);
}

/// „Nachrichten“ für alle Kinder (FamilySwitch, „Alle“): die Unterhaltungen
/// aller Konten in einer Liste, neueste zuerst, jede mit Punkt und Namen
/// ihres Kindes. Öffnen und Schreiben laufen im Rahmen des jeweiligen
/// Kontos (FamilyMember.scope) – die Antwort geht also von dem Konto aus,
/// dem die Unterhaltung gehört.
class LiveAllMessagesPage extends StatelessWidget {
  const LiveAllMessagesPage({super.key, required this.members});

  final List<FamilyMember> members;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final withMessages = [
      for (final m in members)
        if (m.snapshot.offers('nachrichten.php')) m,
    ];
    final owner = <String, FamilyMember>{};
    final rows = <(DateTime, MessageItem)>[];
    for (final m in withMessages) {
      for (final e
          in m.snapshot.conversations.content ?? const <OverviewEntry>[]) {
        if (e.hidden) continue;
        final key = '${m.accountId}|${e.id}';
        owner[key] = m;
        rows.add((
          messageTimeOf(e.date, now),
          MessageItem(
            id: key,
            subject: e.title,
            sender: NameRepairs.global.apply(e.fullName, account: m.accountId),
            date: e.date,
            unread: e.unread,
            kidName: kidLabel(m.snapshot),
            kidColor: m.colorIndex,
          ),
        ));
      }
    }
    rows.sort((a, b) => b.$1.compareTo(a.$1));
    Future<void> refreshAll() async {
      for (final m in withMessages) {
        await m.snapshot.refreshMessages();
      }
    }

    // Krankmeldungen aller Elternkonten (Wunsch 05.11.26); jede Zeile öffnet
    // die Krankmeldung IHRES Kontos (FamilyMember.scope).
    return MessagesPage(
      reports: [
        for (final m in members)
          ...absenceReportsOf(
            m.snapshot,
            now,
            context.t,
            colorIndex: m.colorIndex,
            onTap: () => pushFullScreen<void>(
              context,
              (_) => m.scope(const AbsencePage()),
            ),
          ),
      ],
      items: [for (final r in rows) r.$2],
      loading: withMessages.any(
        (m) => m.snapshot.conversations.content == null,
      ),
      onRefresh: refreshAll,
      onOpen: (item) async {
        final m = owner[item.id];
        if (m == null) return;
        final id = item.id.substring(item.id.indexOf('|') + 1);
        await pushInTab<void>(
          context,
          (_) => m.scope(ConversationChatPage(id: id, title: item.subject)),
        );
        await m.snapshot.refreshMessages();
      },
      onCompose: withMessages.isEmpty
          ? null
          : () async {
              final m = withMessages.length == 1
                  ? withMessages.single
                  : await pickFamilyMember(
                      context,
                      withMessages,
                      title: context.t.writeForWhom,
                    );
              if (m == null || !context.mounted) return;
              await pushFullScreen<bool>(
                context,
                (_) => m.scope(
                  Consumer(
                    builder: (c, ref, _) => ComposePage(
                      candidates: candidatesFrom(
                        m.snapshot.lessons.content ?? const [],
                        ownNames: m.snapshot.ownNames,
                      ),
                      backend: portalBackend(ref),
                    ),
                  ),
                ),
              );
            },
    );
  }

  /// Für welches Kind schreiben? Pillen wie oben in der Leiste.
}
