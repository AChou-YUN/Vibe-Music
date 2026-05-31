import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/debug_log.dart';
import '../../providers/netease_provider.dart';
import '../../providers/audio_provider.dart';
import '../../data/services/netease_service.dart';
import '../../data/services/cache_service.dart';

void _showLogs(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(children: [
        const Text('Debug Log', style: TextStyle(color: AppColors.textPrimary)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.copy_rounded, size: 18), color: AppColors.textSecondary, tooltip: 'Copy', onPressed: () { DebugLog.copyToClipboard(); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1))); }),
      ]),
      content: SizedBox(width: 600, height: 400, child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
        child: SingleChildScrollView(child: SelectableText(DebugLog.allLogs.isEmpty ? 'No logs yet' : DebugLog.allLogs, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'Consolas', height: 1.6))),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _lastQuery = '';
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await CacheService.loadSearchHistory();
    if (mounted) setState(() => _history = h);
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.isNotEmpty && q != _lastQuery) {
      _lastQuery = q;
      DebugLog.log('=== Search: "$q" ===');
      ref.read(neteaseSearchQueryProvider.notifier).state = q;
      CacheService.addSearchHistory(q);
      _loadHistory();
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(neteaseSearchResultsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Search', style: Theme.of(context).textTheme.headlineLarge),
            const Spacer(),
            IconButton(icon: const Icon(Icons.bug_report_rounded, size: 20), color: AppColors.textSecondary, tooltip: 'Debug Log', onPressed: () => _showLogs(context)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: _controller, autofocus: true, onSubmitted: (_) => _search(),
              decoration: InputDecoration(hintText: 'Search songs (NetEase)...', hintStyle: const TextStyle(color: AppColors.textDisabled), prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18), filled: true, fillColor: AppColors.surfaceLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true),
            )),
            const SizedBox(width: 8),
            FilledButton(onPressed: _search, style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), child: const Text('Search')),
          ]),
          const SizedBox(height: 16),
          Expanded(child: resultsAsync.when(
            data: (results) {
              if (results.isEmpty && _lastQuery.isNotEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: 12),
                  Text('No results for "$_lastQuery"', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _search, child: const Text('Retry', style: TextStyle(color: AppColors.accent))),
                  TextButton(onPressed: () => _showLogs(context), child: const Text('View Logs', style: TextStyle(color: AppColors.textDisabled, fontSize: 11))),
                ]));
              }
              if (results.isEmpty) return _buildHistory();
              return ListView.builder(itemCount: results.length, itemBuilder: (context, index) => _SearchResultTile(result: results[index]));
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
            error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Search failed', style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              FilledButton(onPressed: _search, style: FilledButton.styleFrom(backgroundColor: AppColors.accent), child: const Text('Retry')),
              TextButton(onPressed: () => _showLogs(context), child: const Text('View Logs', style: TextStyle(color: AppColors.textSecondary))),
            ])),
          )),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_rounded, size: 48, color: AppColors.textDisabled),
        const SizedBox(height: 12),
        const Text('Search for songs online', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Search History', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(onPressed: () async { await CacheService.clearSearchHistory(); setState(() => _history = []); }, child: const Text('Clear', style: TextStyle(color: AppColors.textDisabled, fontSize: 11))),
        ]),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(
          itemCount: _history.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            leading: const Icon(Icons.history_rounded, size: 18, color: AppColors.textDisabled),
            title: Text(_history[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            trailing: IconButton(icon: const Icon(Icons.north_west_rounded, size: 14, color: AppColors.textDisabled), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24), onPressed: () { _controller.text = _history[i]; _search(); }),
            onTap: () { _controller.text = _history[i]; _search(); },
          ),
        )),
      ],
    );
  }
}

class _SearchResultTile extends ConsumerStatefulWidget {
  final NeteaseSearchResult result;
  const _SearchResultTile({required this.result});
  @override
  ConsumerState<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends ConsumerState<_SearchResultTile> {
  bool _loading = false;

  Future<void> _play() async {
    setState(() => _loading = true);
    DebugLog.log('Play: "${widget.result.songName}" by "${widget.result.artistName}"');
    try {
      final netease = ref.read(neteaseServiceProvider);
      final url = await netease.getPlayUrl(widget.result.id);
      if (url == null || url.isEmpty) {
        DebugLog.log('Play FAILED: no URL');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${netease.lastError ?? "unknown"}'), duration: const Duration(seconds: 3), action: SnackBarAction(label: 'Logs', onPressed: () => _showLogs(context))));
        return;
      }
      DebugLog.log('Play OK: ${url.substring(0, url.length.clamp(0, 80))}');
      final track = netease.resultToTrack(widget.result, playUrl: url);
      final audio = ref.read(audioServiceProvider);
      await audio.addToQueue(track);
      await audio.playTrack(track);
      ref.read(queueProvider.notifier).update();
    } catch (e) {
      DebugLog.log('Play ERROR: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3), action: SnackBarAction(label: 'Logs', onPressed: () => _showLogs(context))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToQueue() async {
    DebugLog.log('Add queue: "${widget.result.songName}"');
    final netease = ref.read(neteaseServiceProvider);
    final url = await netease.getPlayUrl(widget.result.id);
    if (url != null && url.isNotEmpty) {
      final track = netease.resultToTrack(widget.result, playUrl: url);
      ref.read(audioServiceProvider).addToQueue(track);
      ref.read(queueProvider.notifier).update();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added: ${widget.result.songName}'), duration: const Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final dur = r.duration > 0 ? FormatUtils.formatDuration(Duration(milliseconds: r.duration)) : '';
    return InkWell(
      onTap: _loading ? null : _play,
      borderRadius: BorderRadius.circular(6),
      hoverColor: AppColors.surfaceLight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
            child: r.coverUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(r.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20)))
              : _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
                : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.songName, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
            Text('${r.artistName}${r.albumName.isNotEmpty ? '  .  ${r.albumName}' : ''}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ])),
          if (dur.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8), child: Text(dur, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11))),
          IconButton(icon: const Icon(Icons.playlist_add_rounded, size: 18, color: AppColors.textSecondary), tooltip: 'Add to queue', onPressed: _loading ? null : _addToQueue, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
        ]),
      ),
    );
  }
}
