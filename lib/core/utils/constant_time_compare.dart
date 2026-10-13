import 'dart:convert';

/// Membandingkan dua string tanpa berhenti di karakter pertama yang beda.
/// Perbandingan biasa (==) selesai lebih cepat kalau beda di awal, dan selisih
/// waktu itu bisa dipakai penyerang untuk menebak hash sedikit demi sedikit
/// (timing attack). Di sini semua byte selalu diperiksa.
bool constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  final maxLen = aBytes.length > bBytes.length ? aBytes.length : bBytes.length;

  var diff = aBytes.length ^ bBytes.length;
  for (var i = 0; i < maxLen; i++) {
    final x = i < aBytes.length ? aBytes[i] : 0;
    final y = i < bBytes.length ? bBytes[i] : 0;
    diff |= x ^ y;
  }
  return diff == 0;
}
