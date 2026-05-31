import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/services/netease_service.dart';

final neteaseServiceProvider = Provider<NeteaseApiService>((ref) {
  final service = NeteaseApiService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Search query state
final neteaseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Search results
final neteaseSearchResultsProvider = FutureProvider<List<NeteaseSearchResult>>((ref) async {
  final query = ref.watch(neteaseSearchQueryProvider);
  if (query.trim().isEmpty) return [];
  final service = ref.read(neteaseServiceProvider);
  return service.searchSongs(query.trim());
});

/// Login state
final neteaseLoginStateProvider = StateProvider<NeteaseLoginState>((ref) => NeteaseLoginState.loggedOut);

enum NeteaseLoginState { loggedOut, qrPending, loggingIn, loggedIn, error }
