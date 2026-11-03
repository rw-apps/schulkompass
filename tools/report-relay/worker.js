// Weiterleitung für Fehlerberichte und anonyme Seiten (Entwurf 26.10.26).
//
// Ursache: Die App hat bewusst keinen eigenen Server (Entscheidung 17.10.26),
// und ein GitHub-Schlüssel in der App wäre öffentlich (der Code ist offen).
// Dieser Dienst hält den Schlüssel und legt je Bericht ein Issue in einem
// PRIVATEN Repo an; die GitHub-App benachrichtigt die Person, die die App
// betreut.
//
// Einstellungen (Cloudflare → Worker → Settings → Variables):
//   GITHUB_TOKEN  feingranularer Token, nur „Issues: write“ auf REPO (Secret)
//   REPO          z. B. "rw-apps/schulportal-berichte" (privat)
//   LIMITS        KV-Namespace für die Tagesgrenze
//
// Grenzen:
// - Jeder kann an die Adresse senden (die App ist offen, ein Geheimnis in
//   ihr wäre keins). Schutz: Größe, Art, Grenze je Absender und Tag, Tages-
//   grenze gesamt; das Repo ist privat. Grenze: KV zählt nicht atomar –
//   gleichzeitige Anfragen können eine Grenze knapp überschreiten.
// - Speichert keine IP-Adresse; Cloudflare selbst protokolliert Abrufe
//   kurzzeitig (Datenschutzerklärung nennen).
// - Ein Issue fasst 65 536 Zeichen; längere Seiten werden auf Kommentare
//   verteilt.

const MAX_BYTES = 400_000;
const PER_DAY = 50;
// Je Absender und Tag (Sicherheitsprüfung 03.11.26): Sonst konnte ein
// Einzelner mit 50 Anfragen die Tagesgrenze für alle ausschöpfen. Gezählt
// wird ein Hash aus Tag und Adresse – die IP selbst wird nicht gespeichert.
const PER_SENDER = 5;
const CHUNK = 60_000;

export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return text('Nur POST', 405);
    if (+(req.headers.get('content-length') ?? 0) > MAX_BYTES) {
      return text('Zu groß', 413);
    }
    // Echte Länge prüfen: Ohne Content-Length (chunked) griff die Grenze
    // oben nicht (Sicherheitsprüfung 03.11.26).
    const raw = await req.text();
    if (raw.length > MAX_BYTES) return text('Zu groß', 413);
    let r;
    try {
      r = JSON.parse(raw);
    } catch {
      return text('Kein JSON', 400);
    }
    // kind: "fehler" (ErrorLog.report) | "seite" (anonyme Seite)
    if (!['fehler', 'seite'].includes(r.kind) || typeof r.text !== 'string') {
      return text('Unbekannte Art', 400);
    }
    const day = new Date().toISOString().slice(0, 10);
    const ip = req.headers.get('CF-Connecting-IP') ?? '';
    const sender = `${day}:${await sha256(`${day}|${ip}`)}`;
    const m = +((await env.LIMITS.get(sender)) ?? 0);
    if (m >= PER_SENDER) return text('Grenze je Absender erreicht', 429);
    const n = +((await env.LIMITS.get(day)) ?? 0);
    if (n >= PER_DAY) return text('Tagesgrenze erreicht', 429);
    await env.LIMITS.put(sender, `${m + 1}`, { expirationTtl: 172800 });
    await env.LIMITS.put(day, `${n + 1}`, { expirationTtl: 172800 });

    const title = `${r.kind === 'seite' ? 'Seite' : 'Fehler'} ${clip(r.version, 20)}: ${clip(r.area, 60)}`;
    const parts = [];
    for (let i = 0; i < r.text.length; i += CHUNK) {
      parts.push(fenced(r.text.slice(i, i + CHUNK)));
    }
    const issue = await gh(env, `/repos/${env.REPO}/issues`, {
      title,
      body: parts[0] ?? '(leer)',
      labels: [r.kind],
    });
    if (!issue.ok) return text('Weiterleitung fehlgeschlagen', 502);
    const { number } = await issue.json();
    for (const p of parts.slice(1)) {
      await gh(env, `/repos/${env.REPO}/issues/${number}/comments`, { body: p });
    }
    return text('ok', 200);
  },
};

// Codeblock mit einem Zaun, der länger ist als jede Backtick-Folge im Text:
// Sonst konnte ein Bericht mit ``` aus dem Block ausbrechen und im privaten
// Repo Erwähnungen (@…) und Links erzeugen (Sicherheitsprüfung 03.11.26).
const fenced = (t) => {
  const longest = Math.max(2, ...(t.match(/`+/g) ?? []).map((x) => x.length));
  const fence = '`'.repeat(longest + 1);
  return `${fence}\n${t}\n${fence}`;
};
const sha256 = async (s) => {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(d)]
    .slice(0, 12)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
};
const clip = (s, n) => `${s ?? ''}`.replace(/[\r\n]/g, ' ').slice(0, n);
const text = (s, status) => new Response(s, { status });
const gh = (env, path, body) =>
  fetch(`https://api.github.com${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'schulportal-report-relay',
    },
    body: JSON.stringify(body),
  });
