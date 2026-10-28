// Phone + 6-digit code accounts on top of Supabase Auth.
// The phone number becomes a synthetic e-mail (<digits>@phone.migranthub.app) and the code is the password,
// so no SMS provider is needed. Actions: register, login, forgot.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const PHONE_DOMAIN = "phone.migranthub.app";
const RESET_HOURS = 48;
const MAX_FAILS = 5;
const LOCK_MINUTES = 15;

const admin = createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } });

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
const fail = (message: string, status = 400, extra: Record<string, unknown> = {}) => reply({ message, ...extra }, status);

const digitsOf = (raw: unknown) => String(raw ?? "").replace(/\D/g, "");
const emailOf = (digits: string) => `${digits}@${PHONE_DOMAIN}`;
const deadline = (requestedAt: string) => new Date(new Date(requestedAt).getTime() + RESET_HOURS * 3600_000);

function remainingText(until: Date): string {
  const total = Math.max(1, Math.ceil(Math.max(0, until.getTime() - Date.now()) / 60_000));
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h <= 0) return `${m} daqiqa`;
  return m ? `${h} soat ${m} daqiqa` : `${h} soat`;
}

function moscowDateTime(d: Date): string {
  const x = new Date(d.getTime() + 3 * 3600_000);
  const months = ["yanvar", "fevral", "mart", "aprel", "may", "iyun", "iyul", "avgust", "sentabr", "oktabr", "noyabr", "dekabr"];
  return `${x.getUTCDate()}-${months[x.getUTCMonth()]}, ${String(x.getUTCHours()).padStart(2, "0")}:${String(x.getUTCMinutes()).padStart(2, "0")}`;
}

type Profile = { id: string; reset_requested_at: string | null; blocked_at: string | null; blocked_reason: string | null };

async function profileByPhone(digits: string): Promise<Profile | null> {
  const { data } = await admin.from("profiles").select("id, reset_requested_at, blocked_at, blocked_reason").eq("phone", digits).maybeSingle();
  return data as Profile | null;
}

/** When the 48 hours are over the account and everything it created is deleted. */
async function purgeIfResetExpired(p: Profile): Promise<boolean> {
  if (!p.reset_requested_at || Date.now() < deadline(p.reset_requested_at).getTime()) return false;
  const { error } = await admin.auth.admin.deleteUser(p.id);
  if (error) throw error;
  return true;
}

async function signIn(digits: string, code: string) {
  const client = createClient(URL, ANON, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await client.auth.signInWithPassword({ email: emailOf(digits), password: code });
  if (error || !data.session) return null;
  return { access_token: data.session.access_token, refresh_token: data.session.refresh_token, expires_at: data.session.expires_at, user_id: data.user?.id };
}

async function register(body: Record<string, unknown>) {
  const digits = digitsOf(body.phone);
  const code = String(body.code ?? "");
  const firstName = String(body.firstName ?? "").trim();
  if (!/^\d{10,15}$/.test(digits)) return fail("Telefon raqamini to‘liq kiriting");
  if (!/^\d{6}$/.test(code)) return fail("Tasdiqlash kodi 6 ta raqamdan iborat bo‘lsin");
  if (/^(\d)\1{5}$/.test(code) || code === "123456" || code === "654321") return fail("Bu kod juda oddiy. Boshqa kod tanlang");
  if (firstName.length < 2 || firstName.length > 60) return fail("Ismingizni kiriting");
  if (!body.terms) return fail("Foydalanish shartlariga rozilik bering");

  const { data: banned } = await admin.from("banned_phones").select("phone").eq("phone", digits).maybeSingle();
  if (banned) return fail("Bu raqam qoidalarni buzgani uchun bloklangan", 403);

  const existing = await profileByPhone(digits);
  if (existing && !(await purgeIfResetExpired(existing))) {
    if (existing.reset_requested_at) {
      const until = deadline(existing.reset_requested_at);
      return fail(`Bu raqamdagi hisob qayta faollashtirilmoqda. ${moscowDateTime(until)} dan keyin (${remainingText(until)} qoldi) shu raqam bilan yangidan ro‘yxatdan o‘tishingiz mumkin.`, 409, { pendingUntil: until.toISOString() });
    }
    return fail("Bu telefon raqami allaqachon ro‘yxatdan o‘tgan. “Kirish” bo‘limidan tasdiqlash kodingiz bilan kiring.", 409);
  }

  const birth = String(body.birthDate ?? "");
  const { error } = await admin.auth.admin.createUser({
    email: emailOf(digits),
    password: code,
    email_confirm: true,
    user_metadata: {
      phone: digits,
      display_name: firstName,
      last_name: String(body.lastName ?? "").trim().slice(0, 60),
      birth_date: /^\d{4}-\d{2}-\d{2}$/.test(birth) ? birth : "",
      citizenship: String(body.citizenship ?? "").slice(0, 20),
      current_city: String(body.region ?? "").slice(0, 80),
      recovery_email: String(body.email ?? "").trim().slice(0, 120),
    },
  });
  if (error) {
    console.error("createUser", error);
    return fail("Ro‘yxatdan o‘tib bo‘lmadi. Keyinroq urinib ko‘ring.", 500);
  }
  const session = await signIn(digits, code);
  if (!session) return fail("Hisob ochildi, lekin kirib bo‘lmadi. “Kirish” orqali kiring.", 500);
  return reply({ session });
}

async function login(body: Record<string, unknown>) {
  const digits = digitsOf(body.phone);
  const code = String(body.code ?? "");
  if (!/^\d{10,15}$/.test(digits) || !/^\d{6}$/.test(code)) return fail("Telefon raqami yoki tasdiqlash kodi noto‘g‘ri", 401);

  const p = await profileByPhone(digits);
  if (p && (await purgeIfResetExpired(p))) {
    return fail("Hisobingiz qayta faollashtirildi va oldingi barcha ma’lumotlar o‘chirildi. Endi shu raqam bilan yangidan ro‘yxatdan o‘tishingiz mumkin.", 410, { kind: "deleted" });
  }
  if (p?.blocked_at) {
    return fail(`Hisobingiz bloklangan.${p.blocked_reason ? ` Sabab: ${p.blocked_reason}.` : ""} Xato bo‘lsa, qo‘llab-quvvatlash xizmatiga yozing.`, 403, { kind: "locked" });
  }

  const since = new Date(Date.now() - LOCK_MINUTES * 60_000).toISOString();
  const { data: fails } = await admin.from("login_attempts").select("attempted_at").eq("phone", digits).eq("success", false).gte("attempted_at", since).order("attempted_at", { ascending: false });
  const failCount = fails?.length ?? 0;
  if (failCount >= MAX_FAILS && fails?.[0]) {
    const until = new Date(new Date(fails[0].attempted_at).getTime() + LOCK_MINUTES * 60_000);
    if (until > new Date()) {
      return fail(`Kod ${MAX_FAILS} marta noto‘g‘ri kiritildi. ${Math.ceil((until.getTime() - Date.now()) / 60_000)} daqiqadan keyin qayta urinib ko‘ring.`, 429, { kind: "locked" });
    }
  }

  const session = p ? await signIn(digits, code) : null;
  if (!session) {
    await admin.from("login_attempts").insert({ phone: digits, success: false });
    if (p?.reset_requested_at) {
      const until = deadline(p.reset_requested_at);
      return fail(`Bu hisob qayta faollashtirilmoqda. ${moscowDateTime(until)} da (${remainingText(until)} qoldi) barcha ma’lumotlar o‘chiriladi va shu raqam bilan yangidan ro‘yxatdan o‘tishingiz mumkin bo‘ladi. Kodni eslasangiz, to‘g‘ri kod bilan kirib, so‘rovni bekor qilishingiz mumkin.`, 423, { kind: "pending", pendingUntil: until.toISOString() });
    }
    const left = MAX_FAILS - (failCount + 1);
    return fail(left > 0 ? `Telefon raqami yoki tasdiqlash kodi noto‘g‘ri. Yana ${left} marta urinish mumkin.` : `Kod ${MAX_FAILS} marta noto‘g‘ri kiritildi. ${LOCK_MINUTES} daqiqadan keyin qayta urinib ko‘ring.`, 401);
  }

  let notice: string | undefined;
  if (p!.reset_requested_at) {
    await admin.from("profiles").update({ reset_requested_at: null }).eq("id", p!.id);
    notice = "Bu raqam uchun “Kodni unutdim” so‘rovi yuborilgan edi. Siz to‘g‘ri kod bilan kirdingiz, shuning uchun so‘rov bekor qilindi va ma’lumotlaringiz saqlanib qoldi.";
  }
  await admin.from("login_attempts").delete().eq("phone", digits).eq("success", false);
  return reply({ session, notice });
}

async function forgot(body: Record<string, unknown>) {
  const digits = digitsOf(body.phone);
  const p = await profileByPhone(digits);
  if (!p || (await purgeIfResetExpired(p))) {
    return fail("Bu raqam bilan hisob topilmadi. “Ro‘yxatdan o‘tish” orqali yangi hisob ochishingiz mumkin.", 404);
  }
  if (p.reset_requested_at) return reply({ pendingUntil: deadline(p.reset_requested_at).toISOString(), alreadyPending: true });
  const now = new Date().toISOString();
  await admin.from("profiles").update({ reset_requested_at: now }).eq("id", p.id);
  return reply({ pendingUntil: deadline(now).toISOString(), alreadyPending: false });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail("Not found", 404);
  try {
    const body = (await req.json()) as Record<string, unknown>;
    switch (body.action) {
      case "register": return await register(body);
      case "login": return await login(body);
      case "forgot": return await forgot(body);
      default: return fail("Noma’lum amal", 404);
    }
  } catch (e) {
    console.error("auth error", e);
    return fail("Xatolik yuz berdi. Keyinroq urinib ko‘ring.", 500);
  }
});
