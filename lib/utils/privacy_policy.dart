import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork_identity.dart';

/// ISO date of the latest published privacy policy.
///
/// Bump this string when the policy is republished so users are prompted again.
// Fork: 26.10.26 neu wegen der Fehlerberichte (report_relay.dart) – alle
// werden einmal neu gefragt, weil ein neuer Empfänger dazukommt.
// 04.11.26: Datenschutzhinweis vollständig neu (Verantwortlicher,
// Rechtsgrundlagen, Speicherdauer, Rechte) – Nutzer stimmen einmal neu zu.
const privacyPolicyPublishedAt = '2026-11-04';

/// Canonical privacy policy URL (About + login + gate screen).
const privacyPolicyUrl = forkPrivacyPolicyUrl;

/// [shared_settings] key for the last accepted [privacyPolicyPublishedAt].
const privacyPolicyAcceptedVersionKey = 'privacy-policy-accepted-version';

bool isPrivacyPolicyAccepted(TypedSettings shared) {
  return shared.getString(privacyPolicyAcceptedVersionKey) ==
      privacyPolicyPublishedAt;
}

void acceptPrivacyPolicy(TypedSettings shared) {
  shared.setString(privacyPolicyAcceptedVersionKey, privacyPolicyPublishedAt);
}

/// Whether background fetch may authenticate (same gate as cold-start auth).
bool shouldRunBackgroundFetch(TypedSettings shared) {
  return isPrivacyPolicyAccepted(shared);
}
