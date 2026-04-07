/// 预设列表项（轻量，用于列表展示）
class PresetInfo {
  const PresetInfo({
    required this.name,
    required this.filename,
    required this.promptCount,
    required this.enabledCount,
  });

  final String name;
  final String filename;
  final int promptCount;
  final int enabledCount;

  factory PresetInfo.fromJson(Map<String, dynamic> json) {
    return PresetInfo(
      name: json['name'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      promptCount: json['prompt_count'] as int? ?? 0,
      enabledCount: json['enabled_count'] as int? ?? 0,
    );
  }
}

/// 单条预设词条
class PresetPromptEntry {
  const PresetPromptEntry({
    required this.identifier,
    required this.name,
    required this.role,
    required this.content,
    this.isMarker = false,
    this.systemPrompt = false,
  });

  final String identifier;
  final String name;
  final String role;
  final String content;
  final bool isMarker;
  final bool systemPrompt;

  factory PresetPromptEntry.fromJson(Map<String, dynamic> json) {
    return PresetPromptEntry(
      identifier: json['identifier'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'system',
      content: json['content'] as String? ?? '',
      isMarker: json['marker'] as bool? ?? false,
      systemPrompt: json['system_prompt'] as bool? ?? false,
    );
  }
}

/// prompt_order 里的排序项
class PresetOrderItem {
  const PresetOrderItem({
    required this.identifier,
    required this.enabled,
  });

  final String identifier;
  final bool enabled;

  factory PresetOrderItem.fromJson(Map<String, dynamic> json) {
    return PresetOrderItem(
      identifier: json['identifier'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

/// 预设详情（完整数据）
class PresetDetail {
  const PresetDetail({
    required this.name,
    required this.filename,
    required this.prompts,
    required this.promptOrder,
    required this.params,
  });

  final String name;
  final String filename;
  final List<PresetPromptEntry> prompts;
  final List<PresetOrderItem> promptOrder;
  final Map<String, dynamic> params;

  /// 根据 identifier 查找词条
  PresetPromptEntry? findPrompt(String identifier) {
    try {
      return prompts.firstWhere((p) => p.identifier == identifier);
    } catch (_) {
      return null;
    }
  }

  factory PresetDetail.fromJson(Map<String, dynamic> json) {
    final prompts = (json['prompts'] as List<dynamic>? ?? [])
        .map((p) => PresetPromptEntry.fromJson(p as Map<String, dynamic>))
        .toList();

    // prompt_order[1] 是自定义词条排序（character_id: 100001）
    final orderList = json['prompt_order'] as List<dynamic>? ?? [];
    List<PresetOrderItem> order = [];
    if (orderList.length > 1) {
      final customOrder = orderList[1] as Map<String, dynamic>;
      order = (customOrder['order'] as List<dynamic>? ?? [])
          .map((o) => PresetOrderItem.fromJson(o as Map<String, dynamic>))
          .toList();
    } else if (orderList.isNotEmpty) {
      final defaultOrder = orderList[0] as Map<String, dynamic>;
      order = (defaultOrder['order'] as List<dynamic>? ?? [])
          .map((o) => PresetOrderItem.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    return PresetDetail(
      name: json['name'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      prompts: prompts,
      promptOrder: order,
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }
}
