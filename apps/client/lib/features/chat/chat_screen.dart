import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_workspace_client/core/theme/app_theme.dart';
import 'package:ai_workspace_client/core/models/message_model.dart';
import 'package:ai_workspace_client/core/models/context_item_model.dart';
import 'package:ai_workspace_client/state/app_state.dart';

class ChatScreen extends StatefulWidget {
  final AppState state;
  /// When true (split mode), every AI response is automatically placed on canvas
  final bool autoPlaceOnCanvas;

  const ChatScreen({
    super.key,
    required this.state,
    this.autoPlaceOnCanvas = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();
  final FocusNode              _focusNode  = FocusNode();

  // Dot animation for streaming indicator
  late AnimationController _dotAnim;
  bool _wasStreaming = false;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _dotAnim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    if (_wasStreaming && !widget.state.isStreaming) {
      _scrollToBottom();
    }
    _wasStreaming = widget.state.isStreaming;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textCtrl.text.trim();
    if (text.isNotEmpty && !widget.state.isStreaming) {
      _textCtrl.clear();
      widget.state.sendMessage(text);
      _scrollToBottom();
      _focusNode.requestFocus();
    }
  }

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = widget.state.isDarkMode;
    final bg          = isDark ? AppColors.darkBg          : AppColors.lightBg;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted   = isDark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;
    final messages    = widget.state.currentMessages;

    if (widget.state.isStreaming) _scrollToBottom();

    return Scaffold(
      backgroundColor: bg,
      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.state.currentConversation?.title ?? 'AI Chat',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        widget.autoPlaceOnCanvas
                            ? 'Answers appear on canvas automatically'
                            : 'GPT-4o mini · Ready',
                        style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // New conversation
          Tooltip(
            message: 'New conversation',
            child: InkWell(
              onTap: () {
                widget.state.startNewChat();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.add_circle_outline_rounded, size: 20, color: textMuted),
              ),
            ),
          ),
          // Save to workspace
          Tooltip(
            message: 'Save to workspace',
            child: InkWell(
              onTap: () => _showSaveToWorkspaceDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  widget.state.currentConversation?.workspaceId != null
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  size: 20,
                  color: widget.state.currentConversation?.workspaceId != null
                      ? AppColors.primary
                      : textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty && !widget.state.isStreaming
                ? _buildEmptyState(isDark, textPrimary, textMuted)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    itemCount: messages.length + (widget.state.isStreaming ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i < messages.length) {
                        return _MessageBubble(
                          msg: messages[i],
                          isDark: isDark,
                          showPinToCanvas: true,
                          onPin: (content) {
                            widget.state.insertAIResponseToCanvas(content);
                            ScaffoldMessenger.of(context).showSnackBar(
                              _snack('✨ Written directly onto the infinite canvas!'),
                            );
                          },
                        );
                      }
                      return _StreamingBubble(
                        isDark: isDark,
                        text: widget.state.currentStreamingText,
                        dotAnim: _dotAnim,
                      );
                    },
                  ),
          ),

          // Context tray
          if (widget.state.selectedContextItems.isNotEmpty)
            _ContextTrayBar(state: widget.state, isDark: isDark),

          // Auto-canvas notification strip
          if (widget.state.autoWriteToCanvas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: AppColors.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'AI replies are written directly onto the infinite canvas',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: widget.state.toggleAutoWriteToCanvas,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Disable',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Composer
          _Composer(
            isDark: isDark,
            controller: _textCtrl,
            focusNode: _focusNode,
            isStreaming: widget.state.isStreaming,
            state: widget.state,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark, Color textPrimary, Color textMuted) {
    final firstName = widget.state.displayName.split(' ').first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 22),
            Text(
              'Good ${_timeOfDay()}, $firstName 👋',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What would you like to explore today?',
              style: GoogleFonts.inter(fontSize: 14, color: textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  icon: '🧠',
                  label: 'Explain my canvas notes',
                  onTap: () {
                    _textCtrl.text = 'Explain the notes on my canvas clearly.';
                    _handleSend();
                  },
                ),
                _SuggestionChip(
                  icon: '❓',
                  label: 'Generate study questions',
                  onTap: () {
                    _textCtrl.text = 'Create 5 study questions from my notes.';
                    _handleSend();
                  },
                ),
                _SuggestionChip(
                  icon: '📊',
                  label: 'Turn sketch into flowchart',
                  onTap: () {
                    _textCtrl.text = 'Convert my canvas sketch into a structured flowchart.';
                    _handleSend();
                  },
                ),
                _SuggestionChip(
                  icon: '✍️',
                  label: 'Rewrite my handwriting',
                  onTap: () {
                    _textCtrl.text = 'Transcribe and clean up my handwritten notes.';
                    _handleSend();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 2),
      );

  void _showSaveToWorkspaceDialog(BuildContext context) {
    if (widget.state.currentConversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snack('Send a message first before saving.'),
      );
      return;
    }

    String? selectedWsId = widget.state.currentWorkspace?.id ??
        (widget.state.workspaces.isNotEmpty ? widget.state.workspaces.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bookmark_add_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text('Save Conversation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose the workspace to save this conversation:',
                style: GoogleFonts.inter(fontSize: 13, color:
                    widget.state.isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedWsId,
                decoration: const InputDecoration(labelText: 'Workspace'),
                items: widget.state.workspaces.map((ws) {
                  return DropdownMenuItem<String>(value: ws.id, child: Text(ws.name));
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedWsId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedWsId != null) {
                  widget.state.saveCurrentConversationToWorkspace(selectedWsId!);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(_snack('Conversation saved!'));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isDark;
  final bool showPinToCanvas;
  final void Function(String content) onPin;

  const _MessageBubble({
    required this.msg,
    required this.isDark,
    required this.showPinToCanvas,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final isUser    = msg.role == 'user';
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Role label
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 4,
                right: isUser ? 4 : 0,
                bottom: 5,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Assistant',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'You',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.person_rounded, size: 11, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),

            // Bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark
                        ? const Color(0xFF1E2040)
                        : const Color(0xFFEEF0FF))
                    : (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Context badges
                  if (msg.selectedContext.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: msg.selectedContext.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_rounded, size: 10, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              c.title,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Content
                  isUser
                      ? SelectableText(
                          msg.content,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: textColor,
                          ),
                        )
                      : MarkdownBody(
                          data: msg.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: GoogleFonts.inter(fontSize: 14, height: 1.55, color: textColor),
                            h1: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                            h2: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                            h3: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                            code: TextStyle(
                              backgroundColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFE8EBF5),
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFE879F9) : const Color(0xFF7C3AED),
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0E1117) : const Color(0xFFF0F3FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 3),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Action row (copy + optional pin)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionPill(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    isDark: isDark,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied!', style: GoogleFonts.inter(fontSize: 12)),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  if (!isUser && showPinToCanvas) ...[
                    const SizedBox(width: 6),
                    _ActionPill(
                      icon: Icons.gesture_rounded,
                      label: 'Write on Canvas',
                      isDark: isDark,
                      color: AppColors.accent,
                      onTap: () => onPin(msg.content),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Streaming bubble ───────────────────────────────────────────────────────────
class _StreamingBubble extends StatelessWidget {
  final bool isDark;
  final String text;
  final AnimationController dotAnim;

  const _StreamingBubble({
    required this.isDark,
    required this.text,
    required this.dotAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label with animated dots
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI is writing',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 3),
                  _AnimatedDots(controller: dotAnim),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: text.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Thinking...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.55,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated dots ──────────────────────────────────────────────────────────────
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i * 0.2).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity,
                child: const Text(
                  '•',
                  style: TextStyle(fontSize: 14, color: AppColors.accent),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Context tray bar ───────────────────────────────────────────────────────────
class _ContextTrayBar extends StatelessWidget {
  final AppState state;
  final bool isDark;
  const _ContextTrayBar({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_center_focus_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(
            'Context:',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: state.selectedContextItems.map((item) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => state.removeContextItem(item),
                        child: const Icon(Icons.close_rounded, size: 12, color: AppColors.primary),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
          InkWell(
            onTap: state.clearContextTray,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                'Clear',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composer ───────────────────────────────────────────────────────────────────
class _Composer extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isStreaming;
  final AppState state;
  final VoidCallback onSend;

  const _Composer({
    required this.isDark,
    required this.controller,
    required this.focusNode,
    required this.isStreaming,
    required this.state,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textMuted   = isDark ? AppColors.darkTextMuted   : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attach canvas button
          Tooltip(
            message: 'Attach canvas to context',
            child: InkWell(
              onTap: () {
                if (state.canvasObjects.isNotEmpty) {
                  state.addContextItem(ContextItemModel(
                    id: 'canvas-${DateTime.now().millisecondsSinceEpoch}',
                    type: 'canvas',
                    title: 'Active Canvas (${state.canvasObjects.length} items)',
                    content: 'Canvas with ${state.canvasObjects.length} drawing elements.',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Canvas added to context!', style: GoogleFonts.inter(fontSize: 13)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Canvas is empty — draw something first.',
                          style: GoogleFonts.inter(fontSize: 13)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: const Icon(Icons.gesture_rounded, size: 19, color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 6,
                minLines: 1,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: isStreaming ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: isStreaming ? null : AppColors.primaryGradient,
                color: isStreaming ? (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard) : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isStreaming ? [] : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: isStreaming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action pill ────────────────────────────────────────────────────────────────
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: c, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion chip ────────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
