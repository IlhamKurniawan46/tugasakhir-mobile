/// Format angka ke Rupiah tanpa desimal, contoh: 100000 -> "Rp100.000".
String formatIdr(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}Rp$buffer';
}

/// Format angka ke USD dengan 2 desimal, contoh: 24.5 -> "$24.50".
String formatUsd(num? value) {
  if (value == null) return '-';
  return '\$${value.toStringAsFixed(2)}';
}

/// Format angka ke EUR dengan 2 desimal, contoh: 18.2 -> "€18.20".
String formatEur(num? value) {
  if (value == null) return '-';
  return '€${value.toStringAsFixed(2)}';
}
