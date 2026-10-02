import 'package:flutter/material.dart';
import 'package:ai_workspace_client/state/app_state.dart';
import 'package:ai_workspace_client/features/canvas/widgets/pen_settings_panel.dart';
export 'package:ai_workspace_client/features/canvas/widgets/pen_settings_panel.dart';

/// Comprehensive Tool Settings overlay/popover widget for fine-tuning
/// pen types, stroke widths, opacity, pressure curves, and eraser modes.
class ToolSettingsPanel extends StatelessWidget {
  final AppState state;
  final VoidCallback onClose;
  final bool isDark;

  const ToolSettingsPanel({
    super.key,
    required this.state,
    required this.onClose,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return PenSettingsPanel(
      state: state,
      onClose: onClose,
      isDark: isDark,
    );
  }
}
