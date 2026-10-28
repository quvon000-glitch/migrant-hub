import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supa => Supabase.instance.client;
String? get myId => supa.auth.currentUser?.id;

/// A readable Uzbek message for any error (database functions raise user-facing text).
String errorText(Object e) {
  if (e is PostgrestException) {
    if (e.code == 'P0001' || e.code == '23514') return e.message;
    if (e.code == '42501') return 'Ruxsat yo‘q';
    return e.message.isNotEmpty ? e.message : 'Xatolik yuz berdi';
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['message'] is String) return d['message'] as String;
    return 'Server bilan bog‘lanib bo‘lmadi';
  }
  if (e is StorageException) return 'Fayl yuklanmadi: ${e.message}';
  if (e is AuthException) return e.message;
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
    return 'Internet aloqasi yo‘q';
  }
  return 'Xatolik yuz berdi';
}

void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 2600)));
}

String publicUrl(String bucket, String path) => supa.storage.from(bucket).getPublicUrl(path);
