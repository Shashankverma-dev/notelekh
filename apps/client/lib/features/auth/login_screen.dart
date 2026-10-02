import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

const _ink = Color(0xFF0F172A);
const _textSecondary = Color(0xFF64748B);
const _textMuted = Color(0xFF94A3B8);
const _brand = Color(0xFF5C59F2);
const _borderDefault = Color(0xFFE2E8F0);
const _bgPage = Color(0xFFF7F8FE);
const _success = Color(0xFF10B981);
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
  String? _errorMessage; // Firebase auth error message
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
      duration: const Duration(milliseconds: 450),
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
    if (_isSignIn) {
      debugPrint('[AUTH-UI] Sign In button pressed (email: ${_emailController.text.trim()})');
    } else {
      debugPrint('[AUTH-UI] Create Account button pressed (email: ${_emailController.text.trim()})');
    }
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
      debugPrint('[AUTH-UI] Submit unhandled exception: ${e.runtimeType}: $e');
      debugPrint('[AUTH-UI] Stack: $st');
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
    debugPrint('[AUTH-UI] Google button pressed');
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
          // If popup sign-in succeeded, widget.state.isAuthenticated is true
          // and ResponsiveShell renders immediately.
          // If popup was cancelled/closed without authenticating, reset loading:
          if (!widget.state.isAuthenticated) {
            setState(() => _isLoading = false);
            // In case a fallback redirect was triggered, safety watchdog restores UI if navigation failed:
            Future.delayed(const Duration(seconds: 6), () {
              if (mounted && _isLoading && _errorMessage == null) {
                debugPrint('[AUTH-UI] Redirect watchdog: browser did not navigate away, restoring UI state.');
                setState(() => _isLoading = false);
              }
            });
          }
        }
      }
    } catch (e, st) {
      debugPrint('[AUTH-UI] Google button unhandled exception: ${e.runtimeType}: $e');
      debugPrint('[AUTH-UI] Stack: $st');
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
    final isDesktop = size.width >= 1180;
    final isTablet = size.width >= 860 && size.width < 1180;

    return Scaffold(
      backgroundColor: _bgPage,
      body: Stack(
        children: [
          // Background ambient soft glow blobs
          Positioned(
            top: -100,
            left: -80,
            child: _AmbientBlob(
              size: 500,
              color: const Color(0xFF6366F1).withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _AmbientBlob(
              size: 550,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            left: size.width * 0.5 - 250,
            child: _AmbientBlob(
              size: 500,
              color: const Color(0xFFE0E7FF).withValues(alpha: 0.4),
            ),
          ),

          // Hand-drawn doodle connector trails (Desktop / wide view)
          if (isDesktop)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DoodleTrailsPainter(),
                ),
              ),
            ),

          // Main scrollable content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LEFT CREATIVE WING (Desktop)
                      if (isDesktop) ...[
                        SizedBox(
                          width: 290,
                          child: _LeftCreativeWing(state: widget.state),
                        ),
                        const SizedBox(width: 32),
                      ],

                      // CENTER AUTH CARD
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildCard(),
                      ),

                      // RIGHT CREATIVE WING (Desktop)
                      if (isDesktop) ...[
                        const SizedBox(width: 32),
                        SizedBox(
                          width: 290,
                          child: _RightCreativeWing(state: widget.state),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tablet floating teaser cards if viewport between 860px and 1180px
          if (isTablet) ...[
            Positioned(
              left: 20,
              top: 120,
              child: Transform.rotate(
                angle: -0.06,
                child: const _MiniSketchPencilCard(),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 80,
              child: Transform.rotate(
                angle: 0.04,
                child: const _MultiDeviceCard(),
              ),
            ),
          ],

          // Back to home button (Top-Left)
          Positioned(
            top: 16,
            left: 16,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.state.navigateToLanding,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF334155)),
                      const SizedBox(width: 6),
                      Text(
                        'Back to home',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.10),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 38),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Centered Brand Logo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NotelekhIcon(size: 46),
                const SizedBox(height: 8),
                Text(
                  'Notelekh',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: _ink,
                  ),
                ),
                Text(
                  'Think. Write. Grow.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // "Welcome back" Title & Subtitle
          Text(
            _isSignIn ? 'Welcome back' : 'Create your account',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isSignIn
                ? 'Enter your details to access your workspace.'
                : 'Start organizing your thoughts and notes with Notelekh.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),

          // "Continue with Google" button
          _GoogleSignInButton(
            onPressed: _continueWithGoogle,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 18),

          // Divider: "Or continue with email"
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Or continue with email',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
            ],
          ),
          const SizedBox(height: 18),

          // Toggle Tab Bar: Sign In / Create Account
          _TabBar(isSignIn: _isSignIn, onSwitch: _switchTab),
          const SizedBox(height: 20),

          // Optional Full Name for Register
          if (!_isSignIn) ...[
            _fieldLabel('Full Name'),
            const SizedBox(height: 6),
            _AuthField(
              controller: _nameController,
              hintText: 'Your name',
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 16),
          ],

          // Email Address Field with live validation badge
          Row(
            children: [
              _fieldLabel('Email Address'),
              const Spacer(),
              if (_emailValid)
                const _InlineChip(text: 'Looks good!', isSuccess: true)
              else if (_emailTouched)
                const _InlineChip(text: 'Invalid email', isSuccess: false),
            ],
          ),
          const SizedBox(height: 6),
          _AuthField(
            controller: _emailController,
            hintText: 'you@example.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            hasError: _emailTouched && !_emailValid,
            isValid: _emailValid,
            onChanged: (_) {
              if (_emailTouched) setState(() {});
            },
            onEditingComplete: () => setState(() => _emailTouched = true),
          ),
          const SizedBox(height: 16),

          // Password Field with live strength chip
          Row(
            children: [
              _fieldLabel('Password'),
              const Spacer(),
              if (_passwordValid)
                const _InlineChip(text: 'Strong', isSuccess: true)
              else if (_passwordTouched)
                const _InlineChip(text: 'Min 6 chars', isSuccess: false),
            ],
          ),
          const SizedBox(height: 6),
          _AuthField(
            controller: _passwordController,
            hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
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
                size: 19,
                color: _textMuted,
              ),
              onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
          const SizedBox(height: 16),

          // Keep me signed in + Forgot password
          if (_isSignIn)
            Row(
              children: [
                _CheckboxRow(
                  value: _keepSignedIn,
                  label: 'Keep me signed in',
                  onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {},
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _brand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 22),

          // Error message banner
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
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
                    child: Icon(Icons.error_outline_rounded, color: _errorColor, size: 16),
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
            const SizedBox(height: 10),
          ],

          // Developer Authentication Diagnostics Panel
          if (_activeDiagnostic != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
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
                            Text(
                              'Stack Snippet:',
                              style: GoogleFonts.firaCode(
                                fontSize: 10.5,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
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
            ),
          ],

          // Primary Gradient CTA Button
          _CtaButton(
            label: _isSignIn ? 'Sign In to Workspace' : 'Create Account',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 18),

          // Footer toggle
          Center(
            child: GestureDetector(
              onTap: () => _switchTab(!_isSignIn),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                  children: [
                    TextSpan(
                      text: _isSignIn ? "Don't have an account? " : 'Already have an account? ',
                    ),
                    TextSpan(
                      text: _isSignIn ? 'Create one' : 'Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _fieldLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: _ink,
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
// GOOGLE SIGN IN BUTTON
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
          duration: const Duration(milliseconds: 180),
          height: 46,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.06 : 0.03),
                blurRadius: _hovered ? 12 : 6,
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
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Redirecting to Google...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
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
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Official 4-color Google "G" vector painter
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

    // Blue (Right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.2, false, paint);

    // Green (Bottom arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.5, false, paint);

    // Yellow (Bottom-left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.3, false, paint);

    // Red (Top arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.6, 1.5, false, paint);

    // Blue horizontal bar
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
// LEFT CREATIVE WING (Write, Sketch, AI, Paper Stack)
// -------------------------------------------------------------
class _LeftCreativeWing extends StatelessWidget {
  final AppState state;
  const _LeftCreativeWing({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Top Handwritten note + Arrow
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _HandwrittenText('Write & Sketch'),
            const SizedBox(width: 8),
            CustomPaint(
              size: const Size(36, 28),
              painter: _CurvedArrowPainter(pointingRight: false, pointingDown: true),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Card 1: Canvas & Ink
        Transform.rotate(
          angle: -0.06,
          child: const _MiniSketchPencilCard(),
        ),
        const SizedBox(height: 22),

        // Dotted trail node: Pencil
        const Center(
          child: _DoodleNode(icon: Icons.edit_rounded, color: Color(0xFF6366F1)),
        ),
        const SizedBox(height: 22),

        // Card 2: AI Organize & Notes
        Transform.rotate(
          angle: 0.04,
          child: const _MiniAiCard(),
        ),
        const SizedBox(height: 24),

        // Dotted trail node
        const Center(
          child: _DoodleNode(icon: Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
        ),
        const SizedBox(height: 20),

        // Card 3: Stacked Paper Notes
        Transform.rotate(
          angle: -0.05,
          child: const _PaperStackCard(),
        ),
        const SizedBox(height: 12),

        // Bottom Handwritten note
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomPaint(
              size: const Size(32, 24),
              painter: _CurvedArrowPainter(pointingRight: false, pointingDown: false),
            ),
            const SizedBox(width: 6),
            _HandwrittenText('Take notes anywhere...'),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// RIGHT CREATIVE WING (Security, Cloud Sync, Multi-Device)
// -------------------------------------------------------------
class _RightCreativeWing extends StatelessWidget {
  final AppState state;
  const _RightCreativeWing({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Handwritten note + Arrow
        Row(
          children: [
            CustomPaint(
              size: const Size(36, 28),
              painter: _CurvedArrowPainter(pointingRight: true, pointingDown: true),
            ),
            const SizedBox(width: 8),
            _HandwrittenText('End-to-end privacy'),
          ],
        ),
        const SizedBox(height: 8),

        // Card 4: Secure Privacy
        Transform.rotate(
          angle: 0.05,
          child: const _MiniSecurityCard(),
        ),
        const SizedBox(height: 22),

        // Dotted trail node: Lock
        const Center(
          child: _DoodleNode(icon: Icons.lock_outline_rounded, color: Color(0xFF6366F1)),
        ),
        const SizedBox(height: 22),

        // Card 5: Cloud Sync
        Transform.rotate(
          angle: -0.04,
          child: const _MiniCloudCard(),
        ),
        const SizedBox(height: 24),

        // Dotted trail node: Cloud
        const Center(
          child: _DoodleNode(icon: Icons.cloud_done_rounded, color: Color(0xFF3B82F6)),
        ),
        const SizedBox(height: 20),

        // Card 6: Multi-Device Sync Illustration
        const _MultiDeviceCard(),
        const SizedBox(height: 12),

        // Bottom Handwritten note
        Row(
          children: [
            _HandwrittenText('Sync across all devices ✦'),
            const SizedBox(width: 6),
            CustomPaint(
              size: const Size(32, 24),
              painter: _CurvedArrowPainter(pointingRight: true, pointingDown: false),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// FLOATING FEATURE CARDS (Human Creativity Doodles)
// -------------------------------------------------------------

class _MiniSketchPencilCard extends StatelessWidget {
  const _MiniSketchPencilCard();

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.gesture_rounded, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Draw & Ink',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(
                    'Apple Pencil / S-Pen',
                    style: GoogleFonts.inter(fontSize: 10.5, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ruled notebook preview lines with doodle stroke
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: CustomPaint(
              painter: _MiniSketchLinePainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAiCard extends StatelessWidget {
  const _MiniAiCard();

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Assist',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(
                    'Study & Summarize',
                    style: GoogleFonts.inter(fontSize: 10.5, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniTag(label: 'Math Solver', color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              _MiniTag(label: 'Summary', color: const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSecurityCard extends StatelessWidget {
  const _MiniSecurityCard();

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secure',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(
                    'Encrypted workspaces',
                    style: GoogleFonts.inter(fontSize: 10.5, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
              const SizedBox(width: 4),
              Text(
                'Zero-knowledge encryption',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCloudCard extends StatelessWidget {
  const _MiniCloudCard();

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Sync',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  Text(
                    'Real-time & Offline',
                    style: GoogleFonts.inter(fontSize: 10.5, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 6),
              Text(
                'All changes saved automatically',
                style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Multi-layered paper stack representation (Notebook Stack)
class _PaperStackCard extends StatelessWidget {
  const _PaperStackCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 140,
      child: Stack(
        children: [
          // Background layer 2 (rotated -6°)
          Positioned(
            left: 8,
            top: 10,
            right: 4,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.07,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
              ),
            ),
          ),
          // Background layer 1 (rotated -3°)
          Positioned(
            left: 4,
            top: 5,
            right: 8,
            bottom: 4,
            child: Transform.rotate(
              angle: -0.035,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Front layer
          Positioned.fill(
            child: _HoverCard(
              width: 236,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'Organized Folders',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _checklistLine('Calculus Lecture 12', true),
                  const SizedBox(height: 4),
                  _checklistLine('Physics Circuit Diagram', true),
                  const SizedBox(height: 4),
                  _checklistLine('Chemistry Formula Sheet', false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistLine(String text, bool checked) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          size: 13,
          color: checked ? _brand : _textMuted,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 11, color: checked ? _ink : _textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Multi-device illustration card (Laptop + Tablet + Phone with "N" branding)
class _MultiDeviceCard extends StatelessWidget {
  const _MultiDeviceCard();

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices_rounded, size: 16, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                'Cross-Platform',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Devices Mockup Stage
          SizedBox(
            height: 70,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Laptop (Behind, left)
                Positioned(
                  left: 0,
                  bottom: 4,
                  child: Container(
                    width: 100,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 88,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const NotelekhIcon(size: 18),
                    ),
                  ),
                ),
                // Laptop base
                Positioned(
                  left: -4,
                  bottom: 0,
                  child: Container(
                    width: 108,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Tablet with stylus (Middle, center-right)
                Positioned(
                  left: 86,
                  bottom: 4,
                  child: Container(
                    width: 60,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const NotelekhIcon(size: 20),
                  ),
                ),
                // Phone (Front-right)
                Positioned(
                  left: 140,
                  bottom: 4,
                  child: Container(
                    width: 28,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: const Color(0xFF475569), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const NotelekhIcon(size: 12),
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

// -------------------------------------------------------------
// HELPER COMPONENTS & DOODLE GRAPHICS
// -------------------------------------------------------------

class _HoverCard extends StatefulWidget {
  final Widget child;
  final double? width;
  const _HoverCard({required this.child, this.width});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width ?? 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: _hovered ? 0.12 : 0.05),
              blurRadius: _hovered ? 24 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        transform: Matrix4.diagonal3Values(_hovered ? 1.025 : 1.0, _hovered ? 1.025 : 1.0, 1.0),
        child: widget.child,
      ),
    );
  }
}

class _DoodleNode extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _DoodleNode({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _HandwrittenText extends StatelessWidget {
  final String text;
  const _HandwrittenText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Caveat',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Custom painter for mini sketch line preview in "Draw & Ink"
class _MiniSketchLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ruled lines
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(8, size.height * 0.35), Offset(size.width - 8, size.height * 0.35), linePaint);
    canvas.drawLine(Offset(8, size.height * 0.70), Offset(size.width - 8, size.height * 0.70), linePaint);

    // Sketch doodle stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(12, size.height * 0.45)
      ..cubicTo(size.width * 0.25, size.height * 0.15, size.width * 0.45, size.height * 0.85, size.width * 0.65, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.2, size.width - 16, size.height * 0.55);

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for playful curved arrows
class _CurvedArrowPainter extends CustomPainter {
  final bool pointingRight;
  final bool pointingDown;
  const _CurvedArrowPainter({required this.pointingRight, required this.pointingDown});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (!pointingRight && pointingDown) {
      // Left top arrow: starts left-top, arcs down-right
      path.moveTo(4, 4);
      path.quadraticBezierTo(size.width * 0.6, 2, size.width - 4, size.height - 4);
      // Arrowhead
      path.moveTo(size.width - 10, size.height - 8);
      path.lineTo(size.width - 4, size.height - 4);
      path.lineTo(size.width - 8, size.height - 11);
    } else if (pointingRight && pointingDown) {
      // Right top arrow: starts left-top, arcs down-right
      path.moveTo(4, size.height - 4);
      path.quadraticBezierTo(size.width * 0.4, 4, size.width - 4, 8);
      // Arrowhead
      path.moveTo(size.width - 8, 4);
      path.lineTo(size.width - 4, 8);
      path.lineTo(size.width - 9, 13);
    } else {
      // Underline style wavy arrow
      path.moveTo(4, size.height * 0.5);
      path.quadraticBezierTo(size.width * 0.5, size.height * 0.85, size.width - 4, size.height * 0.3);
      path.moveTo(size.width - 8, size.height * 0.65);
      path.lineTo(size.width - 4, size.height * 0.3);
      path.lineTo(size.width - 9, size.height * 0.2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dotted background paths connecting the creative canvas
class _DoodleTrailsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double cx = size.width / 2;
    final double leftNodeX = cx - 350;
    final double rightNodeX = cx + 350;

    // Left trail
    final leftPath = Path()
      ..moveTo(leftNodeX, 100)
      ..cubicTo(leftNodeX - 40, 220, leftNodeX + 40, 360, leftNodeX - 10, 480)
      ..cubicTo(leftNodeX - 50, 580, leftNodeX + 20, 680, leftNodeX, 760);
    _drawDashedPath(canvas, leftPath, paint, 6, 6);

    // Right trail
    final rightPath = Path()
      ..moveTo(rightNodeX, 110)
      ..cubicTo(rightNodeX + 40, 240, rightNodeX - 30, 380, rightNodeX + 15, 500)
      ..cubicTo(rightNodeX + 40, 600, rightNodeX - 25, 700, rightNodeX, 780);
    _drawDashedPath(canvas, rightPath, paint, 6, 6);

    // Tiny decorative star doodles in the empty space
    _drawStarDoodle(canvas, leftNodeX + 50, 160, const Color(0xFF94A3B8));
    _drawStarDoodle(canvas, leftNodeX - 60, 520, const Color(0xFF94A3B8));
    _drawStarDoodle(canvas, rightNodeX - 50, 180, const Color(0xFF94A3B8));
    _drawStarDoodle(canvas, rightNodeX + 60, 470, const Color(0xFF94A3B8));
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double nextDistance = math.min(distance + dashWidth, metric.length);
        final Path extract = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawStarDoodle(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), paint);
    canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), paint);
    canvas.drawLine(Offset(x - 3, y - 3), Offset(x + 3, y + 3), paint);
    canvas.drawLine(Offset(x + 3, y - 3), Offset(x - 3, y + 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// STANDARD FORM CONTROLS
// -------------------------------------------------------------

class _TabBar extends StatelessWidget {
  final bool isSignIn;
  final void Function(bool) onSwitch;
  const _TabBar({required this.isSignIn, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Tab(label: 'Sign In', selected: isSignIn, onTap: () => onSwitch(true)),
          _Tab(label: 'Create Account', selected: !isSignIn, onTap: () => onSwitch(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _ink : _textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  final String text;
  final bool isSuccess;
  const _InlineChip({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? _success : _errorColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AuthField extends StatelessWidget {
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

  const _AuthField({
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
    final borderColor = hasError ? _errorColor : isValid ? _success : _borderDefault;
    final borderWidth = (hasError || isValid) ? 1.5 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: (isValid || hasError)
            ? [
                BoxShadow(
                  color: (hasError ? _errorColor : _success).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        style: GoogleFonts.inter(fontSize: 14, color: _ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _textMuted, fontWeight: FontWeight.w400),
          prefixIcon: Icon(prefixIcon, size: 18, color: _textMuted),
          suffixIcon: suffixWidget,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          isDense: true,
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _CtaButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
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
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF4B48E0), const Color(0xFF6E4CE5)]
                  : [const Color(0xFF5C59F2), const Color(0xFF7C5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C59F2).withValues(alpha: _hovered ? 0.38 : 0.24),
                blurRadius: _hovered ? 20 : 12,
                offset: const Offset(0, 6),
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
                    const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;
  const _CheckboxRow({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? _brand : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: value ? _brand : _borderDefault, width: 1.5),
            ),
            child: value ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _AmbientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
