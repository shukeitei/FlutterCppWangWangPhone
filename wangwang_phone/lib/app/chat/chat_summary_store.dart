import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_models.dart';

const _chatSummaryStorageKey = 'chat_dynamic_summaries';

ChatSummaryStore buildDefaultChatSummaryStore() {
  return const SharedPreferencesChatSummaryStore();
}

abstract class ChatSummaryStore {
  const ChatSummaryStore();

  Future<Map<String, ChatSummaryEntry>> loadSummaries();

  Future<void> saveSummaries(Map<String, ChatSummaryEntry> summaries);
}

class SharedPreferencesChatSummaryStore extends ChatSummaryStore {
  const SharedPreferencesChatSummaryStore();

  /// 把动态 summary 按联系人维度落到本地，保证应用重启后还能恢复上下文摘要。
  @override
  Future<Map<String, ChatSummaryEntry>> loadSummaries() async {
    final preferences = await SharedPreferences.getInstance();
    final rawJson = preferences.getString(_chatSummaryStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    final summaries = <String, ChatSummaryEntry>{};
    decoded.forEach((contactId, value) {
      if (value is! Map<String, dynamic>) {
        return;
      }

      final content = value['content']?.toString().trim();
      final updatedAtString = value['updatedAt']?.toString();
      final updatedAt = updatedAtString == null
          ? null
          : DateTime.tryParse(updatedAtString);

      if (content == null || content.isEmpty || updatedAt == null) {
        return;
      }

      summaries[contactId] = ChatSummaryEntry(
        contactId: contactId,
        content: content,
        updatedAt: updatedAt,
      );
    });

    return summaries;
  }

  /// 使用 JSON 保存 summary，自然语言原文不拆字段，避免后续上下文重建时丢失语义。
  @override
  Future<void> saveSummaries(Map<String, ChatSummaryEntry> summaries) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final entry in summaries.entries)
        entry.key: {
          'content': entry.value.content,
          'updatedAt': entry.value.updatedAt.toIso8601String(),
        },
    });
    await preferences.setString(_chatSummaryStorageKey, encoded);
  }
}

class MemoryChatSummaryStore extends ChatSummaryStore {
  MemoryChatSummaryStore([Map<String, ChatSummaryEntry>? initialSummaries])
    : _summaries = Map<String, ChatSummaryEntry>.from(initialSummaries ?? {});

  final Map<String, ChatSummaryEntry> _summaries;

  @override
  Future<Map<String, ChatSummaryEntry>> loadSummaries() async {
    return Map<String, ChatSummaryEntry>.from(_summaries);
  }

  @override
  Future<void> saveSummaries(Map<String, ChatSummaryEntry> summaries) async {
    _summaries
      ..clear()
      ..addAll(summaries);
  }
}
