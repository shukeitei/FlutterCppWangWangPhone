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
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_api_models.dart';
import 'chat_preset_models.dart';
import 'chat_world_models.dart';

const String kBridgeHost = 'http://192.168.1.217:7700';

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
    loadWorldBindings();
    fetchWorldBookList();
    fetchPersonas();
    loadGlobalPersona();
    fetchPresetList();
    loadGlobalPreset();
    loadPresetOverrides();
    loadApiConfig();
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
            'isHidden': m.isHidden,
            'alternatives': m.alternatives.map((alt) {
              if (alt is WordMessageBody) return alt.text;
              return '';
            }).toList(),
            'activeAltIndex': m.activeAltIndex,
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
        if (!_messages.containsKey(contactId)) {
          // 群聊消息：恢复时 _messages 里可能还没有这个 groupId 的 key
          _messages[contactId] = [];
        }
        final msgs = (entry.value as List).map((m) {
          final altList = (m['alternatives'] as List?)
                  ?.map<ChatMessageBody>(
                      (t) => WordMessageBody(t as String? ?? ''))
                  .toList() ??
              [];
          return ChatMessage(
            id: m['id'],
            contactId: m['contactId'],
            sender: m['sender'] == 'user'
                ? ChatMessageSender.user
                : ChatMessageSender.ai,
            body: WordMessageBody(m['text'] ?? ''),
            sentAt: DateTime.parse(m['sentAt']),
            isHidden: m['isHidden'] == true,
            alternatives: altList,
            activeAltIndex: m['activeAltIndex'] as int? ?? 0,
          );
        }).toList();
        _messages[contactId] = msgs;
      }
      notifyListeners();
    } catch (_) {}
  }

  // ===== 群聊：建群、持久化 =====
  ChatGroup createGroup({
    required String name,
    required List<String> memberContactIds,
  }) {
    final now = DateTime.now();
    final groupId = 'group_${now.microsecondsSinceEpoch}';

    final group = ChatGroup(
      id: groupId,
      name: name.trim(),
      memberContactIds: List<String>.from(memberContactIds),
      createdAt: now,
    );
    _groups[groupId] = group;

    _threads[groupId] = ChatThread(
      contactId: groupId,
      lastMessage: '群聊已创建',
      updatedAt: now,
      groupId: groupId,
    );

    _messages[groupId] = [
      ChatMessage(
        id: '$groupId-${now.microsecondsSinceEpoch}',
        contactId: groupId,
        sender: ChatMessageSender.ai,
        body: WordMessageBody('群聊「${name.trim()}」已创建，开始聊天吧'),
        sentAt: now,
      ),
    ];

    notifyListeners();
    _saveGroups();
    return group;
  }

  Future<void> _saveGroups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_groups.json');
      final data = <String, dynamic>{};
      for (final entry in _groups.entries) {
        data[entry.key] = {
          'id': entry.value.id,
          'name': entry.value.name,
          'memberContactIds': entry.value.memberContactIds,
          'createdAt': entry.value.createdAt.toIso8601String(),
        };
      }
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  bool isGroupRandomMode(String groupId) => _groupRandomMode[groupId] ?? true;

  void toggleGroupMode(String groupId) {
    _groupRandomMode[groupId] = !isGroupRandomMode(groupId);
    notifyListeners();
  }

  String? getGroupError(String groupId) => _groupError[groupId];

  void clearGroupError(String groupId) {
    if (_groupError.remove(groupId) != null) {
      notifyListeners();
    }
  }

  /// 重置群聊对话：清空消息，可选清掉记忆/摘要
  void resetGroupChat({
    required String groupId,
    required bool clearMemory,
  }) {
    final group = _groups[groupId];
    if (group == null) return;

    final now = DateTime.now();
    _messages[groupId] = [
      ChatMessage(
        id: '$groupId-reset-${now.microsecondsSinceEpoch}',
        contactId: groupId,
        sender: ChatMessageSender.ai,
        body: WordMessageBody('对话已重置'),
        sentAt: now,
      ),
    ];

    final existingThread = _threads[groupId];
    if (existingThread != null) {
      _threads[groupId] = existingThread.copyWith(
        lastMessage: '对话已重置',
        updatedAt: now,
        unreadCount: 0,
      );
    }

    if (clearMemory) {
      _summaries.remove(groupId);
      _memories.removeWhere((m) => m.contactId == groupId);
    }

    _groupError.remove(groupId);
    notifyListeners();
    _saveMessages();
  }

  /// 解散群聊：彻底清除群组及其所有相关数据
  void disbandGroup({required String groupId}) {
    _groups.remove(groupId);
    _threads.remove(groupId);
    _messages.remove(groupId);
    _summaries.remove(groupId);
    _memories.removeWhere((m) => m.contactId == groupId);
    _groupError.remove(groupId);
    _groupRandomMode.remove(groupId);

    notifyListeners();
    _saveGroups();
    _saveMessages();
  }

  /// 群聊发消息 / 召唤角色发言。
  /// - 随机模式 + summonOnly=false：追加用户消息 → 自动触发 AI 接力（步骤 8 接入）
  /// - 手动模式 + summonOnly=false：只追加用户消息，不触发 AI，等召唤
  /// - summonOnly=true：不追加用户消息，触发 targetContactId 角色发言（步骤 8 接入）
  Future<void> sendGroupMessage({
    required String groupId,
    required String text,
    String? targetContactId,
    bool summonOnly = false,
  }) async {
    final group = _groups[groupId];
    if (group == null) return;

    if (!summonOnly) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;

      final now = DateTime.now();
      _appendMessage(
        contactId: groupId,
        message: ChatMessage(
          id: '$groupId-${now.microsecondsSinceEpoch}',
          contactId: groupId,
          sender: ChatMessageSender.user,
          body: WordMessageBody(trimmed),
          sentAt: now,
        ),
        unreadCount: 0,
      );
      await _saveMessages();
    }

    final isRandom = isGroupRandomMode(groupId);
    final shouldCallAi =
        (isRandom && !summonOnly) || (summonOnly && targetContactId != null);
    if (!shouldCallAi) return;

    if (!isApiConfigured) {
      _appendGroupFallbackReply(
        groupId,
        '【未配置接口】请先在"我"页面设置 API 接口和密钥。',
      );
      return;
    }

    _typingContacts.add(groupId);
    _groupError.remove(groupId);
    notifyListeners();

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 120);

      if (isRandom && !summonOnly) {
        await _sendGroupRandomReply(dio, groupId, group);
      } else if (summonOnly && targetContactId != null) {
        await _sendGroupManualReply(dio, groupId, group, targetContactId);
      }
      await _saveMessages();
    } catch (e) {
      _groupError[groupId] = '$e';
      _appendGroupFallbackReply(groupId, '【信号中断】$e');
    } finally {
      _typingContacts.remove(groupId);
      notifyListeners();
    }
  }

  /// 群聊 AI 共用：构建最近的对话历史（OpenAI 格式）
  /// 注意：过滤掉 contactId == groupId 的系统消息（建群/重置提示）
  /// 否则 AI 会把它当成某个"旁白/系统"身份，之后模仿着返回非成员 name，匹配失败显示成群消息
  /// AI 成员消息会加上 【角色名】 前缀，让模型能识别"谁说了哪句"
  List<Map<String, dynamic>> _buildGroupHistory(String groupId) {
    final history = messagesFor(groupId)
        .where((m) =>
            m.body is WordMessageBody &&
            !m.isHidden &&
            !(m.sender == ChatMessageSender.ai && m.contactId == groupId))
        .toList();
    final recent =
        history.length > 50 ? history.sublist(history.length - 50) : history;
    return [
      for (final m in recent)
        {
          'role': m.sender == ChatMessageSender.user ? 'user' : 'assistant',
          'content': _formatGroupHistoryContent(m),
        },
    ];
  }

  /// 群聊历史消息格式化：AI 成员消息前加 【角色名】 前缀，用户消息保持原样
  String _formatGroupHistoryContent(ChatMessage m) {
    final text = (m.body as WordMessageBody).text;
    if (m.sender == ChatMessageSender.user) return text;
    try {
      final name = contactById(m.contactId).name;
      return '【$name】$text';
    } catch (_) {
      return text;
    }
  }

  /// 群聊 AI 共用：发请求并取出纯文本回复（兼容 claude / openai 格式）
  Future<String> _callGroupChatApi({
    required Dio dio,
    required String systemPrompt,
    required List<Map<String, dynamic>> historyMessages,
    required int maxTokens,
  }) async {
    final provider = currentApiProvider!;
    final Map<String, dynamic> requestData;
    final Map<String, String> requestHeaders;

    if (_apiProviderId == 'claude') {
      requestHeaders = {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      };
      requestData = {
        'model': _apiModelId,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': historyMessages,
      };
    } else {
      requestHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
      requestData = {
        'model': _apiModelId,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          ...historyMessages,
        ],
        'max_tokens': maxTokens,
        'stream': false,
      };
    }

    final response = await dio.post(
      provider.baseUrl,
      options: Options(headers: requestHeaders),
      data: requestData,
    );

    if (_apiProviderId == 'claude') {
      final content = response.data['content'] as List;
      return content
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'] as String)
          .join('\n');
    } else {
      return response.data['choices'][0]['message']['content'] as String;
    }
  }

  /// 拉指定角色的角色卡，拼成一段 persona 文本
  Future<String> _fetchCharacterPersona(Dio dio, ChatContact contact) async {
    try {
      final res = await dio.get(
        '$kBridgeHost/characters/${Uri.encodeComponent(contact.name)}',
      );
      final d = res.data;
      final desc =
          _replacePlaceholders((d['description'] as String?) ?? '', contact.name);
      final personality = _replacePlaceholders(
          (d['personality'] as String?) ?? '', contact.name);
      final scenario =
          _replacePlaceholders((d['scenario'] as String?) ?? '', contact.name);
      return [
        if (desc.isNotEmpty) desc,
        if (personality.isNotEmpty) '性格：$personality',
        if (scenario.isNotEmpty) '场景：$scenario',
      ].join('\n');
    } catch (_) {
      return contact.personaSummary.isNotEmpty
          ? contact.personaSummary
          : '${contact.name}：来自酒馆的角色';
    }
  }

  /// 随机接力 AI 回复：一次 API 调用，AI 决定哪些角色回复
  Future<void> _sendGroupRandomReply(
    Dio dio,
    String groupId,
    ChatGroup group,
  ) async {
    // 拉所有成员的简要 persona
    final memberProfiles = <String>[];
    for (final cid in group.memberContactIds) {
      try {
        final c = contactById(cid);
        final persona = await _fetchCharacterPersona(dio, c);
        memberProfiles.add('【${c.name}】\n$persona');
      } catch (_) {}
    }

    final memberCount = group.memberContactIds.length;
    final replyCountHint = memberCount <= 5
        ? '1-2个角色'
        : memberCount <= 10
            ? '1-3个角色'
            : '2-3个角色';

    // 群聊世界书：APP全局 + 群聊 + 所有成员的角色专属
    final worldInfo = await buildGroupWorldInfo(
      groupId: groupId,
      memberContactIds: group.memberContactIds,
    );
    final worldBeforeBlock =
        worldInfo.before.isNotEmpty ? '${worldInfo.before}\n\n' : '';
    final worldAfterBlock =
        worldInfo.after.isNotEmpty ? '\n\n${worldInfo.after}' : '';

    // E1: 用户身份（群聊用 group.name 当 key，找不到绑定时落到全局 persona）
    String userName = '江栩栩';
    String personaDesc = '';
    try {
      final resolved = await getResolvedPersona(group.name);
      final pName = resolved['name'] as String? ?? '';
      final pDesc = resolved['description'] as String? ?? '';
      if (pName.isNotEmpty) userName = pName;
      if (pDesc.isNotEmpty) personaDesc = pDesc;
    } catch (_) {}
    final personaBlock = personaDesc.isNotEmpty
        ? '【用户身份】\n用户的名字是 $userName。\n$personaDesc\n\n'
        : '【用户身份】\n用户的名字是 $userName。\n\n';

    // E2b: 抽取预设里非 marker 的通用指令（越狱 / 输出格式 / 风格规则等）
    final presetInstructions = extractPresetInstructions(groupId);
    final presetBlock =
        presetInstructions.isNotEmpty ? '【预设指令】\n$presetInstructions\n\n' : '';

    var systemPrompt = '''$worldBeforeBlock$presetBlock$personaBlock你是一个群聊模拟器。这个群聊叫「${group.name}」，有$memberCount位成员。

以下是每位成员的角色设定：
${memberProfiles.join('\n\n')}

你的任务：
1. 根据用户的最新消息和对话上下文，决定哪些角色会回复（选$replyCountHint）
2. 只选和当前话题相关、有动机发言的角色
3. 多样性与轮换规则：
   - 优先让最近 3 轮没发言过的角色发言，避免总是同一两个角色在对话
   - 同一角色不要连续 3 轮都在说话
   - 如果用户消息明确 @ 或提及某人，优先让那人发言
   - 如果话题与某角色的世界观 / 记忆 / 人设密切相关，优先让那人发言
4. 每个角色的回复要符合其性格和说话风格
5. 回复要自然口语化，像真的群聊一样

历史消息格式说明：
历史里 assistant 的 content 以 【角色名】 开头表示那条是由哪个角色发出的。
注意区分，不要把别人说过的话当成自己的立场继续。

你必须且只能返回以下格式的 JSON 数组，不要返回任何其他内容：
[{"name":"角色名","reply":"回复内容"},{"name":"角色名","reply":"回复内容"}]

返回的 reply 只写正文，不要带 【角色名】 前缀。
不要添加任何解释、前缀或 markdown 格式（不要 ```json 包裹），直接返回 JSON 数组。$worldAfterBlock''';

    // {{user}} 替换；{{char}} 在群聊里没有单角色，留给 AI 自己按上下文判断
    systemPrompt = systemPrompt
        .replaceAll('{{user}}', userName)
        .replaceAll('{{User}}', userName);

    final history = _buildGroupHistory(groupId);
    _dumpGroupRequest(
      tag: 'group-random',
      groupId: groupId,
      contactId: groupId,
      systemPrompt: systemPrompt,
      history: history,
    );
    final rawReply = await _callGroupChatApi(
      dio: dio,
      systemPrompt: systemPrompt,
      historyMessages: history,
      maxTokens: 2000,
    );

    // 解析 JSON 数组（AI 可能在前后塞废话 / markdown / 换行）
    List<dynamic>? replies;
    try {
      var cleaned = rawReply
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
      if (match != null) {
        replies = jsonDecode(match.group(0)!) as List<dynamic>;
      } else {
        replies = jsonDecode(cleaned) as List<dynamic>;
      }
    } catch (_) {
      replies = null;
    }

    if (replies == null || replies.isEmpty) {
      _appendGroupFallbackReply(groupId, rawReply);
      return;
    }

    int appendedCount = 0;
    for (final entry in replies) {
      if (entry is! Map) continue;
      final name = (entry['name'] ?? '').toString().trim();
      final replyText = (entry['reply'] ?? '').toString().trim();
      if (name.isEmpty || replyText.isEmpty) continue;

      final replyContactId = _matchGroupMember(group, name);
      if (replyContactId == null) {
        // AI 幻觉：返回了群里不存在的角色名，丢弃该条避免显示成"群消息"
        debugPrint('[group-ai] 跳过未知角色: "$name"');
        continue;
      }

      final ts = DateTime.now();
      _appendMessage(
        contactId: groupId,
        message: ChatMessage(
          id: '$groupId-$replyContactId-${ts.microsecondsSinceEpoch}',
          contactId: replyContactId,
          sender: ChatMessageSender.ai,
          body: WordMessageBody(replyText),
          sentAt: ts,
        ),
        unreadCount: 0,
      );
      appendedCount++;

      // 让接力有节奏感
      await Future.delayed(const Duration(milliseconds: 300));
      notifyListeners();
    }

    // 所有条目都匹不上群成员 → 退回把原文显示成系统回复，不让用户什么都看不到
    if (appendedCount == 0) {
      _appendGroupFallbackReply(groupId, rawReply);
    }
  }

  /// 把 AI 返回的角色名映射到群成员 contactId。
  /// 策略：精确 → 归一化精确 → 归一化双向包含。归一化会去掉常见标点/括号/空白。
  String? _matchGroupMember(ChatGroup group, String name) {
    // 第一轮：原样精确匹配
    for (final cid in group.memberContactIds) {
      try {
        if (contactById(cid).name == name) return cid;
      } catch (_) {}
    }

    final normalizedTarget = _normalizeContactName(name);
    if (normalizedTarget.isEmpty) return null;

    // 第二轮：归一化后精确匹配
    for (final cid in group.memberContactIds) {
      try {
        if (_normalizeContactName(contactById(cid).name) == normalizedTarget) {
          return cid;
        }
      } catch (_) {}
    }

    // 第三轮：归一化后双向包含
    for (final cid in group.memberContactIds) {
      try {
        final normalizedMember =
            _normalizeContactName(contactById(cid).name);
        if (normalizedMember.isEmpty) continue;
        if (normalizedMember.contains(normalizedTarget) ||
            normalizedTarget.contains(normalizedMember)) {
          return cid;
        }
      } catch (_) {}
    }

    return null;
  }

  /// 归一化角色名：去掉空白、各种括号、引号、标点
  String _normalizeContactName(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[\[\](){}【】《》（）「」『』<>]'), '')
        .replaceAll(RegExp('[\'"`\u2018\u2019\u201C\u201D]'), '')
        .replaceAll(RegExp(r'[~!@#$%^&*_=+|/?.,;:\-]'), '')
        .toLowerCase();
  }

  /// 手动召唤：只调一个角色
  Future<void> _sendGroupManualReply(
    Dio dio,
    String groupId,
    ChatGroup group,
    String targetContactId,
  ) async {
    final ChatContact contact;
    try {
      contact = contactById(targetContactId);
    } catch (_) {
      _appendGroupFallbackReply(groupId, '【召唤失败】角色不存在');
      return;
    }

    // E1: 用户身份（与单聊路径一致：先查角色绑定，否则全局 persona）
    String userName = '江栩栩';
    String personaDesc = '';
    try {
      final resolved = await getResolvedPersona(contact.name);
      final pName = resolved['name'] as String? ?? '';
      final pDesc = resolved['description'] as String? ?? '';
      if (pName.isNotEmpty) userName = pName;
      if (pDesc.isNotEmpty) personaDesc = pDesc;
    } catch (_) {}

    // 拉角色卡原始字段（给预设 marker 用）
    String charDesc = '';
    String charPersonality = '';
    String charScenario = '';
    try {
      final charRes = await dio.get(
        '$kBridgeHost/characters/${Uri.encodeComponent(contact.name)}',
      );
      final d = charRes.data;
      charDesc = (d['description'] as String?) ?? '';
      charPersonality = (d['personality'] as String?) ?? '';
      charScenario = (d['scenario'] as String?) ?? '';
    } catch (_) {}

    // 注入世界书：APP全局 + 群聊 + 被召唤角色的角色专属
    final worldInfo = await buildWorldInfoStrings(
      contactId: targetContactId,
      groupId: groupId,
    );

    // E2a: 复用单聊预设拼装路径，让群手动模式吃到完整预设
    String systemPrompt;
    if (_currentPresetDetail != null) {
      systemPrompt = assembleSystemPrompt(
        contactId: targetContactId,
        charDescription: charDesc,
        charPersonality: charPersonality,
        charScenario: charScenario,
        personaDescription: personaDesc,
        worldInfoBefore: worldInfo.before,
        worldInfoAfter: worldInfo.after,
      );
    } else {
      // 没有预设：兜底用旧式拼接
      final personaText = [
        if (charDesc.isNotEmpty) charDesc,
        if (charPersonality.isNotEmpty) '性格：$charPersonality',
        if (charScenario.isNotEmpty) '场景：$charScenario',
      ].join('\n');
      systemPrompt = [
        if (worldInfo.before.isNotEmpty) worldInfo.before,
        if (personaText.isNotEmpty) personaText,
        if (personaDesc.isNotEmpty) '【用户人设】\n$personaDesc',
        if (worldInfo.after.isNotEmpty) worldInfo.after,
      ].join('\n\n');
    }

    // 群语境补充（追加在预设 system 之后，不破坏预设结构）
    const historyFormatNote =
        '历史里 assistant 的 content 以 【角色名】 开头表示那条是由哪个角色发出的。注意区分哪些是你说过的、哪些是其他角色说的，不要把别人的语气和立场当成自己的。你的回复只写正文，不要带 【】 前缀。';
    final groupContext =
        '\n\n你当前正在群聊「${group.name}」里以 ${contact.name} 的身份发言，请用 ${contact.name} 的语气和性格自然地回复群里的最新消息，简短自然。\n\n$historyFormatNote';
    systemPrompt = systemPrompt + groupContext;

    // 占位符替换（{{user}} → 真实用户名，{{char}} → 被召唤角色）
    systemPrompt = _replacePlaceholders(systemPrompt, contact.name, userName);

    final history = _buildGroupHistory(groupId);
    _dumpGroupRequest(
      tag: 'group-manual',
      groupId: groupId,
      contactId: targetContactId,
      systemPrompt: systemPrompt,
      history: history,
    );
    final rawReply = await _callGroupChatApi(
      dio: dio,
      systemPrompt: systemPrompt,
      historyMessages: history,
      maxTokens: 800,
    );
    final cleaned = _replacePlaceholders(rawReply, contact.name, userName).trim();

    final ts = DateTime.now();
    _appendMessage(
      contactId: groupId,
      message: ChatMessage(
        id: '$groupId-$targetContactId-${ts.microsecondsSinceEpoch}',
        contactId: targetContactId,
        sender: ChatMessageSender.ai,
        body: WordMessageBody(cleaned),
        sentAt: ts,
      ),
      unreadCount: 0,
    );
  }

  void _appendGroupFallbackReply(String groupId, String text) {
    final ts = DateTime.now();
    _appendMessage(
      contactId: groupId,
      message: ChatMessage(
        id: '$groupId-fallback-${ts.microsecondsSinceEpoch}',
        contactId: groupId,
        sender: ChatMessageSender.ai,
        body: WordMessageBody(text),
        sentAt: ts,
      ),
      unreadCount: 0,
    );
  }

  Future<void> loadPersistedGroups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_groups.json');
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in data.entries) {
        final g = entry.value;
        final group = ChatGroup(
          id: g['id'],
          name: g['name'],
          memberContactIds: List<String>.from(g['memberContactIds']),
          createdAt: DateTime.parse(g['createdAt']),
        );
        _groups[group.id] = group;

        if (!_threads.containsKey(group.id)) {
          _threads[group.id] = ChatThread(
            contactId: group.id,
            lastMessage: '群聊已创建',
            updatedAt: group.createdAt,
            groupId: group.id,
          );
          _messages[group.id] ??= [];
        }
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
  final Map<String, ChatGroup> _groups = {};
  final Map<String, bool> _groupRandomMode = {}; // groupId -> true=随机, false=手动；默认 true
  final Map<String, String> _groupError = {}; // groupId -> 最近一次 AI 调用错误
  ChatBubbleAppearance _bubbleAppearance;
  List<Map<String, dynamic>> _personas = [];
  String _globalPersonaId = '';

  // ---- 预设系统 ----
  List<PresetInfo> _presetList = [];
  PresetDetail? _currentPresetDetail;
  String? _globalPresetName;
  final Map<String, String> _chatPresetOverrides = {}; // contactId → presetName
  final Map<String, Map<String, bool>> _chatPromptToggles = {}; // contactId → {identifier: enabled}
  final Map<String, bool> _globalPromptToggles = {}; // identifier → enabled

  // ---- 世界书系统 ----
  List<String> _worldBookList = [];
  WorldBindings _worldBindings = WorldBindings();
  final Map<String, WorldBookDetail> _worldBookCache = {};

  // ---- API 接口配置 ----
  String _apiProviderId = '';
  String _apiKey = '';
  String _apiModelId = '';

  String get apiProviderId => _apiProviderId;
  String get apiKey => _apiKey;
  String get apiModelId => _apiModelId;
  ApiProvider? get currentApiProvider => findProvider(_apiProviderId);
  bool get isApiConfigured =>
      _apiKey.isNotEmpty && _apiProviderId.isNotEmpty && _apiModelId.isNotEmpty;

  Future<void> loadApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _apiProviderId = prefs.getString('api_provider_id') ?? '';
    _apiKey = prefs.getString('api_key') ?? '';
    _apiModelId = prefs.getString('api_model_id') ?? '';
    notifyListeners();
  }

  Future<void> setApiProvider(String providerId) async {
    _apiProviderId = providerId;
    _apiModelId = ''; // 切换 provider 时清空 model
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_provider_id', providerId);
    await prefs.setString('api_model_id', '');
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKey);
    notifyListeners();
  }

  Future<void> setApiModel(String modelId) async {
    _apiModelId = modelId.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_model_id', modelId.trim());
    notifyListeners();
  }

  ChatTab _currentTab = ChatTab.chats;
  String? _activeConversationId;
  bool _disposed = false;

  ChatTab get currentTab => _currentTab;

  UserProfile get profile => _profile;

  ChatContextConfig get contextConfig => _contextConfig;

  ChatBubbleAppearance get bubbleAppearance => _bubbleAppearance;

  List<ChatBubblePreset> get bubblePresets => ChatBubblePreset.presets;

  List<Map<String, dynamic>> get personas => List.unmodifiable(_personas);
  String get globalPersonaId => _globalPersonaId;

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

  List<ChatThread> get friendThreads {
    final items = _threads.values.where((t) => !t.isGroup).toList()
      ..sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        return right.updatedAt.compareTo(left.updatedAt);
      });
    return List<ChatThread>.unmodifiable(items);
  }

  List<ChatThread> get groupThreads {
    final items = _threads.values.where((t) => t.isGroup).toList()
      ..sort((left, right) {
        if (left.isPinned != right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        return right.updatedAt.compareTo(left.updatedAt);
      });
    return List<ChatThread>.unmodifiable(items);
  }

  List<ChatGroup> get groups {
    final items = _groups.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<ChatGroup>.unmodifiable(items);
  }

  ChatGroup groupById(String groupId) {
    return _groups[groupId]!;
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

    final res = await dio.get('$kBridgeHost/characters');
    final List<dynamic> list = res.data;

    _contacts.clear();
    _threads.removeWhere((key, thread) => !thread.isGroup);
    _moments.clear();

    final now = DateTime.now();
    for (final item in list) {
      final name = item['name'] as String? ?? '未知角色';
      final signature = item['signature'] as String? ?? '来自酒馆的角色';
      final firstMes = item['first_mes'] as String? ?? '你好，我是$name。';

      final contactId = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_');
      final filename = item['filename'] as String? ?? '';

      final contact = ChatContact(
        id: contactId,
        name: name,
        signature: signature,
        personaSummary: item['description'] as String? ?? '',
        statusLabel: '在线',
        avatarColor: _colorForContact(contactId),
        emoji: _avatarLabelForName(name),
        avatarUrl: filename.isNotEmpty
            ? '$kBridgeHost/avatar/${Uri.encodeComponent(filename)}'
            : null,
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
          ChatMessage(
            id: '$contactId-${now.microsecondsSinceEpoch}',
            contactId: contactId,
            sender: ChatMessageSender.ai,
            body: WordMessageBody(firstMes),
            sentAt: now,
          ),
        ];
      }
    }

    notifyListeners();
    await loadPersistedGroups();   // 先恢复群组：建好 _messages[groupId] 容器
    await loadPersistedMessages(); // 再恢复消息：群消息能找到对应 key
  } catch (e) {
    // 桥接服务连不上就保留原来的联系人
  }
}

  /// 从桥接服务拉取所有 persona 列表
  Future<void> fetchPersonas() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      final res = await dio.get('$kBridgeHost/personas');
      _personas = List<Map<String, dynamic>>.from(res.data);
      notifyListeners();
    } catch (_) {}
  }

  /// 设置全局默认 persona，存入 shared_preferences
  Future<void> setGlobalPersona(String personaId) async {
    _globalPersonaId = personaId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('global_persona_id', personaId);
    } catch (_) {}
  }

  /// 启动时恢复全局 persona 设置
  Future<void> loadGlobalPersona() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _globalPersonaId = prefs.getString('global_persona_id') ?? '';
    } catch (_) {}
  }

  /// 给某个聊天单独设置 persona（覆盖全局）
  Future<void> setChatPersona(String characterName, String personaId) async {
    try {
      final dio = Dio();
      await dio.post(
        '$kBridgeHost/persona_binding',
        data: {'character': characterName, 'persona_id': personaId},
      );
      notifyListeners();
    } catch (_) {}
  }

  /// 解析某个聊天应该用哪个 persona（单聊绑定 > 全局 > 硬编码）
  Future<Map<String, dynamic>> getResolvedPersona(String characterName) async {
    // 优先查单聊绑定
    try {
      final dio = Dio();
      final res = await dio.get(
        '$kBridgeHost/persona_binding/${Uri.encodeComponent(characterName)}',
      );
      final data = res.data as Map<String, dynamic>;
      if ((data['id'] as String? ?? '').isNotEmpty) return data;
    } catch (_) {}
    // 其次用全局
    if (_globalPersonaId.isNotEmpty) {
      final match = _personas.where((p) => p['id'] == _globalPersonaId);
      if (match.isNotEmpty) return match.first;
    }
    // 兜底
    return {'id': '', 'name': '江栩栩', 'description': ''};
  }

  // ========== 预设系统方法 ==========

  List<PresetInfo> get presetList => List.unmodifiable(_presetList);
  PresetDetail? get currentPresetDetail => _currentPresetDetail;
  String? get globalPresetName => _globalPresetName;

  /// 从桥接服务拉取预设列表
  Future<void> fetchPresetList() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      final res = await dio.get('$kBridgeHost/presets');
      final List<dynamic> list = res.data;
      _presetList = list
          .map((item) => PresetInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// 拉取单个预设的完整详情
  Future<PresetDetail?> fetchPresetDetail(String presetName) async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      final res = await dio.get(
        '$kBridgeHost/presets/${Uri.encodeComponent(presetName)}',
      );
      final detail = PresetDetail.fromJson(res.data as Map<String, dynamic>);
      _currentPresetDetail = detail;
      notifyListeners();
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// 设置全局默认预设
  Future<void> setGlobalPreset(String presetName) async {
    _globalPresetName = presetName;
    await fetchPresetDetail(presetName);
    // 持久化
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_preset_name', presetName);
    _savePresetOverrides();
    notifyListeners();
  }

  /// 启动时恢复全局预设
  Future<void> loadGlobalPreset() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('global_preset_name');
    if (name != null && name.isNotEmpty) {
      _globalPresetName = name;
      await fetchPresetDetail(name);
    }
  }

  /// 设置单聊预设覆盖
  void setChatPreset(String contactId, String? presetName) {
    if (presetName == null) {
      _chatPresetOverrides.remove(contactId);
    } else {
      _chatPresetOverrides[contactId] = presetName;
    }
    _savePresetOverrides();
    notifyListeners();
  }

  /// 获取某聊天实际使用的预设名
  String? getResolvedPresetName(String contactId) {
    return _chatPresetOverrides[contactId] ?? _globalPresetName;
  }

  /// 设置词条开关覆盖（全局级别）
  void setGlobalPromptToggle(String identifier, bool enabled) {
    _globalPromptToggles[identifier] = enabled;
    _savePresetOverrides();
    notifyListeners();
  }

  /// 设置词条开关覆盖（单聊级别）
  void setChatPromptToggle(String contactId, String identifier, bool enabled) {
    _chatPromptToggles.putIfAbsent(contactId, () => {});
    _chatPromptToggles[contactId]![identifier] = enabled;
    _savePresetOverrides();
    notifyListeners();
  }

  /// 将预设覆盖和词条开关持久化到本地 JSON
  Future<void> _savePresetOverrides() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_preset_overrides.json');
      final data = {
        'globalPreset': _globalPresetName,
        'chatPresets': _chatPresetOverrides,
        'globalToggles': _globalPromptToggles,
        'chatToggles': _chatPromptToggles,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// 启动时从本地恢复预设覆盖和词条开关
  Future<void> loadPresetOverrides() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_preset_overrides.json');
      if (!await file.exists()) return;
      final raw =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      if (raw['globalPreset'] is String) {
        _globalPresetName = raw['globalPreset'] as String;
      }
      if (raw['chatPresets'] is Map) {
        _chatPresetOverrides
          ..clear()
          ..addAll(Map<String, String>.from(raw['chatPresets'] as Map));
      }
      if (raw['globalToggles'] is Map) {
        _globalPromptToggles
          ..clear()
          ..addAll(Map<String, bool>.from(raw['globalToggles'] as Map));
      }
      if (raw['chatToggles'] is Map) {
        final ct = raw['chatToggles'] as Map<String, dynamic>;
        _chatPromptToggles.clear();
        ct.forEach((k, v) {
          _chatPromptToggles[k] =
              Map<String, bool>.from(v as Map);
        });
      }
      notifyListeners();
    } catch (_) {}
  }

  // ==================== 世界书系统 ====================

  List<String> get worldBookList => List.unmodifiable(_worldBookList);
  WorldBindings get worldBindings => _worldBindings;

  /// 拉取世界书列表
  Future<void> fetchWorldBookList() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      final res = await dio.get('$kBridgeHost/worlds');
      _worldBookList = List<String>.from(res.data as List);
      notifyListeners();
    } catch (_) {}
  }

  /// 拉取单个世界书详情（带缓存）
  Future<WorldBookDetail?> fetchWorldBookDetail(String name) async {
    if (_worldBookCache.containsKey(name)) return _worldBookCache[name];
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      final res = await dio
          .get('$kBridgeHost/worlds/${Uri.encodeComponent(name)}');
      final entries = (res.data['entries'] as List)
          .map((e) => WorldBookEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final detail = WorldBookDetail(name: name, entries: entries);
      _worldBookCache[name] = detail;
      return detail;
    } catch (_) {
      return null;
    }
  }

  /// APP 全局世界书
  void setAppGlobalWorlds(List<String> names) {
    _worldBindings.appGlobal = List.from(names);
    _saveWorldBindings();
    notifyListeners();
  }

  /// 单聊聊天世界书
  void setChatWorlds(String contactId, List<String> names) {
    _worldBindings.chat[contactId] = List.from(names);
    _saveWorldBindings();
    notifyListeners();
  }

  /// 群聊全局世界书
  void setGroupWorlds(String groupId, List<String> names) {
    _worldBindings.group[groupId] = List.from(names);
    _saveWorldBindings();
    notifyListeners();
  }

  /// 角色专属世界书
  void setCharacterWorlds(String contactId, List<String> names) {
    _worldBindings.character[contactId] = List.from(names);
    _saveWorldBindings();
    notifyListeners();
  }

  /// 解析某次对话应该加载的全部世界书名称
  List<String> resolveWorldBooks({
    required String contactId,
    String? groupId,
  }) {
    final books = <String>{};
    // 1. APP 全局
    books.addAll(_worldBindings.appGlobal);
    // 2. 聊天世界书（单聊用 contactId，群聊用 groupId）
    if (groupId != null) {
      books.addAll(_worldBindings.group[groupId] ?? const []);
    } else {
      books.addAll(_worldBindings.chat[contactId] ?? const []);
    }
    // 3. 角色专属
    books.addAll(_worldBindings.character[contactId] ?? const []);
    return books.toList();
  }

  /// 持久化世界书绑定
  Future<void> _saveWorldBindings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_world_bindings.json');
      await file.writeAsString(jsonEncode(_worldBindings.toJson()));
    } catch (_) {}
  }

  /// 启动时恢复世界书绑定
  Future<void> loadWorldBindings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/wangwang_world_bindings.json');
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _worldBindings = WorldBindings.fromJson(raw);
      notifyListeners();
    } catch (_) {}
  }

  /// 解析某词条在某聊天中的最终开关状态
  /// 优先级：单聊覆盖 > 全局覆盖 > ST 原始开关
  bool resolvePromptEnabled(String contactId, String identifier) {
    // 单聊覆盖
    final chatToggle = _chatPromptToggles[contactId]?[identifier];
    if (chatToggle != null) return chatToggle;
    // 全局覆盖
    final globalToggle = _globalPromptToggles[identifier];
    if (globalToggle != null) return globalToggle;
    // ST 原始开关（从 preset detail 的 promptOrder 读取）
    if (_currentPresetDetail != null) {
      try {
        final orderItem = _currentPresetDetail!.promptOrder
            .firstWhere((o) => o.identifier == identifier);
        return orderItem.enabled;
      } catch (_) {}
    }
    return false;
  }

  /// 打印群聊请求上下文到 logcat
  void _dumpGroupRequest({
    required String tag,
    required String groupId,
    required String contactId,
    required String systemPrompt,
    required List<Map<String, dynamic>> history,
  }) {
    debugPrint('========== AI REQUEST DUMP [$tag] group=$groupId contact=$contactId ==========');
    debugPrint('[$tag] resolved books: ${resolveWorldBooks(contactId: contactId, groupId: groupId)}');
    debugPrint('[$tag] system-prompt length=${systemPrompt.length}');
    for (final chunk in _splitForLog(systemPrompt)) {
      debugPrint('[$tag][system] $chunk');
    }
    debugPrint('[$tag] history count=${history.length}');
    for (var i = 0; i < history.length; i++) {
      final m = history[i];
      final role = m['role'] ?? '?';
      final content = m['content']?.toString() ?? '';
      for (final chunk in _splitForLog('[$i/$role] $content')) {
        debugPrint('[$tag][history] $chunk');
      }
    }
    debugPrint('========== END DUMP [$tag] ==========');
  }

  /// 把超长字符串拆成 800 字符一段，避免 Android logcat 截断
  static List<String> _splitForLog(String s) {
    const chunk = 800;
    if (s.length <= chunk) return [s];
    final out = <String>[];
    for (var i = 0; i < s.length; i += chunk) {
      out.add(s.substring(i, i + chunk > s.length ? s.length : i + chunk));
    }
    return out;
  }

  /// 群聊专用：汇总 APP全局 + 群聊世界书 + 所有成员的角色专属世界书
  /// 软上限 [maxCharsPerSide] 防止大群 token 爆炸，超出直接截断
  Future<({String before, String after})> buildGroupWorldInfo({
    required String groupId,
    required List<String> memberContactIds,
    int maxCharsPerSide = 30000,
  }) async {
    // 1. 汇总所有涉及的世界书名称（dedupe）
    final names = <String>{};
    names.addAll(_worldBindings.appGlobal);
    names.addAll(_worldBindings.group[groupId] ?? const []);
    for (final cid in memberContactIds) {
      names.addAll(_worldBindings.character[cid] ?? const []);
    }
    if (names.isEmpty) return (before: '', after: '');

    // 2. 拉词条，按 position 分成 before/after
    final beforeEntries = <WorldBookEntry>[];
    final afterEntries = <WorldBookEntry>[];
    for (final name in names) {
      final detail = await fetchWorldBookDetail(name);
      if (detail == null) continue;
      for (final e in detail.entries) {
        if (e.disable) continue;
        if (e.content.isEmpty) continue;
        if (e.position == 1) {
          afterEntries.add(e);
        } else {
          beforeEntries.add(e);
        }
      }
    }
    beforeEntries.sort((a, b) => a.order.compareTo(b.order));
    afterEntries.sort((a, b) => a.order.compareTo(b.order));

    String before = beforeEntries.map((e) => e.content).join('\n\n');
    String after = afterEntries.map((e) => e.content).join('\n\n');

    // 3. 软上限截断
    if (before.length > maxCharsPerSide) {
      before = '${before.substring(0, maxCharsPerSide)}\n\n[...世界书内容过长，已截断]';
    }
    if (after.length > maxCharsPerSide) {
      after = '${after.substring(0, maxCharsPerSide)}\n\n[...]';
    }

    return (before: before, after: after);
  }

  /// 解析某次对话要注入的世界书内容，按 position 分成 before/after 两段
  /// position: 0 = worldInfoBefore, 1 = worldInfoAfter
  /// 只拼入 disable=false 的词条，按 order 升序
  Future<({String before, String after})> buildWorldInfoStrings({
    required String contactId,
    String? groupId,
  }) async {
    final names = resolveWorldBooks(contactId: contactId, groupId: groupId);
    if (names.isEmpty) return (before: '', after: '');

    final beforeEntries = <WorldBookEntry>[];
    final afterEntries = <WorldBookEntry>[];
    for (final name in names) {
      final detail = await fetchWorldBookDetail(name);
      if (detail == null) continue;
      for (final e in detail.entries) {
        if (e.disable) continue;
        if (e.content.isEmpty) continue;
        if (e.position == 1) {
          afterEntries.add(e);
        } else {
          beforeEntries.add(e);
        }
      }
    }
    beforeEntries.sort((a, b) => a.order.compareTo(b.order));
    afterEntries.sort((a, b) => a.order.compareTo(b.order));

    return (
      before: beforeEntries.map((e) => e.content).join('\n\n'),
      after: afterEntries.map((e) => e.content).join('\n\n'),
    );
  }

  /// 核心方法：按预设拼装 system prompt
  /// 返回拼好的完整 prompt 文本
  String assembleSystemPrompt({
    required String contactId,
    required String charDescription,
    required String charPersonality,
    required String charScenario,
    required String personaDescription,
    String worldInfoBefore = '',
    String worldInfoAfter = '',
  }) {
    final detail = _currentPresetDetail;
    if (detail == null) {
      // 没有预设就用旧逻辑
      return [
        if (worldInfoBefore.isNotEmpty) worldInfoBefore,
        if (charDescription.isNotEmpty) charDescription,
        if (charPersonality.isNotEmpty) '性格：$charPersonality',
        if (charScenario.isNotEmpty) '场景：$charScenario',
        if (personaDescription.isNotEmpty) '【用户人设】\n$personaDescription',
        if (worldInfoAfter.isNotEmpty) worldInfoAfter,
      ].join('\n\n');
    }

    final parts = <String>[];

    for (final orderItem in detail.promptOrder) {
      final enabled = resolvePromptEnabled(contactId, orderItem.identifier);
      if (!enabled) continue;

      final prompt = detail.findPrompt(orderItem.identifier);

      // marker 词条 → 替换为实际数据
      if (prompt != null && prompt.isMarker) {
        switch (orderItem.identifier) {
          case 'charDescription':
            if (charDescription.isNotEmpty) parts.add(charDescription);
          case 'charPersonality':
            if (charPersonality.isNotEmpty) parts.add(charPersonality);
          case 'scenario':
            if (charScenario.isNotEmpty) parts.add(charScenario);
          case 'personaDescription':
            if (personaDescription.isNotEmpty) parts.add(personaDescription);
          case 'worldInfoBefore':
            if (worldInfoBefore.isNotEmpty) parts.add(worldInfoBefore);
          case 'worldInfoAfter':
            if (worldInfoAfter.isNotEmpty) parts.add(worldInfoAfter);
          // chatHistory, dialogueExamples → 不拼进 system prompt
        }
        continue;
      }

      // 普通词条 → 有 content 就拼进去
      if (prompt != null && prompt.content.isNotEmpty) {
        parts.add(prompt.content);
      }
    }

    return parts.join('\n\n');
  }

  /// 群聊随机模式专用：从当前预设里抽取所有 enabled 的非 marker 指令块。
  /// 群聊里没有单一角色卡，无法复用 [assembleSystemPrompt]，但预设里那些
  /// 通用的"越狱 / 输出格式 / 风格"指令对群聊同样有用，提取出来当群规则注入。
  /// [contextId] 用于查 chat 级覆盖（可传 groupId）。
  String extractPresetInstructions(String contextId) {
    final detail = _currentPresetDetail;
    if (detail == null) return '';
    final parts = <String>[];
    for (final orderItem in detail.promptOrder) {
      if (!resolvePromptEnabled(contextId, orderItem.identifier)) continue;
      final prompt = detail.findPrompt(orderItem.identifier);
      if (prompt == null) continue;
      if (prompt.isMarker) continue; // marker 词条群聊里没单角色数据，跳过
      if (prompt.content.isEmpty) continue;
      parts.add(prompt.content);
    }
    return parts.join('\n\n');
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
      avatarUrl: null,
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

  /// 删除单条消息
  Future<void> deleteMessage({required String contactId, required String messageId}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    msgs.removeWhere((m) => m.id == messageId);
    if (msgs.isNotEmpty) {
      final last = msgs.last;
      _threads[contactId] = _threads[contactId]!.copyWith(
        lastMessage: last.previewText,
        updatedAt: last.sentAt,
      );
    } else {
      _threads[contactId] = _threads[contactId]!.copyWith(lastMessage: '');
    }
    notifyListeners();
    await _saveMessages();
  }

  /// 批量删除消息
  Future<void> batchDeleteMessages({required String contactId, required Set<String> messageIds}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    msgs.removeWhere((m) => messageIds.contains(m.id));
    if (msgs.isNotEmpty) {
      final last = msgs.last;
      _threads[contactId] = _threads[contactId]!.copyWith(
        lastMessage: last.previewText,
        updatedAt: last.sentAt,
      );
    } else {
      _threads[contactId] = _threads[contactId]!.copyWith(lastMessage: '');
    }
    notifyListeners();
    await _saveMessages();
  }

  /// 编辑消息内容（改写）
  Future<void> editMessage({required String contactId, required String messageId, required String newText}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final old = msgs[idx];
    final newBody = WordMessageBody(newText);

    if (old.alternatives.isNotEmpty) {
      // 改写当前激活的那个版本；同步 body 字段保持 previewText / lastMessage 一致
      final newAlts = List<ChatMessageBody>.from(old.alternatives);
      newAlts[old.activeAltIndex] = newBody;
      msgs[idx] = old.copyWith(body: newBody, alternatives: newAlts);
    } else {
      msgs[idx] = old.copyWith(body: newBody);
    }

    if (idx == msgs.length - 1) {
      _threads[contactId] = _threads[contactId]!.copyWith(lastMessage: newText);
    }
    notifyListeners();
    await _saveMessages();
  }

  /// 切换消息隐藏状态
  Future<void> toggleHideMessage({required String contactId, required String messageId}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs[idx] = msgs[idx].copyWith(isHidden: !msgs[idx].isHidden);
    notifyListeners();
    await _saveMessages();
  }

  /// 批量切换隐藏状态
  Future<void> batchToggleHideMessages({required String contactId, required Set<String> messageIds, required bool hide}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    for (var i = 0; i < msgs.length; i++) {
      if (messageIds.contains(msgs[i].id)) {
        msgs[i] = msgs[i].copyWith(isHidden: hide);
      }
    }
    notifyListeners();
    await _saveMessages();
  }

  /// 回溯：删除指定消息及之后的所有消息
  Future<void> rollbackToMessage({required String contactId, required String messageId}) async {
    final msgs = _messages[contactId];
    if (msgs == null) return;
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    msgs.removeRange(idx, msgs.length);
    if (msgs.isNotEmpty) {
      final last = msgs.last;
      _threads[contactId] = _threads[contactId]!.copyWith(
        lastMessage: last.previewText,
        updatedAt: last.sentAt,
      );
    } else {
      _threads[contactId] = _threads[contactId]!.copyWith(lastMessage: '');
    }
    notifyListeners();
    await _saveMessages();
  }

  /// 重新生成最后一条 AI 回复
  Future<void> rerollLastReply({required String contactId}) async {
    final msgs = _messages[contactId];
    if (msgs == null || msgs.isEmpty) return;
    if (msgs.last.sender != ChatMessageSender.ai) return;

    final lastMsg = msgs.last;
    final List<ChatMessageBody> alts = lastMsg.alternatives.isNotEmpty
        ? List.from(lastMsg.alternatives)
        : [lastMsg.body];

    msgs.removeLast();
    notifyListeners();

    await _triggerAiReply(contactId: contactId);

    // _appendMessage 在 _triggerAiReply 内部会用 List.from 重建列表，
    // 所以这里必须重新取一次 _messages[contactId]，旧的 msgs 引用已脱钩。
    final freshMsgs = _messages[contactId];
    if (freshMsgs != null &&
        freshMsgs.isNotEmpty &&
        freshMsgs.last.sender == ChatMessageSender.ai) {
      final newMsg = freshMsgs.last;
      alts.add(newMsg.body);
      freshMsgs[freshMsgs.length - 1] = newMsg.copyWith(
        alternatives: alts,
        activeAltIndex: alts.length - 1,
      );
      notifyListeners();
      await _saveMessages();
    }
  }

  /// 群聊版 reroll：让最后一条 AI 消息的原作者再说一次，结果作为新 alt 追加
  Future<void> rerollGroupLastReply({required String groupId}) async {
    final msgs = _messages[groupId];
    if (msgs == null || msgs.isEmpty) return;
    final lastMsg = msgs.last;
    if (lastMsg.sender != ChatMessageSender.ai) return;
    // 系统消息（建群/重置提示）的 contactId == groupId，跳过
    if (lastMsg.contactId == groupId) return;

    final targetContactId = lastMsg.contactId;
    final List<ChatMessageBody> alts = lastMsg.alternatives.isNotEmpty
        ? List.from(lastMsg.alternatives)
        : [lastMsg.body];

    msgs.removeLast();
    notifyListeners();

    // 复用手动召唤路径：让原作者再说一次
    await sendGroupMessage(
      groupId: groupId,
      text: '',
      targetContactId: targetContactId,
      summonOnly: true,
    );

    // sendGroupMessage 内部会 append，这里读最新引用
    final freshMsgs = _messages[groupId];
    if (freshMsgs != null &&
        freshMsgs.isNotEmpty &&
        freshMsgs.last.sender == ChatMessageSender.ai &&
        freshMsgs.last.contactId == targetContactId) {
      final newMsg = freshMsgs.last;
      alts.add(newMsg.body);
      freshMsgs[freshMsgs.length - 1] = newMsg.copyWith(
        alternatives: alts,
        activeAltIndex: alts.length - 1,
      );
      notifyListeners();
      await _saveMessages();
    }
  }

  /// 切换最后一条 AI 消息的版本
  Future<void> switchAltVersion({
    required String contactId,
    required int newIndex,
  }) async {
    final msgs = _messages[contactId];
    if (msgs == null || msgs.isEmpty) return;
    final lastMsg = msgs.last;
    if (lastMsg.alternatives.isEmpty) return;
    if (newIndex < 0 || newIndex >= lastMsg.alternatives.length) return;

    msgs[msgs.length - 1] = lastMsg.copyWith(
      body: lastMsg.alternatives[newIndex],
      activeAltIndex: newIndex,
    );
    _threads[contactId] = _threads[contactId]!.copyWith(
      lastMessage: msgs.last.previewText,
    );
    notifyListeners();
    await _saveMessages();
  }

  /// 重置对话：清空聊天记录，恢复为角色初始消息
  Future<void> clearChat({required String contactId, bool clearMemories = false}) async {
    final contact = contactById(contactId);
    String firstMes = '你好，我是${contact.name}。';
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 3);
      final res = await dio.get('$kBridgeHost/characters/${Uri.encodeComponent(contact.name)}');
      firstMes = res.data['first_mes'] as String? ?? firstMes;
    } catch (_) {}

    final now = DateTime.now();
    _messages[contactId] = [
      ChatMessage(
        id: '$contactId-${now.microsecondsSinceEpoch}',
        contactId: contactId,
        sender: ChatMessageSender.ai,
        body: WordMessageBody(firstMes),
        sentAt: now,
      ),
    ];
    _threads[contactId] = _threads[contactId]!.copyWith(
      lastMessage: firstMes,
      updatedAt: now,
      unreadCount: 0,
    );

    if (clearMemories) {
      _summaries.remove(contactId);
      _memories.removeWhere((m) => m.contactId == contactId);
      _diaries.removeWhere((d) => d.contactId == contactId);
      _thoughts.removeWhere((t) => t.contactId == contactId);
      _systemEntries.removeWhere((s) => s.contactId == contactId);
      await _summaryStore.saveSummaries(_summaries);
    }

    notifyListeners();
    await _saveMessages();
  }

  /// 发送用户消息后，立即更新会话列表，再异步追加一条角色回复，模拟聊天链路闭环。
  Future<void> sendTextMessage({
    required String contactId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 发新消息前，把上一条 AI 消息的 alternatives 清理掉，只保留当前选中版本
    final existingMsgs = _messages[contactId];
    if (existingMsgs != null && existingMsgs.isNotEmpty) {
      final last = existingMsgs.last;
      if (last.sender == ChatMessageSender.ai &&
          last.alternatives.length > 1) {
        existingMsgs[existingMsgs.length - 1] = last.copyWith(
          alternatives: const [],
          activeAltIndex: 0,
        );
      }
    }

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
    await _saveMessages();

    if (!isApiConfigured) {
      final errorPayloads = [
        {'type': 'word', 'text': '【未配置接口】请先在“我”页面设置 API 接口和密钥。'}
      ];
      await ingestStructuredPayloads(
          contactId: contactId, payloads: errorPayloads);
      return;
    }

    await _triggerAiReply(contactId: contactId);
  }

  /// 触发 AI 回复（不添加用户消息，只调 API 拿回复）
  Future<void> _triggerAiReply({required String contactId}) async {
    _typingContacts.add(contactId);
    notifyListeners();

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 120);

      // 第一步：从桥接服务拉角色人设
      final contact = contactById(contactId);
      String systemPrompt = '你是一个AI角色，请自然地回复用户。';
      String userName = '江栩栩';
      String personaDesc = '';
      try {
        final resolved = await getResolvedPersona(contact.name);
        final pName = resolved['name'] as String? ?? '';
        final pDesc = resolved['description'] as String? ?? '';
        if (pName.isNotEmpty) userName = pName;
        if (pDesc.isNotEmpty) personaDesc = pDesc;
      } catch (_) {}
      try {
        final charRes = await dio.get(
          '$kBridgeHost/characters/${Uri.encodeComponent(contact.name)}',
        );
        final charData = charRes.data;
        final desc = charData['description'] as String? ?? '';
        final personality = charData['personality'] as String? ?? '';
        final scenario = charData['scenario'] as String? ?? '';

        // 拉取世界书内容
        final worldInfo = await buildWorldInfoStrings(contactId: contactId);

        // 如果有预设，用预设拼装；否则走旧逻辑
        if (_currentPresetDetail != null) {
          systemPrompt = assembleSystemPrompt(
            contactId: contactId,
            charDescription: desc,
            charPersonality: personality,
            charScenario: scenario,
            personaDescription: personaDesc,
            worldInfoBefore: worldInfo.before,
            worldInfoAfter: worldInfo.after,
          );
        } else {
          systemPrompt = [
            if (worldInfo.before.isNotEmpty) worldInfo.before,
            if (desc.isNotEmpty) desc,
            if (personality.isNotEmpty) '性格：$personality',
            if (scenario.isNotEmpty) '场景：$scenario',
            if (personaDesc.isNotEmpty) '【用户人设】\n$personaDesc',
            if (worldInfo.after.isNotEmpty) worldInfo.after,
          ].join('\n\n');
        }

        // 统一做占位符替换
        systemPrompt = _replacePlaceholders(systemPrompt, contact.name, userName);
      } catch (_) {
        // 拉不到角色卡就用默认 prompt，不影响聊天
      }

      // 第二步：构建对话历史（过滤隐藏消息）
      final history = messagesFor(contactId)
          .where((m) => m.body is WordMessageBody && !m.isHidden)
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

      // 第三步：根据当前 provider 发请求
      debugPrint('[_triggerAiReply] provider=$_apiProviderId model=$_apiModelId');
      // === 调试：打印完整上下文 ===
      debugPrint('========== AI REQUEST DUMP (contact=$contactId) ==========');
      debugPrint('[world-info] resolved books: ${resolveWorldBooks(contactId: contactId)}');
      debugPrint('[system-prompt] length=${systemPrompt.length}');
      for (final chunk in _splitForLog(systemPrompt)) {
        debugPrint('[system] $chunk');
      }
      debugPrint('[history] count=${recentHistory.length}');
      for (var i = 0; i < recentHistory.length; i++) {
        final m = recentHistory[i];
        final role = m.sender == ChatMessageSender.user ? 'user' : 'assistant';
        final text = (m.body as WordMessageBody).text;
        for (final chunk in _splitForLog('[$i/$role] $text')) {
          debugPrint('[history] $chunk');
        }
      }
      debugPrint('========== END DUMP ==========');
      final provider = currentApiProvider!;

      // Claude API 格式不同，需要特殊处理
      final Map<String, dynamic> requestData;
      final Map<String, String> requestHeaders;

      if (_apiProviderId == 'claude') {
        requestHeaders = {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        };
        requestData = {
          'model': _apiModelId,
          'max_tokens': 1024,
          'system': systemPrompt,
          'messages': [
            for (final m in recentHistory)
              {
                'role': m.sender == ChatMessageSender.user ? 'user' : 'assistant',
                'content': (m.body as WordMessageBody).text,
              },
          ],
        };
      } else {
        requestHeaders = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        };
        requestData = {
          'model': _apiModelId,
          'messages': messages,
          'max_tokens': _apiModelId.contains('reasoner') ? 4000 : 1024,
          'stream': false,
        };
      }

      final response = await dio.post(
        provider.baseUrl,
        options: Options(headers: requestHeaders),
        data: requestData,
      );

      // Claude 返回格式不同
      final String aiReplyText;
      if (_apiProviderId == 'claude') {
        final content = response.data['content'] as List;
        aiReplyText = content
            .where((block) => block['type'] == 'text')
            .map((block) => block['text'] as String)
            .join('\n');
      } else {
        aiReplyText =
            response.data['choices'][0]['message']['content'] as String;
      }
      final String cleanedReply = _replacePlaceholders(aiReplyText, contact.name, userName);

      final replyPayloads = [
        {'type': 'word', 'text': cleanedReply}
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

  String _replacePlaceholders(String text, String charName, [String userName = '江栩栩']) {
    return text
        .replaceAll('{{user}}', userName)
        .replaceAll('{{char}}', charName)
        .replaceAll('{{User}}', userName)
        .replaceAll('{{Char}}', charName);
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
