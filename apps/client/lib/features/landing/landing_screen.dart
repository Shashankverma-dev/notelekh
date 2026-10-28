// ignore_for_file: avoid_unnecessary_containers
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';
import 'package:ai_workspace_client/features/landing/components/landing_footer.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const Color _primary = Color(0xFF0F172A);
const Color _ink = Color(0xFF0F172A);
const Color _textBody = Color(0xFF475569);
const Color _textMuted = Color(0xFF94A3B8);
const Color _bgWarm = Color(0xFFFAFBFC);
const Color _bgWhite = Colors.white;

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
  final GlobalKey _platformsKey = GlobalKey();

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
                  onScrollToPlatforms: () => _scrollToKey(_platformsKey),
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
                child: KeyedSubtree(
                  key: _platformsKey,
                  child: RepaintBoundary(child: _CrossDeviceSection(isDesktop: isDesktop)),
                ),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _FinalCtaSection(isDesktop: isDesktop, onCta: _enterApp)),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: LandingFooter(isDesktop: isDesktop)),
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
              onScrollToPlatforms: () => _scrollToKey(_platformsKey),
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
    ).copyWith(fontFamilyFallback: const ['Georgia', 'serif']);

TextStyle _bodyStyle({double size = 17, Color color = _textBody}) =>
    GoogleFonts.inter(
      fontSize: size,
      color: color,
      height: 1.6,
      fontWeight: FontWeight.w400,
    ).copyWith(fontFamilyFallback: const ['Inter', 'system-ui', 'sans-serif']);

TextStyle _eyebrowStyle() => GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: _textMuted,
    ).copyWith(fontFamilyFallback: const ['Inter', 'system-ui', 'sans-serif']);

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
    child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
  );
}



// ─── Mobile Menu ─────────────────────────────────────────────────────────────
class _MobileMenu extends StatelessWidget {
  final VoidCallback onAuth;
  final VoidCallback onClose;
  final VoidCallback onScrollToTop;
  final VoidCallback onScrollToFeatures;
  final VoidCallback onScrollToPdf;
  final VoidCallback onScrollToPlatforms;

  const _MobileMenu({
    required this.onAuth,
    required this.onClose,
    required this.onScrollToTop,
    required this.onScrollToFeatures,
    required this.onScrollToPdf,
    required this.onScrollToPlatforms,
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
                // Reduced sigma: mobile menu is 96% opaque — lower blur is imperceptible.
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                      _menuLink('Features', Icons.auto_awesome_mosaic_rounded, () {
                        onClose();
                        onScrollToFeatures();
                      }),
                      _menuLink('PDF Markup', Icons.picture_as_pdf_rounded, () {
                        onClose();
                        onScrollToPdf();
                      }),
                      _menuLink('Platforms', Icons.devices_rounded, () {
                        onClose();
                        onScrollToPlatforms();
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
  final VoidCallback onScrollToPlatforms;
  final VoidCallback onMenuToggle;

  _NavBarDelegate({
    required this.isDesktop,
    required this.onAuth,
    required this.onScrollToTop,
    required this.onScrollToFeatures,
    required this.onScrollToPdf,
    required this.onScrollToPlatforms,
    required this.onMenuToggle,
  });

  @override
  double get maxExtent => 72;
  @override
  double get minExtent => 72;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scrolled = shrinkOffset > 8;
    final navContent = Container(
      height: 72,
      decoration: BoxDecoration(
        color: scrolled
            ? Colors.white.withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.96),
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
                          ).copyWith(fontFamilyFallback: const ['Inter', 'system-ui', 'sans-serif']),
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
                            const SizedBox(width: 8),
                            _NavBarItem(title: 'PDF Markup', onTap: onScrollToPdf),
                            const SizedBox(width: 8),
                            _NavBarItem(title: 'Platforms', onTap: onScrollToPlatforms),
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
                          borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(8),
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
    );

    if (scrolled) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: navContent,
        ),
      );
    }
    return navContent;
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

        // Headline: Concrete, honest product focus
        Text(
          'The digital notebook for handwriting,',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 60 : 38,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            height: 1.08,
            letterSpacing: -1.0,
          ),
        ),
        Text(
          'PDF markup & deep research.',
          style: GoogleFonts.playfairDisplay(
            fontSize: isDesktop ? 60 : 38,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            height: 1.08,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 20),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Zero-latency stylus inking, split-screen PDF annotation, and local-first storage.',
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 17 : 15,
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
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
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
                  const Color(0xFF38BDF8).withValues(alpha: 0.08),
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
            child: Icon(Icons.account_circle_outlined, size: 20, color: Color(0xFF64748B)),
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
                        'Field Topography Study',
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
                color: const Color(0xFFFEF3C7),
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
      title: 'Vector Inking',
      desc: 'Ultra-low latency stylus inking calibrated to physical pen dynamics.',
      accentColor: Color(0xFF0F172A),
      iconWidget: _FeatPenIcon(color: Color(0xFF0F172A)),
    );

    const col2 = _StudioInstrumentColumn(
      number: '02',
      tag: 'PDF & Canvas',
      title: 'PDF Markup',
      desc: 'Annotate slides and research papers with infinite expandable margins.',
      accentColor: Color(0xFF0F172A),
      iconWidget: _FeatPdfIcon(color: Color(0xFF0F172A)),
    );

    const col3 = _StudioInstrumentColumn(
      number: '03',
      tag: 'Search',
      title: 'Deep Search',
      desc: 'Instant on-device search across handwriting, typed notes, and PDF text.',
      accentColor: Color(0xFF0F172A),
      iconWidget: _FeatSearchIcon(color: Color(0xFF0F172A)),
    );

    const col4 = _StudioInstrumentColumn(
      number: '04',
      tag: 'Storage',
      title: 'Local-First',
      desc: 'Stored locally on your device in SQLite. No cloud latency, no lock-in.',
      accentColor: Color(0xFF0F172A),
      iconWidget: _FeatCloudSyncIcon(color: Color(0xFF0F172A)),
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

class _StudioInstrumentColumn extends StatelessWidget {
  final String number;
  final String tag;
  final String title;
  final String desc;
  final Color accentColor;
  final Widget iconWidget;

  const _StudioInstrumentColumn({
    required this.number,
    required this.tag,
    required this.title,
    required this.desc,
    required this.accentColor,
    required this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '// $number',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            Text(
              tag.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F5F9),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: iconWidget,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
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
                  const Color(0xFF38BDF8).withValues(alpha: 0.08),
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
                      'Vector Inking\nPrecision Study',
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
            child: Icon(Icons.account_circle_outlined, size: 20, color: Color(0xFF64748B)),
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
                color: const Color(0xFFFEF3C7),
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text('GET STARTED TODAY', style: _eyebrowStyle().copyWith(color: _primary)),
            const SizedBox(height: 16),
            Text(
              'Ready to upgrade your handwriting and research workspace?',
              textAlign: TextAlign.center,
              style: _headingStyle(isDesktop ? 42 : 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Fast, local-first inking and document study for tablet and desktop.',
              textAlign: TextAlign.center,
              style: _bodyStyle(),
            ),
            const SizedBox(height: 32),
            _primaryButton('Get started free', onCta),
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
            Text('Built for focused, undisturbed thinking.',
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

