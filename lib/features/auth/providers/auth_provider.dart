import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

part 'auth_provider.g.dart';

/// Stream of auth state changes — drives the GoRouter redirect guard
@riverpod
Stream<User?> authState(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges.map((state) => state.session?.user);
}

/// Current user (sync, may be null)
@riverpod
User? currentUser(Ref ref) {
  return ref.watch(authStateProvider).valueOrNull;
}
