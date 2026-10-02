import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_workspace_client/features/legal/legal_screen.dart';
import 'package:web/web.dart' as web;

class CookieConsentBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  
  const CookieConsentBanner({super.key, required this.onDismiss});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  void _acceptCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_consented_to_cookies', true);
    } catch (_) {}

    if (kIsWeb) {
      try {
        web.window.localStorage.setItem('has_consented_to_cookies', 'true');
        web.document.cookie = 'notelekh_cookie_consent=accepted; path=/; max-age=31536000; SameSite=Lax';
      } catch (_) {}
    }

    widget.onDismiss();
  }

  void _declineCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_consented_to_cookies', false);
    } catch (_) {}

    if (kIsWeb) {
      try {
        web.window.localStorage.setItem('has_consented_to_cookies', 'false');
        web.document.cookie = 'notelekh_cookie_consent=declined; path=/; max-age=86400; SameSite=Lax';
      } catch (_) {}
    }

    widget.onDismiss();
  }

  void _showPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LegalScreen(
          title: 'Cookie Policy',
          content: 'We use cookies and local storage to enhance your browsing experience, remember your preferences, and maintain secure authentication sessions. Essential cookies are required for Notelekh to function properly. By clicking "Accept", you consent to our use of cookies as described in this policy.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 680;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: isCompact ? 16 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isCompact ? _buildCompactLayout() : _buildWideLayout(),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.cookie_outlined, color: Color(0xFF4F46E5), size: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We value your privacy',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                children: [
                  Text(
                    'We use essential cookies to maintain your workspace session and improve note performance. ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _showPolicy,
                      child: Text(
                        'Read Cookie Policy.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _declineCookies,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Decline',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _acceptCookies,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Accept',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.cookie_outlined, color: Color(0xFF4F46E5), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'We value your privacy',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
              onPressed: _declineCookies,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'We use essential cookies to keep you signed in and secure your notes.',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _showPolicy,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: Text(
                'Policy',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _declineCookies,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                'Decline',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _acceptCookies,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Accept',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
