const citizenships = [
  ('uz', 'O‘zbekiston', '🇺🇿'),
  ('tj', 'Tojikiston', '🇹🇯'),
  ('kg', 'Qirg‘iziston', '🇰🇬'),
  ('kz', 'Qozog‘iston', '🇰🇿'),
  ('tm', 'Turkmaniston', '🇹🇲'),
  ('az', 'Ozarbayjon', '🇦🇿'),
  ('am', 'Armaniston', '🇦🇲'),
  ('md', 'Moldova', '🇲🇩'),
  ('by', 'Belarus', '🇧🇾'),
  ('ru', 'Rossiya', '🇷🇺'),
  ('other', 'Boshqa davlat', '🌐'),
];

const _topRegions = ['Moskva', 'Sankt-Peterburg', 'Moskva viloyati', 'Leningrad viloyati'];
const _otherRegions = [
  'Adigeya Respublikasi', 'Amur viloyati', 'Arxangelsk viloyati', 'Astraxan viloyati', 'Belgorod viloyati',
  'Boshqirdiston (Ufa)', 'Bryansk viloyati', 'Buryatiya (Ulan-Ude)', 'Checheniston (Grozniy)', 'Chelyabinsk viloyati',
  'Chukotka avtonom okrugi', 'Chuvashiya (Cheboksari)', 'Dog‘iston (Maxachqal’a)', 'Ingushetiya', 'Irkutsk viloyati',
  'Ivanovo viloyati', 'Kabardino-Balkariya (Nalchik)', 'Kaliningrad viloyati', 'Kaluga viloyati', 'Kamchatka o‘lkasi',
  'Kareliya (Petrozavodsk)', 'Kemerovo viloyati', 'Kirov viloyati', 'Komi Respublikasi (Siktivkar)', 'Kostroma viloyati',
  'Krasnodar o‘lkasi', 'Krasnoyarsk o‘lkasi', 'Kurgan viloyati', 'Kursk viloyati', 'Lipetsk viloyati',
  'Magadan viloyati', 'Mariy El (Yoshkar-Ola)', 'Mordoviya (Saransk)', 'Murmansk viloyati', 'Nenets avtonom okrugi',
  'Nijniy Novgorod viloyati', 'Novgorod viloyati', 'Novosibirsk viloyati', 'Oltoy o‘lkasi (Barnaul)', 'Oltoy Respublikasi',
  'Omsk viloyati', 'Orenburg viloyati', 'Oryol viloyati', 'Penza viloyati', 'Perm o‘lkasi',
  'Primorye o‘lkasi (Vladivostok)', 'Pskov viloyati', 'Qalmog‘iston (Elista)', 'Qorachoy-Cherkesiya', 'Rostov viloyati',
  'Ryazan viloyati', 'Saxa — Yakutiya (Yakutsk)', 'Saxalin viloyati', 'Samara viloyati', 'Saratov viloyati',
  'Shimoliy Osetiya — Alaniya (Vladikavkaz)', 'Smolensk viloyati', 'Stavropol o‘lkasi', 'Sverdlovsk viloyati (Yekaterinburg)', 'Tambov viloyati',
  'Tatariston (Qozon)', 'Tomsk viloyati', 'Tula viloyati', 'Tuva (Kizil)', 'Tver viloyati',
  'Tyumen viloyati', 'Udmurtiya (Ijevsk)', 'Ulyanovsk viloyati', 'Vladimir viloyati', 'Volgograd viloyati',
  'Vologda viloyati', 'Voronej viloyati', 'Xabarovsk o‘lkasi', 'Xakasiya (Abakan)', 'Xanti-Mansi avtonom okrugi — Yugra',
  'Yahudiy avtonom viloyati', 'Yamalo-Nenets avtonom okrugi', 'Yaroslavl viloyati', 'Zabaykalye o‘lkasi (Chita)',
];

final ruRegions = [..._topRegions, ...([..._otherRegions]..sort())];
