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
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String signature;
  final String personaSummary;
  final String statusLabel;
  final Color avatarColor;
  final String emoji;
  final String? avatarUrl;
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
  static const contacts = <ChatContact>[];
  static final Map<String, ChatThread> threads = {};
  static final Map<String, List<ChatMessage>> messages = {};
  static final moments = <MomentPost>[];
  static const profile = UserProfile(
    name: '你和汪汪机',
    signature: '把想说的话，慢慢交给陪伴你的人。',
    streakDays: 0,
    favoriteCompanion: '',
  );
  static final summaries = <String, ChatSummaryEntry>{};
  static final memories = <ChatMemoryEntry>[];
  static final diaries = <ChatDiaryEntry>[];
  static final thoughts = <ChatThoughtEntry>[];
  static final systemEntries = <ChatSystemEntry>[];
}
