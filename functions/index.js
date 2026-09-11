const { onRequest } = require("firebase-functions/v2/https");
const {
  onDocumentUpdated,
  onDocumentCreated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const fs = require("fs");
const os = require("os");
const path = require("path");
const sharp = require("sharp");
initializeApp();
const db = getFirestore();

// Registers the bundled Shan/Myanmar-capable font (fonts/AJKunheing20.ttf)
// with fontconfig *before* sharp/librsvg ever runs, so songCard's SVG can
// reference it by family name like any other installed font. This has to
// happen via real fontconfig registration, not an SVG `@font-face` + base64
// data URI — that approach renders correctly when tested locally (this
// machine's sharp build honors it) but silently fails on the actual
// deployed Cloud Functions container, falling back to tofu boxes for every
// Myanmar/Shan glyph while Latin text still renders via *some* generic
// fallback — confirmed by fetching the live endpoint after first deploying
// the @font-face version. Fontconfig's own font-matching is the mechanism
// an actually-installed font uses, so it doesn't depend on librsvg's
// (apparently inconsistent) @font-face support at all.
const fontConfigPath = path.join(os.tmpdir(), "paimorn-fontconfig.conf");
fs.writeFileSync(
  fontConfigPath,
  `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>${path.join(__dirname, "fonts")}</dir>
  <cachedir>${path.join(os.tmpdir(), "paimorn-fontconfig-cache")}</cachedir>
</fontconfig>
`,
);
process.env.FONTCONFIG_FILE = fontConfigPath;

// Note: the Storage bucket's CORS config (needed for a browser to read
// profile photos via fetch/canvas — see profile_screen.dart) was set once
// via a temporary function (no gsutil/gcloud CLI available in this
// environment) using the Admin SDK's Storage client, then removed — the
// bucket-level setting itself persists independent of any function's
// existence, so this doesn't need to run again.

const SITE_URL = "https://song-and-chord.web.app";

// Crawlers that generate link previews when a song URL is shared — none of
// these execute JavaScript, so the real Flutter app (which fetches the song
// name from Firestore client-side) is invisible to them. This is the
// standard "dynamic rendering" workaround: detect the bot and hand it a
// tiny static HTML page with the real og:title/description instead.
const BOT_UA_PATTERNS = [
  "facebookexternalhit", "facebot", "twitterbot", "linkedinbot",
  "whatsapp", "telegrambot", "slackbot", "discordbot", "pinterest",
  "line", "vkshare", "redditbot", "googlebot", "bingbot", "applebot",
  "skypeuripreview", "snapchat",
];

function isBot(userAgent) {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return BOT_UA_PATTERNS.some((pattern) => ua.includes(pattern));
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// Hosting rewrites every /songbook/song/** request here (see firebase.json)
// so this one function has to handle both audiences: bots get a bare OG-tag
// page, everyone else gets passed through to the real app shell.
exports.songPreview = onRequest(async (req, res) => {
  const match = req.path.match(/\/songbook\/song\/([^/]+)/);
  const songId = match ? decodeURIComponent(match[1]) : null;
  const userAgent = req.get("user-agent") || "";
  const pageUrl = `${SITE_URL}${req.path}`;

  if (!songId || !isBot(userAgent)) {
    // Real visitors: proxy the actual built index.html so the Flutter app
    // boots exactly as it would if Hosting had served it directly. Fetched
    // from the literal static file, so this can't loop back into this
    // rewrite — Hosting always serves an exact static-file match before it
    // ever considers a rewrite rule.
    //
    // no-store is deliberate: Firebase's CDN in front of this function
    // caches by URL under its own fixed Vary policy, which ignores any
    // Vary: User-Agent this function sets — confirmed by testing, a bot
    // response cached as `public` got replayed verbatim to the very next
    // real browser hitting the same song URL, serving them a dead, non-
    // interactive page instead of the app. Any `public`/cacheable response
    // on this route is unsafe for that reason, on both branches.
    try {
      const shellRes = await fetch(`${SITE_URL}/index.html`);
      const shellHtml = await shellRes.text();
      res.set("Content-Type", "text/html; charset=UTF-8");
      res.set("Cache-Control", "no-store");
      res.send(shellHtml);
    } catch (err) {
      console.error("songPreview: failed to fetch app shell", err);
      res.redirect(302, SITE_URL);
    }
    return;
  }

  let title = "Paimorn";
  let description = "Browse, submit, and read song lyrics and chords.";
  let songExists = false;
  let lyricsHtml = "";
  let jsonLd = null;
  try {
    const doc = await db.collection("songs").doc(songId).get();
    if (doc.exists) {
      songExists = true;
      const data = doc.data();
      const songName = (data.songName || "").toString();
      const artist = (data.artist || "").toString();
      title = [songName, artist].filter(Boolean).join(" — ") || title;
      if (songName) {
        description = artist
          ? `${songName} by ${artist} — lyrics and chords on Paimorn.`
          : `${songName} — lyrics and chords on Paimorn.`;
      }
      // Only an approved song's actual lyrics/chords are real, public
      // content — Admin SDK reads here bypass firestore.rules entirely, so
      // this manually re-enforces the same "pending/rejected/draft songs
      // aren't public" rule the rest of the app gets from Firestore itself.
      // This is the part that actually fixes indexability: everything
      // above already existed for social-preview cards (title/description/
      // image only) — search engines need real body text to match a
      // lyric someone searches for, not just a title.
      if (data.status === "approved") {
        lyricsHtml = lyricsToHtml(data.lyrics);
        jsonLd = {
          "@context": "https://schema.org",
          "@type": "MusicComposition",
          name: songName || undefined,
          composer: artist ? { "@type": "Person", name: artist } : undefined,
          lyrics: { "@type": "CreativeWork", text: lyricsToPlainText(data.lyrics) },
          url: pageUrl,
        };
      }
    }
  } catch (err) {
    console.error("songPreview: failed to load song", songId, err);
  }

  // A real song gets its own generated card (song name + artist + opening
  // chords — see songCard below) instead of the generic app icon, so a
  // shared link actually previews the specific song instead of just
  // "Paimorn" with no way to tell songs apart in a chat thread.
  const imageUrl = songExists
    ? `${SITE_URL}/songbook/song-card/${encodeURIComponent(songId)}.png`
    : `${SITE_URL}/icons/Icon-512.png`;

  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<link rel="canonical" href="${escapeHtml(pageUrl)}">
<meta property="og:type" content="website">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:image" content="${escapeHtml(imageUrl)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="${escapeHtml(pageUrl)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(description)}">
<meta name="twitter:image" content="${escapeHtml(imageUrl)}">
${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>` : ""}
</head>
<body>
<h1>${escapeHtml(title)}</h1>
${lyricsHtml}
<p><a href="${escapeHtml(pageUrl)}">${escapeHtml(SITE_URL)}</a></p>
</body>
</html>`;
  res.set("Content-Type", "text/html; charset=UTF-8");
  // See the no-store note in the branch above — this route can't safely
  // use a shared/public cache on this platform regardless of which branch
  // sets it, since the CDN doesn't actually vary by User-Agent.
  res.set("Cache-Control", "no-store");
  res.send(html);
});

// Same section-label vocabulary/heuristic as lyric_line_view.dart's
// isStandaloneLabelLine/_isSectionLabelText — a line whose only non-chord
// text is empty or starts with one of these keywords (e.g. "Key", "Intro-
// F/Dm") is a label/instrumental line, not a real sung lyric line, so the
// print layout below renders it as one plain inline row instead of trying
// to stack a chord row above it.
const PRINT_SECTION_LABEL_KEYWORDS = new Set([
  "key", "intro", "verse", "chorus", "bridge", "solo", "outro",
]);
const PRINT_SEPARATOR_PATTERN = /^[/-]+$/;

function isStandaloneLabelLineForPrint(content) {
  let buffer = "";
  for (const item of content) {
    if (item.type === "chord") continue;
    const text = (item.text || "").toString();
    if (PRINT_SEPARATOR_PATTERN.test(text.trim())) continue;
    buffer += text;
  }
  const trimmed = buffer.trim();
  if (trimmed === "") return true;
  const match = trimmed.match(/^([a-zA-Z]+)/);
  return Boolean(match && PRINT_SECTION_LABEL_KEYWORDS.has(match[1].toLowerCase()));
}

// Same chord-offset-tracking approach as lyric_line_view.dart's
// buildLyricLine (a chord's position is the length of the lyric text
// accumulated so far when it was encountered), just placed onto a
// character grid instead of measured in pixels — appropriate here because
// the print page renders everything in one monospace font, where a
// character index and a column position are the same thing. Chords never
// reflect the reader's live transpose control (this is a fresh page load
// with no client state to read), always the song's original written key.
function buildAlignedPrintLine(content) {
  let buffer = "";
  const chordEntries = [];
  for (const item of content) {
    const rawText = (item.text || "").toString();
    if (item.type === "chord") {
      chordEntries.push({ offset: buffer.length, text: rawText });
    } else if (PRINT_SEPARATOR_PATTERN.test(rawText.trim())) {
      // Real space characters on both sides, mirroring the same fix in
      // lyric_line_view.dart's buildLyricLine — a bare "/" or "-" glyph
      // reads as glued to the chord text right next to it without them.
      chordEntries.push({ offset: buffer.length, text: ` ${rawText.trim()} ` });
    } else {
      buffer += rawText;
    }
  }
  const lyricLine = buffer;
  let cursor = 0;
  const placed = [];
  for (const entry of chordEntries) {
    const x = entry.offset < cursor ? cursor : entry.offset;
    placed.push({ x, text: entry.text });
    cursor = x + entry.text.length + 1;
  }
  const width = Math.max(lyricLine.length, cursor);
  const chordChars = new Array(width).fill(" ");
  for (const p of placed) {
    for (let i = 0; i < p.text.length; i++) chordChars[p.x + i] = p.text[i];
  }
  const chordLine = chordChars.join("").replace(/\s+$/, "");
  return { chordLine, lyricLine };
}

function buildPrintLyricsHtml(lyrics) {
  if (!Array.isArray(lyrics)) return "";
  const blocks = [];
  for (const lyric of lyrics) {
    const content = Array.isArray(lyric && lyric.content) ? lyric.content : [];
    if (isStandaloneLabelLineForPrint(content)) {
      const text = content
        .map((item) => (item.text || "").toString())
        .join(" ")
        .replace(/\s+/g, " ")
        .trim();
      blocks.push(`<pre class="line">${text ? escapeHtml(text) : "&nbsp;"}</pre>`);
      continue;
    }
    const { chordLine, lyricLine } = buildAlignedPrintLine(content);
    if (chordLine.trim()) {
      blocks.push(`<pre class="line chord-row">${escapeHtml(chordLine)}</pre>`);
    }
    blocks.push(`<pre class="line">${lyricLine ? escapeHtml(lyricLine) : "&nbsp;"}</pre>`);
  }
  return blocks.join("\n");
}

// A print-optimized, real-DOM page for one approved song — reusing the
// same "server renders plain text, browser handles the rest" idea as
// songPreview's bot branch, but for a real visitor's own print/Save-as-PDF
// action. Flutter web's CanvasKit rendering has no real text layer for the
// browser's print engine to lay out on paper (the same underlying reason
// SEO needed songPreview in the first place), so a dedicated static route
// is the only reliable way to print exact, selectable, correctly-paginated
// text instead of a canvas screenshot. Chord/lyric columns are aligned in
// one monospace font on a character grid — exact for Latin/Thai text;
// Myanmar/Shan lyric lines may drift slightly if the visitor's browser
// substitutes a different (non-monospace-width) font for those glyphs,
// same limitation any plain-text chord sheet has.
exports.songPrintPage = onRequest(async (req, res) => {
  const match = req.path.match(/\/songbook\/song\/([^/]+)\/print/);
  const songId = match ? decodeURIComponent(match[1]) : null;
  if (!songId) {
    res.status(400).send("Missing song id");
    return;
  }

  let found = false;
  let songName = "";
  let artist = "";
  let songwriter = "";
  let keyText = "";
  let linesHtml = "";
  try {
    const doc = await db.collection("songs").doc(songId).get();
    if (doc.exists) {
      const data = doc.data();
      // Same privacy gate as songPreview — only an approved song's lyrics
      // are public content, regardless of what the Admin SDK can read.
      if (data.status === "approved") {
        found = true;
        songName = (data.songName || "").toString();
        artist = (data.artist || "").toString();
        songwriter = (data.songwriter || "").toString();
        if (data.key) {
          keyText = `${data.key}${data.keyIsMinor ? "m" : ""}`;
        }
        linesHtml = buildPrintLyricsHtml(data.lyrics);
      }
    }
  } catch (err) {
    console.error("songPrintPage: failed to load song", songId, err);
  }

  if (!found) {
    res
      .status(404)
      .set("Content-Type", "text/html; charset=UTF-8")
      .send("<!DOCTYPE html><html><body><p>Song not available.</p></body></html>");
    return;
  }

  const title = [songName, artist].filter(Boolean).join(" — ") || "Paimorn";
  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>${escapeHtml(title)}</title>
<style>
  @page { size: A4; margin: 16mm; }
  body { font-family: Arial, sans-serif; color: #111; margin: 0; padding: 24px; }
  h1 { font-size: 22px; margin: 0 0 6px; }
  .meta { font-size: 13px; color: #555; margin-bottom: 2px; }
  .key { font-size: 13px; color: #555; margin: 10px 0 18px; }
  pre.line {
    margin: 0; padding: 0; white-space: pre; font-family: 'Courier New', monospace;
    font-size: 13px; line-height: 1.35;
  }
  .chord-row { color: #0B6FCB; font-weight: bold; }
  .print-bar { text-align: center; margin-bottom: 20px; }
  .print-bar button {
    font-family: Arial, sans-serif; font-size: 15px; padding: 8px 22px;
    cursor: pointer; border-radius: 6px; border: 1px solid #ccc; background: #f5f5f5;
  }
  @media print { .print-bar { display: none; } body { padding: 0; } }
</style>
</head>
<body>
<div class="print-bar"><button onclick="window.print()">Print / Save as PDF</button></div>
<h1>${escapeHtml(songName)}</h1>
${artist ? `<div class="meta">${escapeHtml(artist)}</div>` : ""}
${songwriter ? `<div class="meta">${escapeHtml(songwriter)}</div>` : ""}
${keyText ? `<div class="key">Key ${escapeHtml(keyText)}</div>` : ""}
${linesHtml}
</body>
</html>`;

  res.set("Content-Type", "text/html; charset=UTF-8");
  res.set("Cache-Control", "no-store");
  res.send(html);
});

// Flattens one song's `lyrics` array (array of `{content: [{type, text}]}`
// lines) into the exact bracket-syntax plain text the app's own submit form
// uses (lyrics_parser.dart's lyricsBlockToText) — chords as `[Chord]`,
// lyric text as-is, one line per authored line. Shared by both HTML and
// JSON-LD rendering below so the two never drift apart.
function lyricsToPlainText(lyrics) {
  if (!Array.isArray(lyrics)) return "";
  return lyrics
    .map((line) => {
      const content = Array.isArray(line && line.content) ? line.content : [];
      return content
        .map((item) => {
          const text = (item && item.text ? item.text : "").toString();
          return item && item.type === "chord" ? `[${text}]` : text;
        })
        .join("");
    })
    .join("\n");
}

// Real, crawlable body content for search engines — one <p> per authored
// lyric line, same bracket-syntax as lyricsToPlainText so a search engine
// indexing this page sees genuine sung-lyric text (what someone would
// actually type into a search box), not just a title.
function lyricsToHtml(lyrics) {
  if (!Array.isArray(lyrics)) return "";
  return lyrics
    .map((line) => {
      const text = lyricsToPlainText([line]);
      if (!text.trim()) return "";
      return `<p>${escapeHtml(text)}</p>`;
    })
    .join("\n");
}

// The exact family name embedded in AJKunheing20.ttf's own `name` table
// (nameID 1) — "A Jkunheing20", with a space — not the filename. This is
// the string fontconfig registers it under, so it has to match exactly for
// the SVG's font-family to resolve to it instead of silently substituting
// something else.
const SONG_CARD_FONT_FAMILY = "A Jkunheing20";

function escapeXml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

// No text-measurement API is available server-side without pulling in a
// much heavier dependency just for this — a character-count heuristic is
// good enough for a social-preview card (exact pixel-perfect wrapping isn't
// the point), generous enough for Latin, and conservative enough that wider
// Myanmar/Shan glyphs still fit within the 1200px card at these font sizes.
function truncateForCard(text, maxChars) {
  const trimmed = text.trim();
  if (trimmed.length <= maxChars) return trimmed;
  return `${trimmed.slice(0, maxChars - 1).trimEnd()}…`;
}

// Walks a song's lyrics in authored order and collects the first few real
// chord tokens (skipping bar/beat separators like "/" or "-" — see the
// matching logic in lyric_line_view.dart) so the card shows an actual
// taste of the song instead of nothing chord-related at all.
function extractOpeningChords(lyrics, max = 5) {
  const chords = [];
  if (!Array.isArray(lyrics)) return chords;
  for (const lyric of lyrics) {
    const content = lyric && lyric.content;
    if (!Array.isArray(content)) continue;
    for (const item of content) {
      if (item && item.type === "chord" && item.text) {
        chords.push(String(item.text));
        if (chords.length >= max) return chords;
      }
    }
  }
  return chords;
}

// 1200x630 — the standard Open Graph / Twitter large-image size. One
// fontconfig-registered font (SONG_CARD_FONT_FAMILY, see the module-level
// fontconfig setup above) used for every piece of text on the card,
// including the chord chips: this container has no guaranteed system font
// with Myanmar/Shan coverage (unlike a real browser, which is what made
// Shan text look fine in every earlier manual test this session), and the
// registered font already covers Latin cleanly too — one font everywhere
// sidesteps that risk entirely rather than gambling on a system fallback
// for chord text.
function buildSongCardSvg({ songName, artist, chords }) {
  const width = 1200;
  const height = 630;
  const title = escapeXml(truncateForCard(songName || "Paimorn", 22));
  const hasArtist = Boolean(artist && artist.trim());
  const subtitle = hasArtist
    ? escapeXml(truncateForCard(artist.trim(), 34))
    : "";

  const chordChips = chords
    .slice(0, 5)
    .map((chord, i) => {
      const x = 80 + i * 140;
      const y = height - 150;
      const label = escapeXml(truncateForCard(chord, 6));
      return `
        <rect x="${x}" y="${y}" width="110" height="64" rx="14" fill="rgba(255,255,255,0.16)" />
        <text x="${x + 55}" y="${y + 42}" font-size="30" font-weight="bold" fill="#ffffff" text-anchor="middle">${label}</text>
      `;
    })
    .join("");

  return `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <style>
      text { font-family: '${SONG_CARD_FONT_FAMILY}'; }
    </style>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0984E3" />
      <stop offset="100%" stop-color="#C2185B" />
    </linearGradient>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#bg)" />
  <text x="80" y="100" font-size="30" font-weight="bold" fill="rgba(255,255,255,0.85)" letter-spacing="4">PAIMORN</text>
  <text x="80" y="300" font-size="68" font-weight="bold" fill="#ffffff">${title}</text>
  ${subtitle ? `<text x="80" y="360" font-size="34" fill="rgba(255,255,255,0.88)">${subtitle}</text>` : ""}
  ${chordChips}
</svg>`;
}

// Served at /songbook/song-card/{songId}.png (see firebase.json) — bots
// resolving og:image/twitter:image (songPreview above) fetch this directly;
// a real browser could too (e.g. right-click "open image"), but nothing in
// the app links to it for a human audience.
exports.songCard = onRequest(async (req, res) => {
  const match = req.path.match(/\/songbook\/song-card\/([^/]+?)(?:\.png)?$/);
  const songId = match ? decodeURIComponent(match[1]) : null;
  if (!songId) {
    res.status(400).send("missing song id");
    return;
  }

  let songName = "Paimorn";
  let artist = "";
  let chords = [];
  try {
    const doc = await db.collection("songs").doc(songId).get();
    if (doc.exists) {
      const data = doc.data();
      songName = (data.songName || "Paimorn").toString();
      artist = (data.artist || "").toString();
      chords = extractOpeningChords(data.lyrics);
    }
  } catch (err) {
    console.error("songCard: failed to load song", songId, err);
  }

  try {
    const svg = buildSongCardSvg({ songName, artist, chords });
    const png = await sharp(Buffer.from(svg)).png().toBuffer();
    res.set("Content-Type", "image/png");
    // Song name/artist/opening chords essentially never change after
    // publication — a day-long cache keeps repeated crawler fetches (most
    // link-preview bots re-fetch og:image separately from the HTML) cheap.
    res.set("Cache-Control", "public, max-age=86400");
    res.send(png);
  } catch (err) {
    console.error("songCard: render failed for", songId, err);
    res.status(500).send("failed to render card");
  }
});

// Same visual grammar as buildSongCardSvg (small label / big title /
// subtitle / bottom chip row) but for the site itself rather than one song
// — a small label, big "Paimorn", a tagline, and live site stats as chips
// instead of chords, so sharing the bare homepage/app link looks like it
// belongs to the same brand as sharing a song instead of falling back to a
// plain square app icon.
function buildSiteCardSvg({ songCount, artistCount }) {
  const width = 1200;
  const height = 630;
  const stats = [
    `${songCount} Songs`,
    `${artistCount} Artists`,
    "4 Languages",
  ];
  const chipWidth = 200;
  const chipsTotalWidth = stats.length * chipWidth + (stats.length - 1) * 24;
  const chipsStartX = (width - chipsTotalWidth) / 2;
  const chordChips = stats
    .map((label, i) => {
      const x = chipsStartX + i * (chipWidth + 24);
      const y = height - 150;
      return `
        <rect x="${x}" y="${y}" width="${chipWidth}" height="64" rx="14" fill="rgba(255,255,255,0.16)" />
        <text x="${x + chipWidth / 2}" y="${y + 42}" font-size="28" font-weight="bold" fill="#ffffff" text-anchor="middle">${escapeXml(label)}</text>
      `;
    })
    .join("");

  return `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <style>
      text { font-family: '${SONG_CARD_FONT_FAMILY}'; }
    </style>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0984E3" />
      <stop offset="100%" stop-color="#C2185B" />
    </linearGradient>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#bg)" />
  <text x="600" y="220" font-size="28" font-weight="bold" fill="rgba(255,255,255,0.85)" letter-spacing="6" text-anchor="middle">LYRICS &amp; CHORDS</text>
  <text x="600" y="320" font-size="96" font-weight="bold" fill="#ffffff" text-anchor="middle">Paimorn</text>
  <text x="600" y="380" font-size="32" fill="rgba(255,255,255,0.88)" text-anchor="middle">Browse, submit, and read song lyrics and chords</text>
  ${chordChips}
</svg>`;
}

// Served at /site-card.png (see firebase.json) — the image behind
// index.html's static og:image/twitter:image for the bare app link (a
// specific song instead gets songCard above, generated per-song). Live
// song/artist counts via cheap aggregate .count() queries, same pattern
// used throughout the client app (Home page stats, Admin Dashboard).
exports.siteCard = onRequest(async (req, res) => {
  let songCount = 0;
  let artistCount = 0;
  try {
    const [songsSnap, artistsSnap] = await Promise.all([
      db.collection("songs").where("status", "==", "approved").count().get(),
      db.collection("artists").count().get(),
    ]);
    songCount = songsSnap.data().count;
    artistCount = artistsSnap.data().count;
  } catch (err) {
    console.error("siteCard: failed to load stats", err);
  }

  try {
    const svg = buildSiteCardSvg({ songCount, artistCount });
    const png = await sharp(Buffer.from(svg)).png().toBuffer();
    res.set("Content-Type", "image/png");
    // Stats change often enough (new songs/artists) that a day-long cache
    // like songCard's would go stale visibly — an hour keeps it feeling
    // "live" without re-rendering on every single crawler fetch.
    res.set("Cache-Control", "public, max-age=3600");
    res.send(png);
  } catch (err) {
    console.error("siteCard: render failed", err);
    res.status(500).send("failed to render card");
  }
});

// "Today" is pinned to a fixed UTC+7 day boundary (roughly Thailand/
// Indochina time, this app's primary audience region) rather than each
// caller's own local time — a Cloud Function has no "local time" of its
// own (it runs in UTC), and the Flutter client uses this exact same
// helper's logic (see lib/utils/app_day.dart) so the in-app card and the
// shared Facebook image always agree on the same count instead of
// drifting by a few songs right around midnight depending on whose clock
// asked.
const APP_DAY_OFFSET_MS = 7 * 60 * 60 * 1000;
function startOfAppDayUtc(now = new Date()) {
  const shifted = new Date(now.getTime() + APP_DAY_OFFSET_MS);
  const startShifted = Date.UTC(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate(),
  );
  return new Date(startShifted - APP_DAY_OFFSET_MS);
}

// "YYYY-MM-DD" for the current app-day — mirrors lib/utils/app_day.dart's
// appDayLabel() exactly. Embedded as a query param on dailyUpdatePreview's
// own canonical/og:url and its og:image URL so link-preview crawlers
// (Facebook, LINE, ...) see a URL they've never scraped before each day —
// without it they replay whatever snapshot they cached the very first time
// this fixed URL was ever shared, silently never updating again.
function appDayLabel(now = new Date()) {
  const shifted = new Date(now.getTime() + APP_DAY_OFFSET_MS);
  const yyyy = String(shifted.getUTCFullYear()).padStart(4, "0");
  const mm = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(shifted.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

// Same visual grammar as the other share cards — small label, one big
// number, a short highlight list of what actually shipped today. Kept to
// plain text (no emoji glyphs) since sharp/librsvg's font coverage for
// arbitrary emoji code points on the deployed container isn't guaranteed,
// the same reasoning documented above for the Shan/Myanmar font
// registration.
function buildDailyUpdateCardSvg({ count, songs }) {
  const width = 1200;
  const height = 630;
  const highlightLines = songs
    .slice(0, 3)
    .map((s, i) => {
      const label = s.artist ? `${s.songName} — ${s.artist}` : s.songName;
      return `<text x="600" y="${420 + i * 46}" font-size="28" fill="rgba(255,255,255,0.92)" text-anchor="middle">${escapeXml(truncateForCard(label, 56))}</text>`;
    })
    .join("");
  const moreLine =
    songs.length > 3
      ? `<text x="600" y="${420 + 3 * 46}" font-size="22" fill="rgba(255,255,255,0.65)" text-anchor="middle">+${songs.length - 3} more</text>`
      : "";

  return `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <style> text { font-family: '${SONG_CARD_FONT_FAMILY}'; } </style>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0984E3" />
      <stop offset="100%" stop-color="#C2185B" />
    </linearGradient>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#bg)" />
  <text x="600" y="190" font-size="26" font-weight="bold" fill="rgba(255,255,255,0.85)" letter-spacing="6" text-anchor="middle">NEW ON PAIMORN TODAY</text>
  <text x="600" y="320" font-size="110" font-weight="bold" fill="#ffffff" text-anchor="middle">${count}</text>
  <text x="600" y="368" font-size="30" fill="rgba(255,255,255,0.88)" text-anchor="middle">${count === 1 ? "New Song" : "New Songs"}</text>
  ${highlightLines}
  ${moreLine}
</svg>`;
}

// Served at /daily-update-card.png (see firebase.json) — the image behind
// dailyUpdatePreview's og:image below, and directly embeddable by the
// in-app card too. Live query against `approvedAt` (see the admin_screen.
// dart / submit_song_screen.dart writes), not `createdAt` — a song
// submitted days ago but approved just now correctly counts as "today",
// which was the whole reason approvedAt was added this round instead of
// reusing the existing createdAt-based queries.
exports.dailyUpdateCard = onRequest(async (req, res) => {
  let count = 0;
  let songs = [];
  try {
    const snap = await db
      .collection("songs")
      .where("status", "==", "approved")
      .where("approvedAt", ">=", startOfAppDayUtc())
      .orderBy("approvedAt", "desc")
      .get();
    count = snap.size;
    songs = snap.docs.map((d) => ({
      songName: (d.data().songName || "").toString(),
      artist: (d.data().artist || "").toString(),
    }));
  } catch (err) {
    console.error("dailyUpdateCard: failed to load today's songs", err);
  }

  try {
    const svg = buildDailyUpdateCardSvg({ count, songs });
    const png = await sharp(Buffer.from(svg)).png().toBuffer();
    res.set("Content-Type", "image/png");
    // Changes as approvals happen through the day — a short cache lets a
    // freshly-approved song show up within minutes without re-rendering
    // on literally every single crawler/client fetch.
    res.set("Cache-Control", "public, max-age=300");
    res.send(png);
  } catch (err) {
    console.error("dailyUpdateCard: render failed", err);
    res.status(500).send("failed to render card");
  }
});

// Same dynamic-rendering split as songPreview above: a bot (link-preview
// crawler) gets a bare OG-tag page pointing at dailyUpdateCard's image;
// everyone else gets proxied the real app shell (main.dart's `/daily-
// update` route just redirects them straight to Home — this URL only
// exists to give the Facebook share button something with its own OG
// tags to point at, see todays_new_songs_card.dart).
exports.dailyUpdatePreview = onRequest(async (req, res) => {
  const userAgent = req.get("user-agent") || "";
  // ?d=<today> makes this a genuinely new URL each day so link-preview
  // crawlers re-scrape instead of replaying a stale cached snapshot from
  // whenever this page was first shared (see appDayLabel's doc comment) —
  // doesn't affect the redirect below at all, which matches on path only.
  const pageUrl = `${SITE_URL}/daily-update?d=${appDayLabel()}`;

  if (!isBot(userAgent)) {
    try {
      const shellRes = await fetch(`${SITE_URL}/index.html`);
      const shellHtml = await shellRes.text();
      res.set("Content-Type", "text/html; charset=UTF-8");
      res.set("Cache-Control", "no-store");
      res.send(shellHtml);
    } catch (err) {
      console.error("dailyUpdatePreview: failed to fetch app shell", err);
      res.redirect(302, SITE_URL);
    }
    return;
  }

  let count = 0;
  try {
    // .orderBy matches dailyUpdateCard's query exactly (same filters, same
    // direction) so both share the one `{status, approvedAt}` composite
    // index — a bare .count() with no orderBy turned out to want its own
    // separate (ascending-default) index instead, confirmed via
    // `firebase functions:log` after this first came back empty in
    // testing despite dailyUpdateCard already returning the right count.
    const snap = await db
      .collection("songs")
      .where("status", "==", "approved")
      .where("approvedAt", ">=", startOfAppDayUtc())
      .orderBy("approvedAt", "desc")
      .count()
      .get();
    count = snap.data().count;
  } catch (err) {
    console.error("dailyUpdatePreview: failed to load count", err);
  }

  const title =
    count > 0
      ? `${count} new song${count === 1 ? "" : "s"} on Paimorn today!`
      : "Paimorn — Lyrics & Chords";
  const description = "Browse, submit, and read song lyrics and chords.";
  // Same cache-busting reasoning as pageUrl above, applied to the image
  // itself — platforms can cache a scraped og:image by its own URL
  // separately from the page HTML, so this needs the date param too.
  const imageUrl = `${SITE_URL}/daily-update-card.png?d=${appDayLabel()}`;

  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<link rel="canonical" href="${escapeHtml(pageUrl)}">
<meta property="og:type" content="website">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:image" content="${escapeHtml(imageUrl)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="${escapeHtml(pageUrl)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(description)}">
<meta name="twitter:image" content="${escapeHtml(imageUrl)}">
</head>
<body>
<a href="${escapeHtml(SITE_URL)}">${escapeHtml(title)}</a>
</body>
</html>`;
  res.set("Content-Type", "text/html; charset=UTF-8");
  res.set("Cache-Control", "no-store");
  res.send(html);
});

// The static pages every visitor can reach, plus every approved song —
// without the song URLs listed here, nothing ever tells a search engine
// those pages exist to crawl in the first place (the SongBook listing
// itself is canvas-rendered with no crawlable links, and songPreview above
// only helps *once* a bot already has a specific song URL in hand). Served
// from a Hosting rewrite at /sitemap.xml (see firebase.json) rather than a
// static file, so it never goes stale as songs are added.
exports.sitemap = onRequest(async (req, res) => {
  const staticPaths = [
    "/", "/songbook", "/tuner", "/chords", "/request-song", "/about", "/contact",
    "/guide", "/privacy", "/terms", "/community", "/song-requests/vote",
  ];
  const urls = staticPaths.map((path) => `${SITE_URL}${path}`);

  try {
    const snapshot = await db
      .collection("songs")
      .where("status", "==", "approved")
      .get();
    for (const doc of snapshot.docs) {
      urls.push(`${SITE_URL}/songbook/song/${encodeURIComponent(doc.id)}`);
    }
  } catch (err) {
    console.error("sitemap: failed to load songs", err);
  }

  const body = urls
    .map((url) => `  <url><loc>${escapeHtml(url)}</loc></url>`)
    .join("\n");
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${body}
</urlset>`;

  res.set("Content-Type", "application/xml; charset=UTF-8");
  // Google fetches a sitemap at most a few times a day — a light cache cuts
  // Firestore reads without meaningfully delaying a newly-approved song's
  // discovery.
  res.set("Cache-Control", "public, max-age=3600");
  res.send(xml);
});

// In-app notifications live under users/{uid}/notifications and are never
// client-writable (see firestore.rules) — a client can't legally create a
// doc in someone *else's* subcollection, so both notification triggers have
// to run here with the Admin SDK, which bypasses rules entirely.

// Fires whenever a song document changes. Only cares about a genuine
// pending -> approved/rejected transition (not e.g. an admin's later edit to
// an already-approved song, which would otherwise re-notify the author every
// time a typo gets fixed).
exports.onSongStatusChange = onDocumentUpdated(
  "songs/{songId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "approved" && after.status !== "rejected") return;

    const authorId = after.authorId;
    if (!authorId) return;

    await db
      .collection("users")
      .doc(authorId)
      .collection("notifications")
      .add({
        type: after.status === "approved" ? "songApproved" : "songRejected",
        songId: event.params.songId,
        songName: after.songName || "",
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  },
);

// Fires when an admin links a song request to the real song that fulfilled
// it (see admin_song_requests_screen.dart's "Mark Fulfilled" picker) — only
// on the genuine not-fulfilled -> fulfilled transition, same guard shape as
// onSongStatusChange above so re-editing an already-fulfilled request's
// link (if that's ever added) doesn't re-notify. requesterUid lives in the
// private/info subcollection (see firestore.rules) since the requester
// isn't required to be signed in — an anonymous request has no uid at all,
// so there's simply nobody to notify and this quietly no-ops.
exports.onSongRequestFulfilled = onDocumentUpdated(
  "songRequests/{requestId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after) return;
    if (before.status === "fulfilled" || after.status !== "fulfilled") return;

    const fulfilledSongId = after.fulfilledSongId;
    if (!fulfilledSongId) return;

    const privateDoc = await db
      .collection("songRequests")
      .doc(event.params.requestId)
      .collection("private")
      .doc("info")
      .get();
    const requesterUid = privateDoc.exists
      ? privateDoc.data().requesterUid
      : null;
    if (!requesterUid) return;

    await db
      .collection("users")
      .doc(requesterUid)
      .collection("notifications")
      .add({
        type: "songRequestFulfilled",
        songId: fulfilledSongId,
        songName: after.fulfilledSongName || "",
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  },
);

// Fires on every new comment. Notifies the thread's author — but never for
// their own reply to their own thread, which would just be noise.
exports.onCommentCreated = onDocumentCreated(
  "communityThreads/{threadId}/comments/{commentId}",
  async (event) => {
    const comment = event.data.data();
    if (!comment) return;

    const threadId = event.params.threadId;
    const threadDoc = await db
      .collection("communityThreads")
      .doc(threadId)
      .get();
    if (!threadDoc.exists) return;
    const thread = threadDoc.data();
    const authorId = thread.authorId;
    if (!authorId || authorId === comment.authorId) return;

    await db
      .collection("users")
      .doc(authorId)
      .collection("notifications")
      .add({
        type: "threadReply",
        threadId,
        threadTitle: thread.title || "",
        commenterName: comment.authorName || "",
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  },
);

// Keeps songs/{songId}.favoriteCount in sync with the number of
// users/*/favorites/{songId} docs that reference it, so "Popular Songs"
// (book_screen.dart) can just query/orderBy a real field on the song
// instead of a client ever needing to read across other users' private
// favorites subcollections (which firestore.rules correctly forbids — a
// user's own favorites list is private).
exports.onFavoriteAdded = onDocumentCreated(
  "users/{userId}/favorites/{songId}",
  async (event) => {
    await db
      .collection("songs")
      .doc(event.params.songId)
      .update({ favoriteCount: FieldValue.increment(1) })
      .catch(() => {}); // song may have been deleted since — nothing to do
  },
);

exports.onFavoriteRemoved = onDocumentDeleted(
  "users/{userId}/favorites/{songId}",
  async (event) => {
    await db
      .collection("songs")
      .doc(event.params.songId)
      .update({ favoriteCount: FieldValue.increment(-1) })
      .catch(() => {});
  },
);

// Same denormalized-counter pattern as favoriteCount above, for comment
// likes (communityThreads/{threadId}/comments/{commentId}/likes/{uid}) —
// firestore.rules forbids a client from writing likeCount on the comment
// doc directly, so this Admin-SDK trigger is the only thing that ever
// touches it.
exports.onCommentLikeAdded = onDocumentCreated(
  "communityThreads/{threadId}/comments/{commentId}/likes/{uid}",
  async (event) => {
    await db
      .collection("communityThreads")
      .doc(event.params.threadId)
      .collection("comments")
      .doc(event.params.commentId)
      .update({ likeCount: FieldValue.increment(1) })
      .catch(() => {}); // comment may have been deleted since — nothing to do
  },
);

exports.onCommentLikeRemoved = onDocumentDeleted(
  "communityThreads/{threadId}/comments/{commentId}/likes/{uid}",
  async (event) => {
    await db
      .collection("communityThreads")
      .doc(event.params.threadId)
      .collection("comments")
      .doc(event.params.commentId)
      .update({ likeCount: FieldValue.increment(-1) })
      .catch(() => {});
  },
);

// Same denormalized-counter pattern as onCommentLikeAdded/Removed above —
// a song request's voteCount is only ever touched here (via the Admin SDK,
// which bypasses firestore.rules), never written directly by a client, so
// it can't be inflated by a client just setting a bigger number.
exports.onSongRequestVoteAdded = onDocumentCreated(
  "songRequests/{requestId}/votes/{uid}",
  async (event) => {
    await db
      .collection("songRequests")
      .doc(event.params.requestId)
      .update({ voteCount: FieldValue.increment(1) })
      .catch(() => {}); // request may have been deleted since — nothing to do
  },
);

exports.onSongRequestVoteRemoved = onDocumentDeleted(
  "songRequests/{requestId}/votes/{uid}",
  async (event) => {
    await db
      .collection("songRequests")
      .doc(event.params.requestId)
      .update({ voteCount: FieldValue.increment(-1) })
      .catch(() => {});
  },
);

// A denormalized viewCount, incremented server-side rather than letting the
// client write it directly — same reasoning as favoriteCount above, but
// here there's no natural Firestore document (a "view" isn't a doc a client
// creates) to hang a trigger off of, so this is instead a plain HTTPS
// endpoint the reader page calls once per open (song_reader_screen.dart).
// Exposed via a Hosting rewrite (see firebase.json) at /api/record-song-view
// so the call is same-origin from the app — no CORS configuration needed.
exports.recordSongView = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }
  const songId = (req.body && req.body.songId) || req.query.songId;
  if (!songId || typeof songId !== "string") {
    res.status(400).send("songId required");
    return;
  }
  await db
    .collection("songs")
    .doc(songId)
    .update({ viewCount: FieldValue.increment(1) })
    .catch(() => {}); // song may not exist (bad id) — nothing to do
  res.set("Content-Type", "application/json");
  res.send(JSON.stringify({ ok: true }));
});

// Site-wide visit counter — same fire-and-forget shape as recordSongView
// above, just aggregated into one doc instead of per-song. Every real page
// load counts once (see MyApp's initState in main.dart, not a per-route
// SPA navigation), no dedup by visitor — a raw hit count, matching the
// existing per-song viewCount's own semantics rather than adding a whole
// separate unique-visitor mechanism for one Home-page stat tile.
exports.recordSiteView = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }
  await db
    .collection("stats")
    .doc("siteViews")
    .set({ count: FieldValue.increment(1) }, { merge: true })
    .catch(() => {});
  res.set("Content-Type", "application/json");
  res.send(JSON.stringify({ ok: true }));
});
