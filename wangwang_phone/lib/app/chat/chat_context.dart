import 'package:intl/intl.dart';

import 'chat_models.dart';

class ChatEmojiEntry {
  const ChatEmojiEntry({
    required this.id,
    required this.symbol,
    required this.description,
  });

  final String id;
  final String symbol;
  final String description;
}

class ChatContextConfig {
  const ChatContextConfig({
    required this.mainSystemPrompt,
    required this.userPersona,
    required this.worldBook,
    required this.preset,
    required this.maxRecentMessages,
  });

  final String mainSystemPrompt;
  final String userPersona;
  final String worldBook;
  final String preset;
  final int maxRecentMessages;
}

class ChatContextSection {
  const ChatContextSection({required this.title, required this.content});

  final String title;
  final String content;
}

class ChatContextBundle {
  const ChatContextBundle({
    required this.contactId,
    required this.systemSections,
    required this.userSections,
    required this.systemPrompt,
    required this.userPrompt,
    required this.usedSummaryBridge,
    required this.selectedMessages,
    required this.latestUserInput,
    required this.generatedAt,
  });

  final String contactId;
  final List<ChatContextSection> systemSections;
  final List<ChatContextSection> userSections;
  final String systemPrompt;
  final String userPrompt;
  final bool usedSummaryBridge;
  final List<ChatMessage> selectedMessages;
  final String latestUserInput;
  final DateTime generatedAt;
}

class ChatContextAssemblerInput {
  const ChatContextAssemblerInput({
    required this.generatedAt,
    required this.contact,
    required this.config,
    required this.summary,
    required this.memories,
    required this.recentMessages,
    required this.latestUserInput,
    required this.availableEmojis,
  });

  final DateTime generatedAt;
  final ChatContact contact;
  final ChatContextConfig config;
  final ChatSummaryEntry? summary;
  final List<ChatMemoryEntry> memories;
  final List<ChatMessage> recentMessages;
  final String latestUserInput;
  final List<ChatEmojiEntry> availableEmojis;
}

class ChatContextAssembler {
  const ChatContextAssembler();

  ChatContextBundle build(ChatContextAssemblerInput input) {
    final selectedMessages =
        input.recentMessages.length <= input.config.maxRecentMessages
        ? input.recentMessages
        : input.recentMessages.sublist(
            input.recentMessages.length - input.config.maxRecentMessages,
          );
    final usedSummaryBridge =
        input.recentMessages.length > input.config.maxRecentMessages;
    final dateFormatter = DateFormat('yyyy年MM月dd日');
    final timeFormatter = DateFormat('HH:mm');

    final systemSections = [
      ChatContextSection(
        title: '系统日期',
        content: dateFormatter.format(input.generatedAt),
      ),
      ChatContextSection(
        title: '系统时间',
        content: timeFormatter.format(input.generatedAt),
      ),
      ChatContextSection(
        title: '主系统提示词',
        content: input.config.mainSystemPrompt,
      ),
      ChatContextSection(
        title: 'AI角色人设',
        content: input.contact.personaSummary,
      ),
      ChatContextSection(title: '用户人设', content: input.config.userPersona),
      ChatContextSection(title: '世界书', content: input.config.worldBook),
      ChatContextSection(title: '预设', content: input.config.preset),
      ChatContextSection(
        title: '动态summary',
        content: input.summary?.content.isNotEmpty == true
            ? input.summary!.content
            : '暂无历史总结，优先根据当前聊天建立新的陪伴节奏。',
      ),
      ChatContextSection(
        title: 'AI角色记忆memory',
        content: input.memories.isEmpty
            ? '暂无长期记忆。'
            : input.memories
                  .map((entry) => '《${entry.title}》：${entry.content}')
                  .join('\n'),
      ),
      ChatContextSection(
        title: '可用表情包列表',
        content: input.availableEmojis
            .map((entry) => '${entry.id} ${entry.symbol}：${entry.description}')
            .join('\n'),
      ),
    ];

    final transcript = selectedMessages.isEmpty
        ? '暂无历史聊天记录。'
        : selectedMessages
              .map(
                (message) =>
                    '${message.sender == ChatMessageSender.user ? '用户' : input.contact.name}：${message.previewText}',
              )
              .join('\n');

    final userSections = [
      ChatContextSection(
        title: '最近聊天记录',
        content: usedSummaryBridge
            ? '更早聊天内容已由 summary 承接。\n$transcript'
            : transcript,
      ),
      ChatContextSection(
        title: '当前用户输入',
        content: input.latestUserInput.trim().isEmpty
            ? '暂无新的用户输入。'
            : input.latestUserInput.trim(),
      ),
    ];

    return ChatContextBundle(
      contactId: input.contact.id,
      systemSections: systemSections,
      userSections: userSections,
      systemPrompt: _mergeSections(systemSections),
      userPrompt: _mergeSections(userSections),
      usedSummaryBridge: usedSummaryBridge,
      selectedMessages: List<ChatMessage>.unmodifiable(selectedMessages),
      latestUserInput: input.latestUserInput,
      generatedAt: input.generatedAt,
    );
  }

  String _mergeSections(List<ChatContextSection> sections) {
    return sections
        .map((section) => '[${section.title}]\n${section.content}')
        .join('\n\n');
  }
}

class ChatSummaryGenerator {
  const ChatSummaryGenerator();

  /// 用自然语言压缩最近一轮会话重点，直接作为 summary 存储，不做额外结构化拆分。
  String generate({
    required ChatContact contact,
    required List<ChatMessage> messages,
  }) {
    if (messages.isEmpty) {
      return '和${contact.name}还没有形成稳定的聊天上下文。';
    }

    final recentMessages = messages.length <= 4
        ? messages
        : messages.sublist(messages.length - 4);
    final userTopics = recentMessages
        .where((message) => message.sender == ChatMessageSender.user)
        .map((message) => message.previewText)
        .toList();
    final aiTopics = recentMessages
        .where((message) => message.sender == ChatMessageSender.ai)
        .map((message) => message.previewText)
        .toList();

    final userSummary = userTopics.isEmpty
        ? '用户还没有给出新的明确信号'
        : '用户最近提到：${userTopics.join('；')}';
    final aiSummary = aiTopics.isEmpty
        ? '${contact.name}暂未给出回应'
        : '${contact.name}主要通过这些方式回应：${aiTopics.join('；')}';

    return '$userSummary。$aiSummary。后续聊天请继续保持${contact.signature}的陪伴语气。';
  }
}
