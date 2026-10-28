import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';
import 'package:ai_workspace_client/features/legal/legal_screen.dart';

const _kFooterBg = Color(0xFF090D16);
const _kFooterBorder = Color(0x14FFFFFF);
const _kFooterTextMuted = Color(0xFF64748B);
const _kFooterTextSecondary = Color(0xFF94A3B8);

class LandingFooter extends StatelessWidget {
  final bool isDesktop;

  const LandingFooter({super.key, required this.isDesktop});

  void _openPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalScreen.privacyPolicy()),
    );
  }

  void _openTerms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalScreen.termsAndConditions()),
    );
  }

  void _openSecurity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalScreen.security()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _kFooterBg,
        border: Border(top: BorderSide(color: _kFooterBorder, width: 1)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 64 : 44,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Brand Overview + Structured Navigation
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Column
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const NotelekhIcon(size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Notelekh',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              'The focused digital workspace engineered for handwriting, PDF markup, and deep research.',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: _kFooterTextSecondary,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),

                    // Navigation Columns
                    Expanded(
                      flex: 2,
                      child: _buildColumn(context, 'Product', [
                        _FooterLink('Features'),
                        _FooterLink('Inking Engine'),
                        _FooterLink('PDF Markup'),
                        _FooterLink('Infinite Canvas'),
                        _FooterLink('Local Storage'),
                      ]),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildColumn(context, 'Platforms', [
                        _FooterLink('Apple iPad'),
                        _FooterLink('macOS'),
                        _FooterLink('Windows'),
                        _FooterLink('Android'),
                        _FooterLink('Web Studio'),
                      ]),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildColumn(context, 'Resources', [
                        _FooterLink('Documentation'),
                        _FooterLink('Keyboard Shortcuts'),
                        _FooterLink('Release Notes'),
                        _FooterLink('Community'),
                      ]),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildColumn(context, 'Legal & Privacy', [
                        _FooterLink('Privacy Policy', onTap: () => _openPrivacy(context)),
                        _FooterLink('Terms of Service', onTap: () => _openTerms(context)),
                        _FooterLink('Security', onTap: () => _openSecurity(context)),
                      ]),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const NotelekhIcon(size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Notelekh',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The focused digital workspace engineered for handwriting, PDF markup, and deep research.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _kFooterTextSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      spacing: 40,
                      runSpacing: 28,
                      children: [
                        SizedBox(
                          width: 140,
                          child: _buildColumn(context, 'Product', [
                            _FooterLink('Features'),
                            _FooterLink('Inking Engine'),
                            _FooterLink('PDF Markup'),
                            _FooterLink('Local Storage'),
                          ]),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildColumn(context, 'Platforms', [
                            _FooterLink('Apple iPad'),
                            _FooterLink('macOS'),
                            _FooterLink('Windows'),
                            _FooterLink('Android'),
                            _FooterLink('Web Studio'),
                          ]),
                        ),
                        SizedBox(
                          width: 140,
                          child: _buildColumn(context, 'Legal', [
                            _FooterLink('Privacy Policy', onTap: () => _openPrivacy(context)),
                            _FooterLink('Terms of Service', onTap: () => _openTerms(context)),
                            _FooterLink('Security', onTap: () => _openSecurity(context)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 48),
              const Divider(color: _kFooterBorder, height: 1),
              const SizedBox(height: 28),

              // Bottom Bar: Clean Copyright & Secondary Legal Text Links
              if (isDesktop)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '© ${DateTime.now().year} Notelekh, Inc. All rights reserved.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: _kFooterTextMuted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BottomLegalLink(
                          label: 'Privacy',
                          onTap: () => _openPrivacy(context),
                        ),
                        _dividerDot(),
                        _BottomLegalLink(
                          label: 'Terms',
                          onTap: () => _openTerms(context),
                        ),
                        _dividerDot(),
                        _BottomLegalLink(
                          label: 'Security',
                          onTap: () => _openSecurity(context),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BottomLegalLink(
                          label: 'Privacy',
                          onTap: () => _openPrivacy(context),
                        ),
                        _dividerDot(),
                        _BottomLegalLink(
                          label: 'Terms',
                          onTap: () => _openTerms(context),
                        ),
                        _dividerDot(),
                        _BottomLegalLink(
                          label: 'Security',
                          onTap: () => _openSecurity(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '© ${DateTime.now().year} Notelekh, Inc. All rights reserved.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _kFooterTextMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _dividerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '·',
        style: TextStyle(
          color: _kFooterTextMuted.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, String title, List<_FooterLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FooterLinkItem(link: link),
            )),
      ],
    );
  }
}

class _FooterLink {
  final String label;
  final VoidCallback? onTap;

  const _FooterLink(this.label, {this.onTap});
}

class _FooterLinkItem extends StatefulWidget {
  final _FooterLink link;

  const _FooterLinkItem({required this.link});

  @override
  State<_FooterLinkItem> createState() => _FooterLinkItemState();
}

class _FooterLinkItemState extends State<_FooterLinkItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasAction = widget.link.onTap != null;
    return MouseRegion(
      cursor: hasAction ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.link.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _isHovered && hasAction ? Colors.white : _kFooterTextSecondary,
            fontWeight: _isHovered && hasAction ? FontWeight.w500 : FontWeight.w400,
          ),
          child: Text(widget.link.label),
        ),
      ),
    );
  }
}

class _BottomLegalLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomLegalLink({required this.label, required this.onTap});

  @override
  State<_BottomLegalLink> createState() => _BottomLegalLinkState();
}

class _BottomLegalLinkState extends State<_BottomLegalLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: _isHovered ? Colors.white : _kFooterTextMuted,
            fontWeight: _isHovered ? FontWeight.w500 : FontWeight.w400,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
