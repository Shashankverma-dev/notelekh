import 'package:flutter/material.dart';
import 'package:ai_workspace_client/core/widgets/notelekh_logo.dart';

/// High-fidelity, hardware-accelerated skeleton screen for Notelekh workspace.
/// Replaces static spinners with a responsive, shimmering representation of the
/// actual workspace layout (sidebar + header toolbar + canvas notebook sheet).
class WorkspaceSkeletonShell extends StatefulWidget {
  final bool isDarkMode;

  const WorkspaceSkeletonShell({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<WorkspaceSkeletonShell> createState() => _WorkspaceSkeletonShellState();
}

class _WorkspaceSkeletonShellState extends State<WorkspaceSkeletonShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0C0E16) : const Color(0xFFF8FAFC);
    final sidebarBg = isDark ? const Color(0xFF121520) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF1E2536) : const Color(0xFFE5E7EB);
    final paperBg = isDark ? const Color(0xFF141824) : Colors.white;

    final baseShimmer = isDark ? const Color(0xFF1D2335) : const Color(0xFFE2E8F0);
    final highlightShimmer = isDark ? const Color(0xFF2C364F) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final gradient = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [baseShimmer, highlightShimmer, baseShimmer],
            stops: [
              (_controller.value - 0.3).clamp(0.0, 1.0),
              _controller.value.clamp(0.0, 1.0),
              (_controller.value + 0.3).clamp(0.0, 1.0),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              final isTablet = constraints.maxWidth >= 600 && !isDesktop;

              return Row(
                children: [
                  // ── Left Sidebar (Desktop) / Rail (Tablet) ────────────────
                  if (isDesktop)
                    _buildSidebar(sidebarBg, borderColor, gradient, isDark)
                  else if (isTablet)
                    _buildRail(sidebarBg, borderColor, gradient, isDark),

                  // ── Main Workspace Area ──────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        // Top Header Bar
                        _buildTopHeader(borderColor, gradient, isDark, isDesktop),

                        // Document Canvas Sheet
                        Expanded(
                          child: Container(
                            color: bgColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 40 : 16,
                              vertical: 24,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 860),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: paperBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.3 : 0.04,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title skeleton
                                      _box(gradient, width: 260, height: 28, radius: 8),
                                      const SizedBox(height: 14),

                                      // Subtitle / tags row
                                      Row(
                                        children: [
                                          _box(gradient, width: 90, height: 16, radius: 4),
                                          const SizedBox(width: 12),
                                          _box(gradient, width: 64, height: 16, radius: 4),
                                          const SizedBox(width: 12),
                                          _box(gradient, width: 80, height: 16, radius: 4),
                                        ],
                                      ),
                                      const SizedBox(height: 28),
                                      Divider(color: borderColor, height: 1),
                                      const SizedBox(height: 24),

                                      // Paragraph line skeletons of natural varying widths
                                      _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      const SizedBox(height: 12),
                                      FractionallySizedBox(
                                        widthFactor: 0.92,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      ),
                                      const SizedBox(height: 12),
                                      FractionallySizedBox(
                                        widthFactor: 0.84,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      ),
                                      const SizedBox(height: 12),
                                      FractionallySizedBox(
                                        widthFactor: 0.96,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      ),
                                      const SizedBox(height: 12),
                                      FractionallySizedBox(
                                        widthFactor: 0.65,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      ),
                                      const SizedBox(height: 28),

                                      // Canvas sketch / card block placeholder
                                      Container(
                                        width: double.infinity,
                                        height: 130,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: borderColor.withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _box(gradient, width: 140, height: 16, radius: 4),
                                            const SizedBox(height: 12),
                                            FractionallySizedBox(
                                              widthFactor: 0.88,
                                              alignment: Alignment.centerLeft,
                                              child: _box(gradient, width: double.infinity, height: 12, radius: 4),
                                            ),
                                            const SizedBox(height: 8),
                                            FractionallySizedBox(
                                              widthFactor: 0.52,
                                              alignment: Alignment.centerLeft,
                                              child: _box(gradient, width: double.infinity, height: 12, radius: 4),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // More line skeletons
                                      FractionallySizedBox(
                                        widthFactor: 0.90,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
                                      ),
                                      const SizedBox(height: 12),
                                      FractionallySizedBox(
                                        widthFactor: 0.74,
                                        alignment: Alignment.centerLeft,
                                        child: _box(gradient, width: double.infinity, height: 14, radius: 4),
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
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSidebar(Color bg, Color borderColor, Gradient gradient, bool isDark) {
    return Container(
      width: 255,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1.2)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Title
          Row(
            children: [
              NotelekhIcon(size: 28),
              const SizedBox(width: 10),
              _box(gradient, width: 95, height: 18, radius: 4),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar placeholder
          _box(gradient, width: double.infinity, height: 38, radius: 10),
          const SizedBox(height: 16),

          // Workspace dropdown placeholder
          _box(gradient, width: double.infinity, height: 40, radius: 8),
          const SizedBox(height: 20),

          // Section Title
          _box(gradient, width: 80, height: 12, radius: 3),
          const SizedBox(height: 14),

          // Notebook list items
          for (int i = 0; i < 4; i++) ...[
            Row(
              children: [
                _box(gradient, width: 32, height: 32, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(gradient, width: (110 - i * 12).toDouble(), height: 13, radius: 4),
                      const SizedBox(height: 6),
                      _box(gradient, width: 55, height: 10, radius: 3),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          const Spacer(),

          // Bottom profile pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                _circle(gradient, 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(gradient, width: 80, height: 12, radius: 3),
                      const SizedBox(height: 4),
                      _box(gradient, width: 50, height: 9, radius: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(Color bg, Color borderColor, Gradient gradient, bool isDark) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          NotelekhIcon(size: 30),
          const SizedBox(height: 24),
          for (int i = 0; i < 4; i++) ...[
            _box(gradient, width: 38, height: 38, radius: 10),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          _circle(gradient, 32),
        ],
      ),
    );
  }

  Widget _buildTopHeader(Color borderColor, Gradient gradient, bool isDark, bool isDesktop) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Document title placeholder
          _box(gradient, width: 160, height: 18, radius: 4),
          const Spacer(),

          // Drawing toolbar pills
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  for (int t = 0; t < 5; t++) ...[
                    _box(gradient, width: 28, height: 28, radius: 6),
                    if (t < 4) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Page counter pill & actions
          _box(gradient, width: 72, height: 28, radius: 6),
          const SizedBox(width: 12),
          _circle(gradient, 28),
          const SizedBox(width: 12),
          _circle(gradient, 32),
        ],
      ),
    );
  }

  Widget _box(
    Gradient gradient, {
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _circle(Gradient gradient, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
      ),
    );
  }
}
