import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/local_store.dart';
import '../core/supa.dart';
import '../models/profile.dart';

/// Signed-in user and their own profile. Everything else hangs off this.
class AppSession extends ChangeNotifier {
  AppSession._();
  static final instance = AppSession._();

  MyProfile? profile;
  bool ready = false;
  StreamSubscription<AuthState>? _sub;

  bool get signedIn => supa.auth.currentSession != null;

  Future<void> start() async {
    _sub = supa.auth.onAuthStateChange.listen((s) async {
      if (s.event == AuthChangeEvent.signedOut) {
        profile = null;
        notifyListeners();
      } else if (s.event == AuthChangeEvent.signedIn && profile == null) {
        await loadProfile();
      }
    });
    final cached = LocalStore.getJson('u:profile');
    if (signedIn && cached is Map<String, dynamic>) {
      try {
        profile = MyProfile.fromJson(cached);
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
    if (signedIn) unawaited(loadProfile());
  }

  Future<void> loadProfile() async {
    final id = myId;
    if (id == null) return;
    try {
      final row = await supa.from('profiles').select().eq('id', id).maybeSingle();
      if (row == null) {
        // the account was deleted on the server
        await signOut();
        return;
      }
      profile = MyProfile.fromJson(row);
      await LocalStore.setJson('u:profile', row);
      notifyListeners();
    } catch (e) {
      debugPrint('profile load failed: $e');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> values) async {
    final id = myId;
    if (id == null) return;
    final row = await supa.from('profiles').update(values).eq('id', id).select().single();
    profile = MyProfile.fromJson(row);
    await LocalStore.setJson('u:profile', row);
    notifyListeners();
  }

  /// Phone + code sign-in/registration go through the `auth` edge function, which returns a session.
  Future<String?> authCall(Map<String, dynamic> body) async {
    final res = await supa.functions.invoke('auth', body: body);
    final data = res.data as Map<String, dynamic>;
    final session = data['session'] as Map<String, dynamic>?;
    if (session == null) throw Exception(data['message'] ?? 'Xatolik');
    await supa.auth.setSession(session['refresh_token'] as String);
    await loadProfile();
    return data['notice'] as String?;
  }

  Future<void> signOut() async {
    try {
      await supa.auth.signOut();
    } catch (_) {}
    profile = null;
    await LocalStore.clearUserData();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
