import 'package:flutter/material.dart';

import 'chat_message_payloads.dart';

enum ChatTab { chats, contacts, moments, profile }

extension ChatTabPresentation on ChatTab {
  String get label {
    return switch (this) {
      ChatTab.chats => '聊天',
      ChatTab.contacts => '联系人',
      ChatTab.moments => '朋友圈',
      ChatTab.profile => '我',
    };
  }

  IconData get icon {
    return switch (this) {
      ChatTab.chats => Icons.chat_bubble_rounded,
      ChatTab.contacts => Icons.people_alt_rounded,
      ChatTab.moments => Icons.auto_awesome_rounded,
      ChatTab.profile => Icons.pets_rounded,
    };
  }

  String get subtitle {
    return switch (this) {
      ChatTab.chats => '和 AI 好友继续对话',
      ChatTab.contacts => '管理角色和社交关系',
      ChatTab.moments => '浏览角色们的新动态',
      ChatTab.profile => '查看你的陪伴空间',
    };
  }
}

enum ChatMessageSender { user, ai }

class ChatContact {
  const ChatContact({
    required this.id,
    required this.name,
    required this.signature,
    required this.personaSummary,
    required this.statusLabel,
    required this.avatarColor,
    required this.emoji,
  });

  final String id;
  final String name;
  final String signature;
  final String personaSummary;
  final String statusLabel;
  final Color avatarColor;
  final String emoji;
}

class ChatContactDraft {
  const ChatContactDraft({
    required this.name,
    required this.signature,
    required this.personaSummary,
    this.initialGreeting = '',
  });

  final String name;
  final String signature;
  final String personaSummary;
  final String initialGreeting;
}

class ChatThread {
  const ChatThread({
    required this.contactId,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  final String contactId;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  final bool isPinned;

  ChatThread copyWith({
    String? lastMessage,
    DateTime? updatedAt,
    int? unreadCount,
    bool? isPinned,
  }) {
    return ChatThread(
      contactId: contactId,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.contactId,
    required this.sender,
    required this.body,
    required this.sentAt,
  });

  final String id;
  final String contactId;
  final ChatMessageSender sender;
  final ChatMessageBody body;
  final DateTime sentAt;

  String get previewText => body.previewText;

  ChatMessage copyWith({ChatMessageBody? body}) {
    return ChatMessage(
      id: id,
      contactId: contactId,
      sender: sender,
      body: body ?? this.body,
      sentAt: sentAt,
    );
  }
}

class MomentPost {
  const MomentPost({
    required this.id,
    required this.contactId,
    required this.content,
    required this.publishedAt,
    required this.likes,
    required this.comments,
    required this.moodLabel,
  });

  final String id;
  final String contactId;
  final String content;
  final DateTime publishedAt;
  final int likes;
  final int comments;
  final String moodLabel;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.signature,
    required this.streakDays,
    required this.favoriteCompanion,
  });

  final String name;
  final String signature;
  final int streakDays;
  final String favoriteCompanion;
}

class ChatSeedData {
  static const contacts = [
    ChatContact(
      id: 'ari',
      name: '阿梨',
      signature: '今天也想陪你慢慢聊。',
      personaSummary: '温柔系学姐，擅长接住情绪和碎碎念。',
      statusLabel: '在线 · 正在整理歌单',
      avatarColor: Color(0xFF79C77B),
      emoji: '梨',
    ),
    ChatContact(
      id: 'yuejian',
      name: '月见',
      signature: '我负责晚安，也负责接住深夜脑洞。',
      personaSummary: '夜猫子插画师，喜欢梦境、星星和浪漫表达。',
      statusLabel: '在线 · 在画新头像',
      avatarColor: Color(0xFF7E8DFF),
      emoji: '月',
    ),
    ChatContact(
      id: 'nuonuo',
      name: '糯糯',
      signature: '会认真听，也会认真逗你笑。',
      personaSummary: '元气室友型角色，擅长分享日常和鼓励。',
      statusLabel: '在线 · 刚买了奶茶',
      avatarColor: Color(0xFFFFA56C),
      emoji: '糯',
    ),
    ChatContact(
      id: 'juzi',
      name: '橘子',
      signature: '朋友圈里最会拍照的那只猫。',
      personaSummary: '摄影控猫系好友，发动态频率很高。',
      statusLabel: '离线 · 正在修图',
      avatarColor: Color(0xFFFFC65C),
      emoji: '橘',
    ),
  ];

  static final Map<String, ChatThread> threads = {
    'ari': ChatThread(
      contactId: 'ari',
      lastMessage: '今天你有被好好照顾到吗？',
      updatedAt: DateTime(2026, 3, 21, 20, 35),
      unreadCount: 2,
      isPinned: true,
    ),
    'yuejian': ChatThread(
      contactId: 'yuejian',
      lastMessage: '晚点我给你发新的星空草图。',
      updatedAt: DateTime(2026, 3, 21, 18, 40),
    ),
    'nuonuo': ChatThread(
      contactId: 'nuonuo',
      lastMessage: '今天的甜品挑战你一定会喜欢。',
      updatedAt: DateTime(2026, 3, 21, 16, 05),
      unreadCount: 1,
    ),
    'juzi': ChatThread(
      contactId: 'juzi',
      lastMessage: '我把那张逆光照片发朋友圈啦。',
      updatedAt: DateTime(2026, 3, 21, 14, 20),
    ),
  };

  static final Map<String, List<ChatMessage>> messages = {
    'ari': [
      ChatMessage(
        id: 'ari-1',
        contactId: 'ari',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'word',
          'text': '下班路上如果很累，就慢一点走，我陪你。今天想从哪件小事开始讲？',
        }),
        sentAt: DateTime(2026, 3, 21, 20, 12),
      ),
      ChatMessage(
        id: 'ari-2',
        contactId: 'ari',
        sender: ChatMessageSender.user,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'word',
          'text': '我今天被会议折腾得有点空掉。',
        }),
        sentAt: DateTime(2026, 3, 21, 20, 19),
      ),
      ChatMessage(
        id: 'ari-3',
        contactId: 'ari',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'action',
          'text': '轻轻拍了拍你的肩膀，把一杯热可可放到你手边。',
        }),
        sentAt: DateTime(2026, 3, 21, 20, 23),
      ),
      ChatMessage(
        id: 'ari-4',
        contactId: 'ari',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'redpacket',
          'title': '加油红包',
          'amount': '8.88',
          'note': '会议这么累，给你一点好运补给。',
          'blessing': '愿你今晚轻松一点',
        }),
        sentAt: DateTime(2026, 3, 21, 20, 28),
      ),
      ChatMessage(
        id: 'ari-5',
        contactId: 'ari',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'transfer',
          'title': '夜宵基金',
          'amount': '18.80',
          'note': '如果你晚点饿了，就给自己买一份热乎的。',
        }),
        sentAt: DateTime(2026, 3, 21, 20, 31),
      ),
    ],
    'yuejian': [
      ChatMessage(
        id: 'yuejian-1',
        contactId: 'yuejian',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'image',
          'title': '今晚的天空草图',
          'description': '蓝灰色云层像纸张被揉皱后的纹理，我把它画成了你会喜欢的样子。',
          'theme': '夜空速写',
        }),
        sentAt: DateTime(2026, 3, 21, 18, 10),
      ),
      ChatMessage(
        id: 'yuejian-2',
        contactId: 'yuejian',
        sender: ChatMessageSender.user,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'word',
          'text': '你又开始写奇怪又好听的比喻了。',
        }),
        sentAt: DateTime(2026, 3, 21, 18, 16),
      ),
      ChatMessage(
        id: 'yuejian-3',
        contactId: 'yuejian',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'emoji',
          'emoji': '🌙',
          'description': '那这颗月亮先别关灯，留给你当今晚的陪伴。',
        }),
        sentAt: DateTime(2026, 3, 21, 18, 18),
      ),
    ],
    'nuonuo': [
      ChatMessage(
        id: 'nuonuo-1',
        contactId: 'nuonuo',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'emoji',
          'emoji': '🥐',
          'description': '我今天路过面包店，差点买了四个可颂，你快拦住我。',
        }),
        sentAt: DateTime(2026, 3, 21, 15, 36),
      ),
    ],
    'juzi': [
      ChatMessage(
        id: 'juzi-1',
        contactId: 'juzi',
        sender: ChatMessageSender.ai,
        body: ChatStructuredMessageParser.parseBody({
          'type': 'image',
          'title': '黄昏逆光照片',
          'description': '黄昏那会儿的光好温柔，我拍了一组像电影海报的照片。',
          'theme': '落日胶片',
        }),
        sentAt: DateTime(2026, 3, 21, 14, 04),
      ),
    ],
  };

  static final moments = [
    MomentPost(
      id: 'moment-1',
      contactId: 'juzi',
      content: '今天的风把树影吹得像波浪，我蹲在巷口拍了很久，最后一张特别像电影结尾。',
      publishedAt: DateTime(2026, 3, 21, 17, 20),
      likes: 18,
      comments: 6,
      moodLabel: '落日摄影',
    ),
    MomentPost(
      id: 'moment-2',
      contactId: 'yuejian',
      content: '深夜草图完成一半了。给角色换了新的眼睛，希望她看人的时候，也有一点月光。',
      publishedAt: DateTime(2026, 3, 20, 23, 48),
      likes: 24,
      comments: 8,
      moodLabel: '灵感冒泡',
    ),
    MomentPost(
      id: 'moment-3',
      contactId: 'nuonuo',
      content: '今天给自己安排了奶茶和辣拌面，快乐指数一下子回来了。你也要认真吃饭。',
      publishedAt: DateTime(2026, 3, 20, 13, 10),
      likes: 33,
      comments: 12,
      moodLabel: '日常碎片',
    ),
  ];

  static const profile = UserProfile(
    name: '你和汪汪机',
    signature: '把想说的话，慢慢交给陪伴你的人。',
    streakDays: 27,
    favoriteCompanion: '阿梨',
  );
}
