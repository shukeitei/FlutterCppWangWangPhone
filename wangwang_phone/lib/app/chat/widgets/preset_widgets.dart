import 'package:flutter/material.dart';
import '../chat_controller.dart';
import '../chat_preset_models.dart';

// ============================================================
// 橙色常量
// ============================================================
const Color kPresetOrange = Color(0xFFEB9132);
const Color kPresetOrangeDim = Color(0x26EB9132); // 15% 透明度

// ============================================================
// 1. 预设卡片（"我"页面用）
// ============================================================
class PresetCard extends StatelessWidget {
  const PresetCard({super.key, required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final presetName = controller.globalPresetName;
    final detail = controller.currentPresetDetail;
    final promptCount = detail?.prompts.length ?? 0;

    return GestureDetector(
      onTap: () => _showPresetListSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withAlpha(15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPresetOrangeDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.layers_rounded, color: kPresetOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '对话预设',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE8EAF0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    presetName != null
                        ? '$presetName  ·  $promptCount条词条'
                        : '未选择预设',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A6A8A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (presetName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kPresetOrangeDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '默认',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: kPresetOrange,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF3A4A6A), size: 20),
          ],
        ),
      ),
    );
  }

  void _showPresetListSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => PresetListSheet(controller: controller),
    );
  }
}

// ============================================================
// 2. 预设列表弹窗（选择预设用）
// ============================================================
class PresetListSheet extends StatefulWidget {
  const PresetListSheet({super.key, required this.controller, this.contactId});

  final ChatAppController controller;
  final String? contactId;

  @override
  State<PresetListSheet> createState() => _PresetListSheetState();
}

class _PresetListSheetState extends State<PresetListSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.presetList.isEmpty) {
      widget.controller.fetchPresetList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final list = widget.controller.presetList;
        final currentName = widget.contactId != null
            ? widget.controller.getResolvedPresetName(widget.contactId!)
            : widget.controller.globalPresetName;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽条
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '选择预设',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFC0C8D8),
                  ),
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    '加载中...',
                    style: TextStyle(color: Color(0xFF5A6A8A)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final preset = list[index];
                      final isActive = preset.name == currentName;
                      return _PresetListItem(
                        preset: preset,
                        isActive: isActive,
                        onTap: () async {
                          if (widget.contactId != null) {
                            // 从聊天设置进来的，只改单聊级别
                            widget.controller.setChatPreset(widget.contactId!, preset.name);
                            await widget.controller.fetchPresetDetail(preset.name);
                          } else {
                            // 从"我"页面进来的，改全局
                            await widget.controller.setGlobalPreset(preset.name);
                          }
                          if (context.mounted) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _PresetListItem extends StatelessWidget {
  const _PresetListItem({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  final PresetInfo preset;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isActive ? kPresetOrangeDim : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? kPresetOrange : const Color(0xFF3A4A6A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? kPresetOrange : const Color(0xFFC0C8D8),
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${preset.promptCount}条',
              style: const TextStyle(fontSize: 11, color: Color(0xFF4A5A7A)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 18,
              child: isActive
                  ? const Icon(Icons.check, color: kPresetOrange, size: 16)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 3. 聊天设置里的预设区域（可折叠 + 词条开关）
// ============================================================
class ChatPresetSection extends StatefulWidget {
  const ChatPresetSection({
    super.key,
    required this.controller,
    required this.contactId,
  });

  final ChatAppController controller;
  final String contactId;

  @override
  State<ChatPresetSection> createState() => _ChatPresetSectionState();
}

class _ChatPresetSectionState extends State<ChatPresetSection> {
  bool _expanded = false;
  bool _showToggles = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final resolvedName = widget.controller.getResolvedPresetName(widget.contactId);
        final detail = widget.controller.currentPresetDetail;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预设行（点击展开列表）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kPresetOrangeDim,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.layers_rounded, color: kPresetOrange, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '对话预设',
                            style: TextStyle(fontSize: 13, color: Color(0xFFE8EAF0)),
                          ),
                          Text(
                            resolvedName ?? '未选择',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5A6A8A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF5A6A8A),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // 展开的预设列表
            if (_expanded) ...[
              _buildPresetQuickList(),
              // 词条开关区
              if (detail != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showToggles = !_showToggles),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Text(
                          '词条开关（本聊天覆盖）',
                          style: TextStyle(fontSize: 11, color: Color(0xFF4A5A7A)),
                        ),
                        const Spacer(),
                        Icon(
                          _showToggles ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF4A5A7A),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showToggles) _buildPromptToggles(detail),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildPresetQuickList() {
    final list = widget.controller.presetList;
    final resolvedName = widget.controller.getResolvedPresetName(widget.contactId);

    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('加载中...', style: TextStyle(color: Color(0xFF5A6A8A), fontSize: 12)),
      );
    }

    // 只显示前 6 个 + 当前选中的（如果不在前 6）
    final shown = <PresetInfo>[];
    PresetInfo? activePreset;
    for (final p in list) {
      if (p.name == resolvedName) activePreset = p;
    }
    if (activePreset != null) shown.add(activePreset);
    for (final p in list) {
      if (p.name != resolvedName && shown.length < 6) shown.add(p);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final preset in shown)
            GestureDetector(
              onTap: () async {
                widget.controller.setChatPreset(widget.contactId, preset.name);
                await widget.controller.fetchPresetDetail(preset.name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: preset.name == resolvedName ? kPresetOrangeDim : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: preset.name == resolvedName ? kPresetOrange : const Color(0xFF3A4A6A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: preset.name == resolvedName ? kPresetOrange : const Color(0xFFC0C8D8),
                          fontWeight: preset.name == resolvedName ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${preset.promptCount}条',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF4A5A7A)),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 16,
                      child: preset.name == resolvedName
                          ? const Icon(Icons.check, color: kPresetOrange, size: 14)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          // "查看全部"按钮
          if (list.length > 6)
            GestureDetector(
              onTap: () => _showFullPresetList(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '查看全部预设...',
                  style: TextStyle(fontSize: 11, color: kPresetOrange),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromptToggles(PresetDetail detail) {
    final toggleItems = <PresetOrderItem>[];
    for (final orderItem in detail.promptOrder) {
      final prompt = detail.findPrompt(orderItem.identifier);
      if (prompt == null) continue;
      if (prompt.isMarker) continue;
      if (prompt.content.isEmpty) continue;
      toggleItems.add(orderItem);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final orderItem in toggleItems)
            _buildSingleToggle(detail, orderItem),
        ],
      ),
    );
  }

  Widget _buildSingleToggle(PresetDetail detail, PresetOrderItem orderItem) {
    final prompt = detail.findPrompt(orderItem.identifier)!;
    final enabled = widget.controller.resolvePromptEnabled(
      widget.contactId,
      orderItem.identifier,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              prompt.name,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? const Color(0xFFC0C8D8) : const Color(0xFF5A6A8A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              widget.controller.setChatPromptToggle(
                widget.contactId,
                orderItem.identifier,
                !enabled,
              );
            },
            child: Container(
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enabled ? kPresetOrange : const Color(0xFF2A3044),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullPresetList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => PresetListSheet(controller: widget.controller, contactId: widget.contactId),
    );
  }
}
