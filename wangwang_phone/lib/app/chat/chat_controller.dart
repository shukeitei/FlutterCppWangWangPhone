import 'package:dio/dio.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_context.dart';
import 'chat_message_payloads.dart';
import 'chat_models.dart';
import 'chat_summary_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ChatAppController extends ChangeNotifier {
  ChatAppController.seeded({ChatSummaryStore? summaryStore})
    : _contacts = List<ChatContact>.from(ChatSeedData.contacts),
      _threads = Map<String, ChatThread>.from(ChatSeedData.threads),
      _messages = {
        for (final entry in ChatSeedData.messages.entries)
          entry.key: List<ChatMessage>.from(entry.value),
      },
      _moments = List<MomentPost>.from(ChatSeedData.moments),
      _profile = ChatSeedData.profile,
      _summaries = Map<String, ChatSummaryEntry>.from(ChatSeedData.summaries),
      _memories = List<ChatMemoryEntry>.from(ChatSeedData.memories),
      _diaries = List<ChatDiaryEntry>.from(ChatSeedData.diaries),
      _thoughts = List<ChatThoughtEntry>.from(ChatSeedData.thoughts),
      _systemEntries = List<ChatSystemEntry>.from(ChatSeedData.systemEntries),
      _contextConfig = const ChatContextConfig(
        mainSystemPrompt:
            '你是汪汪机里的 AI 角色，需要长期稳定保持人设，优先提供情绪陪伴、日常聊天和轻社交互动。回复要自然口语化，避免说教和空泛鼓励。',
        userPersona: '用户是汪汪机的主人，偏好被温柔接住、被认真倾听，也乐于收藏细腻的陪伴瞬间。',
        worldBook: '汪汪机是一个完全虚拟的社交世界。所有角色、聊天、朋友圈、记忆和日记都发生在这个虚拟系统中，不对应真实外部平台。',
        preset: '回复尽量短而有温度。优先延续对话情绪，必要时可以发动作、表情、图片描述、红包、转账、朋友圈事件和隐藏记录。',
        maxRecentMessages: 6,
      ),
      _emojiCatalog = const [
        ChatEmojiEntry(id: 'hug', symbol: '🥹', description: '安抚和抱抱'),
        ChatEmojiEntry(id: 'moon', symbol: '🌙', description: '晚安和夜聊'),
        ChatEmojiEntry(id: 'bread', symbol: '🥐', description: '吃饭和生活感'),
        ChatEmojiEntry(id: 'sparkle', symbol: '✨', description: '灵感和开心'),
      ],
      _contextAssembler = const ChatContextAssembler(),
      _summaryGenerator = const ChatSummaryGenerator(),
      _summaryStore = summaryStore ?? buildDefaultChatSummaryStore(),
      _bubbleAppearance = ChatBubbleAppearance.fromPreset(
        ChatBubblePreset.iMessageBlue,
      ) {
    // 构造函数里只负责执行这两行指令
    syncContactsFromBridge();
  }
  /// 把当前所有消息持久化到本地 JSON 文件
  Future<void> _saveMessages() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_messages.json');
      final data = <String, dynamic>{};
      for (final entry in _messages.entries) {
        data[entry.key] = entry.value.map((m) {
          final body = m.body;
          return {
            'id': m.id,
            'contactId': m.contactId,
            'sender': m.sender.name,
            'text': body is WordMessageBody ? body.text : '',
            'sentAt': m.sentAt.toIso8601String(),
          };
        }).toList();
      }
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// 启动时从本地 JSON 文件恢复消息
  Future<void> loadPersistedMessages() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_messages.json');
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in data.entries) {
        final contactId = entry.key;
        if (!_messages.containsKey(contactId)) continue;
        final msgs = (entry.value as List).map((m) {
          return ChatMessage(
            id: m['id'],
            contactId: m['contactId'],
            sender: m['sender'] == 'user'
                ? ChatMessageSender.user
                : ChatMessageSender.ai,
            body: WordMessageBody(m['text'] ?? ''),
            sentAt: DateTime.parse(m['sentAt']),
          );
        }).toList();
        _messages[contactId] = msgs;
      }
      notifyListeners();
    } catch (_) {}
  }

  final List<ChatContact> _contacts;
  final Map<String, ChatThread> _threads;
  final Map<String, List<ChatMessage>> _messages;
  final List<MomentPost> _moments;
  final UserProfile _profile;
  final Map<String, ChatSummaryEntry> _summaries;
  final List<ChatMemoryEntry> _memories;
  final List<ChatDiaryEntry> _diaries;
  final List<ChatThoughtEntry> _thoughts;
  final List<ChatSystemEntry> _systemEntries;
  final ChatContextConfig _contextConfig;
  final List<ChatEmojiEntry> _emojiCatalog;
  final ChatContextAssembler _contextAssembler;
  final ChatSummaryGenerator _summaryGenerator;
  final ChatSummaryStore _summaryStore;
  final Set<String> _typingContacts = <String>{};
  final Map<String, ChatContextBundle> _lastContextBundles = {};
  ChatBubbleAppearance _bubbleAppearance;

  ChatTab _currentTab = ChatTab.chats;
  String? _activeConversationId;
  bool _disposed = false;

  ChatTab get currentTab => _currentTab;

  UserProfile get profile => _profile;

  ChatContextConfig get contextConfig => _contextConfig;

  ChatBubbleAppearance get bubbleAppearance => _bubbleAppearance;

  List<ChatBubblePreset> get bubblePresets => ChatBubblePreset.presets;

  List<ChatEmojiEntry> get emojiCatalog =>
      List<ChatEmojiEntry>.unmodifiable(_emojiCatalog);

  List<ChatSummaryEntry> get summaries {
    final items = _summaries.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List<ChatSummaryEntry>.unmodifiable(items);
  }

  List<ChatMemoryEntry> get memories {
    final items = List<ChatMemoryEntry>.from(_memories)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<ChatMemoryEntry>.unmodifiable(items);
  }

  List<ChatDiaryEntry> get diaries {
    final items = List<ChatDiaryEntry>.from(_diaries)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<ChatDiaryEntry>.unmodifiable(items);
  }

  List<ChatThoughtEntry> get thoughts {
    final items = List<ChatThoughtEntry>.from(_thoughts)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<ChatThoughtEntry>.unmodifiable(items);
  }

  List<ChatSystemEntry> get systemEntries {
    final items = List<ChatSystemEntry>.from(_systemEntries)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<ChatSystemEntry>.unmodifiable(items);
  }

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

  ChatSummaryEntry? summaryFor(String contactId) => _summaries[contactId];

  ChatContextBundle? lastContextBundleFor(String contactId) =>
      _lastContextBundles[contactId];
/// 启动时从本地恢复动态 summary，让上下文拼装在首次打开聊天时就能拿到上次保存的摘要。
  Future<void> loadPersistedSummaries() async {
    final storedSummaries = await _summaryStore.loadSummaries();
    if (storedSummaries.isEmpty) {
      return;
    }

    _summaries.addAll(storedSummaries);
    if (!_disposed) {
      notifyListeners();
    }
  }
  /// 启动时从桥接服务同步 ST 角色卡，自动替换联系人列表。
Future<void> syncContactsFromBridge() async {
  try {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 10);

    final res = await dio.get('http://192.168.1.247:7700/characters');
    final List<dynamic> list = res.data;

    _contacts.clear();
    _threads.clear();
    _moments.clear();

    final now = DateTime.now();
    for (final item in list) {
      final name = item['name'] as String? ?? '未知角色';
      final signature = item['signature'] as String? ?? '来自酒馆的角色';
      final firstMes = item['first_mes'] as String? ?? '你好，我是$name。';

      final contactId = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_');

      final contact = ChatContact(
        id: contactId,
        name: name,
        signature: signature,
        personaSummary: item['description'] as String? ?? '',
        statusLabel: '在线',
        avatarColor: _colorForContact(contactId),
        emoji: _avatarLabelForName(name),
      );

      _contacts.add(contact);
      _threads[contactId] = ChatThread(
        contactId: contactId,
        lastMessage: firstMes,
        updatedAt: now,
        unreadCount: 1,
      );
      // 只有新联系人才设置初始消息，已有对话的不覆盖
if (!_messages.containsKey(contactId)) {
  _messages[contactId] = [
    ChatMessage(...)
  ];
}
          id: '$contactId-${now.microsecondsSinceEpoch}',
          contactId: contactId,
          sender: ChatMessageSender.ai,
          body: WordMessageBody(firstMes),
          sentAt: now,
        ),
      ];
    }

    notifyListeners();
    await loadPersistedMessages(); // 加这一行，在同步角色之后再恢复消息
  } catch (e) {
    // 桥接服务连不上就保留原来的联系人
  }
}

  List<ChatMessage> messagesFor(String contactId) {
    return List<ChatMessage>.unmodifiable(_messages[contactId] ?? const []);
  }

  bool isTyping(String contactId) => _typingContacts.contains(contactId);

  /// 切换到预设气泡方案时，直接整体替换颜色，保证 iMessage 风格统一收口。
  void applyBubblePreset(String presetId) {
    final preset = ChatBubblePreset.presets.firstWhere(
      (item) => item.id == presetId,
      orElse: () => ChatBubblePreset.iMessageBlue,
    );
    _bubbleAppearance = ChatBubbleAppearance.fromPreset(preset);
    notifyListeners();
  }

  /// 自定义颜色时保留当前另一侧气泡配色，只更新用户刚选中的那一项。
  void updateCustomBubbleColors({
    Color? userBubbleColor,
    Color? peerBubbleColor,
  }) {
    _bubbleAppearance = _bubbleAppearance.copyWith(
      presetId: 'custom',
      label: '自定义',
      isCustom: true,
      userBubbleColor: userBubbleColor ?? _bubbleAppearance.userBubbleColor,
      peerBubbleColor: peerBubbleColor ?? _bubbleAppearance.peerBubbleColor,
    );
    notifyListeners();
  }

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
        body: WordMessageBody(introMessage),
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

  ChatContextBundle buildContextBundle({
    required String contactId,
    required String latestUserInput,
  }) {
    final contact = contactById(contactId);
    final bundle = _contextAssembler.build(
      ChatContextAssemblerInput(
        generatedAt: DateTime.now(),
        contact: contact,
        config: _contextConfig,
        summary: summaryFor(contactId),
        memories: _memories
            .where((entry) => entry.contactId == contactId)
            .toList(),
        recentMessages: messagesFor(contactId),
        latestUserInput: latestUserInput,
        availableEmojis: _emojiCatalog,
      ),
    );
    _lastContextBundles[contactId] = bundle;
    return bundle;
  }

  /// 统一承接结构化 payload。可见类型会进聊天列表，隐藏类型则进入各自的数据存储。
  Future<void> ingestStructuredPayloads({
    required String contactId,
    required List<Map<String, dynamic>> payloads,
    ChatMessageSender sender = ChatMessageSender.ai,
  }) async {
    var summaryUpdated = false;
    for (final payload in payloads) {
      summaryUpdated =
          _ingestStructuredPayload(
        contactId: contactId,
        payload: payload,
        sender: sender,
      ) ||
          summaryUpdated;
    }
    if (summaryUpdated) {
      await _summaryStore.saveSummaries(_summaries);
    }
    notifyListeners();
  }

  void acceptMoneyCard({required String contactId, required String messageId}) {
    _updateMoneyCardStatus(
      contactId: contactId,
      messageId: messageId,
      status: TransactionCardStatus.accepted,
    );
  }

  void rejectMoneyCard({required String contactId, required String messageId}) {
    _updateMoneyCardStatus(
      contactId: contactId,
      messageId: messageId,
      status: TransactionCardStatus.rejected,
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
  if (trimmed.isEmpty) return;

  final now = DateTime.now();
  _appendMessage(
    contactId: contactId,
    message: ChatMessage(
      id: '$contactId-${now.microsecondsSinceEpoch}',
      contactId: contactId,
      sender: ChatMessageSender.user,
      body: WordMessageBody(trimmed),
      sentAt: now,
    ),
    unreadCount: 0,
  );
  await _saveMessages(); // 加这行，用户发消息就立刻存一次
  _typingContacts.add(contactId);
  notifyListeners();

  try {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 5);
    dio.options.receiveTimeout = const Duration(seconds: 60);

    // 第一步：从桥接服务拉角色人设
    final contact = contactById(contactId);
    String systemPrompt = '你是一个AI角色，请自然地回复用户。';
    try {
      final charRes = await dio.get(
        'http://192.168.1.247:7700/characters/${Uri.encodeComponent(contact.name)}',
      );
      final charData = charRes.data;
      final desc = charData['description'] ?? '';
      final personality = charData['personality'] ?? '';
      final scenario = charData['scenario'] ?? '';
      systemPrompt = [
        if (desc.isNotEmpty) desc,
        if (personality.isNotEmpty) '性格：$personality',
        if (scenario.isNotEmpty) '场景：$scenario',
      ].join('\n\n');
    } catch (_) {
      // 拉不到角色卡就用默认 prompt，不影响聊天
    }

    // 第二步：构建对话历史（最近10条）
    final history = messagesFor(contactId)
        .where((m) => m.body is WordMessageBody)
        .toList();
    final recentHistory = history.length > 100
        ? history.sublist(history.length - 100)
        : history;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      for (final m in recentHistory)
        {
          'role': m.sender == ChatMessageSender.user ? 'user' : 'assistant',
          'content': (m.body as WordMessageBody).text,
        },
    ];

    // 第三步：发给 DeepSeek
    final response = await dio.post(
      'https://api.deepseek.com/v1/chat/completions',
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer sk-cabf1304e6df446e915ea6a0ab22e310',
        },
      ),
      data: {
        'model': 'deepseek-chat',
        'messages': messages,
        'max_tokens': 500,
        'stream': false,
      },
    );

    final String aiReplyText =
        response.data['choices'][0]['message']['content'] as String;

    final replyPayloads = [
      {'type': 'word', 'text': aiReplyText}
    ];
    await ingestStructuredPayloads(
        contactId: contactId, payloads: replyPayloads);
        await _saveMessages();
  } catch (e) {
    final errorPayloads = [
      {'type': 'word', 'text': '【信号中断】连不上酒馆啦！\n具体原因：$e'}
    ];
    await ingestStructuredPayloads(
        contactId: contactId, payloads: errorPayloads);
  } finally {
    _typingContacts.remove(contactId);
    notifyListeners();
  }
}

    List<Map<String, dynamic>> _buildAiReplyPayloads({
    required ChatContact contact,
    required String userMessage,
  }) {
    final normalizedMessage = userMessage.toLowerCase();
    final payloads = <Map<String, dynamic>>[];

    if (normalizedMessage.contains('红包')) {
      payloads.add({
        'type': 'redpacket',
        'title': '给你的安慰红包',
        'amount': '6.66',
        'note': '收下以后，今天糟糕的部分就先到这里。',
        'blessing': '愿你现在就开始转好运',
      });
      return payloads;
    }

    if (normalizedMessage.contains('转账') || normalizedMessage.contains('奶茶')) {
      payloads.add({
        'type': 'transfer',
        'title': '奶茶补给',
        'amount': '19.90',
        'note': '去买一杯你现在最想喝的。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('图片') || normalizedMessage.contains('照片')) {
      payloads.add({
        'type': 'image',
        'title': '刚存下的一张氛围图',
        'description': '窗边的光线很安静，像给情绪盖上一层柔软的滤镜。',
        'theme': '静物氛围',
      });
      return payloads;
    }

    if (normalizedMessage.contains('表情') || normalizedMessage.contains('开心')) {
      payloads.add({
        'type': 'emoji',
        'emoji': '🥹',
        'description': '先把这个抱抱表情塞给你，今天也值得被好好接住。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('总结') ||
        normalizedMessage.contains('summary')) {
      payloads.add({
        'type': 'summary',
        'content': '你最近更希望被温柔接住，聊天主题主要围绕工作压力和睡前陪伴展开。',
      });
      payloads.add({
        'type': 'system',
        'content': '已更新一条新的动态总结到会话上下文。',
        'level': 'info',
      });
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：我把最近的聊天重点整理好了，之后会更贴着你的状态陪你聊。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('记住') ||
        normalizedMessage.contains('memory')) {
      payloads.add({
        'type': 'memory',
        'title': '新的长期记忆',
        'content': '你希望在难过时先被安静抱一下，再慢慢聊发生了什么。',
      });
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：我记住了。以后你一说累，我会先把语气放轻一点。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('日记') ||
        normalizedMessage.contains('diary')) {
      payloads.add({
        'type': 'diary',
        'title': '关于你今天的记录',
        'content': '她今天看起来有点累，但还是愿意把心事交给我。我想把这份信任认真收起来。',
        'mood': '认真珍惜',
      });
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：我替今天写下了一小段日记，已经放进日记本里了。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('朋友圈') && normalizedMessage.contains('评论')) {
      final targetMomentId = _pickMomentTarget(contactId: contact.id);
      if (targetMomentId != null) {
        payloads.add({
          'type': 'moment_comment',
          'momentId': targetMomentId,
          'content': '这条动态的氛围真好，我一眼就记住了。',
        });
      }
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：我已经替你去朋友圈留了一句评论。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('朋友圈') && normalizedMessage.contains('点赞')) {
      final targetMomentId = _pickMomentTarget(contactId: contact.id);
      if (targetMomentId != null) {
        payloads.add({'type': 'moment_like', 'momentId': targetMomentId});
      }
      payloads.add({'type': 'word', 'text': '${contact.name}：我已经替你点过赞啦。'});
      return payloads;
    }

    if (normalizedMessage.contains('朋友圈') ||
        normalizedMessage.contains('moment')) {
      payloads.add({
        'type': 'moment',
        'content': '刚刚路过便利店门口，风把发尾吹起来的那一下，突然觉得今天也没那么糟。',
        'mood': '夜晚碎片',
      });
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：我刚替你发了一条朋友圈，等会儿你去看看。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('累') || normalizedMessage.contains('烦')) {
      payloads.add({'type': 'thought', 'content': '她把疲惫说出口了，这一刻更需要被轻一点地接住。'});
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：先抱抱你一下。你不用马上把自己整理好，先让我陪你把这股疲惫慢慢摊开。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('晚安') || normalizedMessage.contains('睡')) {
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：那我先把今晚的月光和好梦都留给你。睡前记得喝点水，我会在这里等你明天来。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('吃')) {
      payloads.add({
        'type': 'word',
        'text': '${contact.name}：听起来就很有生活感。我已经开始替你脑补香味了，记得也分我一句真实测评。',
      });
      return payloads;
    }

    if (normalizedMessage.contains('工作') || normalizedMessage.contains('会议')) {
      payloads.add({
        'type': 'action',
        'text': '${contact.name}把待办清单推到一边，认真坐下来听你讲工作里的委屈。',
      });
      return payloads;
    }

    payloads.add({
      'type': 'word',
      'text': '${contact.name}：我在呢，刚刚把你的话认真看了一遍。你可以继续说，我会顺着你的情绪慢慢接住。',
    });
    return payloads;
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
      lastMessage: message.previewText,
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

  bool _ingestStructuredPayload({
    required String contactId,
    required Map<String, dynamic> payload,
    required ChatMessageSender sender,
  }) {
    final body = ChatStructuredMessageParser.parseBody(payload);
    final timestamp = DateTime.now();

    switch (body) {
      case ThoughtMessageBody():
        _thoughts.insert(
          0,
          ChatThoughtEntry(
            id: '$contactId-thought-${timestamp.microsecondsSinceEpoch}',
            contactId: contactId,
            content: body.content,
            createdAt: timestamp,
          ),
        );
      case SummaryMessageBody():
        _summaries[contactId] = ChatSummaryEntry(
          contactId: contactId,
          content: body.content,
          updatedAt: timestamp,
        );
        return true;
      case MemoryMessageBody():
        _memories.insert(
          0,
          ChatMemoryEntry(
            id: '$contactId-memory-${timestamp.microsecondsSinceEpoch}',
            contactId: contactId,
            title: body.title,
            content: body.content,
            createdAt: timestamp,
          ),
        );
      case DiaryMessageBody():
        _diaries.insert(
          0,
          ChatDiaryEntry(
            id: '$contactId-diary-${timestamp.microsecondsSinceEpoch}',
            contactId: contactId,
            title: body.title,
            content: body.content,
            moodLabel: body.moodLabel,
            createdAt: timestamp,
          ),
        );
      case SystemMessageBody():
        _systemEntries.insert(
          0,
          ChatSystemEntry(
            id: '$contactId-system-${timestamp.microsecondsSinceEpoch}',
            contactId: contactId,
            content: body.content,
            createdAt: timestamp,
            level: body.level,
          ),
        );
      case MomentMessageBody():
        addMoment(
          contactId: contactId,
          content: body.content,
          moodLabel: body.moodLabel,
        );
      case MomentCommentMessageBody():
        _appendMomentComment(
          contactId: contactId,
          targetMomentId: body.targetMomentId,
          content: body.content,
          createdAt: timestamp,
        );
      case MomentLikeMessageBody():
        _appendMomentLike(
          contactId: contactId,
          targetMomentId: body.targetMomentId,
        );
      default:
        _appendVisibleStructuredMessage(
          contactId: contactId,
          sender: sender,
          body: body,
          timestamp: timestamp,
        );
    }
    return false;
  }

  void _appendVisibleStructuredMessage({
    required String contactId,
    required ChatMessageSender sender,
    required ChatMessageBody body,
    required DateTime timestamp,
  }) {
    _appendMessage(
      contactId: contactId,
      message: ChatMessage(
        id: '$contactId-${timestamp.microsecondsSinceEpoch}',
        contactId: contactId,
        sender: sender,
        body: body,
        sentAt: timestamp,
      ),
      unreadCount: _activeConversationId == contactId ? 0 : 1,
      increaseUnread:
          sender == ChatMessageSender.ai && _activeConversationId != contactId,
    );
  }

  void _appendMomentComment({
    required String contactId,
    required String targetMomentId,
    required String content,
    required DateTime createdAt,
  }) {
    final momentIndex = _moments.indexWhere(
      (moment) => moment.id == targetMomentId,
    );
    if (momentIndex == -1) {
      return;
    }

    final moment = _moments[momentIndex];
    final comments = List<MomentComment>.from(moment.comments)
      ..add(
        MomentComment(
          id: '$targetMomentId-comment-${createdAt.microsecondsSinceEpoch}',
          authorContactId: contactId,
          content: content,
          createdAt: createdAt,
        ),
      );
    _moments[momentIndex] = moment.copyWith(comments: comments);
  }

  void _appendMomentLike({
    required String contactId,
    required String targetMomentId,
  }) {
    final momentIndex = _moments.indexWhere(
      (moment) => moment.id == targetMomentId,
    );
    if (momentIndex == -1) {
      return;
    }

    final moment = _moments[momentIndex];
    if (moment.likedByContactIds.contains(contactId)) {
      return;
    }

    final likes = List<String>.from(moment.likedByContactIds)..add(contactId);
    _moments[momentIndex] = moment.copyWith(likedByContactIds: likes);
  }

  String? _pickMomentTarget({required String contactId}) {
    for (final moment in _moments) {
      if (moment.contactId != contactId) {
        return moment.id;
      }
    }
    return _moments.isNotEmpty ? _moments.first.id : null;
  }

  Future<void> _refreshDynamicSummary(String contactId) async {
    final contact = contactById(contactId);
    final summaryContent = _summaryGenerator.generate(
      contact: contact,
      messages: messagesFor(contactId),
    );
    _summaries[contactId] = ChatSummaryEntry(
      contactId: contactId,
      content: summaryContent,
      updatedAt: DateTime.now(),
    );
    await _summaryStore.saveSummaries(_summaries);
  }

  void _updateMoneyCardStatus({
    required String contactId,
    required String messageId,
    required TransactionCardStatus status,
  }) {
    final currentMessages = _messages[contactId];
    if (currentMessages == null) {
      return;
    }

    final messageIndex = currentMessages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex == -1) {
      return;
    }

    final message = currentMessages[messageIndex];
    final body = message.body;
    if (body is! MoneyCardMessageBody || !body.isPending) {
      return;
    }

    final nextMessages = List<ChatMessage>.from(currentMessages);
    nextMessages[messageIndex] = message.copyWith(
      body: body.copyWithStatus(status),
    );
    _messages[contactId] = nextMessages;

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

class ChatBubbleAppearance {
  const ChatBubbleAppearance({
    required this.presetId,
    required this.label,
    required this.userBubbleColor,
    required this.peerBubbleColor,
    this.isCustom = false,
  });

  final String presetId;
  final String label;
  final Color userBubbleColor;
  final Color peerBubbleColor;
  final bool isCustom;

  factory ChatBubbleAppearance.fromPreset(ChatBubblePreset preset) {
    return ChatBubbleAppearance(
      presetId: preset.id,
      label: preset.label,
      userBubbleColor: preset.userBubbleColor,
      peerBubbleColor: preset.peerBubbleColor,
    );
  }

  ChatBubbleAppearance copyWith({
    String? presetId,
    String? label,
    Color? userBubbleColor,
    Color? peerBubbleColor,
    bool? isCustom,
  }) {
    return ChatBubbleAppearance(
      presetId: presetId ?? this.presetId,
      label: label ?? this.label,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      peerBubbleColor: peerBubbleColor ?? this.peerBubbleColor,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class ChatBubblePreset {
  const ChatBubblePreset({
    required this.id,
    required this.label,
    required this.userBubbleColor,
    required this.peerBubbleColor,
  });

  final String id;
  final String label;
  final Color userBubbleColor;
  final Color peerBubbleColor;

  static const iMessageBlue = ChatBubblePreset(
    id: 'imessage_blue',
    label: 'iMessage 蓝',
    userBubbleColor: Color(0xFF0A84FF),
    peerBubbleColor: Color(0xFFE9EAEE),
  );

  static const softRose = ChatBubblePreset(
    id: 'soft_rose',
    label: '奶油玫瑰',
    userBubbleColor: Color(0xFFFF6B8D),
    peerBubbleColor: Color(0xFFFBE7EC),
  );

  static const freshMint = ChatBubblePreset(
    id: 'fresh_mint',
    label: '薄荷牛奶',
    userBubbleColor: Color(0xFF3BB273),
    peerBubbleColor: Color(0xFFE7F5ED),
  );

  static const lavender = ChatBubblePreset(
    id: 'lavender',
    label: '浅雾薰衣草',
    userBubbleColor: Color(0xFF7C6CF2),
    peerBubbleColor: Color(0xFFECE9FF),
  );

  static const graphite = ChatBubblePreset(
    id: 'graphite',
    label: '冷调石墨',
    userBubbleColor: Color(0xFF3E4C63),
    peerBubbleColor: Color(0xFFE6EAF0),
  );

  static const presets = [
    iMessageBlue,
    softRose,
    freshMint,
    lavender,
    graphite,
  ];
}
