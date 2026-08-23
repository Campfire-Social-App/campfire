const URL_PATTERN = /https?:\/\/[^\s<>"']+/gi;
const TRAILING_PUNCTUATION = /[),.!?;:\]\}]+$/;
const VIDEO_FILE_PATTERN = /\.(?:mp4|webm|ogv|ogg|mov|m4v)$/i;

export interface LinkTarget {
  url: string;
  hostname: string;
}

export interface GenericLinkPreview extends LinkTarget {
  kind: "link";
}

export interface DirectVideoPreview extends LinkTarget {
  kind: "video";
}

export interface EmbeddedVideoPreview extends LinkTarget {
  kind: "embed";
  provider: string;
  embedUrl: string;
  thumbnailUrl?: string;
}

export type LinkPreview = GenericLinkPreview | DirectVideoPreview | EmbeddedVideoPreview;

export interface LinkTextSegment {
  text: string;
  url?: string;
}

function safeUrl(rawUrl: string): URL | null {
  try {
    const parsed = new URL(rawUrl);
    if (!["http:", "https:"].includes(parsed.protocol) || parsed.username || parsed.password) {
      return null;
    }
    return parsed;
  } catch {
    return null;
  }
}

function cleanUrl(rawUrl: string): string {
  return rawUrl.replace(TRAILING_PUNCTUATION, "");
}

export function extractLinks(content: string, limit = 3): LinkTarget[] {
  const seen = new Set<string>();
  const links: LinkTarget[] = [];

  for (const match of content.matchAll(URL_PATTERN)) {
    const parsed = safeUrl(cleanUrl(match[0]));
    if (!parsed || seen.has(parsed.href)) continue;
    seen.add(parsed.href);
    links.push({ url: parsed.href, hostname: parsed.hostname.replace(/^www\./, "") });
    if (links.length === limit) break;
  }

  return links;
}

export function splitLinks(content: string): LinkTextSegment[] {
  const segments: LinkTextSegment[] = [];
  let cursor = 0;

  for (const match of content.matchAll(URL_PATTERN)) {
    const start = match.index;
    const rawUrl = match[0];
    const cleaned = cleanUrl(rawUrl);
    const parsed = safeUrl(cleaned);
    if (!parsed) continue;

    if (start > cursor) segments.push({ text: content.slice(cursor, start) });
    segments.push({ text: cleaned, url: parsed.href });
    if (cleaned.length < rawUrl.length) {
      segments.push({ text: rawUrl.slice(cleaned.length) });
    }
    cursor = start + rawUrl.length;
  }

  if (cursor < content.length) segments.push({ text: content.slice(cursor) });
  return segments.length > 0 ? segments : [{ text: content }];
}

function youtubeStartSeconds(value: string | null): number | null {
  if (!value) return null;
  if (/^\d+$/.test(value)) return Number(value);
  const parts = value.match(/^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$/i);
  if (!parts) return null;
  return Number(parts[1] ?? 0) * 3600 + Number(parts[2] ?? 0) * 60 + Number(parts[3] ?? 0);
}

function youtubePreview(parsed: URL, target: LinkTarget): EmbeddedVideoPreview | null {
  const host = target.hostname;
  const parts = parsed.pathname.split("/").filter(Boolean);
  let id: string | null = null;

  if (host === "youtu.be") id = parts[0] ?? null;
  if (["youtube.com", "m.youtube.com", "music.youtube.com"].includes(host)) {
    if (parsed.pathname === "/watch") id = parsed.searchParams.get("v");
    else if (["shorts", "live", "embed"].includes(parts[0] ?? "")) id = parts[1] ?? null;
  }
  if (!id || !/^[\w-]{11}$/.test(id)) return null;

  const start = youtubeStartSeconds(parsed.searchParams.get("t") ?? parsed.searchParams.get("start"));
  const query = new URLSearchParams({ autoplay: "1" });
  if (start && start > 0) query.set("start", String(start));
  return {
    ...target,
    kind: "embed",
    provider: "YouTube",
    embedUrl: `https://www.youtube-nocookie.com/embed/${id}?${query}`,
    thumbnailUrl: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
  };
}

function vimeoPreview(parsed: URL, target: LinkTarget): EmbeddedVideoPreview | null {
  if (!["vimeo.com", "player.vimeo.com"].includes(target.hostname)) return null;
  const id = parsed.pathname
    .split("/")
    .filter(Boolean)
    .reverse()
    .find((part) => /^\d+$/.test(part));
  if (!id) return null;
  return {
    ...target,
    kind: "embed",
    provider: "Vimeo",
    embedUrl: `https://player.vimeo.com/video/${id}?autoplay=1`,
  };
}

function dailymotionPreview(parsed: URL, target: LinkTarget): EmbeddedVideoPreview | null {
  const parts = parsed.pathname.split("/").filter(Boolean);
  let id: string | null = null;
  if (target.hostname === "dai.ly") id = parts[0] ?? null;
  if (target.hostname === "dailymotion.com" && parts[0] === "video") id = parts[1] ?? null;
  if (!id || !/^[a-zA-Z0-9]+$/.test(id)) return null;
  return {
    ...target,
    kind: "embed",
    provider: "Dailymotion",
    embedUrl: `https://www.dailymotion.com/embed/video/${id}?autoplay=1`,
    thumbnailUrl: `https://www.dailymotion.com/thumbnail/video/${id}`,
  };
}

function loomPreview(parsed: URL, target: LinkTarget): EmbeddedVideoPreview | null {
  if (target.hostname !== "loom.com") return null;
  const [kind, id] = parsed.pathname.split("/").filter(Boolean);
  if (!["share", "embed"].includes(kind ?? "") || !id || !/^[\w-]{8,}$/.test(id)) return null;
  return {
    ...target,
    kind: "embed",
    provider: "Loom",
    embedUrl: `https://www.loom.com/embed/${id}?autoplay=1`,
  };
}

function streamablePreview(parsed: URL, target: LinkTarget): EmbeddedVideoPreview | null {
  if (target.hostname !== "streamable.com") return null;
  const parts = parsed.pathname.split("/").filter(Boolean);
  const id = parts[0] === "e" ? parts[1] : parts[0];
  if (!id || !/^[a-zA-Z0-9]{4,}$/.test(id)) return null;
  return {
    ...target,
    kind: "embed",
    provider: "Streamable",
    embedUrl: `https://streamable.com/e/${id}?autoplay=1`,
  };
}

export function createLinkPreview(target: LinkTarget): LinkPreview {
  const parsed = safeUrl(target.url);
  if (!parsed) return { ...target, kind: "link" };

  const embedded =
    youtubePreview(parsed, target) ??
    vimeoPreview(parsed, target) ??
    dailymotionPreview(parsed, target) ??
    loomPreview(parsed, target) ??
    streamablePreview(parsed, target);
  if (embedded) return embedded;
  if (VIDEO_FILE_PATTERN.test(parsed.pathname)) return { ...target, kind: "video" };
  return { ...target, kind: "link" };
}

export function previewsFromContent(content: string): LinkPreview[] {
  return extractLinks(content).map(createLinkPreview);
}
