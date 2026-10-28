// Collects migrant-related news from official Russian sources and major media (RSS / pravo.gov.ru),
// keeps only what concerns foreign workers and publishes it. New rows reach every open app at once
// through Realtime on public.news_items. Run by pg_cron every 30 minutes.
//
// With the ANTHROPIC_API_KEY secret set, Claude filters the items and retells them in simple Uzbek.
// Without it, keyword-matched items are published with their original (Russian) title.
import Anthropic from "npm:@anthropic-ai/sdk@0.71.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
const claude = apiKey ? new Anthropic({ apiKey }) : null;

type Candidate = { source: string; external_id: string; url: string; title: string; text: string; published_at: Date };

const TAGS = ["Qonunchilik", "Patent", "Hujjatlar", "Ish", "Kirish-chiqish", "Jarimalar", "Imtihon", "Boshqa"];
const GOV_RSS = ["http://government.ru/news/rss/", "http://government.ru/docs/rss/"];
const PRAVO = "http://publication.pravo.gov.ru/api/Documents";
const PRAVO_BLOCKS = ["president", "government", "federal_authorities"];
const MEDIA_FEEDS: Record<string, string> = {
  rg: "https://rg.ru/xml/index.xml",
  tass: "https://tass.ru/rss/v2.xml",
  ria: "https://ria.ru/export/rss2/archive/index.xml",
  interfax: "https://www.interfax.ru/rss.asp",
  rbc: "https://rssexport.rbc.ru/rbcnews/news/30/full.rss",
  kommersant: "https://www.kommersant.ru/RSS/news.xml",
  izvestia: "https://iz.ru/xml/rss/all.xml",
  vedomosti: "https://www.vedomosti.ru/rss/news",
};
const MIGRATION_WORDS = /мигрант|миграц|иностранн(ых|ые|ым|ого|ой|ец|цы|цев|ам) граждан|иностранц|патент на работу|трудов(ые|ых) мигрант|вид на жительство|ВНЖ|РВП|депортац|выдворен|въезд|гражданств|регистрационн|миграционн|Узбекистан|Таджикистан|Киргиз|Кыргыз|экзамен по русскому/i;

function decode(s: string) {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/&quot;/g, '"').replace(/&laquo;/g, "«").replace(/&raquo;/g, "»").replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function rssItems(xml: string, source: string, onlyMigration: boolean): Candidate[] {
  const out: Candidate[] = [];
  for (const m of xml.matchAll(/<item[\s>]([\s\S]*?)<\/item>/g)) {
    const it = m[1];
    const pick = (tag: string) => decode(it.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`))?.[1] ?? "");
    const url = pick("link");
    const title = pick("title");
    const text = pick("description").slice(0, 1500);
    if (!url || !title) continue;
    if (onlyMigration && !MIGRATION_WORDS.test(`${title} ${text}`)) continue;
    const date = new Date(pick("pubDate"));
    out.push({ source, external_id: pick("guid") || url, url, title, text, published_at: Number.isNaN(date.getTime()) ? new Date() : date });
  }
  return out;
}

async function get(url: string, ms: number, accept?: string) {
  const r = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0", ...(accept ? { Accept: accept } : {}) }, signal: AbortSignal.timeout(ms) });
  if (!r.ok) throw new Error(`${url} ${r.status}`);
  return r;
}

async function fromGov(): Promise<Candidate[]> {
  const out: Candidate[] = [];
  for (const feed of GOV_RSS) out.push(...rssItems(await (await get(feed, 15_000)).text(), "government", false));
  return out;
}

async function fromMedia(): Promise<Candidate[]> {
  const lists = await Promise.all(Object.entries(MEDIA_FEEDS).map(async ([source, feed]) => {
    try {
      return rssItems(await (await get(feed, 15_000)).text(), source, true);
    } catch (e) {
      console.error("media feed failed", source, String(e));
      return [];
    }
  }));
  return lists.flat();
}

async function fromPravo(): Promise<Candidate[]> {
  const out: Candidate[] = [];
  for (const block of PRAVO_BLOCKS) {
    const j = (await (await get(`${PRAVO}?block=${block}&PageSize=30&Index=1`, 20_000, "application/json")).json()) as { items?: Array<{ eoNumber: string; complexName: string; publishDateShort: string }> };
    for (const d of j.items ?? []) {
      if (!d.eoNumber || !d.complexName) continue;
      out.push({ source: "pravo", external_id: d.eoNumber, url: `http://publication.pravo.gov.ru/document/${d.eoNumber}`, title: decode(d.complexName), text: "", published_at: new Date(d.publishDateShort) });
    }
  }
  return out;
}

type Verdict = { i: number; relevant: boolean; title: string; summary: string; tag: string };

const INSTRUCTIONS =
  "You read official Russian government news, legal acts and Russian news media for an app used by migrant workers from Uzbekistan, Tajikistan and Kyrgyzstan living in Russia. " +
  "For each item decide if it DIRECTLY concerns foreign citizens/migrants in Russia: work patents, migration registration, residence permits, entry/exit and bans, " +
  "fines and deportation, Russian language/history exams, medical checks, taxes and payments for migrants, employment of foreigners, migrants' children and schools, citizenship. " +
  "Everything else (regional governors, awards, budgets, agriculture, generic economy) is NOT relevant. " +
  "Decisions about specific named persons (granting citizenship to listed people, pardons, appointments) are NOT relevant — only general rules that affect many migrants. " +
  "Media reports are relevant only when they report facts useful to migrants (new or planned rules, official statements, enforcement raids, changed patent prices, court practice); " +
  "crime stories about individual migrants, opinions and rumours are NOT relevant. If several items describe the same event, mark only the most informative one as relevant. " +
  "Retell in your own words — never copy sentences from the source. " +
  "For relevant items write in simple Uzbek (Latin script): a short clear title (max 90 characters) and a summary of 2–4 sentences: what changes, who it concerns, from when. " +
  "Use ONLY facts present in the given title/text — never invent dates, amounts or rules; if the text gives no date, do not mention one. " +
  "For items that are not relevant, return empty strings for title, summary and tag. Return exactly one verdict per input item.";

const VERDICT_SCHEMA = {
  type: "object",
  properties: {
    verdicts: {
      type: "array",
      items: {
        type: "object",
        properties: {
          i: { type: "integer" },
          relevant: { type: "boolean" },
          title: { type: "string" },
          summary: { type: "string" },
          tag: { type: "string", enum: [...TAGS, ""] },
        },
        required: ["i", "relevant", "title", "summary", "tag"],
        additionalProperties: false,
      },
    },
  },
  required: ["verdicts"],
  additionalProperties: false,
};

async function classify(batch: Candidate[]): Promise<Verdict[]> {
  if (!claude) {
    // No AI: keep keyword matches with their original title
    return batch.map((c, i) => ({ i, relevant: MIGRATION_WORDS.test(`${c.title} ${c.text}`), title: c.title.slice(0, 160), summary: c.text.slice(0, 600), tag: "Boshqa" }));
  }
  const response = await claude.beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: INSTRUCTIONS,
    output_config: { effort: "low", format: { type: "json_schema", schema: VERDICT_SCHEMA } },
    messages: [{ role: "user", content: JSON.stringify(batch.map((c, i) => ({ i, title: c.title, text: c.text }))) }],
  } as never) as { stop_reason: string; content: Array<{ type: string; text?: string }> };
  if (response.stop_reason === "refusal") return [];
  const text = response.content.filter((b) => b.type === "text").map((b) => b.text ?? "").join("");
  try {
    return (JSON.parse(text) as { verdicts: Verdict[] }).verdicts;
  } catch {
    return [];
  }
}

async function refresh() {
  const all: Candidate[] = [];
  for (const src of [fromMedia, fromGov, fromPravo]) {
    try {
      all.push(...(await src()));
    } catch (e) {
      console.error("news source failed", String(e));
    }
  }
  const since = Date.now() - 10 * 86400_000;
  const fresh = all.filter((c) => c.published_at.getTime() >= since);
  if (!fresh.length) return { checked: 0, published: 0 };

  const { data: seen } = await admin.from("news_items").select("source, external_id").gte("published_at", new Date(since - 86400_000).toISOString());
  const seenKey = new Set((seen ?? []).map((s) => `${s.source}:${s.external_id}`));
  const unique = new Map<string, Candidate>();
  for (const c of fresh) if (!seenKey.has(`${c.source}:${c.external_id}`)) unique.set(`${c.source}:${c.external_id}`, c);
  const todo = [...unique.values()].slice(0, 140);

  let published = 0;
  for (let k = 0; k < todo.length; k += 20) {
    const batch = todo.slice(k, k + 20);
    let verdicts: Verdict[];
    try {
      verdicts = await classify(batch);
    } catch (e) {
      console.error("news classify failed", String(e));
      continue; // retried next run (not marked as seen)
    }
    if (!verdicts.length) continue;
    const rows = batch.map((c, i) => {
      const v = verdicts.find((x) => x.i === i);
      const ok = !!v?.relevant && !!v.title && !!v.summary;
      if (ok) published++;
      return {
        source: c.source,
        external_id: c.external_id,
        url: c.url,
        original_title: c.title.slice(0, 1000),
        relevant: ok,
        title: ok ? v!.title.slice(0, 160) : null,
        summary: ok ? v!.summary.slice(0, 1200) : null,
        tag: ok ? (TAGS.includes(v!.tag) ? v!.tag : "Boshqa") : null,
        published_at: c.published_at.toISOString(),
      };
    });
    const { error } = await admin.from("news_items").upsert(rows, { onConflict: "source,external_id", ignoreDuplicates: true });
    if (error) console.error("news insert failed", error.message);
  }
  return { checked: todo.length, published, ai: !!claude };
}

Deno.serve(async () => {
  try {
    return Response.json(await refresh());
  } catch (e) {
    console.error("news refresh error", e);
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
