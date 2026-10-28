// Official exchange rates, refreshed hourly by pg_cron. Free sources, no keys:
//  - cbu: Central Bank of Uzbekistan (cbu.uz, falls back to nbu.uz's copy) — so'm per unit
//  - cbr: Bank of Russia (cbr.ru) — rubles per unit
//  - nbu_cash / nbu_app: National Bank of Uzbekistan buy / sell (cash offices and the Milliy app)
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const FX_CCYS = ["RUB", "USD", "EUR", "TJS", "KGS", "KZT"];
const CBR_CCYS = ["USD", "EUR", "CNY", "UZS", "TJS", "KGS", "KZT"];
const CBU = "https://cbu.uz/uz/arkhiv-kursov-valyut/json/";
const CBR = "https://www.cbr.ru/scripts/XML_daily.asp";
const NBU_SHEETS = "https://nbu.uz/api/collections/legal_cbu_exchange_rates/entries?filter[site:is]=en&limit=12&sort=-data_sozdaniya&fields=slug,rates";
const NBU_URL = "https://nbu.uz/en/for-individuals-exchange-rates";
const NBU_TABS: Record<string, string> = { nbu_cash: "02", nbu_app: "06" };

type Row = { source: string; rate_date: string; ccy: string; rate: number; diff: number; sell?: number | null };

const fromDmy = (dmy: string) => {
  const [d, m, y] = dmy.split(".");
  return `${y}-${m}-${d}`;
};

async function save(rows: Row[]) {
  const ok = rows.filter((v) => Number.isFinite(v.rate) && v.rate > 0).map((r) => ({ ...r, fetched_at: new Date().toISOString() }));
  if (!ok.length) return;
  const { error } = await admin.from("fx_rates").upsert(ok, { onConflict: "source,ccy,rate_date" });
  if (error) throw new Error(error.message);
}

async function cbrFetch(date?: Date): Promise<{ date: string; rates: Record<string, number> }> {
  const q = date ? `?date_req=${String(date.getUTCDate()).padStart(2, "0")}/${String(date.getUTCMonth() + 1).padStart(2, "0")}/${date.getUTCFullYear()}` : "";
  const r = await fetch(CBR + q, { signal: AbortSignal.timeout(10_000) });
  if (!r.ok) throw new Error(`cbr.ru ${r.status}`);
  const xml = new TextDecoder("windows-1251").decode(await r.arrayBuffer());
  const dm = xml.match(/<ValCurs[^>]*Date="(\d{2}\.\d{2}\.\d{4})"/);
  if (!dm) throw new Error("cbr.ru: no date");
  const rates: Record<string, number> = {};
  for (const ccy of CBR_CCYS) {
    const m = xml.match(new RegExp(`<CharCode>${ccy}</CharCode>\\s*<Nominal>(\\d+)</Nominal>[\\s\\S]*?<Value>([\\d,]+)</Value>`));
    if (m) rates[ccy] = Number(m[2].replace(",", ".")) / (Number(m[1]) || 1);
  }
  return { date: fromDmy(dm[1]), rates };
}

async function refreshCbr() {
  const today = await cbrFetch();
  let prev: { date: string; rates: Record<string, number> } | null = null;
  for (let i = 1; i <= 6 && !prev; i++) {
    const d = new Date(`${today.date}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() - i);
    const p = await cbrFetch(d).catch(() => null);
    if (p && p.date !== today.date) prev = p;
  }
  await save(Object.entries(today.rates).map(([ccy, rate]) => ({ source: "cbr", rate_date: today.date, ccy, rate, diff: prev?.rates[ccy] ? rate - prev.rates[ccy] : 0 })));
}

async function refreshCbuDirect(): Promise<boolean> {
  try {
    const r = await fetch(CBU, { headers: { Accept: "application/json" }, signal: AbortSignal.timeout(5_000) });
    if (!r.ok) return false;
    const rows = (await r.json()) as Array<{ Ccy: string; Rate: string; Nominal: string; Diff: string; Date: string }>;
    await save(rows.filter((x) => FX_CCYS.includes(x.Ccy)).map((x) => {
      const n = Number(x.Nominal) || 1;
      return { source: "cbu", rate_date: fromDmy(x.Date), ccy: x.Ccy, rate: Number(x.Rate) / n, diff: (Number(x.Diff) || 0) / n };
    }));
    // a week of RUB history for the chart
    for (let i = 1; i <= 7; i++) {
      const day = new Date(Date.now() - i * 86400_000).toISOString().slice(0, 10);
      const h = await fetch(`${CBU}RUB/${day}/`, { signal: AbortSignal.timeout(5_000) }).then((x) => (x.ok ? x.json() : [])).catch(() => []);
      await save((h as Array<{ Ccy: string; Rate: string; Nominal: string; Diff: string; Date: string }>).map((x) => ({ source: "cbu", rate_date: fromDmy(x.Date), ccy: x.Ccy, rate: Number(x.Rate) / (Number(x.Nominal) || 1), diff: Number(x.Diff) || 0 })));
    }
    return true;
  } catch {
    return false;
  }
}

/** cbu.uz often refuses foreign servers; nbu.uz publishes the same Central Bank rate ("rate_sb"). */
async function refreshCbuViaNbu() {
  const r = await fetch(NBU_SHEETS, { headers: { Accept: "application/json", "User-Agent": "Mozilla/5.0 (MigrantHub rates)" }, signal: AbortSignal.timeout(12_000) });
  if (!r.ok) throw new Error(`nbu.uz api ${r.status}`);
  const sheets = ((await r.json()) as { data?: Array<{ slug?: string; rates?: Array<{ rate_code: string; rate_sb?: string; rate_equivalent?: string }> }> }).data ?? [];
  const num = (s?: string) => Number(String(s ?? "").replace(/\s/g, "").replace(",", "."));
  const days = sheets
    .map((s) => {
      const date = s.slug?.match(/(\d{4}-\d{2}-\d{2})$/)?.[1];
      const rates: Record<string, number> = {};
      for (const x of s.rates ?? []) {
        const v = num(x.rate_sb) / (num(x.rate_equivalent) || 1);
        if (FX_CCYS.includes(x.rate_code) && v > 0) rates[x.rate_code] = v;
      }
      return date ? { date, rates } : null;
    })
    .filter((d): d is { date: string; rates: Record<string, number> } => !!d && !!d.rates.RUB)
    .sort((a, b) => a.date.localeCompare(b.date));
  if (!days.length) throw new Error("nbu.uz api: no central bank rates");
  const last = days[days.length - 1];
  const missing = FX_CCYS.filter((c) => !last.rates[c]);
  if (missing.length) {
    const cbr = await cbrFetch().catch(() => null);
    const uzs = cbr?.rates.UZS;
    if (cbr && uzs) for (const c of missing) if (cbr.rates[c]) last.rates[c] = cbr.rates[c] / uzs;
  }
  const rows: Row[] = [];
  days.forEach((d, i) => {
    const prev = days[i - 1]?.rates;
    for (const [ccy, rate] of Object.entries(d.rates)) rows.push({ source: "cbu", rate_date: d.date, ccy, rate, diff: prev?.[ccy] ? rate - prev[ccy] : 0 });
  });
  await save(rows);
}

function parseNbuSection(html: string): Record<string, { buy: number; sell: number }> {
  const tokens = html.replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<[^>]+>/g, "|").split("|").map((t) => t.replace(/&nbsp;/g, " ").trim()).filter(Boolean);
  const num = (t: string) => (/^[\d\s.,]+$/.test(t) ? Number(t.replace(/\s/g, "").replace(",", ".")) : NaN);
  const out: Record<string, { buy: number; sell: number }> = {};
  for (let i = 0; i < tokens.length - 3; i++) {
    if (!/^[A-Z]{3}$/.test(tokens[i]) || out[tokens[i]]) continue;
    const buy = num(tokens[i + 2]);
    const sell = num(tokens[i + 3]);
    if (Number.isFinite(buy) && Number.isFinite(sell)) out[tokens[i]] = { buy, sell };
  }
  return out;
}

async function refreshNbu() {
  const r = await fetch(NBU_URL, { headers: { "User-Agent": "Mozilla/5.0 (MigrantHub rates)", Accept: "text/html" }, signal: AbortSignal.timeout(15_000) });
  if (!r.ok) throw new Error(`nbu.uz ${r.status}`);
  const html = await r.text();
  const rows: Row[] = [];
  for (const [source, tab] of Object.entries(NBU_TABS)) {
    const start = html.indexOf(`data-tab-content="${tab}"`);
    if (start < 0) continue;
    const next = html.slice(start + 30).search(/data-tab-content="\d+"/);
    const section = html.slice(start, next < 0 ? start + 60_000 : start + 30 + next);
    const dm = section.match(/(\d{2}\.\d{2}\.\d{4})/);
    const date = dm ? fromDmy(dm[1]) : new Date().toISOString().slice(0, 10);
    for (const [ccy, v] of Object.entries(parseNbuSection(section))) {
      if (!["RUB", "USD", "EUR", "KZT", "CNY", "GBP"].includes(ccy) || v.buy <= 0) continue;
      rows.push({ source, rate_date: date, ccy, rate: v.buy, diff: 0, sell: v.sell });
    }
  }
  if (!rows.some((x) => x.ccy === "RUB")) throw new Error("nbu.uz: rates not found (page layout changed?)");
  await save(rows);
}

async function saveCross() {
  const { data } = await admin.from("fx_rates").select("ccy, rate, diff, rate_date").eq("source", "cbr").order("rate_date", { ascending: false }).limit(40);
  if (!data?.length) throw new Error("no cbr rates");
  const date = data[0].rate_date as string;
  const day = data.filter((r) => r.rate_date === date);
  const uzs = day.find((r) => r.ccy === "UZS");
  if (!uzs) throw new Error("no UZS in cbr");
  const rubPerSom = Number(uzs.rate);
  const rows: Row[] = [{ source: "cross", rate_date: date, ccy: "RUB", rate: 1 / rubPerSom, diff: 0 }];
  for (const r of day) {
    if (r.ccy === "UZS" || !FX_CCYS.includes(r.ccy)) continue;
    rows.push({ source: "cross", rate_date: date, ccy: r.ccy, rate: Number(r.rate) / rubPerSom, diff: 0 });
  }
  await save(rows);
}

Deno.serve(async () => {
  const jobs: Record<string, () => Promise<unknown>> = {
    cbu: async () => { if (!(await refreshCbuDirect())) await refreshCbuViaNbu(); },
    cbr: refreshCbr,
    nbu: refreshNbu,
  };
  const results = await Promise.allSettled(Object.values(jobs).map((f) => f()));
  const report: Record<string, string> = Object.fromEntries(Object.keys(jobs).map((k, i) => [k, results[i].status === "fulfilled" ? "ok" : String((results[i] as PromiseRejectedResult).reason)]));
  // Uzbek banks often refuse foreign servers: so'm rates are then derived from the Bank of Russia
  // cross rate (shown in the app as "calculated", never as the official CBU rate).
  try {
    await saveCross();
    report.cross = "ok";
  } catch (e) {
    report.cross = String(e);
  }
  return Response.json(report);
});
