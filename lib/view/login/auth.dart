import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/fork/l10n/l10n.dart';
import 'package:lanis/fork/onboarding/onboarding_kit.dart';
import 'package:lanis/fork/class_choice.dart' show storeClass;
import 'package:lanis/fork/login_guard.dart' show handOverLoginUrl;
import 'package:lanis/fork/onboarding/onboarding_pages.dart';
import 'package:lanis/fork/onboarding/restore_backup.dart';
import 'package:lanis/fork/settings_transfer.dart';
import 'package:lanis/fork/ui/live/live_data.dart' show settingsRevision;
import 'package:lanis/fork/ui/settings/device_transfer_page.dart'
    show DeviceReceivePage;
import 'package:lanis/fork/onboarding/setup_class.dart';
import 'package:lanis/fork/ui/settings/class_sheet.dart';
import 'package:lanis/fork/ui/kit.dart';
import 'package:lanis/fork/ui/login_errors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/fork/start.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/login/school_selector.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool showBackButton;

  /// Sicherungsdatei, mit der die Einrichtung beginnt (Willkommen →
  /// „Mit Sicherungsdatei einrichten“, router.dart über `extra`).
  final TransferBackup? restore;
  const LoginForm({required this.showBackButton, this.restore, super.key});

  @override
  ConsumerState<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends ConsumerState<LoginForm> {
  static const double padding = 10.0;

  final _formKey = GlobalKey<FormState>();

  TextEditingController schoolIDController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool dseAgree = false;
  bool errorReportingAgree = false;
  String selectedSchoolName = "";

  /// Bei der Ersteinrichtung bereits angelegte Konten (Anzeige „Schule ·
  /// Benutzer“). Ursache (Wunsch 17.10.26): Familien mit Kindern an
  /// verschiedenen Schulen sollen alle Zugänge gleich nacheinander eingeben,
  /// statt später über Einstellungen → Konten. Grenze: Nur bei der ersten
  /// Anmeldung; „Konto hinzufügen“ aus dem Kontowechsel endet wie bisher nach
  /// einem Konto.
  final _added = <String>[];

  /// Je eingerichtetem Konto: Nummer, Schule, Kind und Klasse (Entwurf
  /// 20.10.26 k3, setup_class.dart).
  final _setup = <({int id, String school, SetupClass cls})>[];
  final _classes = <({String value, bool detected})?>[];

  /// Neu erzeugt den Schulwähler je Runde (ValueKey), damit er leer beginnt.
  int _round = 0;

  /// Einrichtung aus einer Sicherungsdatei (restore_backup.dart): Konten
  /// der Datei nacheinander, je Konto nur das Passwort. null = normales
  /// Formular.
  TransferBackup? _restore;
  final _restoreSteps = <String, RestoreStep>{};

  /// Schulnamen aus der öffentlichen Schulliste für ältere Dateien ohne
  /// `names` (settings_transfer.dart, buildTransfer).
  Map<int, String> _schoolNames = const {};

  BackupAccount? get _restoreActive {
    final b = _restore;
    if (b == null) return null;
    for (final a in b.accounts) {
      if (_restoreSteps[a.key] == RestoreStep.pending) return a;
    }
    return null;
  }

  String _restoreSchool(BackupAccount a) =>
      _restore?.names[a.key] ?? _schoolNames[a.schoolId] ?? '';

  void _startRestore(TransferBackup b) {
    _restore = b;
    _restoreSteps
      ..clear()
      ..addAll({for (final a in b.accounts) a.key: RestoreStep.pending});
    passwordController.clear();
    if (b.accounts.any((a) => !b.names.containsKey(a.key))) {
      fetchSchoolNames()
          .then((names) {
            if (mounted) setState(() => _schoolNames = names);
          })
          // Ohne Netz bleibt „Schule 1234“ stehen; die Anmeldung meldet den
          // fehlenden Zugang dann selbst.
          .catchError((Object _) {});
    }
  }

  /// Aktuelles Konto der Sicherung überspringen; ohne weitere Konten endet
  /// die Einrichtung (mit Konten) oder kehrt zum Formular zurück (ohne).
  void _skipRestore() {
    final a = _restoreActive;
    if (a == null) return;
    setState(() {
      _restoreSteps[a.key] = RestoreStep.skipped;
      passwordController.clear();
    });
    if (_restoreActive != null) return;
    if (_added.isNotEmpty) {
      _finishSetup();
    } else {
      setState(() => _restore = null);
    }
  }

  Future<void> _pickRestore() async {
    final b = await pickBackup(context);
    if (b == null || !mounted) return;
    setState(() => _startRestore(b));
  }

  @override
  void initState() {
    super.initState();
    if (widget.restore case final b?) _startRestore(b);
    // Mirror the device-wide GlitchTip choice when adding another account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shared = ref.read(sharedOverAccountSettingsProvider);
      setState(() {
        errorReportingAgree = isGlitchTipEnabled(shared);
      });
    });
  }

  /// Ende einer Sperre des Portals, die die Einrichtung gemeldet hat.
  /// Ursache (Rückmeldung 19.10.26): Jeder weitere Versuch während der
  /// Sperre verlängert sie; die Einrichtung fragte trotzdem erneut an.
  /// Grenze: nur für diese Seite – ein neuer Start der App kennt sie nicht.
  DateTime? _lockedUntil;

  /// Verständlicher Fehlerdialog (loginErrorText); bei abgelehnten
  /// Zugangsdaten mit Hinweis auf Schule und automatisch eingesetzte
  /// Passwörter statt des rohen Portaltexts.
  void _showLoginError(Object ex) {
    final t = context.t;
    final k = Kit.of(context);
    final msg = loginErrorText(t, ex);
    final school = selectedSchoolName.isEmpty
        ? schoolIDController.text
        : selectedSchoolName;
    final text = ex is WrongCredentialsException
        ? t.loginSetupWrongText(school)
        : msg.text;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(msg.title, style: k.sheetTitle),
        content: Text(text, style: k.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: k.link),
          ),
        ],
      ),
    );
  }

  void login(String username, String password, String schoolID) async {
    final until = _lockedUntil;
    if (until != null && until.isAfter(DateTime.now())) {
      _showLoginError(
        LoginTimeoutException(
          '${until.difference(DateTime.now()).inSeconds + 1}',
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).logInTitle),
        content: const Center(
          heightFactor: 1.2,
          child: CircularProgressIndicator(),
        ),
      ),
    );
    // Fork: Steht der Ladedialog noch? Ursache (Prüfung 27.10.26): Der
    // catch unten schloss immer „den Dialog“ – kam der Fehler erst danach
    // (Rückfrage weiteres Kind, Benachrichtigungs-Seite, Plattform-Abfrage),
    // schloss er stattdessen die Anmeldeseite. Grenze: nur dieser Ablauf.
    var dialogOpen = true;
    try {
      final schoolId = int.parse(schoolID);
      final accounts = await ref.read(accountsProvider.future);
      final firstSetup = accounts.isEmpty || _added.isNotEmpty;
      // Fork: Benutzername ohne Groß/Klein und Leerzeichen vergleichen, wie
      // transferAccountKey (settings_transfer.dart). Ursache (Prüfung
      // 27.10.26): „Max.M“ und „max.m“ wurden zwei Konten derselben Person;
      // die Eingaben-Übertragung ordnete beide demselben Schlüssel zu.
      final wanted = username.trim().toLowerCase();
      if (accounts.any(
        (a) =>
            a.schoolID == schoolId && a.username.trim().toLowerCase() == wanted,
      )) {
        throw AccountAlreadyExistsException();
      }

      // Login checkbox is the first-time privacy acceptance for new accounts.
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);
      setGlitchTipEnabled(shared, errorReportingAgree);

      final config = ref.read(lanisConfigProvider);
      // Fork: Die Prüfung bleibt VOR dem Anlegen – ein falsches Passwort
      // ändert so weder die Datenbank noch die Sitzung eines schon
      // angemeldeten Kontos (loginWithAccount meldet es beim Wechsel ab und
      // nach einem Fehlschlag neu an). Ihr Login-Link wird aber für die
      // Anmeldung gleich danach übergeben (handOverLoginUrl, login_guard.dart).
      // Ursache (Prüfung 27.10.26, Befund 9): Bisher folgte eine zweite,
      // volle Anmeldung mit denselben Daten. Grenze: Die Meldungen bei
      // falschem Passwort, Sperre, Störung oder fehlender Verbindung kommen
      // weiter aus dieser Prüfung – unverändert.
      final loginUrl = await LanisSession.getLoginURL(
        ClearTextAccount(
          localId: -1,
          schoolID: schoolId,
          username: username,
          password: password,
          schoolName: "",
        ),
        config,
      );

      final newID = await ref
          .read(accountsProvider.notifier)
          .add(
            schoolId: schoolId,
            username: username,
            password: password,
            schoolName: selectedSchoolName,
          );
      handOverLoginUrl(newID, loginUrl);
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(newID, removeAccountOnFailure: true);
      if (!mounted) return;
      // Klasse erkennen, solange der Ladedialog noch steht (höchstens 10 s).
      // Aus der Sicherung kommt die Klasse mit den Eingaben (classSetting);
      // die Erkennung und ihre Rückfrage entfallen dort.
      final cls = ok && firstSetup && _restore == null
          ? await detectSetupClass(ref)
          : null;
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      dialogOpen = false;
      if (ok) {
        if (!firstSetup) {
          context.go(firstSupportedHomePath(ref));
          return;
        }
        _added.add(
          '${selectedSchoolName.isEmpty ? schoolID : selectedSchoolName} · $username',
        );
        final c = cls ?? (detected: '', kidName: '', show: false);
        _setup.add((id: newID, school: selectedSchoolName, cls: c));
        _classes.add(c.show ? (value: c.detected, detected: true) : null);
        if (_restore case final b?) {
          // Eingaben dieses Kontos sofort übernehmen, dann das nächste.
          final key = transferAccountKey(schoolId, username);
          final db = ref.read(lanisDatabaseProvider);
          final mine = (await db.listAccounts()).where(
            (a) => a.localId == newID,
          );
          applyTransferValues(db, {key: b.data[key] ?? const {}}, [...mine]);
          settingsRevision.value++;
          if (!mounted) return;
          setState(() {
            _restoreSteps[key] = RestoreStep.done;
            passwordController.clear();
          });
          if (_restoreActive != null) return;
          await _finishSetup();
          return;
        }
        final more = await _askForAnother();
        if (!mounted) return;
        if (more == true) {
          setState(() {
            _round++;
            schoolIDController.clear();
            usernameController.clear();
            passwordController.clear();
            selectedSchoolName = '';
          });
          return;
        }
        await _finishSetup();
        return;
      }
      if (!mounted) return;
      final e = ref.read(authControllerProvider).exception;
      _noteLock(e);
      _showLoginError(e ?? UnknownException(''));
    } catch (ex, s) {
      logger.e(ex, stackTrace: s);
      if (!mounted) return;
      if (dialogOpen) Navigator.pop(context); // pop dialog
      if (ex is AccountAlreadyExistsException) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(
              AppLocalizations.of(context).accountExists,
              style: Kit.of(context).body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: Kit.of(context).link),
              ),
            ],
          ),
        );
        return;
      }
      _noteLock(ex);
      _showLoginError(ex);
    }
  }

  /// Schritt 2: Benachrichtigungen erklären, dann fragen – nur wenn
  /// Android sie noch nicht erlaubt hat (NotifyIntroPage); danach zur
  /// Startseite. Gemeinsam für das Formular und die Sicherung.
  Future<void> _finishSetup() async {
    final home = firstSupportedHomePath(ref);
    // Abfrage kann auf manchen Geräten werfen; dann wie „erlaubt“ direkt
    // zur Startseite (StartupScreen fragt später). Ursache (Prüfung
    // 04.11.26): Aus _skipRestore gerufen, blieb ein Fehler unbehandelt.
    var granted = true;
    try {
      granted = await Permission.notification.isGranted;
    } catch (_) {}
    if (granted) {
      if (mounted) context.go(home);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) =>
            NotifyIntroPage(onDone: () => Navigator.of(page).pop()),
      ),
    );
    if (mounted) context.go(home);
  }

  void _noteLock(Object? e) {
    if (e is! LoginTimeoutException) return;
    final secs = int.tryParse(e.time.trim()) ?? 60;
    _lockedUntil = DateTime.now().add(Duration(seconds: secs + 5));
  }

  /// Klasse eines eben eingerichteten Kontos ändern (class_sheet.dart) und
  /// im Konto speichern (class_choice.dart).
  Future<({String value, bool detected})?> _editClass(int i) async {
    final e = _setup[i];
    final cur = _classes[i];
    final t = context.t;
    final r = await showClassSheet(
      context,
      kidName: e.cls.kidName.isEmpty ? t.yourChild : e.cls.kidName,
      school: e.school,
      colorIndex: i,
      detected: e.cls.detected,
      current: cur?.value ?? '',
      hasEntry: cur != null && !cur.detected,
    );
    if (r == null) return null;
    final db = ref.read(lanisDatabaseProvider);
    storeClass(TypedSettings.account(db, e.id), r.name);
    final next = r.name == null
        ? (value: e.cls.detected, detected: true)
        : (value: r.name!, detected: false);
    _classes[i] = next;
    return next;
  }

  /// „Konto eingerichtet“ als eigene Seite (Entwurf 18.10.26) statt des
  /// Dialogs; true = weiteres Konto.
  Future<bool?> _askForAnother() => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AccountAddedPage(
        accounts: List.of(_added),
        classes: List.of(_classes),
        onEditClass: _editClass,
      ),
    ),
  );

  @override
  void dispose() {
    schoolIDController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Seite „Konten aus der Sicherung“ (Entwurf 04.11.26, abgenommen).
  Widget _buildRestore(BuildContext context) {
    final k = Kit.of(context);
    final t = context.t;
    final l = AppLocalizations.of(context);
    final b = _restore!;
    final accounts = b.accounts;
    final active = _restoreActive;
    final created = b.created?.toLocal();
    final hosts = transferMensaHosts(b.data, [for (final a in accounts) a.key]);
    final done = accounts
        .where((a) => _restoreSteps[a.key] != RestoreStep.pending)
        .length;
    String school(BackupAccount a) {
      final n = _restoreSchool(a);
      final id = '${a.schoolId}';
      return n.isEmpty ? t.restoreSchool(id) : '$n · $id';
    }

    String two(int v) => v.toString().padLeft(2, '0');
    return AutofillGroup(
      child: OnbPage(
        step: t.onbStep(1, 2),
        // Zurück verlässt nur die Sicherung (zum normalen Formular); schon
        // angemeldete Konten bleiben.
        onBack: _added.isEmpty ? () => setState(() => _restore = null) : null,
        top: [
          const SizedBox(height: Sp.m),
          if (created != null)
            Text(
              OnbPage.upper(
                t.restoreFrom(
                  '${two(created.day)}.${two(created.month)}.${created.year}',
                ),
              ),
              style: k.dateCaps,
            ),
          const SizedBox(height: Sp.xs),
          Text(t.restoreTitle, style: k.pageTitle),
          const SizedBox(height: Sp.s),
          Text(t.restoreIntro, style: k.meta),
          // Ursache wie im Übernehmen-Dialog (transfer_page.dart,
          // Sicherheitsprüfung 03.11.26): Eine fremde Datei könnte „Essen“
          // auf eine nachgemachte Bestellseite lenken.
          if (hosts.isNotEmpty) ...[
            const SizedBox(height: Sp.s),
            Text(t.transferMensaHosts(hosts.join(', ')), style: k.meta),
          ],
          const SizedBox(height: Sp.xl),
          for (final a in accounts)
            RestoreAccountCard(
              school: school(a),
              username: a.username,
              step: _restoreSteps[a.key] ?? RestoreStep.pending,
              password: a.key == active?.key
                  ? TextField(
                      controller: passwordController,
                      autofillHints: const [AutofillHints.password],
                      autocorrect: false,
                      obscureText: true,
                      style: k.body,
                      onChanged: (_) => setState(() {}),
                      decoration: onbInput(
                        k,
                        label: l.authPasswordHint,
                        icon: Icons.lock_outline,
                      ),
                    )
                  : null,
            ),
          InkWell(
            onTap: () => setState(() => dseAgree = !dseAgree),
            child: Row(
              children: [
                Checkbox(
                  value: dseAgree,
                  onChanged: (v) => setState(() => dseAgree = v ?? false),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: k.meta,
                      children: [
                        TextSpan(text: l.authIAccept),
                        TextSpan(
                          text: l.authTermsOfService,
                          style: k.link,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => safeLaunchUrl(
                              Uri.parse(privacyPolicyUrl),
                              context: context,
                            ),
                        ),
                        TextSpan(text: l.authOfLanisMobile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: [
          OnbButton(
            // Gedeckelt: Nach dem letzten Konto stünde kurz „3 von 2“.
            label: t.restoreLogin(
              done < accounts.length ? done + 1 : accounts.length,
              accounts.length,
            ),
            onPressed:
                active != null && dseAgree && passwordController.text.isNotEmpty
                ? () async {
                    // Ältere Dateien ohne Namen: Schulliste noch einmal
                    // versuchen, sonst bliebe schoolName des Kontos leer
                    // (Prüfung 04.11.26). Höchstens 5 s, dann ohne Namen.
                    if (_restoreSchool(active).isEmpty) {
                      try {
                        final names = await fetchSchoolNames().timeout(
                          const Duration(seconds: 5),
                        );
                        if (names.isNotEmpty) _schoolNames = names;
                      } catch (_) {}
                      if (!mounted) return;
                    }
                    selectedSchoolName = _restoreSchool(active);
                    schoolIDController.text = '${active.schoolId}';
                    login(
                      active.username.trim().toLowerCase(),
                      passwordController.text,
                      '${active.schoolId}',
                    );
                  }
                : null,
          ),
          const SizedBox(height: Sp.s),
          Center(
            child: TextButton(
              onPressed: active == null ? null : _skipRestore,
              child: Text(t.restoreSkip, style: k.link),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fork (Entwurf 18.10.26): Formular im Stil der App (onboarding_kit.dart)
    // statt Lanis-Standard; Logik (login, Prüfung, Schulwahl) unverändert.
    final k = Kit.of(context);
    final t = context.t;
    final l = AppLocalizations.of(context);
    final noAccounts = ref.watch(accountsProvider).value?.isEmpty == true;
    final firstSetup = noAccounts || _added.isNotEmpty;
    if (_restore != null) return _buildRestore(context);
    final ready = schoolIDController.text.isNotEmpty;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: OnbPage(
          step: firstSetup ? t.onbStep(1, 2) : null,
          onBack: widget.showBackButton && _added.isEmpty
              ? () {
                  // Welcome uses go('/login') (no stack); account switcher uses push.
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                }
              : null,
          top: [
            const SizedBox(height: Sp.m),
            if (firstSetup)
              Text(
                OnbPage.upper(t.onbAccountNumber(_added.length + 1)),
                style: k.dateCaps,
              ),
            const SizedBox(height: Sp.xs),
            Text(
              _added.isEmpty ? t.onbLoginTitle : t.anotherAccountTitle,
              style: k.pageTitle,
            ),
            const SizedBox(height: Sp.s),
            Text(t.onbLoginText, style: k.meta),
            const SizedBox(height: Sp.xl),
            SchoolSelector(
              key: ValueKey(_round),
              controller: schoolIDController,
              outContext: context,
              onSchoolSelected: (name) {
                selectedSchoolName = name;
                setState(() {});
              },
            ),
            const SizedBox(height: Sp.m),
            TextFormField(
              controller: usernameController,
              enabled: ready,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              enableSuggestions: false,
              style: k.body,
              decoration: onbInput(
                k,
                label: l.authUsernameHint,
                icon: Icons.person_outline,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? l.authValidationError : null,
            ),
            const SizedBox(height: Sp.m),
            TextFormField(
              controller: passwordController,
              enabled: ready,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              obscureText: true,
              style: k.body,
              decoration: onbInput(
                k,
                label: l.authPasswordHint,
                icon: Icons.lock_outline,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? l.authValidationError : null,
            ),
            const SizedBox(height: Sp.m),
            InkWell(
              onTap: ready ? () => setState(() => dseAgree = !dseAgree) : null,
              child: Row(
                children: [
                  Checkbox(
                    value: dseAgree,
                    onChanged: ready
                        ? (v) => setState(() => dseAgree = v ?? false)
                        : null,
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: k.meta,
                        children: [
                          TextSpan(text: l.authIAccept),
                          TextSpan(
                            text: l.authTermsOfService,
                            style: k.link,
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => safeLaunchUrl(
                                Uri.parse(privacyPolicyUrl),
                                context: context,
                              ),
                          ),
                          TextSpan(text: l.authOfLanisMobile),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Zweitwege nur bei der allerersten Einrichtung (Entwurf
            // 04.11.26): Nach einer Neuinstallation fand man sie sonst nur
            // auf der Willkommensseite.
            if (noAccounts && _added.isEmpty) ...[
              const SizedBox(height: Sp.l),
              const OnbOrDivider(),
              const SizedBox(height: Sp.m),
              OnbButton(
                label: t.setupWithFile,
                icon: Icons.upload_file,
                strong: false,
                onPressed: _pickRestore,
              ),
              const SizedBox(height: Sp.s),
              OnbButton(
                label: t.devFromOther,
                icon: Icons.qr_code_2,
                strong: false,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeviceReceivePage(firstSetup: true),
                  ),
                ),
              ),
            ],
          ],
          bottom: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: Sz.icon, color: k.p.muted),
                const SizedBox(width: Sp.s),
                Expanded(child: Text(t.onbStoredHint, style: k.meta)),
              ],
            ),
            const SizedBox(height: Sp.l),
            OnbButton(
              label: l.logIn,
              onPressed: dseAgree && ready
                  ? () {
                      if (_formKey.currentState!.validate()) {
                        login(
                          // trim: Android-Tastaturen hängen nach einem
                          // Wortvorschlag ein Leerzeichen an – das Portal
                          // lehnt den Namen dann ab (Rückmeldung 19.10.26).
                          usernameController.text.trim().toLowerCase(),
                          passwordController.text,
                          schoolIDController.text,
                        );
                      }
                    }
                  : null,
            ),
            const SizedBox(height: Sp.s),
            Center(
              child: TextButton(
                onPressed: ready
                    ? () => safeLaunchUrl(
                        Uri.parse(
                          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userPWreminder&i=${schoolIDController.text}",
                        ),
                        context: context,
                      )
                    : null,
                child: Text(l.authResetPassword, style: k.link),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
