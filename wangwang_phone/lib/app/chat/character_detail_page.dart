import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'pages/world_select_page.dart';

class CharacterDetailPage extends StatelessWidget {
  const CharacterDetailPage({
    super.key,
    required this.controller,
    required this.contact,
  });

  final ChatAppController controller;
  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E14),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildAvatar(context),
                    const SizedBox(height: 16),
                    Text(
                      contact.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contact.signature,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        contact.statusLabel,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSection(
                      title: '角色设定',
                      child: _PersonaSummaryCard(text: contact.personaSummary),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: '世界书绑定',
                      child: _WorldBindingCard(
                        controller: controller,
                        contact: contact,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: '高级设定',
                      child: _AdvancedSettingsCard(
                        contactName: contact.name,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildResetButton(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final avatarUrl = contact.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: contact.avatarColor,
      );
    }
    return CircleAvatar(
      radius: 48,
      backgroundColor: contact.avatarColor,
      child: Text(
        contact.emoji,
        style: const TextStyle(fontSize: 36),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showResetDialog(context),
        icon: const Icon(Icons.restart_alt_rounded, size: 20),
        label: const Text('重置对话'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        title: const Text('重置对话', style: TextStyle(color: Colors.white)),
        content: const Text(
          '重置后聊天记录将被清空，恢复为角色初始消息。此操作不可恢复。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              controller.clearChat(
                contactId: contact.id,
                clearMemories: false,
              );
              Navigator.pop(context);
            },
            child: const Text(
              '仅清空聊天',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              controller.clearChat(
                contactId: contact.id,
                clearMemories: true,
              );
              Navigator.pop(context);
            },
            child: const Text(
              '清空聊天+记忆',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaSummaryCard extends StatefulWidget {
  const _PersonaSummaryCard({required this.text});
  final String text;

  @override
  State<_PersonaSummaryCard> createState() => _PersonaSummaryCardState();
}

class _PersonaSummaryCardState extends State<_PersonaSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > 150;
    final displayText = (!_expanded && isLong)
        ? '${widget.text.substring(0, 150)}...'
        : widget.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? '收起' : '展开全部',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdvancedSettingsCard extends StatefulWidget {
  const _AdvancedSettingsCard({required this.contactName});
  final String contactName;

  @override
  State<_AdvancedSettingsCard> createState() => _AdvancedSettingsCardState();
}

class _AdvancedSettingsCardState extends State<_AdvancedSettingsCard> {
  bool _expanded = false;
  bool _loading = false;
  Map<String, dynamic>? _charData;

  Future<void> _fetchData() async {
    if (_charData != null || _loading) return;
    setState(() => _loading = true);
    try {
      final res = await Dio().get(
        '$kBridgeHost/characters/${Uri.encodeComponent(widget.contactName)}',
      );
      if (mounted) setState(() => _charData = res.data as Map<String, dynamic>);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _buildFields();
    // 收起时的摘要
    final summary = fields
        .where((f) => f.length > 0)
        .map((f) => '${f.label} ${f.length}字')
        .join(' · ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 点击头部展开/收起
          InkWell(
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _fetchData();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      color: Colors.purpleAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '角色卡高级定义',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_expanded && summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF2A2A3A)),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
              )
            else
              ...fields.map((f) => _FieldTile(field: f)),
          ],
        ],
      ),
    );
  }

  List<_FieldInfo> _buildFields() {
    final d = _charData;
    if (d == null) return [];
    final dp = d['depth_prompt'] as Map<String, dynamic>? ?? {};
    final dpPrompt = dp['prompt'] as String? ?? '';
    final dpDepth = dp['depth'] as int? ?? 4;
    final dpRole = dp['role'] as String? ?? 'system';

    return [
      _FieldInfo(
        label: '性格设定',
        tag: 'personality',
        content: d['personality'] as String? ?? '',
      ),
      _FieldInfo(
        label: '对话示例',
        tag: 'mes_example',
        content: d['mes_example'] as String? ?? '',
      ),
      _FieldInfo(
        label: '系统提示词',
        tag: 'system_prompt',
        content: d['system_prompt'] as String? ?? '',
      ),
      _FieldInfo(
        label: '后置指令',
        tag: 'post_history',
        content: d['post_history_instructions'] as String? ?? '',
      ),
      _FieldInfo(
        label: '深度提示词',
        tag: 'depth_prompt',
        content: dpPrompt,
        meta: dpPrompt.isNotEmpty ? 'depth=$dpDepth  role=$dpRole' : null,
      ),
    ];
  }
}

class _FieldInfo {
  const _FieldInfo({
    required this.label,
    required this.tag,
    required this.content,
    this.meta,
  });
  final String label;
  final String tag;
  final String content;
  final String? meta;

  int get length => content.length;
}

class _FieldTile extends StatefulWidget {
  const _FieldTile({required this.field});
  final _FieldInfo field;

  @override
  State<_FieldTile> createState() => _FieldTileState();
}

class _FieldTileState extends State<_FieldTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final isEmpty = f.content.isEmpty;

    return Column(
      children: [
        InkWell(
          onTap: isEmpty ? null : () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  f.label,
                  style: TextStyle(
                    color: isEmpty ? Colors.white30 : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (isEmpty)
                  const Text(
                    '未设置',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${f.length}字',
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (f.meta != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    f.meta!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
                const Spacer(),
                if (!isEmpty)
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white30,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (_open && !isEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF12121C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  f.content,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.6,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        if (!isEmpty)
          const Divider(
            height: 1,
            color: Color(0xFF2A2A3A),
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

class _WorldBindingCard extends StatelessWidget {
  const _WorldBindingCard({required this.controller, required this.contact});

  final ChatAppController controller;
  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final books =
            controller.worldBindings.character[contact.id] ?? const [];
        final subtitle = books.isEmpty ? '未绑定' : '已绑定 ${books.length} 个';
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorldSelectPage(
                  controller: controller,
                  title: '角色世界书',
                  selectedNames: books,
                  onConfirm: (names) =>
                      controller.setCharacterWorlds(contact.id, names),
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '角色专属世界书',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
