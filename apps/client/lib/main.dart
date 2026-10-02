import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/landing/landing_screen.dart';
import 'package:ai_workspace_client/features/auth/login_screen.dart';
import 'package:ai_workspace_client/features/shell/responsive_shell.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable runtime fetching so fonts (Caveat, Plus Jakarta Sans, Playfair, Outfit) load seamlessly
  GoogleFonts.config.allowRuntimeFetching = true;

  // Render the app immediately on frame 1 without awaiting network roundtrips
  runApp(const AIWorkspaceApp());
}

/// Custom scroll behavior that enables drag gestures for Apple Pencil (stylus),
/// inverted stylus, touch, mouse, and trackpad on web and mobile platforms.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

/// Sleek loading shell displayed while authenticating or completing redirect callback,
/// ensuring the user never sees an unexpected landing page flash.
class _AuthRestoringShell extends StatelessWidget {
  final AppState state;
  const _AuthRestoringShell({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = state.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E16) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Entering your workspace...',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AIWorkspaceApp extends StatefulWidget {
  const AIWorkspaceApp({super.key});

  @override
  State<AIWorkspaceApp> createState() => _AIWorkspaceAppState();
}

class _AIWorkspaceAppState extends State<AIWorkspaceApp> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Notelekh',
          scrollBehavior: const AppScrollBehavior(),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: _appState.isAuthenticated
              ? ResponsiveShell(state: _appState)
              : _appState.isAuthRestoring
                  ? _AuthRestoringShell(state: _appState)
                  : _appState.showLoginScreen
                      ? LoginScreen(state: _appState)
                      : LandingScreen(state: _appState),
        );
      },
    );
  }
}

