import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/debug_log.dart';
import '../../data/services/cache_service.dart';
import '../../providers/netease_provider.dart';
import '../../providers/playlist_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _testResult;
  bool _testing = false;
  bool _serverOk = false;
  String _cachePath = '';
  List<CacheItem> _cacheItems = [];
  bool _cacheLoading = true;

  @override
  void initState() {
    super.initState();
    _checkServer();
    _loadCacheInfo();
  }

  Future<void> _checkServer() async {
    final netease = ref.read(neteaseServiceProvider);
    final ok = await netease.checkServer();
    if (mounted) setState(() => _serverOk = ok);
  }

  Future<void> _loadCacheInfo() async {
    if (mounted) setState(() => _cacheLoading = true);
    final path = await CacheService.getCachePath();
    final items = await CacheService.getCacheItems();
    if (mounted) {
      setState(() {
        _cachePath = path;
        _cacheItems = items;
        _cacheLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final netease = ref.read(neteaseServiceProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 24),
            _section('Backend', [
              ListTile(
                leading: Icon(
                  _serverOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: _serverOk ? Colors.greenAccent : AppColors.error,
                ),
                title: Text(
                  _serverOk ? 'NeteaseCloudMusic API: Running' : 'NeteaseCloudMusic API: Not Running',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  _serverOk ? 'localhost:3000' : 'Please start: node backend/server.js',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: _checkServer,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ]),
            _section('Account', [
              ListTile(
                leading: Icon(
                  netease.isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                  color: netease.isLoggedIn ? AppColors.accent : AppColors.textSecondary,
                ),
                title: Text(
                  netease.isLoggedIn ? 'Logged in: ${netease.nickname}' : 'Not logged in',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  netease.isLoggedIn ? 'ID: ${netease.userId}' : 'Login to access VIP songs',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                onTap: () => _showLoginDialog(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                hoverColor: AppColors.surfaceLight,
              ),
            ]),
            _section('Music', [
              _tile(Icons.folder_rounded, 'Music directories', 'Manage scanned folders', () {}),
            ]),
            _section('Audio', [
              _tile(Icons.equalizer_rounded, 'Equalizer', 'Adjust audio settings', () => context.push('/equalizer')),
            ]),
            _section('Cache', [
              // Cache path display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cache Directory', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            _cachePath.isEmpty ? 'Loading...' : _cachePath,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontFamily: 'Consolas'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      color: AppColors.textDisabled,
                      tooltip: 'Copy path',
                      onPressed: _cachePath.isEmpty ? null : () {
                        Clipboard.setData(ClipboardData(text: _cachePath));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Path copied'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      color: AppColors.textDisabled,
                      tooltip: 'Open folder',
                      onPressed: _cachePath.isEmpty ? null : () async {
                        try {
                          await Process.run('explorer', [_cachePath]);
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Cache items list
              if (_cacheLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
                )
              else
                ..._cacheItems.map((item) => _cacheItemTile(item)),
              const SizedBox(height: 8),
              // Clear buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearDataCache,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear Data Cache'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearAllCache,
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: const Text('Clear All Cache'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
            _section('Debug', [
              ListTile(
                leading: Icon(_testing ? Icons.hourglass_top_rounded : Icons.network_check_rounded, color: AppColors.textSecondary),
                title: Text(_testing ? 'Testing...' : 'Test API Connection', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text(
                  _testResult ?? 'Test NeteaseCloudMusic API connectivity',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  maxLines: 5,
                ),
                onTap: _testing ? null : _runNetworkTest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                hoverColor: AppColors.surfaceLight,
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_rounded, color: AppColors.textSecondary),
                title: const Text('Debug Log', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text('${DebugLog.logCount} entries', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                onTap: () => _showLogs(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                hoverColor: AppColors.surfaceLight,
              ),
            ]),
            _section('About', [
              _tile(Icons.info_outline_rounded, 'Vibe Music', 'Version 1.0.0 (NetEase Cloud Music)', () {}),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.accent)),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      hoverColor: AppColors.surfaceLight,
    );
  }

  Widget _cacheItemTile(CacheItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(item.icon, color: AppColors.textSecondary, size: 20),
        title: Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        subtitle: Text(item.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.sizeText, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _clearSingleItem(item),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: AppColors.textDisabled),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Future<void> _clearSingleItem(CacheItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear ${item.name}?', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(
          item.boxName == 'netease_auth'
            ? 'This will log you out. You will need to scan QR code again.'
            : 'This will clear ${item.description.toLowerCase()}.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: item.boxName == 'netease_auth' ? AppColors.error : AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await CacheService.clearBox(item.boxName);
      await _loadCacheInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} cleared'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _clearDataCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Data Cache?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text(
          'This will clear liked songs, search history, play queue, and last track. Login session will be preserved.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (confirm == true) {
      await CacheService.clearDataCache();
      await _loadCacheInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data cache cleared'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All Cache?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text(
          'This will clear ALL cached data including login session. You will need to log in again.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await CacheService.clearAll(includeAuth: true);
      await _loadCacheInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cache cleared'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _runNetworkTest() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final netease = ref.read(neteaseServiceProvider);
      final results = <String>[];
      final serverOk = await netease.checkServer();
      results.add('API Server: ${serverOk ? "OK" : "FAIL (not running)"}');
      if (serverOk) {
        final searchResults = await netease.searchSongs('test', limit: 1);
        results.add('Search: ${searchResults.isNotEmpty ? "OK (${searchResults.length} results)" : "FAIL"}');
        if (searchResults.isNotEmpty) {
          final url = await netease.getPlayUrl(searchResults.first.id);
          results.add('Play URL: ${url != null ? "OK" : "FAIL (VIP required?)"}');
        }
      }
      if (mounted) setState(() { _testResult = results.join('\n'); _testing = false; _serverOk = serverOk; });
    } catch (e) {
      if (mounted) setState(() { _testResult = 'Test crashed: $e'; _testing = false; });
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _NeteaseLoginDialog()).then((_) { if (mounted) setState(() {}); });
  }

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
}

class _NeteaseLoginDialog extends ConsumerStatefulWidget {
  const _NeteaseLoginDialog();
  @override
  ConsumerState<_NeteaseLoginDialog> createState() => _NeteaseLoginDialogState();
}

class _NeteaseLoginDialogState extends ConsumerState<_NeteaseLoginDialog> {
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _qrKey;
  String? _qrImage;
  bool _qrMode = true;
  String _qrStatusText = 'Waiting for scan...';

  @override
  void initState() {
    super.initState();
    _startQrLogin();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _startQrLogin() async {
    setState(() { _qrImage = null; _error = null; _qrStatusText = 'Generating QR code...'; });
    final netease = ref.read(neteaseServiceProvider);
    final key = await netease.getQrKey();
    if (key == null) {
      if (mounted) setState(() => _error = netease.lastError ?? 'Failed to get QR key');
      return;
    }
    final img = await netease.createQrCode(key);
    if (mounted) {
      setState(() {
        _qrKey = key;
        _qrImage = img;
        _qrStatusText = 'Scan with NetEase Cloud Music app';
      });
      _pollQrStatus();
    }
  }

  Future<void> _pollQrStatus() async {
    if (_qrKey == null) return;
    final netease = ref.read(neteaseServiceProvider);
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _qrKey == null) break;
      try {
        final result = await netease.checkQrStatus(_qrKey!);
        final code = result['code'] as int;
        DebugLog.log('QR poll: code=$code');
        if (!mounted) break;
        if (code == 803) {
          final cookie = result['cookie'] as String? ?? '';
          if (cookie.isNotEmpty) {
            netease.setCookie(cookie);
            await netease.getUserInfo();
          }
            if (mounted) {
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Welcome, ${netease.nickname}!'), duration: const Duration(seconds: 2)),
              );
              ref.read(playlistProvider.notifier).syncAllFromCloud();
            }
            return;
        } else if (code == 800) {
          if (mounted) setState(() => _qrStatusText = 'QR expired, regenerating...');
          _startQrLogin();
          return;
        } else if (code == 802) {
          if (mounted) setState(() => _qrStatusText = 'Scanned, confirm on phone...');
        } else {
          if (mounted) setState(() => _qrStatusText = 'Waiting for scan...');
        }
      } catch (e) {
        DebugLog.log('QR poll error: $e');
      }
    }
  }

  Future<void> _loginWithPhone() async {
    final phone = _phoneCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    if (phone.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'Please enter phone and password');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final netease = ref.read(neteaseServiceProvider);
    final ok = await netease.loginWithPhone(phone, pwd);
    if (mounted) {
      setState(() => _loading = false);
        if (ok) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome, ${netease.nickname}!'), duration: const Duration(seconds: 2)),
          );
          ref.read(playlistProvider.notifier).syncAllFromCloud();
        } else {
        setState(() => _error = netease.lastError ?? 'Login failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Netease Cloud Music Login', style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _qrMode = true; if (_qrKey == null) _startQrLogin(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _qrMode ? AppColors.accent : Colors.transparent, width: 2))),
                  child: Text('QR Code', textAlign: TextAlign.center, style: TextStyle(color: _qrMode ? AppColors.accent : AppColors.textSecondary)),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _qrMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: !_qrMode ? AppColors.accent : Colors.transparent, width: 2))),
                  child: Text('Phone', textAlign: TextAlign.center, style: TextStyle(color: !_qrMode ? AppColors.accent : AppColors.textSecondary)),
                ),
              )),
            ]),
            const SizedBox(height: 16),
            if (_qrMode) ...[
              if (_qrImage != null && _qrImage!.isNotEmpty)
                Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: _buildQrImage(),
                )
              else
                const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
              const SizedBox(height: 12),
              Text(_qrStatusText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ] else ...[
              TextField(
                controller: _phoneCtrl,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true, fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: AppColors.textDisabled),
                  filled: true, fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _loginWithPhone,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Login'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  Widget _buildQrImage() {
    try {
      final uri = Uri.parse(_qrImage!);
      if (uri.data != null) {
        return Image.memory(uri.data!.contentAsBytes(), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('QR Error', style: TextStyle(color: Colors.black))));
      }
      return const Center(child: Text('Invalid QR', style: TextStyle(color: Colors.black)));
    } catch (e) {
      return Center(child: Text('Error: $e', style: const TextStyle(color: Colors.black, fontSize: 10)));
    }
  }
}



