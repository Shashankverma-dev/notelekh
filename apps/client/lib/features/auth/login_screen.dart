import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

// -------------------------------------------------------------
// Human, Serene Palette Inspired by Goodnotes, Craft & Notion
// -------------------------------------------------------------
const _bgCanvas = Color(0xFFFAFAF9); // Warm tactile ivory paper tone
const _inkPrimary = Color(0xFF18181B); // Deep readable zinc/ink
const _inkSecondary = Color(0xFF52525B); // Balanced neutral secondary
const _inkMuted = Color(0xFFA1A1AA); // Subtle tertiary
const _borderDefault = Color(0xFFE4E4E7); // Crisp hairline border
const _brandBlue = Color(0xFF4F46E5); // Goodnotes-inspired vibrant studio blue
const _brandHover = Color(0xFF4338CA);
const _errorColor = Color(0xFFDC2626);

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
  bool _showDiagnostics = false;
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
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
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
                stackTraceSnippet: st.toString().split('\n').take(6).join('\n'),
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
                stackTraceSnippet: st.toString().split('\n').take(6).join('\n'),
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
    final isSmall = size.width < 480;

    return Scaffold(
      backgroundColor: _bgCanvas,
      body: Stack(
        children: [
          // Subtle, tactile paper grid texture (feels like authentic Goodnotes notebook paper)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TactilePaperGridPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Always visible, non-overlapping)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 16 : 28,
                    vertical: isSmall ? 12 : 18,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back to home
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.state.navigateToLanding,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderDefault),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded, size: 15, color: _inkSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Notelekh',
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

                      // Helpful reference link
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.state.navigateToLanding,
                          child: Text(
                            'Need help?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _inkSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Centered Content (Zero Cards, Balanced, Breathing room)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 16 : 24,
                        vertical: isSmall ? 14 : 32,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 390.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Brand Logo & Title
                              Center(
                          child: Column(
                            children: [
                              const NotelekhIcon(size: 44),
                              const SizedBox(height: 16),
                              Text(
                                _isSignIn ? 'Welcome back' : 'Create your account',
                                textAlign: TextAlign.center,
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
                                    ? 'Open your notebooks and pick up right where you left off.'
                                    : 'Start organizing your thoughts, sketches, and notes today.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: _inkSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Google Sign In Button (Official Standard Design)
                        _GoogleSignInButton(
                          onPressed: _continueWithGoogle,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),

                        // Minimalist Divider: "or"
                        Row(
                          children: [
                            const Expanded(child: Divider(color: _borderDefault, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'or',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: _inkMuted,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: _borderDefault, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Segmented Tab Switcher (Card-free Pill)
                        _SegmentedPill(
                          isSignIn: _isSignIn,
                          onChanged: _switchTab,
                        ),
                        const SizedBox(height: 22),

                        // Full Name (Only when creating account)
                        if (!_isSignIn) ...[
                          _fieldLabel('Name'),
                          const SizedBox(height: 6),
                          _CleanTextField(
                            controller: _nameController,
                            hintText: 'Your name',
                            prefixIcon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        _fieldLabel('Email address'),
                        const SizedBox(height: 6),
                        _CleanTextField(
                          controller: _emailController,
                          hintText: 'you@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          hasError: _emailTouched && !_emailValid,
                          onChanged: (_) {
                            if (_emailTouched) setState(() {});
                          },
                          onEditingComplete: () => setState(() => _emailTouched = true),
                        ),
                        if (_emailTouched && !_emailValid) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Please enter a valid email address',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _errorColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Password Field
                        Row(
                          children: [
                            _fieldLabel('Password'),
                            const Spacer(),
                            if (_isSignIn)
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password reset instructions sent to your email.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _brandBlue,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _CleanTextField(
                          controller: _passwordController,
                          hintText: 'At least 6 characters',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: !_passwordVisible,
                          hasError: _passwordTouched && !_passwordValid,
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
                        if (_passwordTouched && !_passwordValid) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Password must be at least 6 characters',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _errorColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Remember Me
                        if (_isSignIn)
                          _RememberMeCheckbox(
                            value: _keepSignedIn,
                            onChanged: (v) => setState(() => _keepSignedIn = v ?? true),
                          ),
                        const SizedBox(height: 22),

                        // Error message banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: _errorColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    _errorMessage ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF991B1B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Diagnostics (Preserved for dev troubleshooting)
                        if (_activeDiagnostic != null) ...[
                          _buildDiagnosticsToggle(),
                          const SizedBox(height: 16),
                        ],

                        // Confident Solid CTA Button (Goodnotes / Apple / Notion style)
                        _SolidActionButton(
                          label: _isSignIn ? 'Sign in' : 'Create account',
                          isLoading: _isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 22),

                        // Bottom Switcher
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
                                      text: _isSignIn ? "Don't have an account? " : 'Already have an account? ',
                                    ),
                                    TextSpan(
                                      text: _isSignIn ? 'Sign up' : 'Sign in',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _brandBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Humanized, subtle craft note (Like Goodnotes)
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 16, color: _inkMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'Crafted for stylus, pencil, and keyboard',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Your notes are private, encrypted, and synced across all devices.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFA1A1AA),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
);
}

  static Widget _fieldLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ),
      );

  Widget _buildDiagnosticsToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showDiagnostics = !_showDiagnostics),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_outlined, color: Color(0xFF38BDF8), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auth Diagnostics (${_activeDiagnostic!.stage})',
                      style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white),
                    ),
                  ),
                  Text(
                    _showDiagnostics ? 'Hide' : 'View',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          if (_showDiagnostics)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _activeDiagnostic!.toFormattedDetails(),
                style: GoogleFonts.firaCode(fontSize: 10, color: const Color(0xFFE4E4E7)),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// SUBTLE TACTILE PAPER GRID PAINTER
// -------------------------------------------------------------
class _TactilePaperGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF71717A).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    const step = 28.0;
    for (double x = 14; x < size.width; x += step) {
      for (double y = 14; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// GOOGLE SIGN IN BUTTON (Clean, Trusted, Apple/Goodnotes Style)
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
          duration: const Duration(milliseconds: 140),
          height: 44,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF4F4F5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? const Color(0xFFA1A1AA) : _borderDefault,
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _inkSecondary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Signing in...',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _inkSecondary,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: _GoogleVectorPainter(),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
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

class _GoogleVectorPainter extends CustomPainter {
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
// SEGMENTED PILL (Sign in / Create account)
// -------------------------------------------------------------
class _SegmentedPill extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onChanged;

  const _SegmentedPill({required this.isSignIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: _pillOption('Sign in', isSignIn, () => onChanged(true)),
          ),
          Expanded(
            child: _pillOption('Create account', !isSignIn, () => onChanged(false)),
          ),
        ],
      ),
    );
  }

  Widget _pillOption(String label, bool active, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? _inkPrimary : _inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// CLEAN MODERN TEXT FIELD (Goodnotes / Notion style)
// -------------------------------------------------------------
class _CleanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool hasError;
  final Widget? suffixWidget;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  const _CleanTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.hasError = false,
    this.suffixWidget,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? _errorColor : _borderDefault,
          width: hasError ? 1.4 : 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        style: GoogleFonts.inter(fontSize: 13.5, color: _inkPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _inkMuted, fontWeight: FontWeight.w400),
          prefixIcon: Icon(prefixIcon, size: 17, color: _inkMuted),
          suffixIcon: suffixWidget,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SOLID ACTION BUTTON (Clean, Confident, Human)
// -------------------------------------------------------------
class _SolidActionButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  const _SolidActionButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  State<_SolidActionButton> createState() => _SolidActionButtonState();
}

class _SolidActionButtonState extends State<_SolidActionButton> {
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
          duration: const Duration(milliseconds: 140),
          height: 44,
          decoration: BoxDecoration(
            color: _hovered ? _brandHover : _brandBlue,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: _hovered ? 0.24 : 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// REMEMBER ME CHECKBOX
// -------------------------------------------------------------
class _RememberMeCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _RememberMeCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? _brandBlue : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: value ? _brandBlue : _borderDefault, width: 1.5),
              ),
              child: value ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Remember me',
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
