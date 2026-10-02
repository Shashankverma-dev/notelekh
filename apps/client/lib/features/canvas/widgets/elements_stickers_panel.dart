import 'package:flutter/material.dart';

enum ElementItemType {
  emoji,
  badge,
  shape,
}

class CanvasElementItemData {
  final String label;
  final ElementItemType type;
  final String content; // emoji char, badge text, or shape id
  final Color? color;
  final Color? textColor;

  const CanvasElementItemData({
    required this.label,
    required this.type,
    required this.content,
    this.color,
    this.textColor,
  });
}

class ElementsStickersPanel extends StatefulWidget {
  final Function(CanvasElementItemData item) onSelectElement;
  final VoidCallback onClose;
  final bool isDark;

  const ElementsStickersPanel({
    super.key,
    required this.onSelectElement,
    required this.onClose,
    this.isDark = true,
  });

  @override
  State<ElementsStickersPanel> createState() => _ElementsStickersPanelState();
}

class _ElementsStickersPanelState extends State<ElementsStickersPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const List<String> _studyEmojis = [
    '⭐', '✨', '🔥', '💡', '📌', '📍', '📝', '📖', '📚', '🎯',
    '✅', '❌', '⚠️', '❓', '❗', '💯', '🏆', '🎉', '🧠', '🔬',
    '💻', '⏱️', '📅', '🚀', '🎨', '📐', '📊', '📈', '🏷️', '🔖',
    '❤️', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '👍', '👏',
    '🙌', '🤔', '🧐', '🤓', '🥳', '😎', '😴', '☕', '🍎', '🥑',
  ];

  static const List<CanvasElementItemData> _badges = [
    CanvasElementItemData(
      label: 'IMPORTANT',
      type: ElementItemType.badge,
      content: '⚡ IMPORTANT',
      color: Color(0xFFFEE2E2),
      textColor: Color(0xFFDC2626),
    ),
    CanvasElementItemData(
      label: 'TODO',
      type: ElementItemType.badge,
      content: '📋 TO-DO',
      color: Color(0xFFFEF3C7),
      textColor: Color(0xFFD97706),
    ),
    CanvasElementItemData(
      label: 'KEY CONCEPT',
      type: ElementItemType.badge,
      content: '🔑 KEY CONCEPT',
      color: Color(0xFFEDE9FE),
      textColor: Color(0xFF7C3AED),
    ),
    CanvasElementItemData(
      label: 'REVISE',
      type: ElementItemType.badge,
      content: '🔄 REVISE',
      color: Color(0xFFE0E7FF),
      textColor: Color(0xFF4F46E5),
    ),
    CanvasElementItemData(
      label: 'COMPLETED',
      type: ElementItemType.badge,
      content: '✅ COMPLETED',
      color: Color(0xFFD1FAE5),
      textColor: Color(0xFF059669),
    ),
    CanvasElementItemData(
      label: 'EXAM NOTE',
      type: ElementItemType.badge,
      content: '🎯 EXAM NOTE',
      color: Color(0xFFFCE7F3),
      textColor: Color(0xFFDB2777),
    ),
    CanvasElementItemData(
      label: 'QUESTION',
      type: ElementItemType.badge,
      content: '❓ QUESTION?',
      color: Color(0xFFCFFAFE),
      textColor: Color(0xFF0891B2),
    ),
    CanvasElementItemData(
      label: 'DEFINITION',
      type: ElementItemType.badge,
      content: '📖 DEFINITION',
      color: Color(0xFFF3E8FF),
      textColor: Color(0xFF9333EA),
    ),
    CanvasElementItemData(
      label: 'FORMULA',
      type: ElementItemType.badge,
      content: '📐 FORMULA',
      color: Color(0xFFFFEDD5),
      textColor: Color(0xFFEA580C),
    ),
  ];

  static const List<CanvasElementItemData> _stamps = [
    CanvasElementItemData(
      label: 'Star Stamp',
      type: ElementItemType.shape,
      content: 'star',
      color: Color(0xFFF59E0B),
    ),
    CanvasElementItemData(
      label: 'Check Stamp',
      type: ElementItemType.shape,
      content: 'circle',
      color: Color(0xFF10B981),
    ),
    CanvasElementItemData(
      label: 'Card Frame',
      type: ElementItemType.shape,
      content: 'rectangle',
      color: Color(0xFF6366F1),
    ),
    CanvasElementItemData(
      label: 'Direction Arrow',
      type: ElementItemType.shape,
      content: 'arrow',
      color: Color(0xFFEC4899),
    ),
    CanvasElementItemData(
      label: 'Caution Triangle',
      type: ElementItemType.shape,
      content: 'triangle',
      color: Color(0xFFEF4444),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1E2333) : Colors.white;
    final border = widget.isDark ? const Color(0xFF2C344A) : const Color(0xFFE2E8F0);
    final textCol = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = widget.isDark ? Colors.white60 : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        height: 440,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Elements & Stickers',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: subTextCol),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF252C40) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: subTextCol),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().toLowerCase();
                          });
                        },
                        style: TextStyle(color: textCol, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search elements...',
                          hintStyle: TextStyle(color: subTextCol, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close, size: 16, color: subTextCol),
                      ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 2.5,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: subTextCol,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Emojis'),
                Tab(text: 'Badges'),
                Tab(text: 'Stamps'),
              ],
            ),

            const Divider(height: 1, thickness: 1),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmojiTab(),
                  _buildBadgesTab(),
                  _buildStampsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiTab() {
    final list = _searchQuery.isEmpty
        ? _studyEmojis
        : _studyEmojis.where((e) => e.contains(_searchQuery)).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final emoji = list[index];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            widget.onSelectElement(
              CanvasElementItemData(
                label: emoji,
                type: ElementItemType.emoji,
                content: emoji,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF252C40) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab() {
    final list = _searchQuery.isEmpty
        ? _badges
        : _badges.where((b) => b.label.toLowerCase().contains(_searchQuery)).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final badge = list[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onSelectElement(badge),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: badge.color?.withValues(alpha: 0.15) ?? Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (badge.textColor ?? Colors.blue).withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Text(
                  badge.content,
                  style: TextStyle(
                    color: badge.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: badge.textColor?.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStampsTab() {
    final list = _searchQuery.isEmpty
        ? _stamps
        : _stamps.where((s) => s.label.toLowerCase().contains(_searchQuery)).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final stamp = list[index];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onSelectElement(stamp),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF252C40) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (stamp.color ?? Colors.grey).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  stamp.content == 'star'
                      ? Icons.star_rounded
                      : (stamp.content == 'circle'
                          ? Icons.check_circle_outline_rounded
                          : (stamp.content == 'rectangle'
                              ? Icons.crop_square_rounded
                              : (stamp.content == 'arrow'
                                  ? Icons.arrow_forward_rounded
                                  : Icons.warning_amber_rounded))),
                  color: stamp.color,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  stamp.label,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
