import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:lanis/utils/safe_launch.dart';

import '../../error_log.dart';
import '../../l10n/l10n.dart';
import '../../school_apps.dart';
import '../kid_chips.dart';
import '../kit.dart';
import '../pinned_page.dart';
import '../portal_link.dart';

/// Ein Angebot der Schule (school_apps.dart) in der App, angemeldet mit dem
/// Konto des Kindes und direkt auf seiner Seite.
///
/// Ursache (Wunsch 14.11.26): Wahltool, Videokonferenz, Kurswahl und die
/// fremden Angebote sollten aus der App erreichbar sein. liblanis liefert
/// nur eine Anmeldeadresse, die auf der Startseite landet
/// (Session.getLoginURL); deshalb hier in zwei Schritten: anmelden, dann –
/// sobald das Portal geladen ist – die Seite des Angebots.
///
/// Fremde Angebote (Weiterleitung des Portals) verlassen das Portal: Diese
/// Seite gibt die Weiterleitung an den Browser ab und schließt sich. Ob die
/// fremde Seite dort angemeldet bleibt, entscheidet sie selbst.
///
/// Fehler gehen ohne Namen ins Fehlerprotokoll (ErrorLog.notice, Bereich =
/// bekanntes Modul wie „wahl.php“, sonst „App“ – ein selbst vergebener
/// Dateiname könnte die Schule verraten): Anmeldung gescheitert, Hauptseite
/// nicht ladbar (Fehler- oder HTTP-Code nur der Hauptseite; Android meldet
/// HTTP-Fehler jedes Bildes, die zählen nicht – Prüfbefund 14.11.26),
/// unerwartet zurück auf der Anmeldeseite.
/// Grenzen: Herunterladen von Dateien kann die eingebettete Ansicht nicht –
/// dafür bleibt „Im Browser öffnen“ oben rechts. Abmelden im Portal ist
/// gesperrt (wie Moodle, lib/view/moodle.dart): Es beendete alle Sitzungen
/// des Kontos, auch die der App. Leitet das Portal fremde Angebote per
/// Formular weiter, kommt im Browser nur die Adresse an – jede Weiterleitung
/// einmal am Gerät prüfen.
class PortalAppPage extends ConsumerStatefulWidget {
  const PortalAppPage({super.key, required this.app, required this.session});

  final SchoolApp app;
  final LanisSession session;

  @override
  ConsumerState<PortalAppPage> createState() => _PortalAppPageState();
}

class _PortalAppPageState extends ConsumerState<PortalAppPage> {
  late final WebViewController _c;
  int _progress = 0;
  bool _failed = false;

  /// Nach der Anmeldung einmal zur Seite des Angebots.
  bool _sent = false;

  /// Hauptadresse des Portals erreicht (sonst hing die Anmeldung).
  bool _inPortal = false;

  /// Seite schließt sich schon (Weiterleitung zum fremden Angebot): kein
  /// zweites Öffnen, kein zweites Schließen.
  bool _leaving = false;

  /// Zuletzt gestartete Hauptadresse (onPageStarted) – nur deren HTTP-Fehler
  /// zählen.
  String? _main;

  void _report(String what, [Map<String, int> counts = const {}]) =>
      ErrorLog.instance.notice(
        knownModules.contains(widget.app.module) ? widget.app.module : 'App',
        what,
        counts,
      );

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kitWebCanvas)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (url) {
            _main = url;
            if (mounted) setState(() => _failed = false);
          },
          onPageFinished: _finished,
          onWebResourceError: (e) {
            if (e.isForMainFrame == false) return;
            _report('PortalAppFailed', {'web': e.errorCode.abs()});
            if (mounted) setState(() => _failed = true);
          },
          onHttpError: (e) {
            final code = e.response?.statusCode ?? 0;
            final url = e.request?.uri.toString();
            if (code >= 400 && url != null && url == _main) {
              _report('PortalAppHttp', {'status': code});
            }
          },
          onNavigationRequest: (r) {
            final u = Uri.tryParse(r.url);
            if (u == null || _leaving) return NavigationDecision.prevent;
            final nav = portalNavigation(u, mainFrame: r.isMainFrame);
            if (nav == PortalNav.stay) return NavigationDecision.navigate;
            if (nav == PortalNav.device || nav == PortalNav.browser) {
              safeLaunchUrl(
                u,
                context: context,
                mode: LaunchMode.externalApplication,
              );
            }
            // Ein fremdes Angebot schließt die Seite, sobald es das Portal
            // verlässt; ein fremder Link im Wahltool o. Ä. öffnet bloß den
            // Browser (Prüfbefund 14.11.26). Ursache, dass hier kein
            // „angekommen“ mehr zählt (Nachprüfung 14.11.26): Android
            // meldet abgebrochene Seiten als fertig, und bei Weiterleitung
            // per Formular oder JavaScript meldet die WebView erst die
            // Zielseite des Portals als fertig und navigiert danach fort –
            // beides ließ die Portalseite offen. Grenze: Wie das Portal
            // weiterleitet, ist am Gerät noch zu prüfen.
            if (nav == PortalNav.browser && widget.app.external && mounted) {
              _leaving = true;
              Navigator.of(context).pop();
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _start();
  }

  // Auch beim Schließen von außen (Kindwechsel: popUntil umgeht PopScope)
  // nichts mehr nachladen oder im Browser öffnen (Prüfbefund 14.11.26).
  @override
  void deactivate() {
    _leaving = true;
    super.deactivate();
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _sent = false;
      _inPortal = false;
    });
    try {
      // Sitzung eines anderen Kindes im WebView-Speicher leeren (nur das
      // Portal-Cookie „sid“, die Anmeldung beim Caterer bleibt). Ursache
      // (Prüfbefund 14.11.26): Alle WebViews teilen sich die Cookies; ob die
      // Anmeldeadresse eine bestehende Sitzung immer ersetzt, ist nicht
      // belegt.
      await WebViewCookieManager().setCookie(
        const WebViewCookie(
          name: 'sid',
          value: '',
          domain: 'start.schulportal.hessen.de',
        ),
      );
      final config = ref.read(lanisConfigProvider);
      final login = await LanisSession.getLoginURL(
        widget.session.account,
        config,
      );
      if (!mounted) return;
      if (login.isEmpty) throw StateError('leer');
      await _c.loadRequest(Uri.parse(login));
    } catch (_) {
      _report('PortalAppLogin');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _finished(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return;
    // Wieder auf der Anmeldeseite: Die Anmeldeadresse wurde abgelehnt.
    if (u.host == 'login.schulportal.hessen.de' && !_inPortal) {
      _report('PortalAppLoginPage');
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (u.host == 'start.schulportal.hessen.de') _inPortal = true;
    final target = widget.app.uri;
    if (_inPortal && !_sent) {
      if (target == null) {
        _report('PortalAppLink');
        if (mounted) setState(() => _failed = true);
        return;
      }
      _sent = true;
      _c.loadRequest(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    // Zurück erst innerhalb der Seiten des Angebots, dann aus der Seite
    // (wie Moodle).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_failed && await _c.canGoBack()) {
          await _c.goBack();
        } else if (context.mounted) {
          _leaving = true;
          Navigator.of(context).pop();
        }
      },
      // Kopf wie die übrigen Unterseiten (PinnedPage): Überschrift groß,
      // Zurück und Kind-Pillen oben bzw. quer in der Kopfzeile. Ursache
      // (Nachprüfung 14.11.26): Mit eigener AppBar sah die Seite anders aus
      // und zeigte nicht, welches Kind angemeldet ist.
      child: Scaffold(
        backgroundColor: k.p.bg,
        body: PinnedPage(
          leading: BackInChips.of(context)
              ? null
              : IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back, color: k.p.ink),
                  tooltip: t.back,
                ),
          headerPadding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.xl,
            Sp.page - Sp.xs,
            Sp.s,
          ),
          header: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.app.name,
                      style: k.pageTitle,
                      maxLines: 1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t.portalInBrowser,
                  icon: Icon(Icons.open_in_browser, color: k.p.ink),
                  onPressed: () => openPortalFor(context, widget.session),
                ),
              ],
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Immer gleich hoch, damit die Seite beim Fertigladen nicht
              // springt. Farben der App (wie Noten laden, absences_page.dart)
              // statt Material-Lila (Rückmeldung 14.11.26 zum Entwurf).
              SizedBox(
                height: Sz.progress,
                child: _progress < 100 && !_failed
                    ? LinearProgressIndicator(
                        value: _progress / 100,
                        minHeight: Sz.progress,
                        color: k.p.ink,
                        backgroundColor: k.p.inset,
                      )
                    : null,
              ),
              Expanded(
                child: _failed
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.portalAppFailed,
                                style: k.body,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: Sp.l),
                              FilledButton(
                                // Wie die Knöpfe der App (demo_entry.dart).
                                style: FilledButton.styleFrom(
                                  backgroundColor: k.p.strong,
                                  foregroundColor: k.p.onStrong,
                                ),
                                onPressed: _start,
                                child: Text(t.retry),
                              ),
                              TextButton(
                                onPressed: () =>
                                    openPortalFor(context, widget.session),
                                child: Text(t.portalInBrowser, style: k.link),
                              ),
                            ],
                          ),
                        ),
                      )
                    : WebViewWidget(controller: _c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Was ein Link in einem Angebot tut ([portalNavigation]).
enum PortalNav {
  /// Im Portal bleiben (laden).
  stay,

  /// Nicht laden (Abmelden, fremde Rahmen, unbekannte Schemata).
  block,

  /// An eine App des Geräts (E-Mail, Telefon).
  device,

  /// Im Browser öffnen (fremde Seite im Hauptrahmen).
  browser,
}

/// Entscheidung je Link in [PortalAppPage], ohne Seite prüfbar.
///
/// Portal, Login-Server und Landes-Moodle (*.schulportal.hessen.de, nur
/// https; die Anmeldung läuft über login.* und connect.*) bleiben; Abmelden ist gesperrt (wie lib/view/moodle.dart: es
/// beendete alle Sitzungen des Kontos, auch die der App). E-Mail und
/// Telefon (z. B. Kontakt im Wahltool) gehen an das Gerät – Ursache
/// (Nachprüfung 14.11.26): solche Links liefen ins Leere. Alles Fremde nur
/// aus dem Hauptrahmen: ein eingebetteter Rahmen soll weder Browser noch
/// Telefon-App ohne Antippen öffnen (Prüfbefund 14.11.26). Grenze: sms:,
/// intent:// und andere Schemata bleiben gesperrt – safeLaunchUrl öffnet
/// nur Web, E-Mail und Telefon (lib/utils/safe_launch.dart), intent://
/// könnte beliebige Apps starten.
PortalNav portalNavigation(Uri u, {required bool mainFrame}) {
  final portal =
      u.scheme == 'https' &&
      (u.host == 'schulportal.hessen.de' ||
          u.host.endsWith('.schulportal.hessen.de'));
  if (portal) {
    final logout =
        u.queryParameters.containsKey('logout') ||
        u.path == '/login/logout.php';
    return logout ? PortalNav.block : PortalNav.stay;
  }
  if (!mainFrame) return PortalNav.block;
  if (u.scheme == 'mailto' || u.scheme == 'tel') return PortalNav.device;
  if (u.scheme == 'https' || u.scheme == 'http') return PortalNav.browser;
  return PortalNav.block;
}
