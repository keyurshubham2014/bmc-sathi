import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##,##0', 'en_IN');

String _trim(double v, int places) {
  final s = v.toStringAsFixed(places);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Rupees in Indian units: crore to two decimals (₹1.30 cr), lakh to one (₹63.2 L), under ₹1 lakh in
/// full digits with Indian grouping (₹64,531). Western digits in both languages.
String money(num? rupees) {
  if (rupees == null) return '–';
  final sign = rupees < 0 ? '-' : '';
  final v = rupees.abs().toDouble();
  // Round first so 99,99,999 shows as ₹1.00 cr, not ₹100.0 L.
  if (double.parse((v / 1e5).toStringAsFixed(1)) >= 100) return '$sign₹${(v / 1e7).toStringAsFixed(2)} cr';
  if (v >= 1e5) return '$sign₹${(v / 1e5).toStringAsFixed(1)} L';
  return '$sign₹${_grouped.format(v.round())}';
}

/// Full rupees with Indian grouping, for table cells that must show every digit: ₹1,02,000.
String rupees(num? v) => v == null ? '–' : '${v < 0 ? '-' : ''}₹${_grouped.format(v.abs().round())}';

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
