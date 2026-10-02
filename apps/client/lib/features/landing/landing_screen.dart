import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const Color _primary = Color(0xFF5C59F2);
const Color _primaryLight = Color(0xFFEEECFF);
const Color _ink = Color(0xFF0F172A);
const Color _textBody = Color(0xFF475569);
const Color _textMuted = Color(0xFF94A3B8);
const Color _bgWarm = Color(0xFFFAFBFC);
const Color _bgWhite = Colors.white;
const Color _border = Color(0xFFF1F5F9);
const Color _borderMedium = Color(0xFFE2E8F0);

// ─── Landing Screen ──────────────────────────────────────────────────────────
class LandingScreen extends StatefulWidget {
  final AppState state;
  const LandingScreen({super.key, required this.state});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _pdfKey = GlobalKey();
  final GlobalKey _handwritingKey = GlobalKey();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _useCasesKey = GlobalKey();

  bool _mobileMenuOpen = false;
  bool _isNavigatingToApp = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _enterApp() {
    if (_isNavigatingToApp) return;
    _isNavigatingToApp = true;
    widget.state.navigateToLogin();
    // Reset guard immediately since navigation is synchronous
    _isNavigatingToApp = false;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1024;
    final isTablet = w >= 640 && w < 1024;

    return Scaffold(
      backgroundColor: _bgWarm,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Sticky frosted glass navbar
              SliverPersistentHeader(
                pinned: true,
                delegate: _NavBarDelegate(
                  isDesktop: isDesktop,
                  onAuth: _enterApp,
                  onScrollToTop: _scrollToTop,
                  onScrollToFeatures: () => _scrollToKey(_featuresKey),
                  onScrollToPdf: () => _scrollToKey(_pdfKey),
                  onScrollToHandwriting: () => _scrollToKey(_handwritingKey),
                  onScrollToAi: () => _scrollToKey(_aiKey),
                  onScrollToUseCases: () => _scrollToKey(_useCasesKey),
                  onMenuToggle: () => setState(() => _mobileMenuOpen = !_mobileMenuOpen),
                ),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: _HeroSection(isDesktop: isDesktop, isTablet: isTablet, onAuth: _enterApp),
                ),
              ),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _featuresKey,
                  child: RepaintBoundary(child: _WhyNotelekhSection(isDesktop: isDesktop)),
                ),
              ),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _pdfKey,
                  child: RepaintBoundary(
                    child: _PdfAnnotationSection(isDesktop: isDesktop, onCta: _enterApp),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _ProductExperienceSection(isDesktop: isDesktop)),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _CrossDeviceSection(isDesktop: isDesktop)),
              ),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _handwritingKey,
                  child: RepaintBoundary(child: _HandwritingSection(isDesktop: isDesktop)),
                ),
              ),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _aiKey,
                  child: RepaintBoundary(child: _AiSection(isDesktop: isDesktop, onCta: _enterApp)),
                ),
              ),
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _useCasesKey,
                  child: RepaintBoundary(child: _UseCasesSection(isDesktop: isDesktop)),
                ),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _WorkflowsSection(isDesktop: isDesktop)),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _TrustSection(isDesktop: isDesktop)),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _FinalCtaSection(isDesktop: isDesktop, onCta: _enterApp)),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _FooterSection(isDesktop: isDesktop)),
              ),
            ],
          ),
          // Mobile menu overlay
          if (_mobileMenuOpen && !isDesktop)
            _MobileMenu(
              onAuth: _enterApp,
              onClose: () => setState(() => _mobileMenuOpen = false),
              onScrollToTop: _scrollToTop,
              onScrollToFeatures: () => _scrollToKey(_featuresKey),
              onScrollToPdf: () => _scrollToKey(_pdfKey),
              onScrollToHandwriting: () => _scrollToKey(_handwritingKey),
              onScrollToAi: () => _scrollToKey(_aiKey),
              onScrollToUseCases: () => _scrollToKey(_useCasesKey),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
Widget _constrained({required Widget child, double maxWidth = 1200}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

TextStyle _headingStyle(double size) => GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: _ink,
      height: 1.1,
      letterSpacing: -0.5,
    );

TextStyle _bodyStyle({double size = 17, Color color = _textBody}) =>
    GoogleFonts.inter(fontSize: size, color: color, height: 1.6, fontWeight: FontWeight.w400);

TextStyle _eyebrowStyle() => GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: _textMuted,
    );

Widget _sectionPadding({
  required Widget child,
  required bool isDesktop,
  Color color = _bgWhite,
  double vPad = 120,
}) {
  return Container(
    width: double.infinity,
    color: color,
    padding: EdgeInsets.symmetric(
      horizontal: isDesktop ? 48 : 20,
      vertical: isDesktop ? vPad : vPad * 0.6,
    ),
    child: _constrained(child: child),
  );
}

Widget _primaryButton(String label, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: _ink,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      elevation: 0,
    ),
    child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
  );
}


Widget _checkRow(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(text, style: GoogleFonts.inter(fontSize: 15, color: _ink, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}

Widget _pill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: GoogleFonts.inter(color: _ink, fontWeight: FontWeight.w600, fontSize: 14)),
  );
}

// ─── Mobile Menu ─────────────────────────────────────────────────────────────
class _MobileMenu extends StatelessWidget {
  final VoidCallback onAuth;
  final VoidCallback onClose;
  final VoidCallback onScrollToTop;
  final VoidCallback onScrollToFeatures;
  final VoidCallback onScrollToPdf;
  final VoidCallback onScrollToHandwriting;
  final VoidCallback onScrollToAi;
  final VoidCallback onScrollToUseCases;

  const _MobileMenu({
    required this.onAuth,
    required this.onClose,
    required this.onScrollToTop,
    required this.onScrollToFeatures,
    required this.onScrollToPdf,
    required this.onScrollToHandwriting,
    required this.onScrollToAi,
    required this.onScrollToUseCases,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent tap through to dismiss backdrop
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          const _NotelekhRibbonLogo(size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'Notelekh',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 24, color: _ink),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      _menuLink('Features & Infinite Canvas', Icons.auto_awesome_mosaic_rounded, () {
                        onClose();
                        onScrollToFeatures();
                      }),
                      _menuLink('PDF Annotation', Icons.picture_as_pdf_rounded, () {
                        onClose();
                        onScrollToPdf();
                      }),
                      _menuLink('Apple Pencil & Handwriting Engine', Icons.draw_rounded, () {
                        onClose();
                        onScrollToHandwriting();
                      }),
                      _menuLink('AI Note-taking Studio', Icons.auto_awesome_rounded, () {
                        onClose();
                        onScrollToAi();
                      }),
                      _menuLink('Use Cases & Personas', Icons.people_outline_rounded, () {
                        onClose();
                        onScrollToUseCases();
                      }),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            onClose();
                            onAuth();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get started free',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ],
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
      ),
    );
  }

  Widget _menuLink(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

// ─── Interactive Nav Item ───────────────────────────────────────────────────
class _NavBarItem extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _NavBarItem({required this.title, required this.onTap});

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF1F5F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
              color: _hovered ? _primary : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── NavBar Delegate ─────────────────────────────────────────────────────────
class _NavBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isDesktop;
  final VoidCallback onAuth;
  final VoidCallback onScrollToTop;
  final VoidCallback onScrollToFeatures;
  final VoidCallback onScrollToPdf;
  final VoidCallback onScrollToHandwriting;
  final VoidCallback onScrollToAi;
  final VoidCallback onScrollToUseCases;
  final VoidCallback onMenuToggle;

  _NavBarDelegate({
    required this.isDesktop,
    required this.onAuth,
    required this.onScrollToTop,
    required this.onScrollToFeatures,
    required this.onScrollToPdf,
    required this.onScrollToHandwriting,
    required this.onScrollToAi,
    required this.onScrollToUseCases,
    required this.onMenuToggle,
  });

  @override
  double get maxExtent => 72;
  @override
  double get minExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scrolled = shrinkOffset > 8;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: scrolled
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.72),
            border: Border(
              bottom: BorderSide(
                color: scrolled ? const Color(0xFFE2E8F0) : const Color(0x0F000000),
                width: 1,
              ),
            ),
            boxShadow: scrolled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 18),
          child: _constrained(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showDesktopNav = isDesktop && constraints.maxWidth >= 840;
                return Row(
                  children: [
                    // Brand Logo + Name
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onScrollToTop,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _NotelekhRibbonLogo(size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Notelekh',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Desktop Navigation Items
                    if (showDesktopNav) ...[
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _NavBarItem(title: 'Features', onTap: onScrollToFeatures),
                                const SizedBox(width: 2),
                                _NavBarItem(title: 'PDF Annotation', onTap: onScrollToPdf),
                                const SizedBox(width: 2),
                                _NavBarItem(title: 'Handwriting', onTap: onScrollToHandwriting),
                                const SizedBox(width: 2),
                                _NavBarItem(title: 'AI Studio', onTap: onScrollToAi),
                                const SizedBox(width: 2),
                                _NavBarItem(title: 'Use Cases', onTap: onScrollToUseCases),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Primary CTA Button
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onAuth,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Get started free',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      // Tablet & Mobile: compact "Sign in" + Hamburger
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: onAuth,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _ink,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Sign in',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: _ink, size: 28),
                        onPressed: onMenuToggle,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NavBarDelegate oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGO: NOTELEKH FOLDED RIBBON 'N'
// ═══════════════════════════════════════════════════════════════════════════════
class _NotelekhRibbonLogo extends StatelessWidget {
  final double size;
  const _NotelekhRibbonLogo({this.size = 26});

  @override
  Widget build(BuildContext context) {
    return NotelekhIcon(size: size);
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// SECTION: HERO (PIXEL-PERFECT MATCH TO REFERENCE)
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final VoidCallback onAuth;
  const _HeroSection({required this.isDesktop, required this.isTablet, required this.onAuth});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _bgWarm,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 56 : 20,
        vertical: isDesktop ? 50 : 36,
      ),
      child: _constrained(
        maxWidth: 1260,
        child: Column(
          children: [
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _heroText()),
                      const SizedBox(width: 32),
                      Expanded(flex: 6, child: _mockupColumn(isDesktop: true)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroText(),
                      const SizedBox(height: 48),
                      Center(child: _mockupColumn(isDesktop: false)),
                    ],
                  ),
            // Bottom Platform Sync Bar
            _platformSyncBar(),
          ],
        ),
      ),
    );
  }

  Widget _heroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Headline: Your thoughts. / In flow.
        Text(
          'Your thoughts.',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 68 : 46,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            height: 1.06,
            letterSpacing: -1.0,
          ),
        ),
        Text(
          'In flow.',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 68 : 46,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4F46E5),
            height: 1.06,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 20),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Write, sketch, plan, annotate and organize everything in one beautiful workspace.',
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 18 : 16,
              color: const Color(0xFF475569),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // CTA Buttons
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: onAuth,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Get started free',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        // Trust row (Overlapping Avatars + text)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 104,
              height: 36,
              child: Stack(
                children: const [
                  Positioned(left: 0, child: _RealisticAvatar(index: 0)),
                  Positioned(left: 22, child: _RealisticAvatar(index: 1)),
                  Positioned(left: 44, child: _RealisticAvatar(index: 2)),
                  Positioned(left: 66, child: _RealisticAvatar(index: 3)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF475569), height: 1.4),
                  children: [
                    const TextSpan(text: 'Trusted by '),
                    TextSpan(
                      text: '100,000+ ',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const TextSpan(text: 'students,\ncreators and professionals.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Handwritten annotation (Bottom-left): Ideas today. A better tomorrow.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ideas today.',
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                    height: 1.1,
                  ),
                ),
                Text(
                  'A better tomorrow.',
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 50,
              height: 40,
              child: CustomPaint(painter: _BottomLeftCurvedArrowPainter()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mockupColumn({required bool isDesktop}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Soft ambient blue/indigo radial glow (GPU accelerated)
        Positioned(
          top: 30,
          left: 40,
          right: 40,
          bottom: 30,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.12),
                  const Color(0xFF38BDF8).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tablet Mockup
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 620,
                height: 420,
                child: const RepaintBoundary(child: _TabletMockup()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _platformSyncBar() {
    if (!isDesktop) {
      return Container(
        margin: const EdgeInsets.only(top: 36),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
        ),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                _platformItem(const _IpadVectorIcon(), 'iPad'),
                _platformItem(const _MacVectorIcon(), 'Mac'),
                _platformItem(const _WindowsVectorIcon(), 'Windows'),
                _platformItem(const _AndroidVectorIcon(), 'Android'),
                _platformItem(const _WebVectorIcon(), 'Web'),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 24, height: 1, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 12),
                Text(
                  'Sync everywhere · Always with you',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 24, height: 1, color: const Color(0xFFCBD5E1)),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.only(top: 32),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _platformItem(const _IpadVectorIcon(), 'iPad'),
            const SizedBox(width: 38),
            _platformItem(const _MacVectorIcon(), 'Mac'),
            const SizedBox(width: 38),
            _platformItem(const _WindowsVectorIcon(), 'Windows'),
            const SizedBox(width: 38),
            _platformItem(const _AndroidVectorIcon(), 'Android'),
            const SizedBox(width: 38),
            _platformItem(const _WebVectorIcon(), 'Web'),
            const SizedBox(width: 42),
            Container(width: 1, height: 34, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 42),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sync everywhere.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Always with you.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformItem(Widget iconWidget, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Center(child: iconWidget),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

// ─── Crisp Vector Platform Icons ─────────────────────────────────────────────
const Color _platformIconColor = Color(0xFF0F172A);

class _IpadVectorIcon extends StatelessWidget {
  const _IpadVectorIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(19, 23),
      painter: _IpadIconPainter(),
    );
  }
}

class _IpadIconPainter extends CustomPainter {
  const _IpadIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = _platformIconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(rrect, strokePaint);

    // Camera dot
    canvas.drawCircle(Offset(size.width / 2, 3.5), 0.7, Paint()..color = _platformIconColor);

    // Home bar
    canvas.drawLine(
      Offset(size.width * 0.32, size.height - 3.2),
      Offset(size.width * 0.68, size.height - 3.2),
      Paint()
        ..color = _platformIconColor
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MacVectorIcon extends StatelessWidget {
  const _MacVectorIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(23, 19),
      painter: _MacIconPainter(),
    );
  }
}

class _MacIconPainter extends CustomPainter {
  const _MacIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = _platformIconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(3.2, 1.5, size.width - 6.4, size.height - 6.5),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(screen, strokePaint);

    // Base
    canvas.drawLine(
      Offset(1, size.height - 2.5),
      Offset(size.width - 1, size.height - 2.5),
      Paint()
        ..color = _platformIconColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Notch
    canvas.drawLine(
      Offset(size.width / 2 - 2.5, size.height - 1.5),
      Offset(size.width / 2 + 2.5, size.height - 1.5),
      Paint()
        ..color = _platformIconColor
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WindowsVectorIcon extends StatelessWidget {
  const _WindowsVectorIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(19, 19),
      painter: _WindowsIconPainter(),
    );
  }
}

class _WindowsIconPainter extends CustomPainter {
  const _WindowsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = _platformIconColor;
    const double gap = 2.4;
    final double boxW = (size.width - gap) / 2;
    final double boxH = (size.height - gap) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, boxW, boxH), const Radius.circular(1.2)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boxW + gap, 0, boxW, boxH), const Radius.circular(1.2)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, boxH + gap, boxW, boxH), const Radius.circular(1.2)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boxW + gap, boxH + gap, boxW, boxH), const Radius.circular(1.2)),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AndroidVectorIcon extends StatelessWidget {
  const _AndroidVectorIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(22, 19),
      painter: _AndroidIconPainter(),
    );
  }
}

class _AndroidIconPainter extends CustomPainter {
  const _AndroidIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = _platformIconColor;
    final strokePaint = Paint()
      ..color = _platformIconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final domeRect = Rect.fromLTWH(2.5, 5, 17, 14);
    canvas.drawArc(domeRect, math.pi, math.pi, true, fillPaint);

    // Antennae
    canvas.drawLine(const Offset(6.5, 5.5), const Offset(4.0, 1.5), strokePaint);
    canvas.drawLine(const Offset(15.5, 5.5), const Offset(18.0, 1.5), strokePaint);

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(7.5, 9.5), 1.2, eyePaint);
    canvas.drawCircle(const Offset(14.5, 9.5), 1.2, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _WebVectorIcon extends StatelessWidget {
  const _WebVectorIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(20, 20),
      painter: _GlobeIconPainter(),
    );
  }
}

class _GlobeIconPainter extends CustomPainter {
  const _GlobeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _platformIconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.0;

    canvas.drawCircle(center, radius, stroke);

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      stroke,
    );

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.05, height: radius * 2),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





// ═══════════════════════════════════════════════════════════════════════════════
// REALISTIC TABLET MOCKUP (IPAD STYLE WITH SCREEN CONTENT & STICKY NOTE)
// ═══════════════════════════════════════════════════════════════════════════════
class _TabletMockup extends StatelessWidget {
  const _TabletMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Bezel top with camera dot
          Container(
            height: 8,
            alignment: Alignment.center,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Tablet Screen
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // Top App Bar inside tablet
                    _tabletTopBar(),
                    // Main area: Left Sidebar + Canvas
                    Expanded(
                      child: Row(
                        children: [
                          // Left sidebar
                          _tabletSidebar(),
                          // Canvas with checklist, mountains & sticky note
                          Expanded(
                            child: _tabletCanvas(),
                          ),
                        ],
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

  Widget _tabletTopBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          const _NotelekhRibbonLogo(size: 14),
          const SizedBox(width: 5),
          Text(
            'Notelekh',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          // Tools
          _toolIcon(Icons.undo_rounded),
          _toolIcon(Icons.redo_rounded),
          _toolIcon(Icons.edit_outlined, isSelected: true),
          _toolIcon(Icons.brush_outlined),
          _toolIcon(Icons.crop_portrait_rounded),
          _toolIcon(Icons.gesture_rounded),
          _toolIcon(Icons.title_rounded),
          _toolIcon(Icons.image_outlined),
          const SizedBox(width: 6),
          // Color palette dots
          _colorDot(const Color(0xFF1E293B)),
          _colorDot(const Color(0xFF1E3A8A)),
          _colorDot(const Color(0xFF0D9488)),
          _colorDot(const Color(0xFF7C3AED), hasRing: true),
          _colorDot(const Color(0xFFEC4899)),
          const SizedBox(width: 6),
          _toolIcon(Icons.more_horiz_rounded),
          const Spacer(),
          // Share button pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.share_outlined, size: 11, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Share',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Profile avatar
          const SizedBox(
            width: 22,
            height: 22,
            child: _RealisticAvatar(index: 3),
          ),
        ],
      ),
    );
  }

  Widget _toolIcon(IconData icon, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        icon,
        size: 14,
        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
      ),
    );
  }

  Widget _colorDot(Color color, {bool hasRing = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: hasRing ? Border.all(color: const Color(0xFF4F46E5), width: 1.5) : null,
        ),
      ),
    );
  }

  Widget _tabletSidebar() {
    return Container(
      width: 118,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All Notes (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 12, color: Color(0xFF3B82F6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'All Notes',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B82F6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _sidebarItem(Icons.star_border_rounded, 'Starred'),
          _sidebarItem(Icons.people_outline_rounded, 'Shared'),
          _sidebarItem(Icons.delete_outline_rounded, 'Trash'),
          const SizedBox(height: 10),
          // Folders header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Folders',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.add_rounded, size: 13, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 6),
          _sidebarItem(Icons.folder_outlined, 'Class Notes'),
          _sidebarItem(Icons.folder_outlined, 'Personal'),
          _sidebarItem(Icons.folder_outlined, 'Projects'),
          _sidebarItem(Icons.folder_outlined, 'Ideas'),
          _sidebarItem(Icons.folder_outlined, 'Archive'),
          const Spacer(),
          // New folder button
          Row(
            children: [
              const Icon(Icons.add_rounded, size: 13, color: Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'New Folder',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabletCanvas() {
    return Stack(
      children: [
        // Main canvas content
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Small Steps Big Progress & Checklists
              Expanded(
                flex: 6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Small Steps',
                        style: GoogleFonts.caveat(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          height: 1.0,
                        ),
                      ),
                      Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          Positioned(
                            bottom: 2,
                            left: 0,
                            right: 14,
                            height: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Text(
                            'Big Progress',
                            style: GoogleFonts.caveat(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4F46E5),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _canvasCheckItem('Plan the day', isDone: true),
                      _canvasCheckItem('Study with focus', isDone: true),
                      _canvasCheckItem('Make it simple', isDone: true),
                      _canvasCheckItem('Stay consistent', isDone: false),
                    ],
                  ),
                ),
              ),
              // Right Column: Mountains illustration with sun & "A brighter you ♡"
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 170,
                        height: 170,
                        child: CustomPaint(painter: _MountainSketchPainter()),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A brighter you ♡',
                        style: GoogleFonts.caveat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Post-it Sticky Note pinned at bottom-right
        Positioned(
          bottom: 12,
          right: 12,
          child: Transform.rotate(
            angle: 0.04,
            child: Container(
              width: 116,
              height: 104,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discipline\ntoday\nSuccess\ntomorrow.',
                      style: GoogleFonts.caveat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B21A8),
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _canvasCheckItem(String label, {required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF3B82F6) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDone ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.caveat(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDone ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOUNTAIN LANDSCAPE SKETCH PAINTER (HAND-DRAWN VECTOR ART)
// ═══════════════════════════════════════════════════════════════════════════════
class _MountainSketchPainter extends CustomPainter {
  const _MountainSketchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final faintPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final sunFill = Paint()..color = const Color(0xFFFDE68A)..style = PaintingStyle.fill;
    final sunStroke = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // 1. Sun with radiating rays
    final sunCenter = Offset(size.width * 0.72, size.height * 0.22);
    const sunR = 12.0;
    canvas.drawCircle(sunCenter, sunR, sunFill);
    canvas.drawCircle(sunCenter, sunR, sunStroke);

    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4.0);
      final r1 = sunR + 3;
      final r2 = sunR + 8;
      canvas.drawLine(
        Offset(sunCenter.dx + r1 * math.cos(angle), sunCenter.dy + r1 * math.sin(angle)),
        Offset(sunCenter.dx + r2 * math.cos(angle), sunCenter.dy + r2 * math.sin(angle)),
        sunStroke,
      );
    }

    // 2. Tall Main Mountain Peak
    final pMain = Path();
    pMain.moveTo(size.width * 0.08, size.height * 0.82);
    pMain.lineTo(size.width * 0.44, size.height * 0.36); // summit
    pMain.lineTo(size.width * 0.70, size.height * 0.78);
    canvas.drawPath(pMain, inkPaint);

    // Ridge line for main peak
    final ridgeMain = Path();
    ridgeMain.moveTo(size.width * 0.44, size.height * 0.36);
    ridgeMain.quadraticBezierTo(
      size.width * 0.42,
      size.height * 0.58,
      size.width * 0.38,
      size.height * 0.82,
    );
    canvas.drawPath(ridgeMain, inkPaint);

    // Hatching lines on main peak
    for (double y = 0.44; y < 0.78; y += 0.05) {
      final startX = size.width * (0.42 + (y - 0.44) * 0.12);
      final endX = size.width * (0.47 + (y - 0.44) * 0.22);
      canvas.drawLine(
        Offset(startX, size.height * y),
        Offset(endX, size.height * (y + 0.02)),
        faintPaint,
      );
    }

    // 3. Secondary Peak (Right)
    final pSecond = Path();
    pSecond.moveTo(size.width * 0.50, size.height * 0.65);
    pSecond.lineTo(size.width * 0.66, size.height * 0.46); // summit
    pSecond.lineTo(size.width * 0.94, size.height * 0.80);
    canvas.drawPath(pSecond, inkPaint);

    final ridgeSecond = Path();
    ridgeSecond.moveTo(size.width * 0.66, size.height * 0.46);
    ridgeSecond.quadraticBezierTo(
      size.width * 0.70,
      size.height * 0.62,
      size.width * 0.74,
      size.height * 0.80,
    );
    canvas.drawPath(ridgeSecond, inkPaint);

    // Hatching on secondary peak
    for (double y = 0.52; y < 0.76; y += 0.05) {
      final startX = size.width * (0.68 + (y - 0.52) * 0.14);
      final endX = size.width * (0.74 + (y - 0.52) * 0.20);
      canvas.drawLine(
        Offset(startX, size.height * y),
        Offset(endX, size.height * (y + 0.02)),
        faintPaint,
      );
    }

    // 4. Pine Trees along base
    _drawPineTree(canvas, Offset(size.width * 0.18, size.height * 0.74), 16);
    _drawPineTree(canvas, Offset(size.width * 0.25, size.height * 0.76), 20);
    _drawPineTree(canvas, Offset(size.width * 0.32, size.height * 0.78), 15);
    _drawPineTree(canvas, Offset(size.width * 0.80, size.height * 0.74), 20);
    _drawPineTree(canvas, Offset(size.width * 0.86, size.height * 0.76), 16);

    // 5. Calm lake water ripple lines
    final waterY = size.height * 0.86;
    canvas.drawLine(Offset(size.width * 0.10, waterY), Offset(size.width * 0.45, waterY), faintPaint);
    canvas.drawLine(Offset(size.width * 0.50, waterY + 3), Offset(size.width * 0.90, waterY + 3), faintPaint);
    canvas.drawLine(Offset(size.width * 0.22, waterY + 6), Offset(size.width * 0.72, waterY + 6), faintPaint);
  }

  void _drawPineTree(Canvas canvas, Offset base, double height) {
    final p = Path();
    p.moveTo(base.dx, base.dy - height);
    p.lineTo(base.dx + height * 0.32, base.dy);
    p.lineTo(base.dx - height * 0.32, base.dy);
    p.close();
    final fill = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;
    canvas.drawPath(p, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HANDWRITTEN CURVED ARROW PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════
class _BottomLeftCurvedArrowPainter extends CustomPainter {
  const _BottomLeftCurvedArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.80);
    path.cubicTo(
      size.width * 0.40,
      size.height * 0.95,
      size.width * 0.75,
      size.height * 0.85,
      size.width * 0.88,
      size.height * 0.20,
    );
    canvas.drawPath(path, paint);

    // Arrowhead pointing up-right
    final head = Path();
    head.moveTo(size.width * 0.72, size.height * 0.32);
    head.lineTo(size.width * 0.88, size.height * 0.20);
    head.lineTo(size.width * 0.92, size.height * 0.42);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ═══════════════════════════════════════════════════════════════════════════════
// REALISTIC SOCIAL PROOF AVATARS (FRIENDLY VECTOR PORTRAITS)
// ═══════════════════════════════════════════════════════════════════════════════
class _RealisticAvatar extends StatelessWidget {
  final int index;
  const _RealisticAvatar({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: const Size(36, 36),
          painter: _AvatarPainter(index: index),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final int index;
  const _AvatarPainter({required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaints = [
      const Color(0xFFE0E7FF),
      const Color(0xFFCCFBF1),
      const Color(0xFFDBEAFE),
      const Color(0xFFFCE7F3),
    ];
    final shirtPaints = [
      const Color(0xFF1E293B),
      const Color(0xFF0F766E),
      const Color(0xFF1D4ED8),
      const Color(0xFF881337),
    ];
    final skinTones = [
      const Color(0xFFD97706),
      const Color(0xFFB45309),
      const Color(0xFFFBBF24),
      const Color(0xFFD97706),
    ];

    final bg = Paint()..color = bgPaints[index % bgPaints.length];
    canvas.drawRect(Offset.zero & size, bg);

    // Body / Shirt
    final shirt = Paint()..color = shirtPaints[index % shirtPaints.length];
    final bodyPath = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.65, size.width * 0.5, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.65, size.width, size.height)
      ..close();
    canvas.drawPath(bodyPath, shirt);

    // Head / Face
    final face = Paint()..color = skinTones[index % skinTones.length].withValues(alpha: 0.6);
    final faceCenter = Offset(size.width * 0.5, size.height * 0.42);
    canvas.drawOval(
      Rect.fromCenter(center: faceCenter, width: size.width * 0.46, height: size.height * 0.52),
      face,
    );

    // Hair
    final hair = Paint()..color = const Color(0xFF1E293B);
    final hairPath = Path();
    if (index == 3) {
      // Long hair
      hairPath.moveTo(size.width * 0.22, size.height * 0.70);
      hairPath.quadraticBezierTo(size.width * 0.24, size.height * 0.16, size.width * 0.5, size.height * 0.16);
      hairPath.quadraticBezierTo(size.width * 0.76, size.height * 0.16, size.width * 0.78, size.height * 0.70);
      hairPath.quadraticBezierTo(size.width * 0.5, size.height * 0.32, size.width * 0.22, size.height * 0.70);
    } else {
      // Short hair
      hairPath.addArc(
        Rect.fromCenter(center: Offset(faceCenter.dx, faceCenter.dy - 3), width: size.width * 0.48, height: size.height * 0.48),
        math.pi,
        math.pi,
      );
    }
    canvas.drawPath(hairPath, hair);

    // Friendly smile
    final smile = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(size.width * 0.42, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.57, size.width * 0.58, size.height * 0.52);
    canvas.drawPath(smilePath, smile);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 1: WHY NOTELEKH
// ═══════════════════════════════════════════════════════════════════════════════
class _WhyNotelekhSection extends StatelessWidget {
  final bool isDesktop;
  const _WhyNotelekhSection({required this.isDesktop});

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFE2E8F0),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const col1 = _StudioInstrumentColumn(
      number: '01',
      tag: 'Inking Engine',
      title: 'Write naturally',
      desc: 'Smooth, ultra-low latency inking with authentic pressure dynamics. Calibrated to feel identical to 0.38mm ink on cotton paper.',
      tactileDetail: 'sub-8ms input latency on stylus',
      actionText: 'Explore inking engine',
      accentColor: Color(0xFF4F46E5),
      iconWidget: _FeatPenIcon(color: Color(0xFF4F46E5)),
    );

    const col2 = _StudioInstrumentColumn(
      number: '02',
      tag: 'PDF & Canvas',
      title: 'Annotate anything',
      desc: 'Drop slide decks, research papers, and textbooks onto infinite margins. Scribble notes and equations directly beside citations.',
      tactileDetail: 'infinite margin expansion',
      actionText: 'Discover markup canvas',
      accentColor: Color(0xFFE11D48),
      iconWidget: _FeatPdfIcon(color: Color(0xFFE11D48)),
    );

    const col3 = _StudioInstrumentColumn(
      number: '03',
      tag: 'Deep Search',
      title: 'Find every idea',
      desc: 'Search your handwriting, typed thoughts, and text inside embedded PDFs. On-device neural indexing recalls concepts instantly.',
      tactileDetail: 'indexes cursive and rough sketches',
      actionText: 'Experience smart search',
      accentColor: Color(0xFFD97706),
      iconWidget: _FeatSearchIcon(color: Color(0xFFD97706)),
    );

    const col4 = _StudioInstrumentColumn(
      number: '04',
      tag: 'Instant Sync',
      title: 'Work anywhere',
      desc: 'Local-first architecture keeps your notes instantly accessible offline. Automatic CRDT merging ensures zero conflict loss.',
      tactileDetail: 'offline-first, zero cloud lag',
      actionText: 'See sync architecture',
      accentColor: Color(0xFF0284C7),
      iconWidget: _FeatCloudSyncIcon(color: Color(0xFF0284C7)),
    );

    return _sectionPadding(
      isDesktop: isDesktop,
      color: _bgWhite,
      child: Column(
        children: [
          Text('WHY NOTELEKH', style: _eyebrowStyle()),
          const SizedBox(height: 16),
          Text(
            'Everything you need to think clearly',
            textAlign: TextAlign.center,
            style: _headingStyle(isDesktop ? 44 : 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Powerful, humanized instruments crafted for the way you learn, write and explore.',
            textAlign: TextAlign.center,
            style: _bodyStyle(size: 17),
          ),
          const SizedBox(height: 64),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: col1),
                    _verticalDivider(),
                    const Expanded(child: col2),
                    _verticalDivider(),
                    const Expanded(child: col3),
                    _verticalDivider(),
                    const Expanded(child: col4),
                  ],
                )
              : Wrap(
                  spacing: 28,
                  runSpacing: 44,
                  alignment: WrapAlignment.center,
                  children: const [
                    SizedBox(width: 320, child: col1),
                    SizedBox(width: 320, child: col2),
                    SizedBox(width: 320, child: col3),
                    SizedBox(width: 320, child: col4),
                  ],
                ),
        ],
      ),
    );
  }
}

class _StudioInstrumentColumn extends StatefulWidget {
  final String number;
  final String tag;
  final String title;
  final String desc;
  final String tactileDetail;
  final String actionText;
  final Color accentColor;
  final Widget iconWidget;

  const _StudioInstrumentColumn({
    required this.number,
    required this.tag,
    required this.title,
    required this.desc,
    required this.tactileDetail,
    required this.actionText,
    required this.accentColor,
    required this.iconWidget,
  });

  @override
  State<_StudioInstrumentColumn> createState() => _StudioInstrumentColumnState();
}

class _StudioInstrumentColumnState extends State<_StudioInstrumentColumn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Metadata Row: Index + Tag Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '// ${widget.number}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                widget.tag.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.accentColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Circular Floating Instrument Lens (Not a box card!)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.accentColor.withValues(alpha: _hovered ? 0.12 : 0.06),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: _hovered ? 0.35 : 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: _hovered ? 0.20 : 0.0),
                  blurRadius: _hovered ? 24 : 0,
                  spreadRadius: _hovered ? 2 : 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: widget.iconWidget,
          ),
          const SizedBox(height: 22),
          // Title
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          // Description
          Text(
            widget.desc,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.62,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          // Tactile Humanized Detail (Handwritten annotation)
          Row(
            children: [
              Text(
                '✦ ',
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  widget.tactileDetail,
                  style: GoogleFonts.caveat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Interactive Action Link with Expanding Underline
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.actionText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(_hovered ? 4 : 0, 0, 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: widget.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: 1.5,
                width: _hovered ? 120 : 0,
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VECTOR ICONS FOR FEATURE CARDS (Immune to Web tree-shaking)
// ─────────────────────────────────────────────────────────────────────────────

class _FeatPenIcon extends StatelessWidget {
  final Color color;
  const _FeatPenIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _FeatPenPainter(color: color),
    );
  }
}

class _FeatPenPainter extends CustomPainter {
  final Color color;
  const _FeatPenPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Stylus pen body
    final path = Path()
      ..moveTo(size.width * 0.70, size.height * 0.12)
      ..lineTo(size.width * 0.88, size.height * 0.30)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.16, size.height * 0.84)
      ..lineTo(size.width * 0.22, size.height * 0.60)
      ..close();
    canvas.drawPath(path, stroke);

    // Tip dot
    canvas.drawCircle(Offset(size.width * 0.16, size.height * 0.84), 1.2, fill);

    // Ink flourish curve
    final swish = Path()
      ..moveTo(size.width * 0.28, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.58, size.height * 0.98,
        size.width * 0.86, size.height * 0.88,
      );
    canvas.drawPath(swish, stroke..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _FeatPenPainter oldDelegate) => oldDelegate.color != color;
}

class _FeatPdfIcon extends StatelessWidget {
  final Color color;
  const _FeatPdfIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _FeatPdfPainter(color: color),
    );
  }
}

class _FeatPdfPainter extends CustomPainter {
  final Color color;
  const _FeatPdfPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Document page with folded corner
    final doc = Path()
      ..moveTo(size.width * 0.22, size.height * 0.10)
      ..lineTo(size.width * 0.58, size.height * 0.10)
      ..lineTo(size.width * 0.80, size.height * 0.32)
      ..lineTo(size.width * 0.80, size.height * 0.90)
      ..lineTo(size.width * 0.22, size.height * 0.90)
      ..close();
    canvas.drawPath(doc, stroke);

    // Corner fold
    final fold = Path()
      ..moveTo(size.width * 0.58, size.height * 0.10)
      ..lineTo(size.width * 0.58, size.height * 0.32)
      ..lineTo(size.width * 0.80, size.height * 0.32);
    canvas.drawPath(fold, stroke);

    // Annotation highlight pill
    final highlight = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.32, size.height * 0.44, size.width * 0.38, 4.0),
        const Radius.circular(2),
      ),
      highlight,
    );

    // Document lines
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.58),
      Offset(size.width * 0.68, size.height * 0.58),
      stroke..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.72),
      Offset(size.width * 0.54, size.height * 0.72),
      stroke..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _FeatPdfPainter oldDelegate) => oldDelegate.color != color;
}

class _FeatSearchIcon extends StatelessWidget {
  final Color color;
  const _FeatSearchIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _FeatSearchPainter(color: color),
    );
  }
}

class _FeatSearchPainter extends CustomPainter {
  final Color color;
  const _FeatSearchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;

    // Lens circle
    const center = Offset(9.5, 9.5);
    const radius = 6.0;
    canvas.drawCircle(center, radius, stroke);

    // Lens handle
    canvas.drawLine(const Offset(14.0, 14.0), const Offset(19.5, 19.5), stroke..strokeWidth = 2.2);

    // Sparkle diamond inside lens
    final spark = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final sparkPath = Path()
      ..moveTo(9.5, 7.0)
      ..lineTo(10.2, 8.8)
      ..lineTo(12.0, 9.5)
      ..lineTo(10.2, 10.2)
      ..lineTo(9.5, 12.0)
      ..lineTo(8.8, 10.2)
      ..lineTo(7.0, 9.5)
      ..lineTo(8.8, 8.8)
      ..close();
    canvas.drawPath(sparkPath, spark);
  }

  @override
  bool shouldRepaint(covariant _FeatSearchPainter oldDelegate) => oldDelegate.color != color;
}

class _FeatCloudSyncIcon extends StatelessWidget {
  final Color color;
  const _FeatCloudSyncIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _FeatCloudSyncPainter(color: color),
    );
  }
}

class _FeatCloudSyncPainter extends CustomPainter {
  final Color color;
  const _FeatCloudSyncPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Cloud outline
    final cloud = Path()
      ..moveTo(5.5, 15.5)
      ..lineTo(16.5, 15.5)
      ..arcToPoint(const Offset(17.5, 11.5), radius: const Radius.circular(4.0), clockwise: false)
      ..arcToPoint(const Offset(13.5, 7.0), radius: const Radius.circular(4.5), clockwise: false)
      ..arcToPoint(const Offset(8.0, 9.0), radius: const Radius.circular(4.0), clockwise: false)
      ..arcToPoint(const Offset(5.5, 15.5), radius: const Radius.circular(3.5), clockwise: false)
      ..close();
    canvas.drawPath(cloud, stroke);

    // Sync arrows inside cloud
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: const Offset(11.0, 12.0), radius: 3.0);
    // Upper arrow
    canvas.drawArc(arcRect, -math.pi * 0.75, math.pi * 0.65, false, arrowPaint);
    canvas.drawLine(const Offset(13.2, 10.6), const Offset(13.2, 9.2), arrowPaint);
    canvas.drawLine(const Offset(13.2, 10.6), const Offset(11.8, 10.6), arrowPaint);

    // Lower arrow
    canvas.drawArc(arcRect, math.pi * 0.25, math.pi * 0.65, false, arrowPaint);
    canvas.drawLine(const Offset(8.8, 13.4), const Offset(8.8, 14.8), arrowPaint);
    canvas.drawLine(const Offset(8.8, 13.4), const Offset(10.2, 13.4), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _FeatCloudSyncPainter oldDelegate) => oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2: PRODUCT EXPERIENCE
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductExperienceSection extends StatelessWidget {
  final bool isDesktop;
  const _ProductExperienceSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return _sectionPadding(
      isDesktop: isDesktop,
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Text('PRODUCT', style: _eyebrowStyle()),
          const SizedBox(height: 16),
          Text('Made for the way you think.',
              textAlign: TextAlign.center, style: _headingStyle(isDesktop ? 44 : 32)),
          const SizedBox(height: 16),
          Text(
            'Write, sketch, type, organize and explore ideas without changing\nthe way you naturally work.',
            textAlign: TextAlign.center,
            style: _bodyStyle(size: 17),
          ),
          const SizedBox(height: 56),
          // Large workspace mockup
          Container(
            width: double.infinity,
            height: isDesktop ? 500 : 300,
            decoration: BoxDecoration(
              color: _bgWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderMedium),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 12))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Row(
                children: [
                  // Sidebar
                  Container(
                    width: isDesktop ? 200 : 100,
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.all(isDesktop ? 20 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, color: _primary, size: 18),
                            if (isDesktop) ...[
                              const SizedBox(width: 8),
                              Text('Notelekh', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        _sidebarItem(Icons.description_outlined, 'All Notes', true, isDesktop),
                        _sidebarItem(Icons.star_border_rounded, 'Starred', false, isDesktop),
                        _sidebarItem(Icons.folder_outlined, 'Projects', false, isDesktop),
                        _sidebarItem(Icons.delete_outline_rounded, 'Trash', false, isDesktop),
                        const Spacer(),
                        _sidebarItem(Icons.auto_awesome_rounded, 'AI Assistant', false, isDesktop),
                      ],
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isDesktop ? 32 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toolbar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                for (final icon in [Icons.edit, Icons.brush, Icons.highlight, Icons.text_fields, Icons.undo, Icons.redo])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(icon, size: 18, color: _textMuted),
                                  ),
                                const Spacer(),
                                const Icon(Icons.share_rounded, size: 18, color: _textMuted),
                              ],
                            ),
                          ),
                          SizedBox(height: isDesktop ? 28 : 14),
                          Text('Lecture Notes — Biology 201', style: GoogleFonts.playfairDisplay(fontSize: isDesktop ? 24 : 16, fontWeight: FontWeight.w700, color: _ink)),
                          const SizedBox(height: 16),
                          // Fake content lines
                          Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFFEF08A), borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 8),
                          Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 6),
                          Container(height: 12, width: isDesktop ? 400 : 200, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 20),
                          if (isDesktop)
                            Text('Photosynthesis converts light energy\ninto chemical energy', style: GoogleFonts.caveat(fontSize: 24, color: _ink)),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, size: 14, color: _primary),
                                    const SizedBox(width: 6),
                                    Text('AI Summary', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.search_rounded, size: 18, color: _textMuted),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, bool active, bool showLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: active ? _primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: active ? _primary : _textMuted),
          if (showLabel) ...[
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: active ? _primary : _textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.w500), overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 2: PDF ANNOTATION (EXACT MATCH TO REFERENCE)
// ═══════════════════════════════════════════════════════════════════════════════
class _PdfAnnotationSection extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onCta;
  const _PdfAnnotationSection({required this.isDesktop, required this.onCta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 56 : 20,
        vertical: isDesktop ? 80 : 48,
      ),
      child: _constrained(
        maxWidth: 1260,
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: _leftContent()),
                  const SizedBox(width: 48),
                  Expanded(flex: 6, child: _mockupColumn(isDesktop: true)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leftContent(),
                  const SizedBox(height: 48),
                  Center(child: _mockupColumn(isDesktop: false)),
                ],
              ),
      ),
    );
  }

  Widget _leftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading (H2): Go beyond note-taking. / Make it truly yours.
        Text(
          'Go beyond note-taking.',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 48 : 34,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Make it truly yours.',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 48 : 34,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4F46E5),
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(
            'Highlight, write, draw, and add comments to any PDF or document. Keep all your study materials, ideas and inspiration in one place.',
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 17 : 15.5,
              color: const Color(0xFF475569),
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Feature items list
        _featureItem(Icons.edit_outlined, 'Smooth PDF annotation'),
        _featureItem(Icons.chat_bubble_outline_rounded, 'Add comments & bookmarks'),
        _featureItem(Icons.folder_outlined, 'Organize with custom folders'),
        _featureItem(Icons.auto_awesome_rounded, 'A cleaner, smarter study experience'),
        const SizedBox(height: 20),
        // CTA link
        InkWell(
          onTap: onCta,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore all features',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF4F46E5), size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 19),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mockupColumn({required bool isDesktop}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Soft ambient blue glow behind tablet
        Positioned(
          top: 30,
          left: 40,
          right: 40,
          bottom: 30,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.12),
                  const Color(0xFF38BDF8).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row with top-right annotation: Better Notes Brighter Tomorrow ♡
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Better\nNotes\nBrighter\nTomorrow.\n♡',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.caveat(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3B82F6),
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const SizedBox(
                      width: 28,
                      height: 32,
                      child: CustomPaint(painter: _PdfTopRightArrowPainter()),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
            // Tablet Mockup
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 630,
                height: 420,
                child: const RepaintBoundary(child: _PdfTabletMockup()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PDF TABLET MOCKUP (EXACT BRAIN ANATOMY & TOOLBAR SCREEN)
// ═══════════════════════════════════════════════════════════════════════════════
class _PdfTabletMockup extends StatelessWidget {
  const _PdfTabletMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Bezel top with camera dot
          Container(
            height: 8,
            alignment: Alignment.center,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Tablet Screen
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    // PDF App Toolbar
                    _pdfTopBar(),
                    // Main area: Thumbnails Strip + PDF Document
                    Expanded(
                      child: Row(
                        children: [
                          _pdfThumbnailsStrip(),
                          Expanded(child: _pdfDocumentCanvas()),
                        ],
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

  Widget _pdfTopBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          // Left icons
          _pdfToolIcon(Icons.grid_view_rounded),
          _pdfToolIcon(Icons.search_rounded),
          _pdfToolIcon(Icons.menu_book_rounded),
          _pdfToolIcon(Icons.arrow_forward_rounded),
          const SizedBox(width: 4),
          // 100% zoom pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '100%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Color(0xFF475569)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _pdfToolIcon(Icons.undo_rounded),
          _pdfToolIcon(Icons.redo_rounded),
          const Spacer(),
          // Center tools
          // Active pen with blue outline circle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF4F46E5), width: 1.2),
            ),
            child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF4F46E5)),
          ),
          _pdfToolIcon(Icons.brush_outlined),
          _pdfToolIcon(Icons.crop_portrait_rounded),
          _pdfToolIcon(Icons.perm_media_outlined),
          _pdfToolIcon(Icons.title_rounded),
          const SizedBox(width: 6),
          // Color palette dots
          _pdfColorDot(const Color(0xFF1E293B)),
          _pdfColorDot(const Color(0xFF8B5CF6)),
          _pdfColorDot(const Color(0xFF38BDF8)),
          _pdfColorDot(const Color(0xFF6EE7B7)),
          _pdfColorDot(const Color(0xFF64748B)),
          _pdfColorDot(Colors.white, hasBorder: true),
          const Spacer(),
          // Share button pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.upload_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Share',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Profile avatar
          const SizedBox(
            width: 22,
            height: 22,
            child: _RealisticAvatar(index: 3),
          ),
        ],
      ),
    );
  }

  Widget _pdfToolIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.5),
      child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
    );
  }

  Widget _pdfColorDot(Color color, {bool hasBorder = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: hasBorder ? Border.all(color: const Color(0xFFCBD5E1), width: 1) : null,
        ),
      ),
    );
  }

  Widget _pdfThumbnailsStrip() {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          _thumbnailItem(1, isSelected: true),
          const SizedBox(height: 8),
          _thumbnailItem(2),
          const SizedBox(height: 8),
          _thumbnailItem(3),
          const SizedBox(height: 8),
          _thumbnailItem(4),
        ],
      ),
    );
  }

  Widget _thumbnailItem(int page, {bool isSelected = false}) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 24, height: 3, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 3),
              Container(width: 30, height: 2, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 2),
              Container(width: 28, height: 2, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 2),
              Container(
                width: 18,
                height: 2,
                color: isSelected ? const Color(0xFFFDE047) : const Color(0xFFE2E8F0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$page',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _pdfDocumentCanvas() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Title with purple marker underline
              Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 4,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Text(
                    'The Human Brain',
                    style: GoogleFonts.caveat(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Document text paragraph with yellow highlighter
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: const Color(0xFF334155),
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(text: 'The human brain is '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF08A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'a remarkable and complex',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '\norgan that controls our thoughts, emotions,\nand actions. It consists of billions of neurons\nthat communicate through electrical and\nchemical signals.'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Handwritten annotation: Incredible how this works!
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Incredible\nhow this works!',
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Brain Anatomical Diagram with Callout Pointers
        Positioned(
          top: 36,
          right: 36,
          child: SizedBox(
            width: 270,
            height: 250,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BrainDiagramPainter(),
                    ),
                  ),
                ),
                // Native Flutter Text widgets for callouts (Instant, zero paint overhead)
                Positioned(
                  top: 12,
                  left: 118,
                  child: Text(
                    'Parietal Lobe\n(Sensory)',
                    style: GoogleFonts.caveat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      height: 1.05,
                    ),
                  ),
                ),
                Positioned(
                  top: 96,
                  left: 0,
                  child: Text(
                    'Frontal Lobe\n(Thinking)',
                    style: GoogleFonts.caveat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      height: 1.05,
                    ),
                  ),
                ),
                Positioned(
                  top: 82,
                  right: 4,
                  child: Text(
                    'Occipital\nLobe\n(Vision)',
                    style: GoogleFonts.caveat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      height: 1.05,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 72,
                  left: 45,
                  child: Text(
                    'Temporal Lobe\n(Memory)',
                    style: GoogleFonts.caveat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      height: 1.05,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 68,
                  right: 18,
                  child: Text(
                    'Cerebellum\n(Co-ordination)',
                    style: GoogleFonts.caveat(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pinned Sticky Note on Top Right of Canvas
        Positioned(
          top: 12,
          right: 14,
          child: Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 80,
              height: 84,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Text(
                'Small\nSteps\nBig\nResults',
                style: GoogleFonts.caveat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B21A8),
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BRAIN ANATOMICAL ILLUSTRATION PAINTER (MEDICAL VECTOR ART)
// ═══════════════════════════════════════════════════════════════════════════════
class _BrainDiagramPainter extends CustomPainter {
  const _BrainDiagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double ox = 110.0;
    const double oy = 110.0;

    // Ink pen setup
    final ink = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fineInk = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final pointerPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // ── 1. Frontal Lobe (Mint Green) ──
    final frontal = Path()
      ..moveTo(ox - 30, oy - 45)
      ..cubicTo(ox - 65, oy - 35, ox - 75, oy + 5, ox - 55, oy + 32)
      ..cubicTo(ox - 38, oy + 42, ox - 20, oy + 25, ox - 12, oy + 10)
      ..cubicTo(ox - 18, oy - 15, ox - 24, oy - 35, ox - 30, oy - 45)
      ..close();
    canvas.drawPath(frontal, Paint()..color = const Color(0xFF86EFAC).withValues(alpha: 0.85)..style = PaintingStyle.fill);
    canvas.drawPath(frontal, ink);

    // ── 2. Parietal Lobe (Soft Yellow) ──
    final parietal = Path()
      ..moveTo(ox - 30, oy - 45)
      ..cubicTo(ox + 5, oy - 55, ox + 38, oy - 45, ox + 50, oy - 20)
      ..cubicTo(ox + 35, oy - 5, ox + 15, oy + 5, ox - 8, oy + 5)
      ..cubicTo(ox - 15, oy - 15, ox - 22, oy - 35, ox - 30, oy - 45)
      ..close();
    canvas.drawPath(parietal, Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.85)..style = PaintingStyle.fill);
    canvas.drawPath(parietal, ink);

    // ── 3. Occipital Lobe (Periwinkle Blue) ──
    final occipital = Path()
      ..moveTo(ox + 50, oy - 20)
      ..cubicTo(ox + 72, oy - 5, ox + 74, oy + 25, ox + 55, oy + 40)
      ..cubicTo(ox + 38, oy + 35, ox + 22, oy + 15, ox + 18, oy + 5)
      ..lineTo(ox + 50, oy - 20)
      ..close();
    canvas.drawPath(occipital, Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.85)..style = PaintingStyle.fill);
    canvas.drawPath(occipital, ink);

    // ── 4. Temporal Lobe (Lavender Purple) ──
    final temporal = Path()
      ..moveTo(ox - 12, oy + 10)
      ..cubicTo(ox + 10, oy + 5, ox + 32, oy + 12, ox + 38, oy + 32)
      ..cubicTo(ox + 25, oy + 48, ox - 8, oy + 52, ox - 28, oy + 38)
      ..cubicTo(ox - 25, oy + 22, ox - 18, oy + 15, ox - 12, oy + 10)
      ..close();
    canvas.drawPath(temporal, Paint()..color = const Color(0xFFC4B5FD).withValues(alpha: 0.85)..style = PaintingStyle.fill);
    canvas.drawPath(temporal, ink);

    // ── 5. Cerebellum (Striped Salmon Pink) ──
    final cerebellum = Path()
      ..moveTo(ox + 18, oy + 42)
      ..cubicTo(ox + 48, oy + 36, ox + 68, oy + 48, ox + 62, oy + 68)
      ..cubicTo(ox + 45, oy + 76, ox + 20, oy + 72, ox + 12, oy + 56)
      ..close();
    canvas.drawPath(cerebellum, Paint()..color = const Color(0xFFFDA4AF).withValues(alpha: 0.9)..style = PaintingStyle.fill);
    canvas.drawPath(cerebellum, ink);

    // Cerebellum fine folia horizontal stripes
    for (double y = oy + 46; y <= oy + 68; y += 4.5) {
      canvas.drawLine(Offset(ox + 22, y), Offset(ox + 58, y), fineInk);
    }

    // ── 6. Brain Stem ──
    final stem = Path()
      ..moveTo(ox + 5, oy + 52)
      ..lineTo(ox + 15, oy + 86)
      ..lineTo(ox + 25, oy + 84)
      ..lineTo(ox + 18, oy + 52)
      ..close();
    canvas.drawPath(stem, Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.fill);
    canvas.drawPath(stem, ink);

    // ── 7. Internal Gyri / Sulci Curves ──
    canvas.drawArc(Rect.fromCenter(center: Offset(ox - 38, oy - 15), width: 28, height: 20), 0.2, 2.2, false, fineInk);
    canvas.drawArc(Rect.fromCenter(center: Offset(ox - 48, oy + 12), width: 22, height: 16), 0.5, 2.5, false, fineInk);
    canvas.drawArc(Rect.fromCenter(center: Offset(ox + 10, oy - 25), width: 32, height: 22), 0.1, 2.6, false, fineInk);
    canvas.drawArc(Rect.fromCenter(center: Offset(ox + 35, oy - 10), width: 25, height: 18), 0.3, 2.4, false, fineInk);
    canvas.drawArc(Rect.fromCenter(center: Offset(ox + 55, oy + 15), width: 22, height: 16), 0.4, 2.2, false, fineInk);
    canvas.drawArc(Rect.fromCenter(center: Offset(ox + 2, oy + 28), width: 32, height: 18), 0.2, 2.5, false, fineInk);

    // ── 8. Callout Pointers ──
    // Parietal Lobe (Sensory) - top
    _drawPointer(canvas, Offset(ox + 28, oy - 48), Offset(ox + 22, oy - 62), pointerPaint);

    // Frontal Lobe (Thinking) - left
    _drawPointer(canvas, Offset(ox - 62, oy), Offset(ox - 92, oy - 5), pointerPaint);

    // Occipital Lobe (Vision) - right
    _drawPointer(canvas, Offset(ox + 72, oy + 15), Offset(ox + 98, oy + 15), pointerPaint);

    // Temporal Lobe (Memory) - bottom-left
    _drawPointer(canvas, Offset(ox - 2, oy + 46), Offset(ox - 12, oy + 65), pointerPaint);

    // Cerebellum (Co-ordination) - bottom-right
    _drawPointer(canvas, Offset(ox + 55, oy + 62), Offset(ox + 88, oy + 68), pointerPaint);
  }

  void _drawPointer(Canvas canvas, Offset target, Offset start, Paint paint) {
    canvas.drawLine(start, target, paint);
    // Draw tiny arrowhead at target
    final angle = math.atan2(target.dy - start.dy, target.dx - start.dx);
    const arrowLen = 5.0;
    const arrowAngle = 0.45;
    canvas.drawLine(
      target,
      Offset(target.dx - arrowLen * math.cos(angle - arrowAngle), target.dy - arrowLen * math.sin(angle - arrowAngle)),
      paint,
    );
    canvas.drawLine(
      target,
      Offset(target.dx - arrowLen * math.cos(angle + arrowAngle), target.dy - arrowLen * math.sin(angle + arrowAngle)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PdfTopRightArrowPainter extends CustomPainter {
  const _PdfTopRightArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.85, size.height * 0.15);
    path.cubicTo(
      size.width * 0.95,
      size.height * 0.55,
      size.width * 0.60,
      size.height * 0.80,
      size.width * 0.20,
      size.height * 0.90,
    );
    canvas.drawPath(path, paint);

    // Arrowhead
    final head = Path();
    head.moveTo(size.width * 0.35, size.height * 0.80);
    head.lineTo(size.width * 0.20, size.height * 0.90);
    head.lineTo(size.width * 0.28, size.height * 1.02);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 4: CROSS DEVICE
// ═══════════════════════════════════════════════════════════════════════════════
class _CrossDeviceSection extends StatelessWidget {
  final bool isDesktop;
  const _CrossDeviceSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _ink,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 120 : 72,
      ),
      child: _constrained(
        child: Column(
          children: [
            Text('SYNC EVERYWHERE', style: _eyebrowStyle().copyWith(color: const Color(0xFF64748B))),
            const SizedBox(height: 16),
            Text('Your notes,\non all your devices.',
                textAlign: TextAlign.center,
                style: _headingStyle(isDesktop ? 48 : 34).copyWith(color: Colors.white)),
            const SizedBox(height: 20),
            Text(
              'Start on your laptop, continue on your tablet, review on your phone.',
              textAlign: TextAlign.center,
              style: _bodyStyle(color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _darkChip('Seamless Sync'),
                _darkChip('Any Device'),
                _darkChip('Offline Access'),
                _darkChip('Safe & Private'),
              ],
            ),
            const SizedBox(height: 56),
            // Device mockups
            SizedBox(
              height: isDesktop ? 300 : 200,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Laptop
                  Container(
                    width: isDesktop ? 500 : 280,
                    height: isDesktop ? 280 : 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155), width: 3),
                    ),
                    child: Center(
                      child: Text('Notelekh', style: GoogleFonts.outfit(color: Colors.white24, fontSize: isDesktop ? 28 : 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  // Tablet
                  Positioned(
                    left: isDesktop ? -30 : 0,
                    bottom: isDesktop ? -20 : -10,
                    child: Container(
                      width: isDesktop ? 180 : 100,
                      height: isDesktop ? 260 : 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF475569), width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8))],
                      ),
                    ),
                  ),
                  // Phone
                  Positioned(
                    right: isDesktop ? 10 : 10,
                    bottom: isDesktop ? -30 : -20,
                    child: Container(
                      width: isDesktop ? 90 : 56,
                      height: isDesktop ? 180 : 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF64748B), width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
            Text('Web · Windows · macOS · iOS · Android',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _darkChip(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, color: _primary, size: 18),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 5: HANDWRITING
// ═══════════════════════════════════════════════════════════════════════════════
class _HandwritingSection extends StatelessWidget {
  final bool isDesktop;
  const _HandwritingSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return _sectionPadding(
      isDesktop: isDesktop,
      color: _bgWhite,
      child: Column(
        children: [
          Text('FEEL THE DIFFERENCE', style: _eyebrowStyle()),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: 'Write, sketch, and express ',
              style: _headingStyle(isDesktop ? 44 : 32),
              children: [TextSpan(text: 'naturally.', style: TextStyle(color: _primary))],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'A smooth writing experience designed to feel like pen on paper.',
            textAlign: TextAlign.center,
            style: _bodyStyle(),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _pill('Pressure Sensitive'),
              _pill('Tilt Support'),
              _pill('Handwriting to Text'),
              _pill('Shapes & Diagrams'),
              _pill('Colors & Tools'),
              _pill('Infinite Canvas'),
            ],
          ),
          const SizedBox(height: 56),
          // Writing canvas mockup
          Container(
            width: double.infinity,
            height: isDesktop ? 400 : 260,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _borderMedium, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 12))],
            ),
            child: Stack(
              children: [
                Center(
                  child: Text('Ideas today',
                      style: GoogleFonts.caveat(fontSize: isDesktop ? 64 : 36, color: _ink, fontWeight: FontWeight.w700)),
                ),
                if (isDesktop)
                  Positioned(
                    right: 80,
                    bottom: 60,
                    child: Text('Write without limits.',
                        style: GoogleFonts.caveat(fontSize: 28, color: _primary.withValues(alpha: 0.6))),
                  ),
                if (isDesktop)
                  Positioned(
                    left: 60,
                    top: 40,
                    child: Text('Simple tools.\nReal progress.',
                        style: GoogleFonts.caveat(fontSize: 22, color: _textMuted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 6: NOTELEKH AI
// ═══════════════════════════════════════════════════════════════════════════════
class _AiSection extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onCta;
  const _AiSection({required this.isDesktop, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOTELEKH AI', style: _eyebrowStyle().copyWith(color: _primary)),
        const SizedBox(height: 16),
        Text.rich(TextSpan(
          text: 'Turn messy notes\ninto ',
          style: _headingStyle(isDesktop ? 40 : 30),
          children: [TextSpan(text: 'clear ideas.', style: TextStyle(color: _primary))],
        )),
        const SizedBox(height: 20),
        Text('Use AI to summarize, organize and understand your notes.', style: _bodyStyle()),
        const SizedBox(height: 28),
        _checkRow('AI Summaries'),
        _checkRow('Action Items & To-dos'),
        _checkRow('Ask Anything'),
        _checkRow('Multiple Languages'),
        const SizedBox(height: 28),
        _primaryButton('Try Notelekh AI →', onCta),
      ],
    );

    final mockup = _AiMockup(isDesktop: isDesktop);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAFAFA), Color(0xFFF3E8FF)],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 120 : 72,
      ),
      child: _constrained(
        child: isDesktop
            ? Row(children: [Expanded(child: mockup), const SizedBox(width: 48), Expanded(child: text)])
            : Column(children: [text, const SizedBox(height: 48), mockup]),
      ),
    );
  }
}

class _AiMockup extends StatelessWidget {
  final bool isDesktop;
  const _AiMockup({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: isDesktop ? 420 : 300),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          // Notes side
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Marketing Strategy', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: isDesktop ? 20 : 16, color: _ink)),
                  const SizedBox(height: 20),
                  Text('1. Goals', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
                  const SizedBox(height: 8),
                  Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 16),
                  Text('2. Key Ideas', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _ink)),
                  const SizedBox(height: 8),
                  Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 140, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(3))),
                ],
              ),
            ),
          ),
          // AI panel
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(19)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: _primary, size: 16),
                        const SizedBox(width: 6),
                        Text('AI Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: _primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 60, decoration: BoxDecoration(color: _bgWhite, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 12),
                    Text('Action Items', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: _ink)),
                    const SizedBox(height: 8),
                    Container(height: 24, decoration: BoxDecoration(color: _bgWhite, borderRadius: BorderRadius.circular(8))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _bgWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Text('Ask anything...', style: GoogleFonts.inter(color: _textMuted, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 7: USE CASES
// ═══════════════════════════════════════════════════════════════════════════════
class _UseCasesSection extends StatefulWidget {
  final bool isDesktop;
  const _UseCasesSection({required this.isDesktop});

  @override
  State<_UseCasesSection> createState() => _UseCasesSectionState();
}

class _UseCasesSectionState extends State<_UseCasesSection> {
  int _activePersona = 0;

  final List<_PersonaData> _personas = const [
    _PersonaData(
      id: 'students',
      label: 'Students & Fellows',
      iconKind: 0,
      accentColor: Color(0xFF2563EB),
      kicker: 'ACADEMIC EXCELLENCE & RESEARCH',
      headline: 'A sanctuary for heavy lectures, proofs, and high-stakes exams.',
      story: 'When you are managing 80-page slides across four intense courses, messy notebooks and scattered PDFs fail. Notelekh gives you an expansive split-screen canvas with zero-latency inking, infinite margins for proof derivations, and instant search across every formula you scribble.',
      quote: 'Annotating 80-page PDF slides alongside split-screen handwritten formulas saved my finals.',
      author: 'Aarav Sharma',
      authorTitle: 'Med-Tech Scholar, AIIMS',
      authorInitial: 'A',
      tactileNote: 'pressure curves switch to fine line for subscripts ✦',
      chips: ['Calculus II', 'Lecture Slides', 'Formula Sheets', 'Split-Screen LaTeX'],
    ),
    _PersonaData(
      id: 'leaders',
      label: 'Leaders & Builders',
      iconKind: 1,
      accentColor: Color(0xFF0D9488),
      kicker: 'ENGINEERING & STRATEGY',
      headline: 'Where raw whiteboard sessions turn into crisp architectural reality.',
      story: 'High-growth engineering leaders do not think in rigid linear docs. They sketch system topologies, flowcharts, and team topology maps. Notelekh bridges raw ideation and structured execution, giving you infinite space to map out architecture before specs get committed to code.',
      quote: 'Every product roadmap and architecture draft starts on Notelekh before specs get written.',
      author: 'Marcus Chen',
      authorTitle: 'VP of Engineering, ScaleFlow',
      authorInitial: 'M',
      tactileNote: 'vector export matches Figma and Linear specs ✦',
      chips: ['System Design', '1-on-1 Notes', 'Sprint Retros', 'Architecture Specs'],
    ),
    _PersonaData(
      id: 'creators',
      label: 'Creators & Artists',
      iconKind: 2,
      accentColor: Color(0xFFD946EF),
      kicker: 'VISUAL ARTS & STORYTELLING',
      headline: 'Fluid digital ink that preserves your initial creative spark.',
      story: 'Great visual projects begin as messy, beautiful fragments—color moodboards, thumbnail storyboards, and quick stylus gestures. Notelekh treats your stylus with the precision of a fine-nib pen, letting you freely draft concept art without software UI getting in your way.',
      quote: 'The low-latency stylus response makes storyboarding and quick sketches feel truly analog.',
      author: 'Elena Rostova',
      authorTitle: 'Visual Director & Illustrator',
      authorInitial: 'E',
      tactileNote: 'brush tilt feels identical to 4B graphite ✦',
      chips: ['Moodboards', 'Storyboards', 'Concept Art', 'Palette Swatches'],
    ),
    _PersonaData(
      id: 'thinkers',
      label: 'Thinkers & Authors',
      iconKind: 3,
      accentColor: Color(0xFF7C3AED),
      kicker: 'DEEP WORK & SYNTHESIS',
      headline: 'A quiet, distraction-free sanctuary for long-form synthesis.',
      story: 'For authors, cognitive scientists, and essayists, thoughts do not arrive pre-categorized. Notelekh provides a tranquil space where book excerpts, margin thoughts, and bidirectional links connect naturally, building a permanent web of connected knowledge.',
      quote: 'Every literature excerpt and research hypothesis connects cleanly in one searchable space.',
      author: 'Dr. Julian Vance',
      authorTitle: 'Cognitive Science Fellow',
      authorInitial: 'J',
      tactileNote: 'bidirectional links connect disparate journals ✦',
      chips: ['Paper Notes', 'Book Synthesis', 'Daily Journal', 'Knowledge Graphs'],
    ),
  ];

  Widget _getPersonaIcon(int iconKind, Color color) {
    switch (iconKind) {
      case 0:
        return _PersonaStudentIcon(color: color);
      case 1:
        return _PersonaWorkIcon(color: color);
      case 2:
        return _PersonaCreatorIcon(color: color);
      case 3:
      default:
        return _PersonaThinkerIcon(color: color);
    }
  }

  Widget _buildPersonaTab(int index, _PersonaData p) {
    final bool isSelected = _activePersona == index;
    final Color iconColor = isSelected ? p.accentColor : const Color(0xFF94A3B8);

    return InkWell(
      onTap: () => setState(() => _activePersona = index),
      borderRadius: BorderRadius.circular(999),
      hoverColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isDesktop ? 18 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(color: p.accentColor.withValues(alpha: 0.25), width: 1.2)
              : Border.all(color: Colors.transparent, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: _getPersonaIcon(p.iconKind, iconColor),
            ),
            const SizedBox(width: 8),
            Text(
              p.label,
              style: GoogleFonts.inter(
                fontSize: widget.isDesktop ? 13 : 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persona = _personas[_activePersona];

    return _sectionPadding(
      isDesktop: widget.isDesktop,
      color: _bgWhite,
      child: Column(
        children: [
          Text('BUILT FOR EVERY JOURNEY', style: _eyebrowStyle()),
          const SizedBox(height: 16),
          Text(
            'A space for every kind of thinker.',
            textAlign: TextAlign.center,
            style: _headingStyle(widget.isDesktop ? 44 : 32),
          ),
          const SizedBox(height: 16),
          Text(
            'From university lecture halls and sprint war rooms to studio easels and research labs.',
            textAlign: TextAlign.center,
            style: _bodyStyle(size: 16),
          ),
          const SizedBox(height: 48),

          // Segmented Persona Bar (Cardless pill track)
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: List.generate(
                _personas.length,
                (i) => _buildPersonaTab(i, _personas[i]),
              ),
            ),
          ),
          const SizedBox(height: 60),

          // Main 2-Column Editorial Desk View (Zero box cards!)
          widget.isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: The Narrative Voice
                    Expanded(
                      flex: 5,
                      child: _buildNarrativeColumn(persona),
                    ),
                    const SizedBox(width: 56),
                    // Right Column: The Living Artifact (Open Desk Sheet)
                    Expanded(
                      flex: 6,
                      child: _LivingNotebookArtifact(
                        persona: persona,
                        isDesktop: widget.isDesktop,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildNarrativeColumn(persona),
                    const SizedBox(height: 48),
                    _LivingNotebookArtifact(
                      persona: persona,
                      isDesktop: widget.isDesktop,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildNarrativeColumn(_PersonaData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expressive Editorial Headline
        Text(
          p.headline,
          style: GoogleFonts.playfairDisplay(
            fontSize: widget.isDesktop ? 34 : 26,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            height: 1.25,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 18),

        // Story Prose
        Text(
          p.story,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.7,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 32),

        // Editorial Quote Block (Cardless: Open accent bar)
        Container(
          padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: p.accentColor, width: 3.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${p.quote}”',
                style: GoogleFonts.inter(
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: p.accentColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.authorInitial,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: p.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${p.author} · ${p.authorTitle}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Handwritten Margin Reflection
              Row(
                children: [
                  Text('✍ ', style: TextStyle(fontSize: 12, color: p.accentColor)),
                  Text(
                    p.tactileNote,
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Workflow Tags (Pills)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.chips.map((chip) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              chip,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _PersonaData {
  final String id;
  final String label;
  final int iconKind;
  final Color accentColor;
  final String kicker;
  final String headline;
  final String story;
  final String quote;
  final String author;
  final String authorTitle;
  final String authorInitial;
  final String tactileNote;
  final List<String> chips;

  const _PersonaData({
    required this.id,
    required this.label,
    required this.iconKind,
    required this.accentColor,
    required this.kicker,
    required this.headline,
    required this.story,
    required this.quote,
    required this.author,
    required this.authorTitle,
    required this.authorInitial,
    required this.tactileNote,
    required this.chips,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVING NOTEBOOK ARTIFACT (Cardless open desk sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _LivingNotebookArtifact extends StatelessWidget {
  final _PersonaData persona;
  final bool isDesktop;

  const _LivingNotebookArtifact({
    required this.persona,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio Desk Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Row(
                  children: const [
                    CircleAvatar(radius: 4.5, backgroundColor: Color(0xFFFDA4AF)),
                    SizedBox(width: 6),
                    CircleAvatar(radius: 4.5, backgroundColor: Color(0xFFFDE047)),
                    SizedBox(width: 6),
                    CircleAvatar(radius: 4.5, backgroundColor: Color(0xFF86EFAC)),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 13, color: persona.accentColor),
                      const SizedBox(width: 5),
                      Text(
                        'Active Workspace · ${persona.label}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '240Hz Digitizer Live',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),

          // Authentic Dynamic Paper Canvas based on active persona
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildArtifactContent(persona),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactContent(_PersonaData p) {
    switch (p.id) {
      case 'students':
        return _buildStudentSheet(p);
      case 'leaders':
        return _buildLeaderSheet(p);
      case 'creators':
        return _buildCreatorSheet(p);
      case 'thinkers':
      default:
        return _buildThinkerSheet(p);
    }
  }

  // 1. Student Artifact: Calculus proof on lined paper with yellow highlighter and margin note
  Widget _buildStudentSheet(_PersonaData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Embedded PDF Slide Reference Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 14, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Lecture 14: Differential Geometry.pdf — Slide 42',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E40AF),
                ),
              ),
              const Spacer(),
              Text('Split View', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF3B82F6))),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Handwritten Mathematical Derivation
        Text(
          'Derivation of Stoke’s Theorem on Manifolds:',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF2F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '∫_∂Ω ω  =  ∫_Ω dω',
                style: GoogleFonts.caveat(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Core Theorem (Exam 2)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '← verify boundary orientation!',
                    style: GoogleFonts.caveat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Margin Lecture Notes
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Boundary ∂Ω must be compact, oriented, smooth manifold', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.5)),
            const SizedBox(height: 4),
            Text('• Exterior derivative d satisfies d(dω) = 0 identically', style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155), height: 1.5)),
          ],
        ),
      ],
    );
  }

  // 2. Leader Artifact: System Architecture topology on dot-grid blueprint
  Widget _buildLeaderSheet(_PersonaData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spec Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ARCHITECTURE RFC #104: Offline-First Inking Sync',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('APPROVED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Connected Architecture Blocks
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF2F6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildArchNode('Stylus Digitizer\n(240Hz Sample)', const Color(0xFF0D9488)),
              const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
              _buildArchNode('WASM Bezier\nFitting Engine', const Color(0xFF2563EB)),
              const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
              _buildArchNode('CRDT Peer\nState Stream', const Color(0xFF7C3AED)),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action Item Checkmarks
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCheckItem('Sub-8ms latency benchmark passed on Apple Pencil & S-Pen', true),
            const SizedBox(height: 6),
            _buildCheckItem('Zero data loss conflict resolution across 5 active peers', true),
            const SizedBox(height: 6),
            _buildCheckItem('Signed off for production deployment in Sprint 25', true),
          ],
        ),
      ],
    );
  }

  Widget _buildArchNode(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text, bool checked) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: checked ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  // 3. Creator Artifact: Color Swatches & Storyboard Sketches
  Widget _buildCreatorSheet(_PersonaData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONCEPT BOARD: "Twilight Odyssey" Keyframes',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '4B Pencil + Watercolor',
              style: GoogleFonts.caveat(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFD946EF)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Color Palette Chips
        Row(
          children: [
            _buildColorSwatch(const Color(0xFF4F46E5), '#4F46E5', 'Indigo Dusk'),
            const SizedBox(width: 8),
            _buildColorSwatch(const Color(0xFFD946EF), '#D946EF', 'Magenta Ray'),
            const SizedBox(width: 8),
            _buildColorSwatch(const Color(0xFFF59E0B), '#F59E0B', 'Amber Flare'),
            const SizedBox(width: 8),
            _buildColorSwatch(const Color(0xFF10B981), '#10B981', 'Aurora Emerald'),
          ],
        ),
        const SizedBox(height: 18),

        // Storyboard Thumbnail Frame
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF2F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCENE 04 · SHOT B', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  Text('Camera pushes slowly toward the horizon', style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      const Color(0xFFD946EF).withValues(alpha: 0.12),
                      const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '〰 Fluid stroke vector path — 100% vector scalability 〰',
                  style: GoogleFonts.caveat(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFD946EF)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorSwatch(Color color, String hex, String name) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEF2F6)),
        ),
        child: Column(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(hex, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // 4. Thinker Artifact: Deep Literature Synthesis & Bidirectional Links
  Widget _buildThinkerSheet(_PersonaData p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LITERATURE SYNTHESIS: The Extension of Mind',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Book Journal #8',
              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Editorial Quote Excerpt
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEEF2F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“Where does the mind stop and the rest of the world begin? The active externalist sees no reason to stop at the skull.”',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '— Clark & Chalmers, The Extended Mind (1998)',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bidirectional Conceptual Links
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBacklink('[[Cognitive Scaffolding]]'),
            _buildBacklink('[[Tactile Memory Formation]]'),
            _buildBacklink('[[Spatial Indexing]]'),
          ],
        ),
        const SizedBox(height: 12),

        Text(
          'Personal thesis note: handwriting creates motor memory traces that keyboard typing fundamentally destroys.',
          style: GoogleFonts.caveat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildBacklink(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6D28D9),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VECTOR ICONS FOR USE CASE PERSONAS (Immune to Web tree-shaking)
// ─────────────────────────────────────────────────────────────────────────────

class _PersonaStudentIcon extends StatelessWidget {
  final Color color;
  const _PersonaStudentIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _PersonaStudentPainter(color: color),
    );
  }
}

class _PersonaStudentPainter extends CustomPainter {
  final Color color;
  const _PersonaStudentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Mortarboard diamond cap
    final cap = Path()
      ..moveTo(size.width * 0.50, size.height * 0.16)
      ..lineTo(size.width * 0.90, size.height * 0.35)
      ..lineTo(size.width * 0.50, size.height * 0.54)
      ..lineTo(size.width * 0.10, size.height * 0.35)
      ..close();
    canvas.drawPath(cap, stroke);

    // Skullcap curve underneath
    final underCap = Path()
      ..moveTo(size.width * 0.28, size.height * 0.44)
      ..lineTo(size.width * 0.28, size.height * 0.64)
      ..quadraticBezierTo(
        size.width * 0.50, size.height * 0.80,
        size.width * 0.72, size.height * 0.64,
      )
      ..lineTo(size.width * 0.72, size.height * 0.44);
    canvas.drawPath(underCap, stroke);

    // Tassel
    final tassel = Path()
      ..moveTo(size.width * 0.50, size.height * 0.35)
      ..lineTo(size.width * 0.88, size.height * 0.48)
      ..lineTo(size.width * 0.88, size.height * 0.74);
    canvas.drawPath(tassel, stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.76), 1.4, fill);
  }

  @override
  bool shouldRepaint(covariant _PersonaStudentPainter oldDelegate) => oldDelegate.color != color;
}

class _PersonaWorkIcon extends StatelessWidget {
  final Color color;
  const _PersonaWorkIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _PersonaWorkPainter(color: color),
    );
  }
}

class _PersonaWorkPainter extends CustomPainter {
  final Color color;
  const _PersonaWorkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Briefcase body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.28, size.width * 0.76, size.height * 0.60),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(body, stroke);

    // Briefcase handle
    final handle = Path()
      ..moveTo(size.width * 0.36, size.height * 0.28)
      ..lineTo(size.width * 0.36, size.height * 0.15)
      ..arcToPoint(Offset(size.width * 0.42, size.height * 0.11), radius: const Radius.circular(2))
      ..lineTo(size.width * 0.58, size.height * 0.11)
      ..arcToPoint(Offset(size.width * 0.64, size.height * 0.15), radius: const Radius.circular(2))
      ..lineTo(size.width * 0.64, size.height * 0.28);
    canvas.drawPath(handle, stroke..strokeWidth = 1.6);

    // Division line
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.50),
      Offset(size.width * 0.88, size.height * 0.50),
      stroke..strokeWidth = 1.5,
    );

    // Clasp
    final clasp = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.50), width: 4.5, height: 5.5),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(clasp, fill);
  }

  @override
  bool shouldRepaint(covariant _PersonaWorkPainter oldDelegate) => oldDelegate.color != color;
}

class _PersonaCreatorIcon extends StatelessWidget {
  final Color color;
  const _PersonaCreatorIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _PersonaCreatorPainter(color: color),
    );
  }
}

class _PersonaCreatorPainter extends CustomPainter {
  final Color color;
  const _PersonaCreatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Palette outline
    final palette = Path()
      ..moveTo(size.width * 0.50, size.height * 0.12)
      ..cubicTo(size.width * 0.88, size.height * 0.12, size.width * 0.92, size.height * 0.60, size.width * 0.75, size.height * 0.82)
      ..cubicTo(size.width * 0.62, size.height * 0.94, size.width * 0.40, size.height * 0.92, size.width * 0.28, size.height * 0.82)
      ..cubicTo(size.width * 0.12, size.height * 0.70, size.width * 0.12, size.height * 0.28, size.width * 0.50, size.height * 0.12)
      ..close();
    canvas.drawPath(palette, stroke);

    // Thumb hole
    canvas.drawCircle(Offset(size.width * 0.64, size.height * 0.68), 2.0, stroke..strokeWidth = 1.5);

    // Pigment dabs
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.35), 1.7, fill);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.30), 1.7, fill);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.42), 1.7, fill);
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.58), 1.7, fill);
  }

  @override
  bool shouldRepaint(covariant _PersonaCreatorPainter oldDelegate) => oldDelegate.color != color;
}

class _PersonaThinkerIcon extends StatelessWidget {
  final Color color;
  const _PersonaThinkerIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _PersonaThinkerPainter(color: color),
    );
  }
}

class _PersonaThinkerPainter extends CustomPainter {
  final Color color;
  const _PersonaThinkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Open book pages
    final book = Path()
      ..moveTo(size.width * 0.50, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.22, size.width * 0.14, size.height * 0.26)
      ..lineTo(size.width * 0.14, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.74, size.width * 0.50, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.74, size.width * 0.86, size.height * 0.78)
      ..lineTo(size.width * 0.86, size.height * 0.26)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.22, size.width * 0.50, size.height * 0.30)
      ..close();
    canvas.drawPath(book, stroke);

    // Book center spine
    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.30),
      Offset(size.width * 0.50, size.height * 0.82),
      stroke..strokeWidth = 1.5,
    );

    // Bookmark ribbon
    final ribbon = Path()
      ..moveTo(size.width * 0.46, size.height * 0.82)
      ..lineTo(size.width * 0.46, size.height * 0.94)
      ..lineTo(size.width * 0.50, size.height * 0.90)
      ..lineTo(size.width * 0.54, size.height * 0.94)
      ..lineTo(size.width * 0.54, size.height * 0.82);
    canvas.drawPath(ribbon, fill);
  }

  @override
  bool shouldRepaint(covariant _PersonaThinkerPainter oldDelegate) => oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 8: WORKFLOWS (Continuous Flowing Ribbon - Zero Cards)
// ═══════════════════════════════════════════════════════════════════════════════
class _WorkflowsSection extends StatelessWidget {
  final bool isDesktop;
  const _WorkflowsSection({required this.isDesktop});

  Widget _buildCapturePreview(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 12, color: accent),
                    const SizedBox(width: 5),
                    Text('Inking Canvas', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('Zero Latency', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '∫ f(x) dx = F(x) + C',
            style: GoogleFonts.caveat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF08A),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'Core Equation',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF854D0E)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Slide p. 42', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizePreview(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 12, color: accent),
                    const SizedBox(width: 5),
                    Text('Workspace Library', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('Auto-Synced', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Text('📁', style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Text('Active Projects / Sprint 24', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Architecture.note', style: TextStyle(fontSize: 10, color: Color(0xFF475569))),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Specs.pdf', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnderstandPreview(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: accent),
                    const SizedBox(width: 5),
                    Text('Notelekh AI Studio', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('OCR Ready', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Text('🔍', style: TextStyle(fontSize: 11)),
              SizedBox(width: 5),
              Text('"Find neurological pathways"', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '✨ 3 handwritten diagrams matched',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step1 = _WorkflowStreamStation(
      stepNumber: '01',
      stageTag: 'CAPTURE',
      title: 'In uninterrupted flow',
      desc: 'Write naturally with zero-latency stylus inking. Import slide decks or sketch diagrams freely on infinite paper.',
      tactileNote: 'pressure curves adapt dynamically to your hand ✦',
      accentColor: const Color(0xFF4F46E5),
      iconWidget: const _WfCaptureIcon(color: Color(0xFF4F46E5)),
      preview: _buildCapturePreview(const Color(0xFF4F46E5)),
    );

    final step2 = _WorkflowStreamStation(
      stepNumber: '02',
      stageTag: 'ORGANIZE',
      title: 'Structure without friction',
      desc: 'Group notes into intuitive color-coded folders, tagged workbooks, and searchable multi-page binders that stay synced.',
      tactileNote: 'instant multi-tab workspaces with zero load lag ✦',
      accentColor: const Color(0xFF0D9488),
      iconWidget: const _WfOrganizeIcon(color: Color(0xFF0D9488)),
      preview: _buildOrganizePreview(const Color(0xFF0D9488)),
    );

    final step3 = _WorkflowStreamStation(
      stepNumber: '03',
      stageTag: 'UNDERSTAND',
      title: 'Synthesize with intelligence',
      desc: 'Instant neural OCR searches your handwritten ink. Notelekh AI synthesizes deep summaries and study flashcards.',
      tactileNote: 'understands cursive & mathematical equations ✦',
      accentColor: const Color(0xFF7C3AED),
      iconWidget: const _WfUnderstandIcon(color: Color(0xFF7C3AED)),
      preview: _buildUnderstandPreview(const Color(0xFF7C3AED)),
    );

    return _sectionPadding(
      isDesktop: isDesktop,
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          Text('WORKFLOW & ARCHITECTURE', style: _eyebrowStyle()),
          const SizedBox(height: 16),
          Text(
            'From thought to finished work.',
            textAlign: TextAlign.center,
            style: _headingStyle(isDesktop ? 44 : 32),
          ),
          const SizedBox(height: 16),
          Text(
            'A seamless 3-stage continuous creative stream designed to keep your mind in uninterrupted flow.',
            textAlign: TextAlign.center,
            style: _bodyStyle(size: 16),
          ),
          const SizedBox(height: 64),

          // Cardless Continuous Flow Stream
          if (isDesktop)
            Column(
              children: [
                // Top Connecting Gradient Ribbon Track
                Container(
                  height: 3,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4F46E5),
                        Color(0xFF0D9488),
                        Color(0xFF7C3AED),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: step1),
                    const SizedBox(width: 36),
                    Expanded(child: step2),
                    const SizedBox(width: 36),
                    Expanded(child: step3),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                step1,
                const SizedBox(height: 40),
                step2,
                const SizedBox(height: 40),
                step3,
              ],
            ),
        ],
      ),
    );
  }
}

class _WorkflowStreamStation extends StatefulWidget {
  final String stepNumber;
  final String stageTag;
  final String title;
  final String desc;
  final String tactileNote;
  final Color accentColor;
  final Widget iconWidget;
  final Widget preview;

  const _WorkflowStreamStation({
    required this.stepNumber,
    required this.stageTag,
    required this.title,
    required this.desc,
    required this.tactileNote,
    required this.accentColor,
    required this.iconWidget,
    required this.preview,
  });

  @override
  State<_WorkflowStreamStation> createState() => _WorkflowStreamStationState();
}

class _WorkflowStreamStationState extends State<_WorkflowStreamStation> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Milestone Top Bar: Glowing circular beacon + stage tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Luminous circular beacon (No box card!)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withValues(alpha: _hovered ? 0.14 : 0.07),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: _hovered ? 0.40 : 0.20),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: _hovered ? 0.22 : 0.0),
                      blurRadius: _hovered ? 20 : 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: widget.iconWidget,
              ),

              // Watermark Stylized Numeral
              Text(
                widget.stepNumber,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: widget.accentColor.withValues(alpha: 0.20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stage Indicator
          Text(
            'STAGE ${widget.stepNumber} · ${widget.stageTag}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: widget.accentColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Narrative Prose
          Text(
            widget.desc,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.62,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 14),

          // Handwritten Tactile Note
          Row(
            children: [
              Text('✦ ', style: TextStyle(color: widget.accentColor, fontSize: 11)),
              Expanded(
                child: Text(
                  widget.tactileNote,
                  style: GoogleFonts.caveat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Open Micro-Preview Artifact
          widget.preview,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VECTOR ICONS FOR WORKFLOW SECTION (Immune to Web tree-shaking)
// ─────────────────────────────────────────────────────────────────────────────

class _WfCaptureIcon extends StatelessWidget {
  final Color color;
  const _WfCaptureIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _WfCapturePainter(color: color),
    );
  }
}

class _WfCapturePainter extends CustomPainter {
  final Color color;
  const _WfCapturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Stylus barrel
    final pen = Path()
      ..moveTo(size.width * 0.74, size.height * 0.10)
      ..lineTo(size.width * 0.90, size.height * 0.26)
      ..lineTo(size.width * 0.38, size.height * 0.78)
      ..lineTo(size.width * 0.14, size.height * 0.84)
      ..lineTo(size.width * 0.20, size.height * 0.60)
      ..close();
    canvas.drawPath(pen, stroke);

    // Tip
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.84), 1.3, fill);

    // Dynamic wave
    final wave = Path()
      ..moveTo(size.width * 0.22, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.52, size.height * 0.98, size.width * 0.86, size.height * 0.88);
    canvas.drawPath(wave, stroke..strokeWidth = 1.7);
  }

  @override
  bool shouldRepaint(covariant _WfCapturePainter oldDelegate) => oldDelegate.color != color;
}

class _WfOrganizeIcon extends StatelessWidget {
  final Color color;
  const _WfOrganizeIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _WfOrganizePainter(color: color),
    );
  }
}

class _WfOrganizePainter extends CustomPainter {
  final Color color;
  const _WfOrganizePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // Back folder tab
    final backFolder = Path()
      ..moveTo(size.width * 0.20, size.height * 0.22)
      ..lineTo(size.width * 0.44, size.height * 0.22)
      ..lineTo(size.width * 0.54, size.height * 0.32)
      ..lineTo(size.width * 0.88, size.height * 0.32)
      ..lineTo(size.width * 0.88, size.height * 0.68)
      ..lineTo(size.width * 0.20, size.height * 0.68)
      ..close();
    canvas.drawPath(backFolder, stroke..strokeWidth = 1.5);

    // Front folder
    final frontFolder = Path()
      ..moveTo(size.width * 0.12, size.height * 0.38)
      ..lineTo(size.width * 0.38, size.height * 0.38)
      ..lineTo(size.width * 0.48, size.height * 0.48)
      ..lineTo(size.width * 0.82, size.height * 0.48)
      ..lineTo(size.width * 0.82, size.height * 0.86)
      ..lineTo(size.width * 0.12, size.height * 0.86)
      ..close();
    canvas.drawPath(frontFolder, fill);
    canvas.drawPath(frontFolder, stroke..strokeWidth = 1.8);

    // Division line
    canvas.drawLine(
      Offset(size.width * 0.26, size.height * 0.64),
      Offset(size.width * 0.68, size.height * 0.64),
      stroke..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _WfOrganizePainter oldDelegate) => oldDelegate.color != color;
}

class _WfUnderstandIcon extends StatelessWidget {
  final Color color;
  const _WfUnderstandIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _WfUnderstandPainter(color: color),
    );
  }
}

class _WfUnderstandPainter extends CustomPainter {
  final Color color;
  const _WfUnderstandPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Center AI sparkle
    final sparkCenter = Offset(size.width * 0.46, size.height * 0.48);
    final spark = Path()
      ..moveTo(sparkCenter.dx, sparkCenter.dy - 8.0)
      ..quadraticBezierTo(sparkCenter.dx + 1.2, sparkCenter.dy - 1.2, sparkCenter.dx + 8.0, sparkCenter.dy)
      ..quadraticBezierTo(sparkCenter.dx + 1.2, sparkCenter.dy + 1.2, sparkCenter.dx, sparkCenter.dy + 8.0)
      ..quadraticBezierTo(sparkCenter.dx - 1.2, sparkCenter.dy + 1.2, sparkCenter.dx - 8.0, sparkCenter.dy)
      ..quadraticBezierTo(sparkCenter.dx - 1.2, sparkCenter.dy - 1.2, sparkCenter.dx, sparkCenter.dy - 8.0)
      ..close();
    canvas.drawPath(spark, fill);

    // Mini companion sparkle
    const miniCenter = Offset(20.0, 7.5);
    final miniSpark = Path()
      ..moveTo(miniCenter.dx, miniCenter.dy - 3.8)
      ..lineTo(miniCenter.dx + 1.0, miniCenter.dy - 1.0)
      ..lineTo(miniCenter.dx + 3.8, miniCenter.dy)
      ..lineTo(miniCenter.dx + 1.0, miniCenter.dy + 1.0)
      ..lineTo(miniCenter.dx, miniCenter.dy + 3.8)
      ..lineTo(miniCenter.dx - 1.0, miniCenter.dy + 1.0)
      ..lineTo(miniCenter.dx - 3.8, miniCenter.dy)
      ..lineTo(miniCenter.dx - 1.0, miniCenter.dy - 1.0)
      ..close();
    canvas.drawPath(miniSpark, fill);

    // Intelligence arcs
    final arcRect1 = Rect.fromCircle(center: sparkCenter, radius: 10.5);
    canvas.drawArc(arcRect1, math.pi * 0.7, math.pi * 0.5, false, stroke..strokeWidth = 1.5);
    final arcRect2 = Rect.fromCircle(center: sparkCenter, radius: 11.0);
    canvas.drawArc(arcRect2, -math.pi * 0.3, math.pi * 0.4, false, stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _WfUnderstandPainter oldDelegate) => oldDelegate.color != color;
}


// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 10: TRUST
// ═══════════════════════════════════════════════════════════════════════════════
class _TrustSection extends StatelessWidget {
  final bool isDesktop;
  const _TrustSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return _sectionPadding(
      isDesktop: isDesktop,
      color: const Color(0xFFF8FAFC),
      vPad: 80,
      child: Column(
        children: [
          Text('BUILT TO LAST', style: _eyebrowStyle()),
          const SizedBox(height: 32),
          Wrap(
            spacing: 40,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _trustItem(Icons.lock_outline_rounded, 'Secure Notes'),
              _trustItem(Icons.cloud_done_outlined, 'Reliable Sync'),
              _trustItem(Icons.devices_rounded, 'Cross-device'),
              _trustItem(Icons.folder_special_rounded, 'Organized'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _primary, size: 22),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION 11: FINAL CTA
// ═══════════════════════════════════════════════════════════════════════════════
class _FinalCtaSection extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onCta;
  const _FinalCtaSection({required this.isDesktop, required this.onCta});

  @override
  Widget build(BuildContext context) {
    return _sectionPadding(
      isDesktop: isDesktop,
      color: _bgWhite,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 72, horizontal: isDesktop ? 48 : 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF3E8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            Text('GET STARTED TODAY', style: _eyebrowStyle().copyWith(color: _primary)),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                text: 'Ready to write ',
                style: _headingStyle(isDesktop ? 48 : 32),
                children: [TextSpan(text: 'your story?', style: TextStyle(color: _primary))],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Give your ideas a better place to live.',
              textAlign: TextAlign.center,
              style: _bodyStyle(),
            ),
            const SizedBox(height: 32),
            _primaryButton('Get started free →', onCta),
            const SizedBox(height: 28),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _miniCheck('Free to start'),
                _miniCheck('No credit card required'),
                _miniCheck('Available on supported devices'),
              ],
            ),
            const SizedBox(height: 28),
            Text('Your next chapter starts here.',
                style: GoogleFonts.caveat(fontSize: 26, color: _primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _miniCheck(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, size: 14, color: _primary),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.inter(color: _textBody, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════════
class _FooterSection extends StatefulWidget {
  final bool isDesktop;
  const _FooterSection({required this.isDesktop});

  @override
  State<_FooterSection> createState() => _FooterSectionState();
}

class _FooterSectionState extends State<_FooterSection> {
  final TextEditingController _emailController = TextEditingController();
  bool _subscribed = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSubscribe() {
    if (_emailController.text.trim().isNotEmpty) {
      setState(() => _subscribed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Thanks for subscribing to Notelekh updates!'),
          backgroundColor: Color(0xFF4F46E5),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.isDesktop;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      padding: EdgeInsets.only(
        left: isDesktop ? 56 : 24,
        right: isDesktop ? 56 : 24,
        top: 60,
        bottom: 40,
      ),
      child: _constrained(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Newsletter / Stay in the Flow Banner ──
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 22,
                vertical: isDesktop ? 28 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(
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
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    alignment: Alignment.center,
                                    child: const _FooterMailIcon(color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Stay in the creative flow',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Get major feature releases, study templates, and handwriting tips. No spam, ever.',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        _buildNewsletterInput(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              alignment: Alignment.center,
                              child: const _FooterMailIcon(color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Stay in the creative flow',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Get major feature releases, study templates, and handwriting tips.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildNewsletterInput(),
                      ],
                    ),
            ),

            const SizedBox(height: 56),

            // ── Main Footer Link Grid ──
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand & Mission Column
                      Expanded(
                        flex: 3,
                        child: _buildBrandColumn(),
                      ),
                      const SizedBox(width: 48),
                      // Link Columns
                      Expanded(
                        flex: 2,
                        child: _buildFooterColumn(
                          'PRODUCT',
                          [
                            _FooterLink('Features', badge: 'NEW'),
                            _FooterLink('Inking Canvas'),
                            _FooterLink('PDF & Slides'),
                            _FooterLink('AI Studio'),
                            _FooterLink('Multi-Device Sync'),
                            _FooterLink('Pricing Plans'),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildFooterColumn(
                          'USE CASES',
                          [
                            _FooterLink('Students & Medical'),
                            _FooterLink('Engineers & Tech'),
                            _FooterLink('Creators & Artists'),
                            _FooterLink('Deep Researchers'),
                            _FooterLink('Template Gallery'),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildFooterColumn(
                          'RESOURCES',
                          [
                            _FooterLink('Documentation'),
                            _FooterLink('Study Guides'),
                            _FooterLink('Help Center & FAQ'),
                            _FooterLink('Changelog'),
                            _FooterLink('Discord Community'),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildFooterColumn(
                          'COMPANY',
                          [
                            _FooterLink('About Notelekh'),
                            _FooterLink('Careers', badge: 'HIRING'),
                            _FooterLink('Privacy & Security'),
                            _FooterLink('Terms of Service'),
                            _FooterLink('Security Whitepaper'),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrandColumn(),
                      const SizedBox(height: 40),
                      Wrap(
                        spacing: 48,
                        runSpacing: 36,
                        children: [
                          _buildFooterColumn(
                            'PRODUCT',
                            [
                              _FooterLink('Features', badge: 'NEW'),
                              _FooterLink('Inking Canvas'),
                              _FooterLink('PDF & Slides'),
                              _FooterLink('AI Studio'),
                              _FooterLink('Pricing Plans'),
                            ],
                          ),
                          _buildFooterColumn(
                            'USE CASES',
                            [
                              _FooterLink('Students & Medical'),
                              _FooterLink('Engineers & Tech'),
                              _FooterLink('Creators & Artists'),
                              _FooterLink('Deep Researchers'),
                            ],
                          ),
                          _buildFooterColumn(
                            'RESOURCES',
                            [
                              _FooterLink('Documentation'),
                              _FooterLink('Study Guides'),
                              _FooterLink('Help Center'),
                              _FooterLink('Changelog'),
                            ],
                          ),
                          _buildFooterColumn(
                            'COMPANY',
                            [
                              _FooterLink('About Notelekh'),
                              _FooterLink('Careers', badge: 'HIRING'),
                              _FooterLink('Privacy & Terms'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

            const SizedBox(height: 48),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 24),

            // ── Bottom Legal & Trust Bar ──
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 14,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '© 2026 Notelekh, Inc. All rights reserved.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '·  Crafted for curious minds worldwide.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsletterInput() {
    if (_subscribed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'You’re on the list! Welcome aboard.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 390;

        final inputField = Container(
          width: isNarrow ? double.infinity : 250,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _emailController,
            style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF0F172A)),
            decoration: const InputDecoration(
              hintText: 'Enter your email...',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _handleSubscribe(),
          ),
        );

        final submitBtn = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _handleSubscribe,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    'Subscribe',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              inputField,
              const SizedBox(height: 10),
              submitBtn,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            inputField,
            const SizedBox(width: 10),
            submitBtn,
          ],
        );
      },
    );
  }

  Widget _buildBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand logo & title
        const NotelekhLogo(height: 30),
        const SizedBox(height: 14),
        Text(
          'The tactile digital workspace for natural handwriting, deep thinking, PDF markup, and AI synthesis.',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        // Social icons
        Row(
          children: const [
            _SocialIconButton(icon: _SocialXIcon(color: Color(0xFF475569))),
            SizedBox(width: 10),
            _SocialIconButton(icon: _SocialGithubIcon(color: Color(0xFF475569))),
            SizedBox(width: 10),
            _SocialIconButton(icon: _SocialDiscordIcon(color: Color(0xFF475569))),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterColumn(String title, List<_FooterLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 18),
        ...links.map((link) => _FooterLinkItem(link: link)),
      ],
    );
  }
}

class _FooterLink {
  final String title;
  final String? badge;
  const _FooterLink(this.title, {this.badge});
}

class _FooterLinkItem extends StatefulWidget {
  final _FooterLink link;
  const _FooterLinkItem({required this.link});

  @override
  State<_FooterLinkItem> createState() => _FooterLinkItemState();
}

class _FooterLinkItemState extends State<_FooterLinkItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(_hovered ? 3 : 0, 0, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.link.title,
                style: GoogleFonts.inter(
                  color: _hovered ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                  fontSize: 13.5,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (widget.link.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.link.badge == 'HIRING'
                        ? const Color(0xFFFDF2F8)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.link.badge == 'HIRING'
                          ? const Color(0xFFF472B6)
                          : const Color(0xFF818CF8),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.link.badge!,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: widget.link.badge == 'HIRING'
                          ? const Color(0xFFDB2777)
                          : const Color(0xFF4F46E5),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatefulWidget {
  final Widget icon;
  const _SocialIconButton({required this.icon});

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: _hovered ? 0.08 : 0.02),
              blurRadius: _hovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: widget.icon,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL & TRUST VECTOR ICONS FOR FOOTER (Immune to Web tree-shaking)
// ─────────────────────────────────────────────────────────────────────────────

class _FooterMailIcon extends StatelessWidget {
  final Color color;
  const _FooterMailIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 14),
      painter: _FooterMailPainter(color: color),
    );
  }
}

class _FooterMailPainter extends CustomPainter {
  final Color color;
  const _FooterMailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, stroke);

    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height * 0.58)
      ..lineTo(size.width, 0);
    canvas.drawPath(flap, stroke);
  }

  @override
  bool shouldRepaint(covariant _FooterMailPainter oldDelegate) => oldDelegate.color != color;
}


class _SocialXIcon extends StatelessWidget {
  final Color color;
  const _SocialXIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _SocialXPainter(color: color),
    );
  }
}

class _SocialXPainter extends CustomPainter {
  final Color color;
  const _SocialXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.12)
      ..lineTo(size.width * 0.44, size.height * 0.52)
      ..lineTo(size.width * 0.10, size.height * 0.88)
      ..lineTo(size.width * 0.22, size.height * 0.88)
      ..lineTo(size.width * 0.50, size.height * 0.59)
      ..lineTo(size.width * 0.74, size.height * 0.88)
      ..lineTo(size.width * 0.90, size.height * 0.88)
      ..lineTo(size.width * 0.57, size.height * 0.47)
      ..lineTo(size.width * 0.88, size.height * 0.12)
      ..lineTo(size.width * 0.76, size.height * 0.12)
      ..lineTo(size.width * 0.50, size.height * 0.40)
      ..lineTo(size.width * 0.28, size.height * 0.12)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SocialXPainter oldDelegate) => oldDelegate.color != color;
}

class _SocialGithubIcon extends StatelessWidget {
  final Color color;
  const _SocialGithubIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _SocialGithubPainter(color: color),
    );
  }
}

class _SocialGithubPainter extends CustomPainter {
  final Color color;
  const _SocialGithubPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.46), size.width * 0.38, stroke);

    final leftEar = Path()
      ..moveTo(size.width * 0.22, size.height * 0.28)
      ..lineTo(size.width * 0.24, size.height * 0.12)
      ..lineTo(size.width * 0.38, size.height * 0.18);
    canvas.drawPath(leftEar, fill);

    final rightEar = Path()
      ..moveTo(size.width * 0.78, size.height * 0.28)
      ..lineTo(size.width * 0.76, size.height * 0.12)
      ..lineTo(size.width * 0.62, size.height * 0.18);
    canvas.drawPath(rightEar, fill);

    final body = Path()
      ..moveTo(size.width * 0.32, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.94, size.width * 0.68, size.height * 0.82);
    canvas.drawPath(body, stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant _SocialGithubPainter oldDelegate) => oldDelegate.color != color;
}

class _SocialDiscordIcon extends StatelessWidget {
  final Color color;
  const _SocialDiscordIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _SocialDiscordPainter(color: color),
    );
  }
}

class _SocialDiscordPainter extends CustomPainter {
  final Color color;
  const _SocialDiscordPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.14, size.width * 0.80, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.94, size.height * 0.62, size.width * 0.82, size.height * 0.84)
      ..quadraticBezierTo(size.width * 0.70, size.height * 0.78, size.width * 0.60, size.height * 0.86)
      ..lineTo(size.width * 0.54, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.80, size.width * 0.46, size.height * 0.78)
      ..lineTo(size.width * 0.40, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.78, size.width * 0.18, size.height * 0.84)
      ..quadraticBezierTo(size.width * 0.06, size.height * 0.62, size.width * 0.20, size.height * 0.22)
      ..close();
    canvas.drawPath(path, fill);

    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.36, size.height * 0.52), 1.6, eyePaint);
    canvas.drawCircle(Offset(size.width * 0.64, size.height * 0.52), 1.6, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _SocialDiscordPainter oldDelegate) => oldDelegate.color != color;
}
