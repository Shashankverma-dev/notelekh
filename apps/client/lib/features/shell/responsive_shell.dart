import 'package:flutter/material.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/shell/widgets/app_sidebar.dart';
import 'package:ai_workspace_client/features/dashboard/dashboard_screen.dart';
import 'package:ai_workspace_client/features/studio/unified_studio_screen.dart';
import 'package:ai_workspace_client/features/files/files_screen.dart';
import 'package:ai_workspace_client/features/search/search_screen.dart';
import 'package:ai_workspace_client/features/settings/settings_screen.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

// Nav index: 0=Home, 1=Studio(Canvas+AI), 2=Files, 3=Search, 4=Settings
class ResponsiveShell extends StatelessWidget {
  final AppState state;

  const ResponsiveShell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (w >= 1024) return _DesktopShell(state: state);
            if (w >= 640)  return _TabletShell(state: state);
            return _MobileShell(state: state);
          },
        );
      },
    );
  }
}

// ── Desktop: full sidebar + content ───────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final AppState state;
  const _DesktopShell({required this.state});

  @override
  Widget build(BuildContext context) {
    // Hide sidebar when viewing/editing a notebook (navIndex 1) for distraction-free canvas
    final showSidebar = state.selectedNavIndex != 1 || state.isNotebookSidebarVisible;
    return Scaffold(
      body: Row(
        children: [
          if (showSidebar) AppSidebar(state: state),
          Expanded(child: _ScreenRouter(state: state)),
        ],
      ),
    );
  }
}

// ── Tablet: compact rail navigation ───────────────────────────────────────────
class _TabletShell extends StatelessWidget {
  final AppState state;
  const _TabletShell({required this.state});

  @override
  Widget build(BuildContext context) {
    final showSidebar = state.selectedNavIndex != 1 || state.isNotebookSidebarVisible;
    final isDark = state.isDarkMode;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor  = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final mutedColor   = isDark ? AppColors.darkTextMuted  : AppColors.lightTextMuted;

    return Scaffold(
      body: Row(
        children: [
          // Compact Rail
          if (showSidebar)
            Container(
              width: 72,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Logo icon
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  child: const Center(
                    child: NotelekhIcon(size: 34),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Nav items
                _railItem(context, Icons.dashboard_outlined, Icons.dashboard_rounded, 0, 'Home', state),
                _railItem(context, Icons.splitscreen_outlined, Icons.splitscreen_rounded, 1, 'Studio', state),
                _railItem(context, Icons.folder_open_rounded, Icons.folder_rounded, 2, 'Files', state),
                _railItem(context, Icons.search_rounded, Icons.search_rounded, 3, 'Search', state),
                const Spacer(),
                // Theme toggle
                IconButton(
                  icon: Icon(
                    state.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: mutedColor,
                  ),
                  onPressed: state.toggleTheme,
                  tooltip: 'Toggle Theme',
                ),
                // Settings
                _railItem(context, Icons.settings_outlined, Icons.settings_rounded, 4, 'Settings', state),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(child: _ScreenRouter(state: state)),
        ],
      ),
    );
  }

  Widget _railItem(BuildContext context, IconData icon, IconData activeIcon,
      int idx, String tooltip, AppState state) {
    final isSelected = state.selectedNavIndex == idx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        child: InkWell(
          onTap: () => state.setNavIndex(idx),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.darkTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile: bottom navigation bar ─────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final AppState state;
  const _MobileShell({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    final showBottomNav = state.selectedNavIndex != 1;
    return Scaffold(
      body: _ScreenRouter(state: state),
      bottomNavigationBar: showBottomNav
          ? Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _clamp(state.selectedNavIndex),
          onDestinationSelected: (i) => state.setNavIndex(i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.splitscreen_outlined),
              selectedIcon: Icon(Icons.splitscreen_rounded),
              label: 'Studio',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_open_rounded),
              selectedIcon: Icon(Icons.folder_rounded),
              label: 'Files',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ) : null,
    );
  }

  int _clamp(int idx) => idx.clamp(0, 4);
}

// ── Shared screen router ───────────────────────────────────────────────────────
class _ScreenRouter extends StatelessWidget {
  final AppState state;
  const _ScreenRouter({required this.state});

  @override
  Widget build(BuildContext context) {
    final wsKey = state.currentWorkspace?.id ?? 'none';
    switch (state.selectedNavIndex) {
      case 0:  return DashboardScreen(key: ValueKey('dash_$wsKey'), state: state);
      case 1:  return UnifiedStudioScreen(key: ValueKey('studio_$wsKey'), state: state);
      case 2:  return FilesScreen(key: ValueKey('files_$wsKey'), state: state);
      case 3:  return SearchScreen(key: ValueKey('search_$wsKey'), state: state);
      case 4:  return SettingsScreen(state: state);
      default: return DashboardScreen(key: ValueKey('dash_$wsKey'), state: state);
    }
  }
}
