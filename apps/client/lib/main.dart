import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/landing/landing_screen.dart';
import 'package:ai_workspace_client/features/auth/login_screen.dart';
import 'package:ai_workspace_client/features/shell/responsive_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/widgets/workspace_skeleton_shell.dart';

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
      listenable: _appState.appShellNotifier,
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
                  ? WorkspaceSkeletonShell(isDarkMode: _appState.isDarkMode)
                  : _appState.showLoginScreen
                      ? LoginScreen(state: _appState)
                      : LandingScreen(state: _appState),
        );
      },
    );
  }
}

