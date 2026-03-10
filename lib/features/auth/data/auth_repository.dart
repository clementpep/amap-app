import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository(Supabase.instance.client);

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String amapName,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'amap_name': amapName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? amapName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (amapName != null) updates['amap_name'] = amapName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client.from('profiles').update(updates).eq('id', userId);
  }
}
