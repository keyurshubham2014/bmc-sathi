import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##,##0', 'en_IN');

String _trim(double v, int places) {
  final s = v.toStringAsFixed(places);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Rupees in Indian units: ₹1.62 cr, ₹4.2 L, ₹9,500. Western digits in both languages.
String money(num? rupees) {
  if (rupees == null) return '–';
  final sign = rupees < 0 ? '-' : '';
  final v = rupees.abs().toDouble();
  if (v >= 1e7) return '$sign₹${_trim(v / 1e7, 2)} cr';
  if (v >= 1e5) return '$sign₹${_trim(v / 1e5, 1)} L';
  return '$sign₹${_grouped.format(v.round())}';
}

String pct(num? share) => share == null ? '–' : '${(share * 100).round()}%';

String ratio(num? r) => r == null ? '–' : _trim(r.toDouble(), 2);

String count(num n) => _grouped.format(n);

/// Timestamps arrive as IST wall-clock marked UTC; show them as given.
String date(Object? iso) {
  if (iso == null) return '–';
  final d = DateTime.tryParse('$iso');
  return d == null ? '$iso' : DateFormat('d MMM yyyy').format(d.toUtc());
}

/// Dataset times are wall-clock times, shown as stored. Pass [local] for a real moment (e.g. when a
/// decision was saved), which is shown in the viewer's own time zone.
String dateTime(Object? iso, {bool local = false}) {
  if (iso == null) return '–';
  final d = DateTime.tryParse('$iso');
  return d == null ? '$iso' : DateFormat('d MMM yyyy, HH:mm').format(local ? d.toLocal() : d.toUtc());
}
