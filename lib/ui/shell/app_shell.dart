import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/player_bar.dart';
import '../pages/home_page.dart';
import '../pages/library_page.dart';
import '../pages/playlists_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';

/// Current tab index
final currentTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  final Widget? overlayChild;
  const AppShell({super.key, this.overlayChild});

  static const _pages = <Widget>[
    HomePage(),
    LibraryPage(),
    PlaylistsPage(),
    SearchPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TitleBar(),
          Expanded(
            child: Row(
              children: [
                _SideBar(currentIndex: currentIndex),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: overlayChild ?? IndexedStack(
                          index: currentIndex,
                          children: _pages,
                        ),
                      ),
                      const PlayerBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: AppConstants.titleBarHeight,
        color: Colors.transparent,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Text(
              'Vibe Music',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const Spacer(),
            _WindowButtons(),
          ],
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WindowButton(icon: Icons.remove_rounded, onTap: () => windowManager.minimize()),
        _WindowButton(
          icon: Icons.crop_square_rounded,
          onTap: () async {
            final isMaximized = await windowManager.isMaximized();
            isMaximized ? await windowManager.unmaximize() : await windowManager.maximize();
          },
        ),
        _WindowButton(icon: Icons.close_rounded, isClose: true, onTap: () => windowManager.close()),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  const _WindowButton({required this.icon, required this.onTap, this.isClose = false});
  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: AppConstants.titleBarHeight,
          color: _hovering ? (widget.isClose ? AppColors.error : AppColors.surfaceLight) : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: _hovering ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  final int currentIndex;
  const _SideBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.sideBarWidth,
      color: AppColors.surface,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _SideBarItem(icon: Icons.home_rounded, label: 'Home', index: 0, active: currentIndex == 0),
          _SideBarItem(icon: Icons.library_music_rounded, label: 'Library', index: 1, active: currentIndex == 1),
          _SideBarItem(icon: Icons.queue_music_rounded, label: 'Playlists', index: 2, active: currentIndex == 2),
          _SideBarItem(icon: Icons.search_rounded, label: 'Search', index: 3, active: currentIndex == 3),
          const Spacer(),
          _SideBarItem(icon: Icons.settings_rounded, label: 'Settings', index: 4, active: currentIndex == 4),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SideBarItem extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool active;
  const _SideBarItem({required this.icon, required this.label, required this.index, required this.active});
  @override
  ConsumerState<_SideBarItem> createState() => _SideBarItemState();
}

class _SideBarItemState extends ConsumerState<_SideBarItem> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => ref.read(currentTabProvider.notifier).state = widget.index,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active ? AppColors.accent.withValues(alpha: 0.12) : _hovering ? AppColors.surfaceLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.active ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400, color: widget.active ? AppColors.accent : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
