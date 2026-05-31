import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/services/kugou_service.dart';
import '../data/services/kuwo_service.dart';

final kugouServiceProvider = Provider<KugouService>((ref) {
  final service = KugouService();
  ref.onDispose(() => service.dispose());
  return service;
});

final kuwoServiceProvider = Provider<KuwoService>((ref) {
  final service = KuwoService();
  ref.onDispose(() => service.dispose());
  return service;
});

final kugouSearchQueryProvider = StateProvider<String>((ref) => '');

final kugouSearchResultsProvider = FutureProvider<List<KugouSearchResult>>((ref) async {
  final query = ref.watch(kugouSearchQueryProvider);
  if (query.trim().isEmpty) return [];
  final kugou = ref.read(kugouServiceProvider);
  return kugou.searchSongs(query.trim());
});
