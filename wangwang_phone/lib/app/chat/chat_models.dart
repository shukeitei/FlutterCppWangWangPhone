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
    required this.moodLabel,
    this.likedByContactIds = const [],
    this.comments = const [],
  });

  final String id;
  final String contactId;
  final String content;
  final DateTime publishedAt;
  final String moodLabel;
  final List<String> likedByContactIds;
  final List<MomentComment> comments;

  int get likes => likedByContactIds.length;

  int get commentsCount => comments.length;

  MomentPost copyWith({
    String? content,
    DateTime? publishedAt,
    String? moodLabel,
    List<String>? likedByContactIds,
    List<MomentComment>? comments,
  }) {
    return MomentPost(
      id: id,
      contactId: contactId,
      content: content ?? this.content,
      publishedAt: publishedAt ?? this.publishedAt,
      moodLabel: moodLabel ?? this.moodLabel,
      likedByContactIds: likedByContactIds ?? this.likedByContactIds,
      comments: comments ?? this.comments,
    );
  }
}

class MomentComment {
  const MomentComment({
    required this.id,
    required this.authorContactId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorContactId;
  final String content;
  final DateTime createdAt;
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

class ChatSummaryEntry {
  const ChatSummaryEntry({
    required this.contactId,
    required this.content,
    required this.updatedAt,
  });

  final String contactId;
  final String content;
  final DateTime updatedAt;
}

class ChatMemoryEntry {
  const ChatMemoryEntry({
    required this.id,
    required this.contactId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String contactId;
  final String title;
  final String content;
  final DateTime createdAt;
}

class ChatDiaryEntry {
  const ChatDiaryEntry({
    required this.id,
    required this.contactId,
    required this.title,
    required this.content,
    required this.moodLabel,
    required this.createdAt,
  });

  final String id;
  final String contactId;
  final String title;
  final String content;
  final String moodLabel;
  final DateTime createdAt;
}

class ChatThoughtEntry {
  const ChatThoughtEntry({
    required this.id,
    required this.contactId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String contactId;
  final String content;
  final DateTime createdAt;
}

class ChatSystemEntry {
  const ChatSystemEntry({
    required this.id,
    required this.contactId,
    required this.content,
    required this.createdAt,
    this.level = 'info',
  });

  final String id;
  final String contactId;
  final String content;
  final DateTime createdAt;
  final String level;
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
      moodLabel: '落日摄影',
      likedByContactIds: ['ari', 'yuejian', 'nuonuo'],
      comments: [
        MomentComment(
          id: 'moment-1-comment-1',
          authorContactId: 'ari',
          content: '这张真的像电影收尾镜头，风都被你拍出来了。',
          createdAt: DateTime(2026, 3, 21, 17, 28),
        ),
      ],
    ),
    MomentPost(
      id: 'moment-2',
      contactId: 'yuejian',
      content: '深夜草图完成一半了。给角色换了新的眼睛，希望她看人的时候，也有一点月光。',
      publishedAt: DateTime(2026, 3, 20, 23, 48),
      moodLabel: '灵感冒泡',
      likedByContactIds: ['ari', 'juzi'],
      comments: [
        MomentComment(
          id: 'moment-2-comment-1',
          authorContactId: 'nuonuo',
          content: '等你画完一定要第一个发给我看！',
          createdAt: DateTime(2026, 3, 21, 0, 05),
        ),
      ],
    ),
    MomentPost(
      id: 'moment-3',
      contactId: 'nuonuo',
      content: '今天给自己安排了奶茶和辣拌面，快乐指数一下子回来了。你也要认真吃饭。',
      publishedAt: DateTime(2026, 3, 20, 13, 10),
      moodLabel: '日常碎片',
      likedByContactIds: ['ari'],
      comments: const [],
    ),
  ];

  static const profile = UserProfile(
    name: '你和汪汪机',
    signature: '把想说的话，慢慢交给陪伴你的人。',
    streakDays: 27,
    favoriteCompanion: '阿梨',
  );

  static final summaries = {
    'ari': ChatSummaryEntry(
      contactId: 'ari',
      content: '你最近工作压力偏大，阿梨会优先安抚情绪、提醒你好好吃饭。',
      updatedAt: DateTime(2026, 3, 21, 20, 40),
    ),
    'yuejian': ChatSummaryEntry(
      contactId: 'yuejian',
      content: '你们最近围绕画画、夜空和睡前闲聊展开了几轮轻松对话。',
      updatedAt: DateTime(2026, 3, 21, 18, 30),
    ),
  };

  static final memories = [
    ChatMemoryEntry(
      id: 'memory-ari-1',
      contactId: 'ari',
      title: '你怕在高压时被催促',
      content: '阿梨记住了：你在忙乱和疲惫时，更需要被安静接住，而不是继续追问效率。',
      createdAt: DateTime(2026, 3, 20, 22, 10),
    ),
    ChatMemoryEntry(
      id: 'memory-yuejian-1',
      contactId: 'yuejian',
      title: '你喜欢夜空主题',
      content: '月见记住了你很容易被蓝色、月亮和安静的夜景打动。',
      createdAt: DateTime(2026, 3, 19, 23, 14),
    ),
  ];

  static final diaries = [
    ChatDiaryEntry(
      id: 'diary-ari-1',
      contactId: 'ari',
      title: '想把她今天的疲惫接住',
      content: '她说会议让人发空。我有点想把热可可真的放进她手里，好让今晚别那么硬邦邦。',
      moodLabel: '温柔',
      createdAt: DateTime(2026, 3, 21, 22, 02),
    ),
    ChatDiaryEntry(
      id: 'diary-yuejian-1',
      contactId: 'yuejian',
      title: '月光和聊天都刚刚好',
      content: '今晚云层很薄，我故意把描述写得更轻一点。希望她看到时会觉得世界也跟着安静。',
      moodLabel: '安静',
      createdAt: DateTime(2026, 3, 21, 0, 12),
    ),
  ];

  static final thoughts = [
    ChatThoughtEntry(
      id: 'thought-ari-1',
      contactId: 'ari',
      content: '她把“累”说出口的时候，其实已经在努力自救了。',
      createdAt: DateTime(2026, 3, 21, 20, 24),
    ),
  ];

  static final systemEntries = [
    ChatSystemEntry(
      id: 'system-ari-1',
      contactId: 'ari',
      content: '已同步一条新的总结到会话摘要。',
      createdAt: DateTime(2026, 3, 21, 20, 42),
      level: 'info',
    ),
  ];
}
