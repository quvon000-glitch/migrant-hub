# Migrant Hub

Rossiyadagi migrantlar uchun mobil ilova: Flutter + Supabase. Avvalgi versiya Floot'da edi.

## Tuzilma

```
app/                 Flutter ilova (Android, iOS)
supabase/migrations  Ma'lumotlar bazasi sxemasi, RLS, server funksiyalari
supabase/functions   Edge funksiyalar (Deno)
```

## Server (Supabase)

| Qism | Nima qiladi |
|---|---|
| `profiles` + `public_profiles` | Foydalanuvchi profili; boshqalarga faqat ochiq maydonlar (telefon egasi ruxsat bersa) ko‘rinadi |
| `group_messages`, `group_members` | Shahar guruhlari (Moskva, SPb). Yozish faqat `group_send` orqali: ban, limitlar, havola va spam filtri, qoidabuzarlik → ogohlantirish → 24 soat → 7 kun → doimiy ban |
| `ads`, `ad_favorites` | E'lonlar; narx matni, kategoriya maydonlari va limit trigger orqali serverda tekshiriladi |
| `conversations`, `dm_messages` | E'lon bo‘yicha shaxsiy yozishmalar, o‘qildi belgisi, bloklash |
| `news_items`, `broadcasts` | Yangiliklar va admin xabarlari |
| `fx_rates` + `fx_snapshot()` | Valyuta kurslari |

Realtime yoqilgan jadvallar: yangiliklar, e'lonnomalar, guruh xabarlari va a'zolari, shaxsiy xabarlar, yozishmalar, e'lonlar.
"Yozmoqda…" va online soni Realtime broadcast/presence orqali ishlaydi.

Edge funksiyalar:

- `auth` — telefon + 6 xonali kod bilan ro‘yxatdan o‘tish/kirish (SMS kerak emas), 5 xato → 15 daqiqa blok, "kodni unutdim" (48 soat).
- `news-refresh` — rasmiy manbalar va OAV RSS'idan migrantlarga oid yangiliklarni yig‘adi (pg_cron, 30 daqiqada). `ANTHROPIC_API_KEY` maxfiy kaliti qo‘yilsa, Claude yangiliklarni saralaydi va o‘zbekchaga qayta yozadi.
- `fx-refresh` — CBU / CBR / NBU kurslari (har soat). O‘zbek banklari Supabase serveriga javob bermasa, so‘m kursi Rossiya MB kross-kursidan hisoblanadi va ilovada "taxminiy kurs" deb ko‘rsatiladi.
- `maintenance` — 48 soatdan eski guruh xabarlari va fayllarini, muddati o‘tgan "kodni unutdim" hisoblarini o‘chiradi (har soat).

## Ilovani ishga tushirish

```bash
cd app
flutter pub get
flutter run            # Supabase manzili va kaliti lib/config.dart da
flutter build apk --release
```

Boshqa Supabase loyihasi uchun: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## Chat (Telegram uslubida)

- Xabar darhol ekranda paydo bo‘ladi (⏱), server qabul qilgach ✓, kimdir o‘qisa ✓✓.
- Qayta yuborishda takrorlanmaydi (`client_id` bo‘yicha idempotent).
- Javob berish (chapga surish), tahrirlash, o‘chirish, nusxa, saqlash, mahkamlash (admin), shikoyat.
- Rasm, video (60 s), ovozli xabar (30 s); rasmlar yuborishdan oldin siqiladi.
- "Yozmoqda…", online soni, uzilishdan keyin qayta ulanib, o‘tkazib yuborilgan xabarlarni yuklaydi.
- Oxirgi xabarlar telefonda saqlanadi: chat internet bo‘lmasa ham darhol ochiladi.
