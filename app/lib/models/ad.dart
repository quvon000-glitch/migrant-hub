class Ad {
  final int id;
  final String userId;
  final String category;
  final String title;
  final int? amount;
  final String priceText;
  final String city;
  final String address;
  final String description;
  final Map<String, String> attrs;
  final List<String> photos;
  final String? telegram;
  final String? whatsapp;
  final String status;
  final int views;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Ad({
    required this.id, required this.userId, required this.category, required this.title, this.amount, required this.priceText,
    required this.city, required this.address, required this.description, required this.attrs, required this.photos,
    this.telegram, this.whatsapp, required this.status, required this.views, required this.createdAt, required this.updatedAt,
  });

  bool get active => status == 'active';
  String get location => [city, address].where((s) => s.isNotEmpty).join(', ');
  String get categoryLabel => category == 'Maishiy xizmatlar' ? 'Xizmatlar' : category;

  factory Ad.fromJson(Map<String, dynamic> j) => Ad(
        id: (j['id'] as num).toInt(),
        userId: j['user_id'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        amount: (j['amount'] as num?)?.toInt(),
        priceText: j['price_text'] as String? ?? 'Kelishiladi',
        city: j['city'] as String? ?? '',
        address: j['address'] as String? ?? '',
        description: j['description'] as String? ?? '',
        attrs: ((j['attrs'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        photos: ((j['photos'] as List?) ?? const []).whereType<String>().toList(),
        telegram: j['telegram'] as String?,
        whatsapp: j['whatsapp'] as String?,
        status: j['status'] as String? ?? 'active',
        views: (j['views'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'user_id': userId, 'category': category, 'title': title, 'amount': amount, 'price_text': priceText, 'city': city,
        'address': address, 'description': description, 'attrs': attrs, 'photos': photos, 'telegram': telegram, 'whatsapp': whatsapp,
        'status': status, 'views': views, 'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
      };
}

sealed class AdField {
  final String key;
  final String label;
  const AdField(this.key, this.label);
}

class SelectField extends AdField {
  final List<String> options;
  const SelectField(super.key, super.label, this.options);
}

class TextAdField extends AdField {
  final String hint;
  const TextAdField(super.key, super.label, this.hint);
}

class YearField extends AdField {
  const YearField(super.key, super.label);
}

const adCategories = ['Ish', 'Uy-joy', 'Transport', 'Maishiy xizmatlar'];

/// Category-specific fields. Keys match the listing filters, so posted values are filterable.
const categoryFields = <String, List<AdField>>{
  'Ish': [
    TextAdField('company', 'Ish beruvchi (kompaniya nomi)', 'Masalan: OOO Stroy-Invest'),
    TextAdField('jobType', 'Kasb / lavozim', 'Masalan: Omborchi'),
    SelectField('type', 'Ish turi', ['To‘liq stavka', 'Qisman']),
    SelectField('schedule', 'Ish jadvali', ['To‘liq kun', 'Smenali', 'Qisman']),
    SelectField('experience', 'Tajriba', ['Kerak emas', '1–3 yil', '3+ yil']),
  ],
  'Uy-joy': [
    SelectField('housingType', 'Uy-joy turi', ['Kvartira', 'Uy', 'Xona', 'Yotoqxona']),
    SelectField('deal', 'Bitim turi', ['Ijara', 'Sotuv', 'Kunlik ijara']),
    SelectField('rooms', 'Xonalar soni', ['1 xona', '2 xona', '3+ xona']),
  ],
  'Transport': [
    SelectField('vehicleType', 'Transport turi', ['Yengil avtomobil', 'Yuk mashinasi', 'Mototsikl', 'Velosiped']),
    TextAdField('make', 'Marka', 'Masalan: Toyota'),
    TextAdField('model', 'Model', 'Masalan: Camry'),
    YearField('year', 'Yili'),
  ],
  'Maishiy xizmatlar': [
    SelectField('serviceType', 'Xizmat turi', ['Santexnik', 'Elektrik', 'Mebel yig‘ish', 'Sartarosh', 'Tozalash', 'Usta']),
    SelectField('serviceMode', 'Xizmat ko‘rsatish usuli', ['Joyida', 'Masofadan']),
  ],
};

String priceLabel(String category) =>
    category == 'Ish' ? 'Maosh (₽ / oy)' : category == 'Maishiy xizmatlar' ? 'Narx (₽, dan)' : 'Narx (₽)';

const adReportReasons = ['Firibgarlik', 'Noto‘g‘ri ma’lumot', 'Spam yoki reklama', 'Haqoratli muomala', 'Boshqa'];
