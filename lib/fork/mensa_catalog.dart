import 'mensa.dart' show mensaSameSite;

/// Bekannte Bestellseiten von Caterern samt Schulen, die dort bestellen –
/// für die Vorauswahl im Blatt „Bestellseite der Mensa“ (mensa_sheet.dart).
///
/// Ursache (Wunsch 02.11.26): Die Familie musste die Adresse bisher selbst
/// eintippen; auf dem Tablet geriet dabei die Adresse des Geschwisters an
/// das falsche Kind. Schulen stehen nur als Schulnummer darin (wie im
/// Schulportal, Session.account.schoolID), keine Schulnamen – Abwägung
/// 02.11.26: Caterer und Bestelladressen sind öffentliche Firmenangaben,
/// die Zuordnung zu einer Schule soll im öffentlichen Code nicht lesbar
/// sein. Belege der Zuordnung liegen außerhalb des Repositorys.
///
/// Grenze: Stand der Recherche (Webseiten der Schulen und Caterer); wechselt
/// eine Schule den Caterer, stimmt der Vorschlag nicht mehr – deshalb ist er
/// nur vorausgewählt, die Familie bestätigt ihn und kann jederzeit eine
/// eigene Adresse eintragen.
class MensaCaterer {
  const MensaCaterer({
    required this.key,
    required this.name,
    required this.url,
    this.prefix,
    this.schools = const {},
  });

  /// Feste Kennung (Tests, gespeicherte Auswahl).
  final String key;
  final String name;

  /// Anmelde- bzw. Startseite (normalizeMensaUrl nimmt sie an).
  final String url;

  /// Pfad des Mandanten, wenn sich mehrere Caterer eine Plattform teilen
  /// („/mandant“); null = die ganze Domain gehört diesem Caterer.
  final String? prefix;

  /// Schulnummern, deren Familien hier bestellen.
  final Set<String> schools;

  /// Gehört [address] zu diesem Caterer? Gleiche Hauptdomain
  /// (mensaSameSite) und ggf. derselbe Mandantenpfad.
  bool matches(String? address) {
    if (!mensaSameSite(url, address)) return false;
    final p = prefix;
    if (p == null) return true;
    final path = Uri.tryParse(address!.trim())?.path.toLowerCase() ?? '';
    return path == p || path.startsWith('$p/');
  }

  /// Nur Domain und Mandant zur Anzeige („menuebestellung.de/mandant“).
  String get shortUrl {
    final u = Uri.parse(url);
    final host = u.host.startsWith('www.') ? u.host.substring(4) : u.host;
    return prefix == null ? host : '$host$prefix';
  }
}

/// Frankfurt am Main (Recherche 02.11.26). Quellen je Caterer:
/// - GEG: Auswahlliste „Einrichtung“ der Neukunden-Registrierung auf der
///   Bestellseite (46 Einträge, zwei Schulen mit zwei Standorten) – über die
///   Schulliste des Portals Schulnummern zugeordnet.
/// - OPAL Catering (bis 08/2024 ASB Hessen Service): Einrichtungsseiten
///   des Caterers je Schule (Frankfurter Adresse, Link „Essensbestellung“);
///   drei Mandanten auf derselben Plattform.
/// - OFW: Mensaseite einer Schule (Registrierung im Kundenportal, 2025).
/// Zwei Schulen stehen bei GEG und OPAL (je eigener Standort); dort wählt
/// die Familie selbst (MensaSheet wählt dann nichts vor).
const mensaCatalog = <MensaCaterer>[
  MensaCaterer(
    key: 'geg',
    name: 'GEG Gastro Service',
    url: 'https://www.bestellung-geggastro.de/login',
    schools: {
      '3109',
      '3113',
      '3121',
      '3135',
      '3137',
      '3149',
      '3151',
      '3158',
      '3162',
      '3166',
      '3180',
      '3181',
      '3667',
      '4179',
      '4208',
      '4288',
      '4387',
      '4388',
      '4389',
      '4391',
      '4395',
      '4397',
      '4398',
      '4399',
      '4400',
      '4401',
      '4406',
      '4413',
      '4426',
      '5002',
      '5007',
      '5104',
      '5107',
      '5108',
      '5110',
      '5112',
      '5113',
      '5116',
      '6055',
      '6090',
      '6091',
      '6108',
      '104288',
    },
  ),
  MensaCaterer(
    key: 'asb-heserv',
    name: 'OPAL Catering (ehem. ASB)',
    url: 'https://www.menuebestellung.de/asb-heserv/login.php',
    prefix: '/asb-heserv',
    schools: {
      '3106',
      '3111',
      '3117',
      '3123',
      '3124',
      '3125',
      '3130',
      '3133',
      '3136',
      '3138',
      '3148',
      '3153',
      '3160',
      '3161',
      '3164',
      '3165',
      '3168',
      '3174',
      '3654',
      '3666',
      '4002',
      '4380',
      '4384',
      '4385',
      '4386',
      '4388',
      '4396',
      '4400',
      '4403',
      '4412',
      '4601',
      '4607',
      '4611',
      '4612',
      '5012',
      '5102',
      '5105',
      '5106',
      '5109',
      '6002',
      '6121',
      '6135',
    },
  ),
  MensaCaterer(
    key: 'opalfrankf',
    name: 'OPAL Catering · opalfrankf',
    url: 'https://www.menuebestellung.de/opalfrankf/login.php',
    prefix: '/opalfrankf',
    schools: {'3159', '5101'},
  ),
  MensaCaterer(
    key: 'opal',
    name: 'OPAL Catering · opal',
    url: 'https://www.menuebestellung.de/opal/login.php',
    prefix: '/opal',
    schools: {'3179', '4606'},
  ),
  MensaCaterer(
    key: 'ofw',
    name: 'OFW Catering',
    url: 'https://ofw.clients.pca.de/',
    schools: {'5218'},
  ),
];

/// Caterer der Schule [schoolId] (meist einer; leer = unbekannt).
List<MensaCaterer> mensaCaterersForSchool(
  String schoolId, [
  List<MensaCaterer> catalog = mensaCatalog,
]) => [
  for (final c in catalog)
    if (c.schools.contains(schoolId)) c,
];

/// Caterer, zu dem [address] gehört; null = keiner aus der Liste.
MensaCaterer? mensaCatererForUrl(
  String? address, [
  List<MensaCaterer> catalog = mensaCatalog,
]) {
  for (final c in catalog) {
    if (c.matches(address)) return c;
  }
  return null;
}
