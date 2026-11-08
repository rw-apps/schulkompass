import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart' show sharedOverAccountSettingsProvider;
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:lanis/utils/safe_launch.dart';

import '../../l10n/l10n.dart';
import '../../mensa.dart';
import '../../mensa_login.dart';
import '../kit.dart';
import '../../mensa_store.dart';
import '../../mensa_week.dart';
import 'meal_fetcher.dart' show jsText, pageHtml;
import 'mensa_unclip.dart';

// Wer zuletzt auf welcher Bestellseite war: mensaLastKey (mensa_store.dart).
// Öffnet man nach einem Kind die gleiche Seite für ein anderes, wäre noch das
// erste angemeldet – deshalb erscheint dann ein Hinweis mit „Abmelden“.
// Grenze: Teilen sich Geschwister EIN Konto beim Caterer, ist der Hinweis
// überflüssig und lässt sich einfach schließen.

/// Bestellseite in der App; die Anmeldung bleibt gespeichert, bis man sich
/// in der App abmeldet (Einstellungen → Abmelden löscht alle Web-Cookies).
class MensaPage extends ConsumerStatefulWidget {
  const MensaPage({
    super.key,
    required this.url,
    required this.owner,
    this.childName,
    this.open,
    this.returnAfterLogin = false,
  });

  /// Nach der Anmeldung zurück in die App-Ansicht, sobald eine Woche lesbar
  /// ist. Ursache (Rückmeldung 08.11.26): Ohne gemerkten Zugang konnte
  /// „Essen“ den Plan nicht lesen; nach „Bestellen oder ändern“ und der
  /// Anmeldung blieb man auf der Seite des Caterers statt in der Ansicht der
  /// App. MealWeekPage._order setzt das nur im Zustand „Laden
  /// fehlgeschlagen“ und liest nach der Rückkehr neu (_refresh). Grenze:
  /// erst nach der Rückfrage „Anmeldung merken?“, nur mit einer Woche, die
  /// NACH dem Abschicken der Anmeldung gelesen wurde (selbst oder mit dem
  /// gemerkten Zugang), und nur, wenn die Sitzung diesem Kind gehört
  /// (_otherName == null). Kein Rücksprung, wenn man noch per Cookie
  /// angemeldet ist (dann gibt es keine Anmeldung) oder der Caterer ohne
  /// neue Seite anmeldet (kein onPageFinished). Ein falsches Passwort führt
  /// auf die Anmeldeseite zurück – ohne lesbare Woche, also bleibt man.
  final bool returnAfterLogin;

  /// Genau diese Adresse öffnen (eine Woche aus „Essen“); null = die
  /// Bestellwoche (mensaWeekUrl). Ursache: Sonst ersetzte mensaWeekUrl die
  /// gewählte Woche wieder durch die Bestellwoche.
  final String? open;

  /// Eingetragene Adresse (normalizeMensaUrl); die Woche wird beim Öffnen
  /// ersetzt (mensaWeekUrl).
  final String url;

  /// Eindeutig je Konto und Kind (`konto:kind`).
  final String owner;

  final String? childName;

  @override
  ConsumerState<MensaPage> createState() => _MensaPageState();
}

class _MensaPageState extends ConsumerState<MensaPage> {
  late final Uri _home = Uri.parse(widget.url);
  late final WebViewController _c;
  int _progress = 0;
  bool _failed = false;
  String? _otherName;

  /// Hinweis ausgeblendet – die Seite gilt trotzdem nicht als übernommen.
  bool _hidden = false;

  /// Gemerkte Anmeldung je Seite höchstens einmal einsetzen (mensa_login.dart).
  bool _triedLogin = false;
  bool _afterLogin = false;
  bool _asked = false;

  /// Für [MensaPage.returnAfterLogin] (mensaShouldReturn): Seitenzähler
  /// [_starts] beim Abschicken bzw. Ausfüllen der Anmeldung (-1 = keine;
  /// „abgeschickt“, nicht „vom Caterer angenommen“) und beim Lesen der
  /// letzten Woche; [_deciding] solange _onLogin läuft (Speicherzugriffe,
  /// Rückfrage „merken?“).
  int _signedInAt = -1;
  int _weekAt = -1;
  int _deciding = 0;
  bool _returned = false;

  void _maybeReturn() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (!mensaShouldReturn(
      enabled: widget.returnAfterLogin,
      returned: _returned,
      signedInAt: _signedInAt,
      weekAt: _weekAt,
      deciding: _deciding > 0,
      otherSession: _otherName != null,
      // Nur wenn diese Seite oben liegt (Prüfung 08.11.26): Nach Android-
      // Zurück ist sie während der Ausblendung noch eingehängt – ein pop
      // träfe dann die Woche darunter; ein offener Dialog wäre das Ziel.
      onTop: route?.isCurrent ?? false,
    )) {
      return;
    }
    _returned = true;
    Navigator.of(context).pop();
  }

  String get _start => widget.open ?? mensaWeekUrl(widget.url, DateTime.now());

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kitWebCanvas)
      ..addJavaScriptChannel(
        mensaLoginChannel,
        onMessageReceived: (m) => _onLogin(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            _starts++;
            if (mounted) setState(() => _failed = false);
          },
          // Abgeschnittene Gerichte aufheben (mensa_unclip.dart). Fehler
          // (Seite schon verlassen) sind folgenlos: dann bleibt sie, wie
          // der Caterer sie liefert.
          onPageFinished: (_) {
            _c.runJavaScript(mensaUnclipJs).catchError((_) {});
            _c.runJavaScript(mensaLoginCaptureJs).catchError((_) {});
            _autoLogin();
            _remember();
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: (r) {
            final target = Uri.tryParse(r.url);
            if (target == null) return NavigationDecision.prevent;
            if (mensaAllows(_home, target)) return NavigationDecision.navigate;
            // Nur der Hauptrahmen öffnet extern; eingebettete Rahmen
            // (Werbung, Zähler) werden still verworfen.
            if (r.isMainFrame &&
                (target.scheme == 'https' || target.scheme == 'http')) {
              safeLaunchUrl(
                target,
                context: context,
                mode: LaunchMode.externalApplication,
              );
            }
            return NavigationDecision.prevent;
          },
        ),
      );
    _checkOwner();
    _c.loadRequest(Uri.parse(_start));
  }

  Future<bool> _hasPasswordField() async {
    try {
      final r = await _c.runJavaScriptReturningResult(
        "document.querySelector('input[type=password]') ? 1 : 0",
      );
      return '$r' == '1';
    } catch (_) {
      return false;
    }
  }

  /// Abgelaufene Sitzung: gemerkte Anmeldung einsetzen. Danach leitet der
  /// Caterer meist auf seine Startseite – dann einmal die gewünschte Woche
  /// neu laden.
  ///
  /// Doppelt gemeldetes Seitenende (Android, Abrufverlauf 27.10.26): Ein
  /// zweites Ausfüllen läuft nicht parallel ([_filling]), und erst eine neu
  /// begonnene Seite ([_starts] > [_fillStarts]) gilt als Ergebnis der
  /// Anmeldung – sonst verbrauchte das zweite Ereignis [_afterLogin] noch
  /// auf der Anmeldeseite, und die gewünschte Woche kam nie.
  Future<void> _autoLogin() async {
    if (_afterLogin) {
      if (_starts <= _fillStarts) return;
      _afterLogin = false;
      if (!await _hasPasswordField() && mounted) {
        await _c.loadRequest(Uri.parse(_start));
      }
      return;
    }
    if (_triedLogin || _filling) return;
    _filling = true;
    try {
      final l = await readMensaLogin(widget.owner, auto: true);
      final host = Uri.tryParse(await _c.currentUrl() ?? '')?.host;
      if (l == null ||
          !mensaSameHost('https://$host', 'https://${l.host}') ||
          !mounted) {
        return;
      }
      final r = await _c.runJavaScriptReturningResult(mensaLoginFillJs(l));
      if ('$r'.contains('filled')) {
        _triedLogin = true;
        _afterLogin = true;
        _fillStarts = _starts;
        _signedInAt = _starts;
        _claim();
      }
    } catch (_) {
    } finally {
      _filling = false;
    }
  }

  var _filling = false;
  var _starts = 0;
  var _fillStarts = 0;

  /// Anmeldung eingegeben: einmal fragen, ob die App sie merken soll.
  /// Seitenzähler beim Eingang festhalten: Bis die Prüfungen fertig sind,
  /// kann schon die nächste Seite laufen.
  Future<void> _onLogin(String message) async {
    final at = _starts;
    _deciding++;
    try {
      await _onLoginAt(message, at);
    } finally {
      _deciding--;
      _maybeReturn();
    }
  }

  Future<void> _onLoginAt(String message, int at) async {
    final Object? v;
    try {
      v = jsonDecode(message);
    } catch (_) {
      return;
    }
    if (v is! Map) return;
    final u = v['u'], p = v['p'];
    if (u is! String || p is! String || u.isEmpty || p.isEmpty) return;
    // Absender nicht glauben (Sicherheitsprüfung 03.11.26): Der Kanal steht
    // auf Android jedem Rahmen offen, auch fremden iframes (Werbung,
    // Zähler), und die Nachricht nannte ihren Host selbst. Jetzt zählt der
    // Host der Seite im Hauptrahmen, und dort muss ein Passwortfeld genau
    // diesen Wert tragen – sonst weder übernehmen (_claim) noch merken.
    final h = Uri.tryParse(await _c.currentUrl() ?? '')?.host ?? '';
    if (!mounted || h.isEmpty) return;
    if (!mensaAllows(_home, Uri(scheme: 'https', host: h))) return;
    final Object typed;
    try {
      typed = await _c.runJavaScriptReturningResult(
        '(function (p) { var ps = document.querySelectorAll('
        "'input[type=password]'); for (var i = 0; i < ps.length; i++) "
        "{ if (ps[i].value === p) return 'yes'; } return 'no'; })"
        '(${jsonEncode(p)})',
      );
    } catch (_) {
      return;
    }
    if (!'$typed'.contains('yes') || !mounted) return;
    // Selbst angemeldet: ab jetzt die Sitzung dieses Kindes.
    if (at > _signedInAt) _signedInAt = at;
    _claim();
    // Sofort sperren: Das Skript meldet Klick, Absenden und Enter – zwei
    // Meldungen je Anmeldung kamen sonst beide bis zur Rückfrage (Prüfung
    // 08.11.26).
    if (_asked) return;
    _asked = true;
    final old = await readMensaLogin(widget.owner);
    if (old != null && old.user == u && old.pass == p && old.host == h) {
      // Selbst eingegeben, also wieder gültig: eine frühere Ablehnung
      // (markMensaLoginFailed) aufheben.
      if (await mensaLoginFailed(widget.owner)) {
        await saveMensaLogin(widget.owner, old);
      }
      return;
    }
    if (old == null && await mensaLoginDeclined(widget.owner)) return;
    if (!mounted) return;
    final t = context.t;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.mensaRememberTitle),
        content: Text(t.mensaRememberText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(t.mensaRememberNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(t.mensaRememberYes),
          ),
        ],
      ),
    );
    if (yes == true) {
      await saveMensaLogin(widget.owner, MensaLogin(host: h, user: u, pass: p));
    } else if (yes == false && old == null) {
      await declineMensaLogin(widget.owner);
    }
  }

  /// Gelesene Woche für „Essen“ und Heute merken (mensa_store.dart): Nach
  /// einer Bestellung hier stimmt die Anzeige ohne weiteren Abruf.
  Future<void> _remember() async {
    final at = _starts;
    final src = await pageHtml(_c);
    final url = await _c.currentUrl();
    final w = (src == null ? null : parseMealWeek(src))?.withUrl(url);
    if (!mounted) return;
    if (w == null) return _hop(url);
    _hopDone = true;
    // Noch die Sitzung des anderen Kindes (_checkOwner): nicht merken.
    if (_otherName != null) return;
    try {
      MealCache.instance
        ..attach(ref.read(sharedOverAccountSettingsProvider))
        ..put(widget.owner, [w]);
    } catch (_) {}
    if (at > _weekAt) _weekAt = at;
    _maybeReturn();
  }

  /// Erste Seite ohne Woche und ohne Anmeldemaske (Hinweisseite nach der
  /// Anmeldung): einmal dem Link zur Essensbestellung folgen (mealNavJs).
  /// Ursache (Bildschirmfoto 27.10.26): Sonst musste man über die Figur
  /// oben rechts und „Kundenbereich“ gehen. Grenze: nur beim Öffnen, nicht
  /// wenn man danach selbst auf die Startseite wechselt.
  bool _hopDone = false;

  Future<void> _hop(String? url) async {
    if (_hopDone || _afterLogin || await _hasPasswordField()) return;
    _hopDone = true;
    try {
      final h = jsText(await _c.runJavaScriptReturningResult(mealNavJs));
      final t = Uri.tryParse(h);
      if (h.isEmpty || t == null || h == url || !mensaAllows(_home, t)) return;
      if (mounted) await _c.loadRequest(t);
    } catch (_) {}
  }

  /// War zuletzt ein anderes Kind auf dieser Seite, gilt noch dessen
  /// Sitzung: Hinweis mit „Abmelden“, und die Seite zählt erst als die
  /// dieses Kindes, wenn man sich abmeldet, selbst anmeldet (auch mit der
  /// gemerkten Anmeldung) oder den Hinweis schließt ([_claim]).
  ///
  /// Ursache (Rückmeldung 01.11.26): Bis 9463 zählte die Seite schon beim
  /// Öffnen als die dieses Kindes. Mit der (versehentlich eingetragenen)
  /// Adresse des Geschwisters las die App dessen angemeldete Woche als die
  /// dieses Kindes ([_remember]) und hätte unsichtbar auf dessen Konto
  /// bestellt (MealOrderRunner prüft mensaLastOwner).
  void _checkOwner() {
    final shared = ref.read(sharedOverAccountSettingsProvider);
    final prev = mensaLastOwner(shared, _home.host);
    if (prev != null && prev != widget.owner) {
      _otherName = mensaLastName(shared, _home.host);
      return;
    }
    _claim();
  }

  void _claim() {
    try {
      setMensaLastOwner(
        ref.read(sharedOverAccountSettingsProvider),
        _home.host,
        widget.owner,
        name: widget.childName ?? '',
      );
    } catch (_) {}
    if (_otherName != null && mounted) setState(() => _otherName = null);
  }

  Future<void> _logout() async {
    await WebViewCookieManager().clearCookies();
    if (!mounted) return;
    _claim();
    _triedLogin = false;
    await _c.loadRequest(Uri.parse(_start));
  }

  @override
  Widget build(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final other = _otherName;
    return Scaffold(
      backgroundColor: k.p.bg,
      appBar: AppBar(
        backgroundColor: k.p.bg,
        surfaceTintColor: k.p.bg,
        title: Text(
          widget.childName == null || widget.childName!.isEmpty
              ? t.orderMeal
              : t.orderMealFor(widget.childName!),
          style: k.section,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: t.reload,
            icon: const Icon(Icons.refresh),
            onPressed: () => _c.reload(),
          ),
          IconButton(
            tooltip: t.openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final now = await _c.currentUrl();
              if (!context.mounted) return;
              safeLaunchUrl(
                Uri.parse(now ?? mensaWeekUrl(widget.url, DateTime.now())),
                context: context,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(Sz.progress),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: Sz.progress,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (other != null && !_hidden)
            Material(
              color: k.p.change.bg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.s, Sp.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            other.isEmpty
                                ? t.mensaOtherLoggedIn
                                : t.mensaOtherLoggedInName(other),
                            style: k.boxText(k.p.change),
                          ),
                        ),
                        IconButton(
                          tooltip: t.close,
                          icon: Icon(Icons.close, color: k.p.change.ink),
                          onPressed: () => setState(() => _hidden = true),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: Sp.s,
                      children: [
                        TextButton(
                          onPressed: _logout,
                          child: Text(t.mensaLogout, style: k.link),
                        ),
                        // Geschwister teilen ein Konto beim Caterer: erst
                        // dieser ausdrückliche Knopf übernimmt die Seite
                        // (_claim). Ursache (unabhängige Prüfung 02.11.26):
                        // Bis 9466 tat das schon das Schließen – wer den
                        // Hinweis nur wegklickte, ließ die App die Woche des
                        // Geschwisters als die dieses Kindes merken und dort
                        // bestellen.
                        TextButton(
                          onPressed: _claim,
                          child: Text(t.mensaSameAccount, style: k.link),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                            t.mensaLoadFailed,
                            style: k.meta,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => _c.reload(),
                            child: Text(t.retry, style: k.link),
                          ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _c),
          ),
        ],
      ),
    );
  }
}

/// Entscheidung für MensaPage.returnAfterLogin, ohne WebView prüfbar.
/// [signedInAt]/[weekAt]: Seitenzähler beim Abschicken der Anmeldung bzw.
/// beim Lesen der Woche (-1 = nie); die Woche muss von einer SPÄTEREN Seite
/// stammen – eine lesbare Seite vor der Anmeldung zählt nicht (Prüfung
/// 08.11.26).
bool mensaShouldReturn({
  required bool enabled,
  required bool returned,
  required int signedInAt,
  required int weekAt,
  required bool deciding,
  required bool otherSession,
  required bool onTop,
}) =>
    enabled &&
    !returned &&
    signedInAt >= 0 &&
    weekAt > signedInAt &&
    !deciding &&
    !otherSession &&
    onTop;
