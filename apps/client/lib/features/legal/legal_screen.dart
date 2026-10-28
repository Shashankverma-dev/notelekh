import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
  });

  static Widget privacyPolicy() {
    return const LegalScreen(
      title: 'Privacy Policy',
      content: '''
1. Introduction & Overview
Notelekh is built with a local-first philosophy. We prioritize your privacy and data sovereignty above all else. Your handwriting, notes, drawings, sketches, and annotated PDF files remain on your device and are processed locally by default.

2. Information We Collect
We collect only the minimal information required to authenticate and operate your account:
* Account Credentials: When you create an account, we store your email address and an encrypted authentication token.
* Sync Metadata: If you enable cloud synchronization, notes and metadata (such as note titles, folder structure, and timestamps) are encrypted during transit and stored securely on our sync servers.
* Client Diagnostics: Anonymous, aggregated technical diagnostics (such as crash logs and OS version) may be collected solely to maintain application reliability. We never collect or inspect handwritten contents, stroke coordinates, or PDF text.

3. Local-First Storage & Offline Operation
Your canvas data is written directly to local on-device SQLite storage. You can use Notelekh completely offline without an internet connection. We do not sell, rent, monetize, or train machine learning models on your personal notes.

4. Third-Party Integrations
If you choose to use optional cloud features (such as external cloud backup), data is transferred directly according to your chosen provider's security standards. No advertising trackers, third-party analytics pixels, or data brokers are integrated into Notelekh.

5. Data Retention & Deletion
You retain complete ownership and control of your data. You may export your notes in open vector and PDF formats at any time. When you delete a note or delete your account, your data is permanently expunged from our synchronization servers without delay.

6. Your Rights
Under GDPR, CCPA, and applicable data privacy regulations, you have the right to inspect, export, correct, or delete any personal information held by Notelekh.

7. Contact & Inquiries
For privacy questions, data requests, or compliance inquiries, please contact our security team at privacy@notelekh.com.
''',
    );
  }

  static Widget termsAndConditions() {
    return const LegalScreen(
      title: 'Terms of Service',
      content: '''
1. Agreement to Terms
By accessing or using Notelekh across web, desktop, or mobile applications, you agree to be bound by these Terms of Service. If you do not agree to these terms, do not access or use the application.

2. Intellectual Property & User Ownership
You retain 100% intellectual property ownership of all notes, vector inking, drawings, formulas, annotations, and documents created or imported into Notelekh. Notelekh does not claim any license, copyright, or ownership over your personal creations.

3. Acceptable Use
You agree to use Notelekh in compliance with all applicable laws and regulations. You may not:
* Attempt to reverse engineer, decompile, or compromise the security of Notelekh services.
* Use Notelekh to store or distribute malicious software or unlawful materials.
* Abuse or overload synchronization and backend infrastructure.

4. Subscription & Billing
Certain premium capabilities, expanded cloud sync storage, or organizational features may require a paid subscription. Billing terms, renewal dates, and cancellation procedures are transparently presented prior to purchase. You may cancel your subscription at any time.

5. Warranty Disclaimer
Notelekh is provided on an "as is" and "as available" basis without warranties of any kind, whether express or implied. While we employ rigorous local persistence and data integrity verification, you are encouraged to maintain regular backups of essential work.

6. Limitation of Liability
To the maximum extent permitted by applicable law, Notelekh and its team shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service.

7. Changes to Terms
We may update these terms periodically to reflect product improvements or regulatory requirements. Continued use of Notelekh constitutes acceptance of updated terms.

8. Contact Information
For legal notices, business inquiries, or questions regarding these Terms, contact legal@notelekh.com.
''',
    );
  }

  static Widget security() {
    return const LegalScreen(
      title: 'Security Architecture',
      content: '''
1. Local-First Security Architecture
Notelekh's core security model is founded on local data sovereignty. Notes, vector strokes, and PDF documents are written directly to your device's local database before any optional network activity.

2. Encryption in Transit and at Rest
All network communications with synchronization endpoints utilize TLS 1.3 with modern cipher suites. Cloud synchronization backups are stored encrypted at rest using industry-standard AES-256 encryption.

3. Zero Telemetry on Note Content
We do not log, parse, analyze, or inspect your handwriting or document contents. No telemetry agents or marketing tracking pixels are present in Notelekh.

4. Account Protection
Authentication is guarded by industry-standard token-based protocols. We enforce strict session validation and immediate revocation upon logout.

5. Vulnerability Reporting
We welcome responsible security disclosures. If you discover a potential vulnerability, please report it to security@notelekh.com for prompt investigation and resolution.
''',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Effective Date: January 1, 2026',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 32),
                Text(
                  content.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.75,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
