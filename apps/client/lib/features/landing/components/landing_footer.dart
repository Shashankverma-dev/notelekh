import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

const _kFooterTextSecondary = Color(0xFF94A3B8);
const _kFooterTextMuted = Color(0xFF64748B);

class LandingFooter extends StatelessWidget {
  final bool isDesktop;

  const LandingFooter({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF04060E),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 64 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Top Section: Brand Info + Link Columns
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand Column
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const NotelekhIcon(size: 24),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Notelekh',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'The intelligent workspace for handwritten thoughts, deep reading, and research synthesis.',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: _kFooterTextSecondary,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),

                        // Links Columns
                        Expanded(flex: 2, child: _linkColumn('Product', ['Features', 'Inking Engine', 'PDF Markup', 'AI Studio', 'Pricing'])),
                        Expanded(flex: 2, child: _linkColumn('Platforms', ['Apple iPad', 'macOS', 'Windows', 'Android', 'Web Studio'])),
                        Expanded(flex: 2, child: _linkColumn('Resources', ['Documentation', 'Changelog', 'Keyboard Guide', 'Community', 'Status'])),
                        Expanded(flex: 2, child: _linkColumn('Legal', ['Privacy Policy', 'Terms of Service', 'Security', 'GDPR Compliance'])),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const NotelekhIcon(size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Notelekh',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The intelligent workspace for handwritten thoughts and deep reading.',
                          style: GoogleFonts.inter(fontSize: 13, color: _kFooterTextSecondary),
                        ),
                        const SizedBox(height: 36),
                        Wrap(
                          spacing: 36,
                          runSpacing: 28,
                          children: [
                            _linkColumn('Product', ['Features', 'Inking Engine', 'PDF Markup', 'AI Studio']),
                            _linkColumn('Platforms', ['iPad', 'macOS', 'Windows', 'Android']),
                            _linkColumn('Legal', ['Privacy', 'Terms', 'Security']),
                          ],
                        ),
                      ],
                    ),

              const SizedBox(height: 48),
              const Divider(color: Color(0x1AFFFFFF), height: 1),
              const SizedBox(height: 28),

              // Bottom Bar: Copyright + Operational Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© ${DateTime.now().year} Notelekh. All rights reserved.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _kFooterTextMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x1F10B981),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x3310B981)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'All Systems Operational',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6EE7B7),
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
    );
  }

  Widget _linkColumn(String title, List<String> links) {
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
              child: Text(
                link,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _kFooterTextSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            )),
      ],
    );
  }
}
