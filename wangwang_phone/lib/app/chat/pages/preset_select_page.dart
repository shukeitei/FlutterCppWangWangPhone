import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_preset_models.dart';

/// Preset 选择页（两段式）：
/// 上半显示预设列表，下半显示当前选中预设的词条开关。
class PresetSelectPage extends StatefulWidget {
  const PresetSelectPage({
    super.key,
    required this.presets,
    required this.currentPresetName,
    required this.contactId,
    required this.controller,
  });

  /// 预设列表，每项是 PresetInfo（name, promptCount, enabledCount）
  final List<PresetInfo> presets;
  final String? currentPresetName;
  final String contactId;
  final ChatAppController controller;

  @override
  State<PresetSelectPage> createState() => _PresetSelectPageState();
}

class _PresetSelectPageState extends State<PresetSelectPage> {
  String? _selectedPresetName;
  PresetDetail? _presetDetail;
  bool _isLoading = false;
  late final List<PresetInfo> _sortedPresets;

  @override
  void initState() {
    super.initState();
    _sortedPresets = List<PresetInfo>.from(widget.presets)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _selectedPresetName = widget.currentPresetName;
    if (_selectedPresetName != null && _selectedPresetName!.isNotEmpty) {
      _loadDetail(_selectedPresetName!);
    }
  }

  Future<void> _loadDetail(String name) async {
    setState(() => _isLoading = true);
    await widget.controller.fetchPresetDetail(name);
    if (!mounted) return;
    setState(() {
      _presetDetail = widget.controller.currentPresetDetail;
      _isLoading = false;
    });
  }

  Future<void> _handlePresetTap(String name) async {
    setState(() {
      _selectedPresetName = name;
    });
    widget.controller.setChatPreset(widget.contactId, name);
    await _loadDetail(name);
  }

  /// 过滤掉 marker 和空内容词条，得到可开关的词条列表
  List<PresetOrderItem> _toggleableItems(PresetDetail detail) {
    final items = <PresetOrderItem>[];
    for (final orderItem in detail.promptOrder) {
      final prompt = detail.findPrompt(orderItem.identifier);
      if (prompt == null) continue;
      if (prompt.isMarker) continue;
      if (prompt.content.isEmpty) continue;
      items.add(orderItem);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择对话预设'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 上：预设列表
          SizedBox(
            height: 240,
            child: _sortedPresets.isEmpty
                ? const Center(child: Text('没有可用的预设'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _sortedPresets.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) {
                      final p = _sortedPresets[index];
                      final name = p.name;
                      final promptCount = p.promptCount;
                      final enabledCount = p.enabledCount;
                      final isSelected = name == _selectedPresetName;

                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.layers_outlined,
                              color: Color(0xFFFF9500), size: 20),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '$enabledCount / $promptCount 个词条启用',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFFFF9500))
                            : null,
                        onTap: () => _handlePresetTap(name),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // 中：词条标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '词条列表',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                if (_presetDetail != null)
                  Text(
                    '(${_toggleableItems(_presetDetail!).where((o) => widget.controller.resolvePromptEnabled(widget.contactId, o.identifier)).length}个启用)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),

          // 下：词条列表 + 开关
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _presetDetail == null
                    ? const Center(child: Text('选择一个预设查看词条'))
                    : _buildToggleList(_presetDetail!),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleList(PresetDetail detail) {
    final items = _toggleableItems(detail);
    if (items.isEmpty) {
      return const Center(child: Text('该预设没有可开关的词条'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final orderItem = items[index];
        final prompt = detail.findPrompt(orderItem.identifier)!;
        final enabled = widget.controller
            .resolvePromptEnabled(widget.contactId, orderItem.identifier);
        return ListTile(
          title: Text(
            prompt.name,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            prompt.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: Switch(
            value: enabled,
            activeColor: const Color(0xFFFF9500),
            onChanged: (val) {
              widget.controller.setChatPromptToggle(
                widget.contactId,
                orderItem.identifier,
                val,
              );
              setState(() {});
            },
          ),
        );
      },
    );
  }
}
