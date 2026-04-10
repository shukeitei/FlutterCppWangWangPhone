/// 世界书简要信息（列表用）
class WorldBookInfo {
  const WorldBookInfo({required this.name});
  final String name;
}

/// 世界书词条
class WorldBookEntry {
  const WorldBookEntry({
    required this.uid,
    required this.comment,
    required this.content,
    required this.key,
    required this.keysecondary,
    required this.constant,
    required this.disable,
    required this.position,
    required this.order,
    required this.depth,
    required this.selective,
    required this.selectiveLogic,
  });

  final int uid;
  final String comment;
  final String content;
  final List<String> key;
  final List<String> keysecondary;
  final bool constant;
  final bool disable;
  final int position;
  final int order;
  final int depth;
  final bool selective;
  final int selectiveLogic;

  factory WorldBookEntry.fromJson(Map<String, dynamic> json) {
    return WorldBookEntry(
      uid: json['uid'] ?? 0,
      comment: json['comment'] ?? '',
      content: json['content'] ?? '',
      key: List<String>.from(json['key'] ?? []),
      keysecondary: List<String>.from(json['keysecondary'] ?? []),
      constant: json['constant'] ?? false,
      disable: json['disable'] ?? false,
      position: json['position'] ?? 0,
      order: json['order'] ?? 100,
      depth: json['depth'] ?? 4,
      selective: json['selective'] ?? false,
      selectiveLogic: json['selectiveLogic'] ?? 0,
    );
  }
}

/// 世界书详情（含词条列表）
class WorldBookDetail {
  const WorldBookDetail({required this.name, required this.entries});
  final String name;
  final List<WorldBookEntry> entries;
}

/// 本地世界书绑定配置
class WorldBindings {
  WorldBindings({
    List<String>? appGlobal,
    Map<String, List<String>>? character,
    Map<String, List<String>>? chat,
    Map<String, List<String>>? group,
  })  : appGlobal = appGlobal ?? [],
        character = character ?? {},
        chat = chat ?? {},
        group = group ?? {};

  List<String> appGlobal;                    // APP全局
  Map<String, List<String>> character;       // 角色专属（key=contactId）
  Map<String, List<String>> chat;            // 单聊聊天世界书（key=contactId）
  Map<String, List<String>> group;           // 群聊全局世界书（key=groupId）

  Map<String, dynamic> toJson() => {
        'appGlobal': appGlobal,
        'character': character,
        'chat': chat,
        'group': group,
      };

  factory WorldBindings.fromJson(Map<String, dynamic> json) {
    return WorldBindings(
      appGlobal: List<String>.from(json['appGlobal'] ?? []),
      character: _mapListFromJson(json['character']),
      chat: _mapListFromJson(json['chat']),
      group: _mapListFromJson(json['group']),
    );
  }

  static Map<String, List<String>> _mapListFromJson(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), List<String>.from(v ?? [])));
  }
}
