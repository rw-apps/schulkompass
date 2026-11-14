// Links in einem Angebot der Schule (PortalAppPage, Nachprüfung 14.11.26).
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/fork/ui/more/portal_app_page.dart';

void main() {
  PortalNav nav(String url, {bool main = true}) =>
      portalNavigation(Uri.parse(url), mainFrame: main);

  test('Portal bleibt, Abmelden gesperrt', () {
    expect(nav('https://start.schulportal.hessen.de/wahl.php'), PortalNav.stay);
    expect(nav('https://login.schulportal.hessen.de/?x=1'), PortalNav.stay);
    expect(
      nav('https://start.schulportal.hessen.de/index.php?logout=all'),
      PortalNav.block,
    );
    expect(
      nav('https://mo1.schulportal.hessen.de/login/logout.php'),
      PortalNav.block,
    );
    // Nur https; ähnlich klingende Hosts sind fremd.
    expect(nav('http://start.schulportal.hessen.de/'), PortalNav.browser);
    expect(nav('https://schulportal.hessen.de.example/'), PortalNav.browser);
  });

  test('E-Mail und Telefon ans Gerät, sonst gesperrt', () {
    expect(nav('mailto:info@schule.example'), PortalNav.device);
    expect(nav('tel:+49123'), PortalNav.device);
    expect(nav('sms:+49123'), PortalNav.block);
    expect(nav('intent://scan/#Intent;scheme=x;end'), PortalNav.block);
    expect(nav('javascript:alert(1)'), PortalNav.block);
  });

  test('Fremdes nur aus dem Hauptrahmen', () {
    expect(nav('https://lern.example/'), PortalNav.browser);
    expect(nav('https://lern.example/', main: false), PortalNav.block);
    expect(nav('tel:+49123', main: false), PortalNav.block);
    expect(
      nav('https://start.schulportal.hessen.de/img.php', main: false),
      PortalNav.stay,
    );
  });
}
