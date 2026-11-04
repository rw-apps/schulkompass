# Weiterleitung für Fehlerberichte

Nimmt Berichte der App an (automatisches Melden, „Anonym senden“) und legt
sie als Issue in einem **privaten** Repo an. Der GitHub-Schlüssel liegt nur
hier, nie in der App (die App ist quelloffen).

## Einrichten (einmalig)

1. Auf GitHub ein privates Repo anlegen, z. B. `schulportal-berichte`.
2. Feingranularen Token erstellen: nur dieses Repo, Berechtigung
   „Issues: Read and write“, sonst nichts.
3. Bei Cloudflare: Workers & Pages → Worker anlegen, Inhalt von
   `worker.js` einfügen.
4. Unter Settings → Variables:
   - `GITHUB_TOKEN` (als Secret) = der Token
   - `REPO` = `<besitzer>/schulportal-berichte`
   - `SALT` (als Secret) = zufälliger Text, mindestens 32 Zeichen. Macht den
     gezählten Absender-Hash unumkehrbar (sonst ließe er sich über alle
     IPv4-Adressen zurückrechnen).
5. Unter Storage → KV einen Namespace anlegen und im Worker als `LIMITS`
   binden (Tagesgrenze).
6. Adresse des Workers in `lib/fork/report_relay.dart` bei
   `reportRelayUrl` eintragen und ausliefern.

## Grenzen

- Die Adresse ist öffentlich bekannt; Schutz sind Größe (400 KB),
  Tagesgrenze (50) und das private Repo.
- Speichert keine IP-Adressen, nur zwei Tage lang einen Hash aus `SALT`, Tag
  und Adresse (5 Berichte je Absender und Tag). Cloudflare protokolliert
  Abrufe kurzzeitig.
