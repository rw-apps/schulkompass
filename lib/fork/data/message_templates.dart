/// Vorlagen für Betreff und Textanfang einer neuen Nachricht (nur Daten).
///
/// Ursache Deutsch: Die Nachricht geht an die Schule, die Deutsch liest –
/// Betreff und Text bleiben daher in jeder App-Sprache deutsch; nur die
/// Beschriftung der Auswahl wird übersetzt (Schlüssel [id] in ForkL10n,
/// siehe compose_page.dart). Grenze: neue Vorlagen brauchen dort einen
/// eigenen Schlüssel.
class MessageTemplate {
  const MessageTemplate(this.id, this.subject, this.text);

  final String id;
  final String subject;
  final String text;
}

const messageTemplates = <MessageTemplate>[
  MessageTemplate(
    'homeworkQuestion',
    'Frage zur Hausaufgabe',
    'Guten Tag,\n\nwir haben eine Frage zur Hausaufgabe: ',
  ),
  MessageTemplate(
    'callback',
    'Bitte um Rückruf',
    'Guten Tag,\n\nkönnten Sie uns bitte zurückrufen? Wir sind erreichbar unter ',
  ),
  MessageTemplate(
    'appointment',
    'Termin vereinbaren',
    'Guten Tag,\n\nwir würden gern einen Gesprächstermin vereinbaren. ',
  ),
];

/// Entschuldigung für eine Fehlstunde (Wunsch 18.10.26): Betreff und Text
/// an die Lehrkraft des Fachs. Deutsch aus demselben Grund wie oben. Der
/// Grund bleibt offen („Grund: “) – den kennt nur die Familie; die Seite
/// setzt den Cursor dorthin. Grenze: Anrede ohne Namen („Guten Tag“), weil
/// das Portal Lehrkräfte teils nur mit Kürzel nennt.
({String subject, String text}) absenceExcuse({
  required String child,
  required String subject,
  required String when,
}) => (
  subject: 'Entschuldigung $child – $subject am $when',
  text:
      'Guten Tag,\n\n'
      '$child hat am $when im Fach $subject gefehlt.\n'
      'Grund: \n\n'
      'Bitte entschuldigen Sie das Fehlen.\n\n'
      'Mit freundlichen Grüßen\n',
);

/// Vorlage „Krankmeldung“ für „An die Schule schreiben“ nach der Meldung
/// (Wunsch 14.11.26: „Bei ‚Worum geht es‘ fehlt die Krankmeldung“). Nur
/// dort angeboten, weil erst die Meldung Kind und Tage kennt; die Meldung
/// selbst geht weiter über das Formular (abwesenheitsmeldung.php) – die
/// Nachricht ergänzt sie für die Lehrkräfte. Deutsch wie oben, auch die
/// Tage („am Mo 16.11.“, „vom Mo 16.11. bis Mi 18.11.“) – unabhängig von
/// der App-Sprache.
MessageTemplate sickNoteTemplate({
  required String child,
  required List<({DateTime from, DateTime to})> periods,
}) {
  const wd = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  String day(DateTime d) => '${wd[d.weekday - 1]} ${d.day}.${d.month}.';
  // Aneinander anschließende Meldungen zusammenfassen (ein Wochenende
  // dazwischen zählt als anschließend); Lücken bleiben getrennt. Ursache
  // (Prüfbefund 14.11.26): Mit min–max behauptete „vom Mo bis Do“ auch Di
  // und Mi als Krankheitstage, obwohl nur Mo und Do gemeldet waren.
  final sorted = [...periods]..sort((a, b) => a.from.compareTo(b.from));
  final merged = <({DateTime from, DateTime to})>[];
  for (final p in sorted) {
    if (merged.isNotEmpty) {
      final last = merged.last;
      var next = DateTime(last.to.year, last.to.month, last.to.day + 1);
      while (next.weekday > 5) {
        next = DateTime(next.year, next.month, next.day + 1);
      }
      if (!p.from.isAfter(next)) {
        merged[merged.length - 1] = (
          from: last.from,
          to: p.to.isAfter(last.to) ? p.to : last.to,
        );
        continue;
      }
    }
    merged.add(p);
  }
  final parts = [
    for (final p in merged)
      p.from == p.to ? day(p.from) : '${day(p.from)} bis ${day(p.to)}',
  ];
  final single = merged.length == 1 && merged.single.from != merged.single.to;
  final when = single
      ? 'vom ${parts.single}'
      : 'am ${parts.length == 1 ? parts.single : '${parts.take(parts.length - 1).join(', ')} und ${parts.last}'}';
  return MessageTemplate(
    'sickNote',
    'Krankmeldung $child – $when',
    'Guten Tag,\n\n'
        '$child ist $when krank und kann nicht am Unterricht teilnehmen. '
        'Die Abwesenheit ist im Schulportal gemeldet.\n\n'
        'Mit freundlichen Grüßen\n',
  );
}
