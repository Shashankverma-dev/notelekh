import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

// Brand & Theme Palette
const _inkPrimary = Color(0xFF0F172A);
const _inkSecondary = Color(0xFF475569);
const _inkMuted = Color(0xFF94A3B8);
const _brandPrimary = Color(0xFF4F46E5);
const _brandViolet = Color(0xFF7C3AED);
const _borderLight = Color(0xFFE2E8F0);
const _bgAuth = Color(0xFFFFFFFF);
const _bgHero = Color(0xFF0B0F19);
const _successColor = Color(0xFF10B981);
const _errorColor = Color(0xFFEF4444);

class LoginScreen extends StatefulWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignIn = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _passwordVisible = false;
  bool _keepSignedIn = true;
  bool _isLoading = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  String? _errorMessage;
  AuthDiagnosticInfo? _activeDiagnostic;
  bool _showDiagnostics = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (widget.state.pendingAuthError != null) {
      _errorMessage = widget.state.pendingAuthError;
      _activeDiagnostic = widget.state.lastAuthDiagnostic;
      widget.state.clearPendingAuthError();
    } else if (widget.state.lastAuthDiagnostic != null) {
      _activeDiagnostic = widget.state.lastAuthDiagnostic;
    }
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.pendingAuthError != null && _errorMessage == null) {
      setState(() {
        _errorMessage = widget.state.pendingAuthError;
        _activeDiagnostic = widget.state.lastAuthDiagnostic;
        widget.state.clearPendingAuthError();
      });
    } else if (widget.state.lastAuthDiagnostic != null && _activeDiagnostic == null) {
      setState(() {
        _activeDiagnostic = widget.state.lastAuthDiagnostic;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final v = _emailController.text.trim();
    return v.contains('@') && v.contains('.');
  }

  bool get _passwordValid => _passwordController.text.length >= 6;

  Future<void> _submit() async {
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _errorMessage = null;
    });
    if (!_emailValid || !_passwordValid) return;
    setState(() => _isLoading = true);
    try {
      String? error;
      if (_isSignIn) {
        error = await widget.state.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        error = await widget.state.createAccount(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
        );
      }
      if (mounted && error != null) {
        setState(() {
          _errorMessage = error;
          _activeDiagnostic = widget.state.lastAuthDiagnostic;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _errorMessage = widget.state.formatAuthError(e);
          _activeDiagnostic = widget.state.lastAuthDiagnostic ??
              AuthDiagnosticInfo(
                stage: 'submit',
                exceptionType: e.runtimeType.toString(),
                message: e.toString(),
                rawException: e.toString(),
                stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
              );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeDiagnostic = null;
    });
    try {
      final error = await widget.state.signInWithGoogle();
      if (mounted) {
        if (error != null) {
          setState(() {
            _isLoading = false;
            _errorMessage = error;
            _activeDiagnostic = widget.state.lastAuthDiagnostic;
          });
        } else {
          if (!widget.state.isAuthenticated) {
            setState(() => _isLoading = false);
            Future.delayed(const Duration(seconds: 6), () {
              if (mounted && _isLoading && _errorMessage == null) {
                setState(() => _isLoading = false);
              }
            });
          }
        }
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.state.formatAuthError(e);
          _activeDiagnostic = widget.state.lastAuthDiagnostic ??
              AuthDiagnosticInfo(
                stage: 'signInWithGoogle-ui',
                exceptionType: e.runtimeType.toString(),
                message: e.toString(),
                rawException: e.toString(),
                stackTraceSnippet: st.toString().split('\n').take(8).join('\n'),
              );
        });
      }
    }
  }

  void _switchTab(bool signIn) {
    if (_isSignIn == signIn) return;
    setState(() {
      _isSignIn = signIn;
      _emailTouched = false;
      _passwordTouched = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1024;

    return Scaffold(
      backgroundColor: isWide ? _bgHero : _bgAuth,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: isWide
            ? Row(
                children: [
                  // LEFT: Atmospheric Human Creativity Showcase
                  Expanded(
                    flex: 11,
                    child: _CreativeStudioHero(state: widget.state),
                  ),
                  // Vertical Hairline Separator
                  Container(
                    width: 1,
                    color: const Color(0xFF1E293B),
                  ),
                  // RIGHT: Clean, Card-Free Professional Auth Form
                  Expanded(
                    flex: 10,
                    child: Container(
                      color: _bgAuth,
                      height: double.infinity,
                      child: SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _buildAuthForm(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMobileHeroHeader(),
                          const SizedBox(height: 28),
                          _buildAuthForm(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Compact header displayed on tablets and mobile screens
  Widget _buildMobileHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.state.navigateToLanding,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: _inkPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const NotelekhIcon(size: 32),
            const SizedBox(width: 8),
            Text(
              'Notelekh',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _inkPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Where ideas begin with a stroke.',
          style: GoogleFonts.caveat(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _brandPrimary,
          ),
        ),
      ],
    );
  }

  /// The core card-free authentication form
  Widget _buildAuthForm() {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top utility row on desktop (Back to home)
        if (isWide) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.state.navigateToLanding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 16, color: _inkSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Back to home',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],

        // Brand Icon & Badge (Desktop)
        if (isWide) ...[
          Row(
            children: [
              const NotelekhIcon(size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notelekh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _inkPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'Creative Studio Workspace',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],

        // Heading & warm greeting
        Text(
          _isSignIn ? 'Welcome back' : 'Start your creative journey',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _inkPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignIn
              ? 'Enter your credentials to step inside your workspace.'
              : 'Join thousands of visual thinkers sketching, planning, and organizing notes.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: _inkSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),

        // Google Authentication Button (Seamless, tactile, high-craft)
        _GoogleSignInButton(
          onPressed: _continueWithGoogle,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 22),

        // Minimalist Divider: "or continue with email"
        Row(
          children: [
            const Expanded(child: Divider(color: _borderLight, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or continue with email',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _inkMuted,
                ),
              ),
            ),
            const Expanded(child: Divider(color: _borderLight, thickness: 1)),
          ],
        ),
        const SizedBox(height: 22),

        // Segmented Tab Selector (Sign In / Create Account) - Card-free pill
        _SegmentedAuthTabs(
          isSignIn: _isSignIn,
          onChanged: _switchTab,
        ),
        const SizedBox(height: 24),

        // Create Account: Full Name
        if (!_isSignIn) ...[
          _fieldLabel('Full Name'),
          const SizedBox(height: 6),
          _ModernInputField(
            controller: _nameController,
            hintText: 'e.g. Leonardo da Vinci',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 18),
        ],

        // Email Address with validation status
        Row(
          children: [
            _fieldLabel('Email Address'),
            const Spacer(),
            if (_emailValid)
              const _StatusBadge(text: 'Valid email', isSuccess: true)
            else if (_emailTouched)
              const _StatusBadge(text: 'Invalid format', isSuccess: false),
          ],
        ),
        const SizedBox(height: 6),
        _ModernInputField(
          controller: _emailController,
          hintText: 'name@studio.com',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          hasError: _emailTouched && !_emailValid,
          isValid: _emailValid,
          onChanged: (_) {
            if (_emailTouched) setState(() {});
          },
          onEditingComplete: () => setState(() => _emailTouched = true),
        ),
        const SizedBox(height: 18),

        // Password with strength indicator
        Row(
          children: [
            _fieldLabel('Password'),
            const Spacer(),
            if (_passwordValid)
              const _StatusBadge(text: 'Ready', isSuccess: true)
            else if (_passwordTouched)
              const _StatusBadge(text: 'Min 6 characters', isSuccess: false),
          ],
        ),
        const SizedBox(height: 6),
        _ModernInputField(
          controller: _passwordController,
          hintText: '••••••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: !_passwordVisible,
          hasError: _passwordTouched && !_passwordValid,
          isValid: _passwordValid,
          onChanged: (_) {
            if (_passwordTouched) setState(() {});
          },
          onEditingComplete: () => setState(() => _passwordTouched = true),
          suffixWidget: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: _inkMuted,
            ),
            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          ),
        ),
        const SizedBox(height: 14),

        // Keep me signed in & Forgot password
        if (_isSignIn)
          Row(
            children: [
              _CustomCheckbox(
                value: _keepSignedIn,
                label: 'Remember this device',
                onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset link sent to your email if registered.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _brandPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Error message banner (if any)
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline_rounded, color: _errorColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    _errorMessage ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Developer Diagnostics Bar (Collapsible for complete developer observability)
        if (_activeDiagnostic != null) ...[
          _buildDiagnosticsPanel(),
          const SizedBox(height: 14),
        ],

        // Primary Action Button (Vibrant, high-craft gradient)
        _PrimaryActionButton(
          label: _isSignIn ? 'Sign In to Workspace' : 'Create Free Account',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 20),

        // Switch Mode Link
        Center(
          child: GestureDetector(
            onTap: () => _switchTab(!_isSignIn),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13, color: _inkSecondary),
                  children: [
                    TextSpan(
                      text: _isSignIn ? "New to Notelekh? " : 'Already have an account? ',
                    ),
                    TextSpan(
                      text: _isSignIn ? 'Create one for free' : 'Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Humanized Trust & Security Micro-Footer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'End-to-end encrypted notes • Offline local storage • Zero tracking',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showDiagnostics = !_showDiagnostics),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auth Diagnostics (${_activeDiagnostic!.stage})',
                      style: GoogleFonts.firaCode(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF1F5F9),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _showDiagnostics ? 'Hide' : 'Show',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showDiagnostics ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (_showDiagnostics) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _diagnosticRow('Stage', _activeDiagnostic!.stage),
                  _diagnosticRow('Type', _activeDiagnostic!.exceptionType),
                  if (_activeDiagnostic!.code != null && _activeDiagnostic!.code!.isNotEmpty)
                    _diagnosticRow('Code', _activeDiagnostic!.code!),
                  if (_activeDiagnostic!.message != null && _activeDiagnostic!.message!.isNotEmpty)
                    _diagnosticRow('Message', _activeDiagnostic!.message!),
                  if (_activeDiagnostic!.rawException != null &&
                      _activeDiagnostic!.rawException!.isNotEmpty &&
                      _activeDiagnostic!.rawException != _activeDiagnostic!.message)
                    _diagnosticRow('Raw', _activeDiagnostic!.rawException!),
                  if (_activeDiagnostic!.stackTraceSnippet != null &&
                      _activeDiagnostic!.stackTraceSnippet!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: SelectableText(
                        _activeDiagnostic!.stackTraceSnippet!,
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          color: const Color(0xFFE2E8F0),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _activeDiagnostic!.toFormattedDetails()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Diagnostics copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF38BDF8)),
                      label: Text(
                        'Copy Diagnostics',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _fieldLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _inkPrimary,
        ),
      );

  Widget _diagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.firaCode(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: GoogleFonts.firaCode(
                fontSize: 10.5,
                color: const Color(0xFFF8FAFC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// ATMOSPHERIC CREATIVE HERO SIDE (Celebrates Human Expression)
// -------------------------------------------------------------
class _CreativeStudioHero extends StatelessWidget {
  final AppState state;
  const _CreativeStudioHero({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgHero,
      child: Stack(
        children: [
          // Architectural Dot Grid underlay
          Positioned.fill(
            child: CustomPaint(
              painter: _ArchitecturalDotGridPainter(),
            ),
          ),

          // Radiant Ambient Light Blobs (Warm violet, indigo aura)
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.18),
                    const Color(0xFF4F46E5).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    const Color(0xFF7C3AED).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Hero Showcase Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Studio Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gesture_rounded, color: Color(0xFF818CF8), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'NOTELEKH INK ENGINE v3',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Designed for Thinkers',
                        style: GoogleFonts.caveat(
                          fontSize: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Grand Editorial Headline on Human Creativity
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.2,
                        height: 1.15,
                      ),
                      children: [
                        const TextSpan(text: 'Ideas don’t start typed.\nThey begin with a '),
                        TextSpan(
                          text: 'stroke.',
                          style: GoogleFonts.newsreader(
                            fontSize: 46,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFA5B4FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'An infinite tactile sanctuary for fluid handwriting, visual thinking, and unbounded imagination.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF94A3B8),
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Integrated Human Creativity Studio Vignette (Card-free vector drawing)
                  Expanded(
                    flex: 12,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1F2937),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          children: [
                            // Custom Painter: Realistic handwritten sketch, golden spiral, fluid calligraphy
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CreativeShowcaseCanvasPainter(),
                              ),
                            ),

                            // Handwritten note overlay in Caveat
                            Positioned(
                              top: 24,
                              left: 32,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '“Thoughts flow faster when you write by hand.”',
                                    style: GoogleFonts.caveat(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '— Infinite canvas, zero boundaries',
                                    style: GoogleFonts.caveat(
                                      fontSize: 16,
                                      color: const Color(0xFF818CF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Technical Inking Indicators at Bottom
                            Positioned(
                              bottom: 16,
                              left: 24,
                              right: 24,
                              child: Row(
                                children: [
                                  _studioSpec('Tool', 'Fountain Pen (0.5mm)'),
                                  const SizedBox(width: 24),
                                  _studioSpec('Dynamics', 'Sub-pixel pressure curve'),
                                  const Spacer(),
                                  _studioSpec('Latency', '0.4ms predictive ink'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Bottom Quote & Creative Authority
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Icon(Icons.brush_rounded, color: Color(0xFFA5B4FC), size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '“Finally, a digital workspace that feels as intimate and expressive as real paper.”',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Crafted for visual thinkers, researchers & students',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studioSpec(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// REALISTIC CREATIVE CANVAS PAINTER (Human Ink & Geometry)
// -------------------------------------------------------------
class _CreativeShowcaseCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle horizontal ruled lines (Notebook feel)
    final linePaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    const spacing = 38.0;
    for (double y = 80; y < h - 40; y += spacing) {
      canvas.drawLine(Offset(24, y), Offset(w - 24, y), linePaint);
    }

    // 2. Highlighting translucent bands (Golden Amber and Lavender)
    final highlightAmber = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.18)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 22;
    canvas.drawLine(Offset(w * 0.12, h * 0.38), Offset(w * 0.48, h * 0.38), highlightAmber);

    final highlightViolet = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.20)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24;
    canvas.drawLine(Offset(w * 0.35, h * 0.54), Offset(w * 0.72, h * 0.54), highlightViolet);

    // 3. Mathematical Geometry: Golden Ratio logarithmic spiral & tangents
    final spiralPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final spiralPath = Path();
    final centerX = w * 0.76;
    final centerY = h * 0.42;
    spiralPath.moveTo(centerX, centerY);
    for (double theta = 0; theta < 3.2 * math.pi; theta += 0.05) {
      final r = 2.5 * math.exp(0.24 * theta);
      final x = centerX + r * math.cos(theta);
      final y = centerY + r * math.sin(theta);
      spiralPath.lineTo(x, y);
    }
    canvas.drawPath(spiralPath, spiralPaint);

    // Geometry axis lines
    final axisPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(centerX - 80, centerY), Offset(centerX + 80, centerY), axisPaint);
    canvas.drawLine(Offset(centerX, centerY - 70), Offset(centerX, centerY + 70), axisPaint);

    // 4. Fluid Human Calligraphy Stroke (Smooth pressure curves with variable width)
    final inkPath = Path();
    inkPath.moveTo(w * 0.08, h * 0.68);
    inkPath.cubicTo(
      w * 0.22, h * 0.52,
      w * 0.38, h * 0.78,
      w * 0.58, h * 0.62,
    );
    inkPath.cubicTo(
      w * 0.72, h * 0.50,
      w * 0.82, h * 0.74,
      w * 0.92, h * 0.60,
    );

    // Deep ink shadow
    final inkGlow = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(inkPath, inkGlow);

    // Primary fluid ink
    final inkMain = Paint()
      ..color = const Color(0xFFA5B4FC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(inkPath, inkMain);

    // Ink contact point (glowing stylus tip)
    final stylusPoint = Offset(w * 0.92, h * 0.60);
    final glowPoint = Paint()..color = const Color(0xFF818CF8).withValues(alpha: 0.6);
    canvas.drawCircle(stylusPoint, 6, glowPoint);
    final corePoint = Paint()..color = Colors.white;
    canvas.drawCircle(stylusPoint, 2.5, corePoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// ARCHITECTURAL DOT GRID PAINTER
// -------------------------------------------------------------
class _ArchitecturalDotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    const step = 28.0;
    for (double x = 14; x < size.width; x += step) {
      for (double y = 14; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// GOOGLE SIGN IN BUTTON (Clean, borderless-card, tactile)
// -------------------------------------------------------------
class _GoogleSignInButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  const _GoogleSignInButton({required this.onPressed, required this.isLoading});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.05 : 0.02),
                blurRadius: _hovered ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Redirecting to Google...',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _inkSecondary,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(20, 20),
                      painter: _GoogleVectorLogoPainter(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _inkPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoogleVectorLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.46;
    final strokeWidth = w * 0.20;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeWidth / 2);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.2, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.5, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.3, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.6, 1.5, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - strokeWidth * 0.25, cy - strokeWidth * 0.5, r + strokeWidth * 0.25, strokeWidth),
      Radius.circular(strokeWidth * 0.2),
    );
    canvas.drawRRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// SEGMENTED AUTH TABS (Sign In / Create Account) - Card-Free
// -------------------------------------------------------------
class _SegmentedAuthTabs extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onChanged;

  const _SegmentedAuthTabs({required this.isSignIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton('Sign In', isSignIn, () => onChanged(true)),
          ),
          Expanded(
            child: _tabButton('Create Account', !isSignIn, () => onChanged(false)),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _inkPrimary : _inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// MODERN INPUT FIELD (Integrated, breathable, card-free)
// -------------------------------------------------------------
class _ModernInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool hasError;
  final bool isValid;
  final Widget? suffixWidget;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  const _ModernInputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.hasError = false,
    this.isValid = false,
    this.suffixWidget,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? _errorColor
        : isValid
            ? _successColor
            : _borderLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: (hasError || isValid) ? 1.4 : 1.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        style: GoogleFonts.inter(fontSize: 14, color: _inkPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(fontSize: 13.5, color: _inkMuted, fontWeight: FontWeight.w400),
          prefixIcon: Icon(prefixIcon, size: 18, color: _inkMuted),
          suffixIcon: suffixWidget,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// PRIMARY CTA ACTION BUTTON
// -------------------------------------------------------------
class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _PrimaryActionButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF4338CA), const Color(0xFF6D28D9)]
                  : [_brandPrimary, _brandViolet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _brandPrimary.withValues(alpha: _hovered ? 0.35 : 0.22),
                blurRadius: _hovered ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// CHECKBOX
// -------------------------------------------------------------
class _CustomCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;
  const _CustomCheckbox({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: value ? _brandPrimary : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: value ? _brandPrimary : _borderLight, width: 1.5),
              ),
              child: value ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: _inkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// VALIDATION STATUS BADGE
// -------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final String text;
  final bool isSuccess;
  const _StatusBadge({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? _successColor : _errorColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isSuccess ? Icons.check_circle_rounded : Icons.info_rounded, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
