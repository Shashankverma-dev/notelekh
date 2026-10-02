import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/models/canvas_object.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedModel = 'gpt-4o-mini';
  double _penSensitivity = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.state.isDarkMode;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: isMobile ? 12 : 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              )
            : null,
        title: Text(
          'Settings & Preferences',
          style: GoogleFonts.inter(
            fontSize: isMobile ? 17 : 19,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 16),
        children: [
          // Section: Account Profile
          _sectionHeader('ACCOUNT & SECURITY', textMuted),
          _cardContainer(
            isDark: isDark,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              widget.state.displayName.isNotEmpty
                                  ? widget.state.displayName.substring(0, widget.state.displayName.length >= 2 ? 2 : 1).toUpperCase()
                                  : 'US',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.state.displayName.isNotEmpty ? widget.state.displayName : 'Workspace User',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.state.userEmail,
                                  style: TextStyle(color: textMuted, fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Cloud Synced (SQLite & Backend)',
                                      style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      widget.state.displayName.isNotEmpty
                          ? widget.state.displayName.substring(0, widget.state.displayName.length >= 2 ? 2 : 1).toUpperCase()
                          : 'US',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    widget.state.displayName.isNotEmpty ? widget.state.displayName : 'Workspace User',
                    style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.state.userEmail, style: TextStyle(color: textMuted, fontSize: 12.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Cloud Synced (SQLite & Backend)',
                            style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: AI Configuration
          _sectionHeader('AI ORCHESTRATION', textMuted),
          _cardContainer(
            isDark: isDark,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Default AI Model', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('OpenAI API credentials securely managed on the backend server', style: TextStyle(color: textMuted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedModel,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o Mini (Fast)')),
                              DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o (Multimodal)')),
                              DropdownMenuItem(value: 'o1-mini', child: Text('o1-mini (Reasoning)')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedModel = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('Default AI Model', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('OpenAI API credentials securely managed on the backend server', style: TextStyle(color: textMuted, fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: _selectedModel,
                    items: const [
                      DropdownMenuItem(value: 'gpt-4o-mini', child: Text('GPT-4o Mini (Fast)')),
                      DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o (Multimodal)')),
                      DropdownMenuItem(value: 'o1-mini', child: Text('o1-mini (Reasoning)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedModel = v);
                    },
                  ),
                ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 2),
                title: Text('Selective Context Enforcement', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Prevent unselected workspace materials from being sent to OpenAI model', style: TextStyle(color: textMuted, fontSize: 12)),
                value: true,
                onChanged: (_) {},
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Stylus & Digital Canvas
          _sectionHeader('CANVAS & STYLUS INPUT', textMuted),
          _cardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 2),
                title: Text('Hardware Pressure Sensitivity', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Supports Surface Pen, Apple Pencil, and Android Wacom styluses with pressure curves', style: TextStyle(color: textMuted, fontSize: 12)),
                value: widget.state.isStylusPressureEnabled,
                onChanged: (val) {
                  setState(() {
                    widget.state.setPressureSensitivity(val ? PressureSensitivity.medium : PressureSensitivity.off);
                  });
                },
                activeThumbColor: AppColors.primary,
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pressure Curve Sensitivity', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${(_penSensitivity * 100).toInt()}%', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Slider(
                      value: _penSensitivity,
                      min: 0.5,
                      max: 2.0,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _penSensitivity = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Appearance & Theme
          _sectionHeader('APPEARANCE', textMuted),
          _cardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 2),
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
                ),
                title: Text('Dark Theme', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Deep Slate/Zinc palette optimized for long coding and study sessions', style: TextStyle(color: textMuted, fontSize: 12)),
                value: isDark,
                onChanged: (_) => widget.state.toggleTheme(),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Workspace Session & Sign Out
          _sectionHeader('ACCOUNT & WORKSPACE', textMuted),
          _cardContainer(
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                ),
                title: Text('Sign Out of Workspace', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Exit the studio workspace and return to the Notelekh landing page', style: TextStyle(color: textMuted, fontSize: 12)),
                trailing: OutlinedButton(
                  onPressed: () async {
                    await widget.state.signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Sign Out', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // App Info
          Center(
            child: Text(
              'Notelekh AI Studio • Version 1.0.4',
              style: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.8),
      ),
    );
  }

  Widget _cardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
