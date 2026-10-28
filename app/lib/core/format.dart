import 'package:intl/intl.dart';

const _months = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];

String two(int n) => n.toString().padLeft(2, '0');

String clock(DateTime d) {
  final x = d.toLocal();
  return '${two(x.hour)}:${two(x.minute)}';
}

bool sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String dayLabel(DateTime d) {
  final x = d.toLocal();
  final now = DateTime.now();
  if (sameDay(x, now)) return 'Bugun';
  if (sameDay(x, now.subtract(const Duration(days: 1)))) return 'Kecha';
  return '${x.day}-${_months[x.month - 1]}${x.year != now.year ? ' ${x.year}' : ''}';
}

/// "5 daqiqa oldin", "3 soat oldin", "Kecha", "2 kun oldin", "12.10.2026"
String ago(DateTime d) {
  final min = DateTime.now().difference(d).inMinutes;
  if (min < 1) return 'hozirgina';
  if (min < 60) return '$min daqiqa oldin';
  final h = (min / 60).round();
  if (h < 24) return '$h soat oldin';
  final days = (h / 24).round();
  if (days == 1) return 'Kecha';
  if (days < 7) return '$days kun oldin';
  return DateFormat('dd.MM.yyyy').format(d.toLocal());
}

/// Chat list time: today → 14:05, this week → day, older → 12.10
String listTime(DateTime d) {
  final x = d.toLocal();
  final now = DateTime.now();
  if (sameDay(x, now)) return clock(x);
  if (now.difference(x).inDays < 6) return const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'][x.weekday - 1];
  return '${two(x.day)}.${two(x.month)}';
}

String lastSeen(DateTime? d) {
  if (d == null) return 'yaqinda bo‘lgan';
  final min = DateTime.now().difference(d).inMinutes;
  if (min < 2) return 'online';
  if (min < 60) return '$min daqiqa oldin bo‘lgan';
  if (sameDay(d, DateTime.now())) return 'bugun ${clock(d)} da bo‘lgan';
  return '${dayLabel(d)} ${clock(d)} da bo‘lgan';
}

String mmss(num sec) {
  final s = sec.round().clamp(0, 99999);
  return '${s ~/ 60}:${two(s % 60)}';
}

final _num = NumberFormat.decimalPattern('ru');
String fmtNum(num n) => _num.format(n).replaceAll(' ', ' ');

String moneyShort(num n, {int digits = 2}) => NumberFormat('#,##0.${'0' * digits}', 'ru').format(n).replaceAll(' ', ' ');
