import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_models.dart';

class ChatAppController extends ChangeNotifier {
  ChatAppController.seeded()
    : _contacts = List<ChatContact>.from(ChatSeedData.contacts),
      _threads = Map<String, ChatThread>.from(ChatSeedData.threads),
      _messages = {
        for (final entry in ChatSeedData.messages.entries)
          entry.key: List<ChatMessage>.from(entry.value),
      },
      _moments = List<MomentPost>.from(ChatSeedData.moments),
      _profile = ChatSeedData.profile;

  final List<ChatContact> _contacts;
  final Map<String, ChatThread> _threads;
  final Map<String, List<ChatMessage>> _messages;
  final List<MomentPost> _moments;
  final UserProfile _profile;
  final Set<String> _typingContacts = <String>{};

  ChatTab _currentTab = ChatTab.chats;
  String? _activeConversationId;
  bool _disposed = false;

  ChatTab get currentTab => _currentTab;

  UserProfile get profile => _profile;

  List<ChatContact> get contacts => List<ChatContact>.unmodifiable(_contacts);

  List<MomentPost> get moments {
    final sortedMoments = List<MomentPost>.from(_moments)
      ..sort((left, right) => right.publishedAt.compareTo(left.publishedAt));
    return List<MomentPost>.unmodifiable(sortedMoments);
  }

  List<ChatThread> get threads {
    final sortedThreads = _threads.values.toList()
      ..sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        return right.updatedAt.compareTo(left.updatedAt);
      });
    return List<ChatThread>.unmodifiable(sortedThreads);
  }

  ChatContact contactById(String contactId) {
    return _contacts.firstWhere((contact) => contact.id == contactId);
  }

  ChatThread threadById(String contactId) {
    return _threads[contactId]!;
  }

  List<ChatMessage> messagesFor(String contactId) {
    return List<ChatMessage>.unmodifiable(_messages[contactId] ?? const []);
  }

  bool isTyping(String contactId) => _typingContacts.contains(contactId);

  void selectTab(ChatTab nextTab) {
    if (nextTab == _currentTab) {
      return;
    }

    _currentTab = nextTab;
    notifyListeners();
  }

  void openConversation(String contactId) {
    _activeConversationId = contactId;
    _markThreadRead(contactId);
  }

  void closeConversation(String contactId) {
    if (_activeConversationId != contactId) {
      return;
    }
    _activeConversationId = null;
  }

  ChatContact addContact({
    required String name,
    required String signature,
    required String personaSummary,
    String initialGreeting = '',
  }) {
    final trimmedName = name.trim();
    final trimmedSignature = signature.trim();
    final trimmedPersona = personaSummary.trim();
    final trimmedGreeting = initialGreeting.trim();

    final contactId = _buildContactId(trimmedName);
    final contact = ChatContact(
      id: contactId,
      name: trimmedName,
      signature: trimmedSignature.isEmpty ? '新的陪伴角色已加入。' : trimmedSignature,
      personaSummary: trimmedPersona,
      statusLabel: '在线 · 刚加入汪汪机',
      avatarColor: _colorForContact(contactId),
      emoji: _avatarLabelForName(trimmedName),
    );

    final introMessage = trimmedGreeting.isEmpty
        ? '你好呀，我是${contact.name}。我已经准备好认识你了，想先从今天的心情开始聊吗？'
        : trimmedGreeting;

    final now = DateTime.now();
    _contacts.insert(0, contact);
    _threads[contactId] = ChatThread(
      contactId: contactId,
      lastMessage: introMessage,
      updatedAt: now,
      unreadCount: 1,
    );
    _messages[contactId] = [
      ChatMessage(
        id: '$contactId-${now.microsecondsSinceEpoch}',
        contactId: contactId,
        sender: ChatMessageSender.ai,
        text: introMessage,
        sentAt: now,
      ),
    ];

    notifyListeners();
    return contact;
  }

  MomentPost addMoment({
    required String contactId,
    required String content,
    required String moodLabel,
  }) {
    final now = DateTime.now();
    final moment = MomentPost(
      id: 'moment-${now.microsecondsSinceEpoch}',
      contactId: contactId,
      content: content.trim(),
      publishedAt: now,
      likes: 0,
      comments: 0,
      moodLabel: moodLabel.trim().isEmpty ? '今日分享' : moodLabel.trim(),
    );

    _moments.insert(0, moment);
    notifyListeners();
    return moment;
  }

  ChatContact importContactFromText({
    required String fileName,
    required String content,
  }) {
    final draft = draftFromImportedText(fileName: fileName, content: content);
    return addContact(
      name: draft.name,
      signature: draft.signature,
      personaSummary: draft.personaSummary,
      initialGreeting: draft.initialGreeting,
    );
  }

  /// 把导入的 TXT 文本转换成联系人草稿，优先解析结构化字段，解析不到再回退到摘要提取。
  ChatContactDraft draftFromImportedText({
    required String fileName,
    required String content,
  }) {
    final normalizedContent = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final lines = normalizedContent
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final fileBaseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final name =
        _extractField(lines: lines, keys: const ['名字', '名称', '角色名', 'name']) ??
        (fileBaseName.trim().isNotEmpty ? fileBaseName.trim() : '新角色');
    final signature =
        _extractField(
          lines: lines,
          keys: const ['签名', '简介', '设定一句话', 'signature'],
        ) ??
        _buildFallbackSignature(normalizedContent);
    final personaSummary =
        _extractField(
          lines: lines,
          keys: const ['人设', '设定', 'persona', 'profile'],
        ) ??
        _buildFallbackPersonaSummary(normalizedContent);
    final greeting = _extractField(
      lines: lines,
      keys: const ['开场白', '初始消息', 'greeting'],
    );

    return ChatContactDraft(
      name: name,
      signature: signature,
      personaSummary: personaSummary,
      initialGreeting: greeting ?? '',
    );
  }

  /// 发送用户消息后，立即更新会话列表，再异步追加一条角色回复，模拟聊天链路闭环。
  Future<void> sendTextMessage({
    required String contactId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final now = DateTime.now();
    _appendMessage(
      contactId: contactId,
      message: ChatMessage(
        id: '$contactId-${now.microsecondsSinceEpoch}',
        contactId: contactId,
        sender: ChatMessageSender.user,
        text: trimmed,
        sentAt: now,
      ),
      unreadCount: 0,
    );

    _typingContacts.add(contactId);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (_disposed) {
      return;
    }

    _typingContacts.remove(contactId);

    final contact = contactById(contactId);
    final replyText = _buildAiReply(contact: contact, userMessage: trimmed);
    final replyTime = DateTime.now();

    _appendMessage(
      contactId: contactId,
      message: ChatMessage(
        id: '$contactId-${replyTime.microsecondsSinceEpoch}',
        contactId: contactId,
        sender: ChatMessageSender.ai,
        text: replyText,
        sentAt: replyTime,
      ),
      unreadCount: _activeConversationId == contactId ? 0 : 1,
      increaseUnread: _activeConversationId != contactId,
    );
  }

  /// 根据角色设定和用户最后一句话拼出一条稳定可预测的回复，便于后续替换成真实 AI 接口。
  String _buildAiReply({
    required ChatContact contact,
    required String userMessage,
  }) {
    final normalizedMessage = userMessage.toLowerCase();

    if (normalizedMessage.contains('累') || normalizedMessage.contains('烦')) {
      return '${contact.name}：先抱抱你一下。你不用马上把自己整理好，先让我陪你把这股疲惫慢慢摊开。';
    }

    if (normalizedMessage.contains('晚安') || normalizedMessage.contains('睡')) {
      return '${contact.name}：那我先把今晚的月光和好梦都留给你。睡前记得喝点水，我会在这里等你明天来。';
    }

    if (normalizedMessage.contains('吃') || normalizedMessage.contains('奶茶')) {
      return '${contact.name}：听起来就很有生活感。我已经开始替你脑补香味了，记得也分我一句真实测评。';
    }

    if (normalizedMessage.contains('工作') || normalizedMessage.contains('会议')) {
      return '${contact.name}：工作的事先放我这里一会儿。你可以先挑一件最想吐槽的，我认真听。';
    }

    return '${contact.name}：我在呢，刚刚把你的话认真看了一遍。你可以继续说，我会顺着你的情绪慢慢接住。';
  }

  void _appendMessage({
    required String contactId,
    required ChatMessage message,
    required int unreadCount,
    bool increaseUnread = false,
  }) {
    final currentMessages = List<ChatMessage>.from(
      _messages[contactId] ?? const [],
    )..add(message);
    _messages[contactId] = currentMessages;

    final currentThread = _threads[contactId]!;
    final nextUnreadCount = increaseUnread
        ? currentThread.unreadCount + unreadCount
        : unreadCount;

    _threads[contactId] = currentThread.copyWith(
      lastMessage: message.text,
      updatedAt: message.sentAt,
      unreadCount: nextUnreadCount,
    );

    notifyListeners();
  }

  void _markThreadRead(String contactId) {
    final thread = _threads[contactId];
    if (thread == null || thread.unreadCount == 0) {
      return;
    }

    _threads[contactId] = thread.copyWith(unreadCount: 0);
    notifyListeners();
  }

  String _buildContactId(String name) {
    final normalized = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'),
      '_',
    );
    final baseId = normalized.isEmpty ? 'contact' : normalized;
    if (!_threads.containsKey(baseId)) {
      return baseId;
    }
    return '${baseId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Color _colorForContact(String contactId) {
    const palette = [
      Color(0xFF79C77B),
      Color(0xFF7E8DFF),
      Color(0xFFFFA56C),
      Color(0xFFFFC65C),
      Color(0xFFEF7FB0),
      Color(0xFF68B9D8),
    ];
    final index =
        contactId.runes.fold<int>(0, (sum, rune) => sum + rune) %
        palette.length;
    return palette[index];
  }

  String? _extractField({
    required List<String> lines,
    required List<String> keys,
  }) {
    for (final line in lines) {
      for (final key in keys) {
        final pattern = RegExp('^$key[:：]\\s*(.+)\$', caseSensitive: false);
        final match = pattern.firstMatch(line);
        if (match != null) {
          return match.group(1)?.trim();
        }
      }
    }
    return null;
  }

  String _buildFallbackSignature(String content) {
    final compact = content.replaceAll('\n', ' ').trim();
    if (compact.isEmpty) {
      return '新的陪伴角色已加入。';
    }
    return compact.length <= 24 ? compact : '${compact.substring(0, 24)}...';
  }

  String _buildFallbackPersonaSummary(String content) {
    final compact = content.replaceAll('\n', ' ').trim();
    if (compact.isEmpty) {
      return '还没有填写详细人设。';
    }
    return compact.length <= 88 ? compact : '${compact.substring(0, 88)}...';
  }

  String _avatarLabelForName(String name) {
    if (name.isEmpty) {
      return '新';
    }
    return String.fromCharCode(name.runes.first);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
