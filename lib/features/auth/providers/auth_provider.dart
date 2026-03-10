import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

part 'auth_provider.g.dart';

/// Stream of auth state changes — drives the GoRouter redirect guard
/// TEMP: Disabled to debug NPE - returns empty stream
@riverpod
Stream<User?> authState(Ref ref) {
  // final repo = ref.watch(authRepositoryProvider);
  // return repo.authStateChanges.map((state) => state.session?.user);
  return Stream.value(null); // Return empty auth stream
}

/// Current user (sync, may be null)
/// TEMP: Disabled to debug NPE - returns null user
@riverpod
User? currentUser(Ref ref) {
  // return ref.watch(authStateProvider).valueOrNull;
  return null; // No authenticated user
}
