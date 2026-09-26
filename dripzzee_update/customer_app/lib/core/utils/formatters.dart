/// Formats whole rupees with Indian digit grouping: 125000 → ₹1,25,000.
String formatInr(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  var digits = rounded.abs().toString();
  if (digits.length > 3) {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    digits = '${parts.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$digits';
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

String formatDateTime(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

/// Short, human-friendly order reference derived from the document id.
String shortOrderId(String id) {
  final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final take = cleaned.length < 8 ? cleaned.length : 8;
  return '#${cleaned.substring(0, take).toUpperCase()}';
}

String pluralize(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
