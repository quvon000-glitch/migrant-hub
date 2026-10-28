class NewsItem {
  final int id;
  final String title;
  final String summary;
  final String tag;
  final String url;
  final String source;
  final String? imageUrl;
  final DateTime publishedAt;
  final bool pinned;

  const NewsItem({required this.id, required this.title, required this.summary, required this.tag, required this.url, required this.source, this.imageUrl, required this.publishedAt, required this.pinned});

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String? ?? j['original_title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        tag: j['tag'] as String? ?? 'Boshqa',
        url: j['url'] as String? ?? '',
        source: j['source'] as String? ?? '',
        imageUrl: j['image_url'] as String?,
        publishedAt: DateTime.parse(j['published_at'] as String),
        pinned: j['pinned_at'] != null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'summary': summary, 'tag': tag, 'url': url, 'source': source, 'image_url': imageUrl,
        'published_at': publishedAt.toIso8601String(), 'pinned_at': pinned ? publishedAt.toIso8601String() : null,
      };

  static const sourceNames = {
    'admin': 'Migrant Hub',
    'government': 'Rossiya Hukumati (government.ru)',
    'pravo': 'Rasmiy huquqiy portal (pravo.gov.ru)',
    'rg': 'Rossiyskaya gazeta',
    'tass': 'TASS',
    'ria': 'RIA Novosti',
    'interfax': 'Interfaks',
    'rbc': 'RBK',
    'kommersant': 'Kommersant',
    'izvestia': 'Izvestiya',
    'vedomosti': 'Vedomosti',
  };
  String get sourceName => sourceNames[source] ?? source;
  bool get official => source == 'government' || source == 'pravo';
}
