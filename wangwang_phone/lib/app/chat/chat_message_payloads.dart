enum ChatMessageKind {
  word,
  action,
  emoji,
  image,
  redPacket,
  transfer,
  thought,
  summary,
  memory,
  diary,
  system,
  moment,
  momentComment,
  momentLike,
}

enum TransactionCardStatus { pending, accepted, rejected }

extension TransactionCardStatusPresentation on TransactionCardStatus {
  String get label {
    return switch (this) {
      TransactionCardStatus.pending => '待处理',
      TransactionCardStatus.accepted => '已收下',
      TransactionCardStatus.rejected => '已拒绝',
    };
  }
}

abstract class ChatMessageBody {
  const ChatMessageBody();

  ChatMessageKind get kind;

  String get previewText;
}

class WordMessageBody extends ChatMessageBody {
  const WordMessageBody(this.text);

  final String text;

  @override
  ChatMessageKind get kind => ChatMessageKind.word;

  @override
  String get previewText => text;
}

class ActionMessageBody extends ChatMessageBody {
  const ActionMessageBody(this.text);

  final String text;

  @override
  ChatMessageKind get kind => ChatMessageKind.action;

  @override
  String get previewText => '[动作] $text';
}

class EmojiMessageBody extends ChatMessageBody {
  const EmojiMessageBody({required this.emoji, required this.description});

  final String emoji;
  final String description;

  @override
  ChatMessageKind get kind => ChatMessageKind.emoji;

  @override
  String get previewText => '$emoji $description';
}

class ImageMessageBody extends ChatMessageBody {
  const ImageMessageBody({
    required this.title,
    required this.description,
    required this.themeLabel,
  });

  final String title;
  final String description;
  final String themeLabel;

  @override
  ChatMessageKind get kind => ChatMessageKind.image;

  @override
  String get previewText => '[图片] $title';
}

abstract class MoneyCardMessageBody extends ChatMessageBody {
  const MoneyCardMessageBody({
    required this.title,
    required this.note,
    required this.amountLabel,
    required this.status,
  });

  final String title;
  final String note;
  final String amountLabel;
  final TransactionCardStatus status;

  bool get isPending => status == TransactionCardStatus.pending;

  MoneyCardMessageBody copyWithStatus(TransactionCardStatus status);
}

class RedPacketMessageBody extends MoneyCardMessageBody {
  const RedPacketMessageBody({
    required super.title,
    required super.note,
    required super.amountLabel,
    this.blessing = '收下今天的好运',
    super.status = TransactionCardStatus.pending,
  });

  final String blessing;

  @override
  ChatMessageKind get kind => ChatMessageKind.redPacket;

  @override
  String get previewText => '[红包] $title';

  @override
  RedPacketMessageBody copyWithStatus(TransactionCardStatus status) {
    return RedPacketMessageBody(
      title: title,
      note: note,
      amountLabel: amountLabel,
      blessing: blessing,
      status: status,
    );
  }
}

class TransferMessageBody extends MoneyCardMessageBody {
  const TransferMessageBody({
    required super.title,
    required super.note,
    required super.amountLabel,
    super.status = TransactionCardStatus.pending,
  });

  @override
  ChatMessageKind get kind => ChatMessageKind.transfer;

  @override
  String get previewText => '[转账] $title';

  @override
  TransferMessageBody copyWithStatus(TransactionCardStatus status) {
    return TransferMessageBody(
      title: title,
      note: note,
      amountLabel: amountLabel,
      status: status,
    );
  }
}

class ThoughtMessageBody extends ChatMessageBody {
  const ThoughtMessageBody(this.content);

  final String content;

  @override
  ChatMessageKind get kind => ChatMessageKind.thought;

  @override
  String get previewText => '[想法] $content';
}

class SummaryMessageBody extends ChatMessageBody {
  const SummaryMessageBody(this.content);

  final String content;

  @override
  ChatMessageKind get kind => ChatMessageKind.summary;

  @override
  String get previewText => '[总结] $content';
}

class MemoryMessageBody extends ChatMessageBody {
  const MemoryMessageBody({required this.title, required this.content});

  final String title;
  final String content;

  @override
  ChatMessageKind get kind => ChatMessageKind.memory;

  @override
  String get previewText => '[记忆] $title';
}

class DiaryMessageBody extends ChatMessageBody {
  const DiaryMessageBody({
    required this.title,
    required this.content,
    required this.moodLabel,
  });

  final String title;
  final String content;
  final String moodLabel;

  @override
  ChatMessageKind get kind => ChatMessageKind.diary;

  @override
  String get previewText => '[日记] $title';
}

class SystemMessageBody extends ChatMessageBody {
  const SystemMessageBody({required this.content, this.level = 'info'});

  final String content;
  final String level;

  @override
  ChatMessageKind get kind => ChatMessageKind.system;

  @override
  String get previewText => '[系统] $content';
}

class MomentMessageBody extends ChatMessageBody {
  const MomentMessageBody({required this.content, required this.moodLabel});

  final String content;
  final String moodLabel;

  @override
  ChatMessageKind get kind => ChatMessageKind.moment;

  @override
  String get previewText => '[朋友圈] $content';
}

class MomentCommentMessageBody extends ChatMessageBody {
  const MomentCommentMessageBody({
    required this.targetMomentId,
    required this.content,
  });

  final String targetMomentId;
  final String content;

  @override
  ChatMessageKind get kind => ChatMessageKind.momentComment;

  @override
  String get previewText => '[评论朋友圈] $content';
}

class MomentLikeMessageBody extends ChatMessageBody {
  const MomentLikeMessageBody({required this.targetMomentId});

  final String targetMomentId;

  @override
  ChatMessageKind get kind => ChatMessageKind.momentLike;

  @override
  String get previewText => '[点赞朋友圈] $targetMomentId';
}

/// 统一按 `type` 字段分发消息内容，后续可直接承接 LLM/C++ 解码后的结构化结果。
class ChatStructuredMessageParser {
  const ChatStructuredMessageParser._();

  static ChatMessageBody parseBody(Map<String, dynamic> payload) {
    final type = payload['type']?.toString().trim().toLowerCase() ?? 'word';
    return switch (type) {
      'word' => WordMessageBody(
        _readText(payload, const ['text', 'content'], fallback: '...'),
      ),
      'action' => ActionMessageBody(
        _readText(payload, const ['text', 'content'], fallback: '发来一个动作提示'),
      ),
      'emoji' => EmojiMessageBody(
        emoji: _readText(payload, const ['emoji'], fallback: '🙂'),
        description: _readText(payload, const [
          'description',
          'text',
        ], fallback: '发来一个表情'),
      ),
      'image' => ImageMessageBody(
        title: _readText(payload, const ['title'], fallback: '分享了一张图片'),
        description: _readText(payload, const [
          'description',
          'text',
        ], fallback: '一张带着氛围感的图片'),
        themeLabel: _readText(payload, const [
          'theme',
          'themeLabel',
        ], fallback: '影像片段'),
      ),
      'redpacket' => RedPacketMessageBody(
        title: _readText(payload, const ['title'], fallback: '给你的小红包'),
        note: _readText(payload, const ['note', 'text'], fallback: '记得收下这份心意'),
        amountLabel: _readText(payload, const [
          'amount',
          'amountLabel',
        ], fallback: '5.20'),
        blessing: _readText(payload, const ['blessing'], fallback: '收下今天的好运'),
        status: _readStatus(payload['status']),
      ),
      'transfer' => TransferMessageBody(
        title: _readText(payload, const ['title'], fallback: '给你的转账'),
        note: _readText(payload, const [
          'note',
          'text',
        ], fallback: '记得买点自己喜欢的东西'),
        amountLabel: _readText(payload, const [
          'amount',
          'amountLabel',
        ], fallback: '18.80'),
        status: _readStatus(payload['status']),
      ),
      'thought' => ThoughtMessageBody(
        _readText(payload, const ['text', 'content'], fallback: '产生了一段新的思考'),
      ),
      'summary' => SummaryMessageBody(
        _readText(payload, const ['text', 'content'], fallback: '生成了一段新的总结'),
      ),
      'memory' => MemoryMessageBody(
        title: _readText(payload, const ['title'], fallback: '新的长期记忆'),
        content: _readText(payload, const [
          'content',
          'text',
        ], fallback: '记录了一条新的长期记忆'),
      ),
      'diary' => DiaryMessageBody(
        title: _readText(payload, const ['title'], fallback: '今日小记'),
        content: _readText(payload, const [
          'content',
          'text',
        ], fallback: '写下了一段今天的日记'),
        moodLabel: _readText(payload, const [
          'mood',
          'moodLabel',
        ], fallback: '心情记录'),
      ),
      'system' => SystemMessageBody(
        content: _readText(payload, const [
          'content',
          'text',
        ], fallback: '系统生成了一条记录'),
        level: _readText(payload, const ['level'], fallback: 'info'),
      ),
      'moment' => MomentMessageBody(
        content: _readText(payload, const [
          'content',
          'text',
        ], fallback: '发布了一条新的朋友圈'),
        moodLabel: _readText(payload, const [
          'mood',
          'moodLabel',
        ], fallback: '今日分享'),
      ),
      'moment_comment' => MomentCommentMessageBody(
        targetMomentId: _readText(payload, const [
          'momentId',
          'targetMomentId',
        ], fallback: ''),
        content: _readText(payload, const [
          'content',
          'text',
        ], fallback: '留下一条新的评论'),
      ),
      'moment_like' => MomentLikeMessageBody(
        targetMomentId: _readText(payload, const [
          'momentId',
          'targetMomentId',
        ], fallback: ''),
      ),
      _ => WordMessageBody(
        _readText(payload, const ['text', 'content'], fallback: '收到一条暂未识别的消息'),
      ),
    };
  }

  static String _readText(
    Map<String, dynamic> payload,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  static TransactionCardStatus _readStatus(Object? rawStatus) {
    final normalized = rawStatus?.toString().trim().toLowerCase();
    return switch (normalized) {
      'accepted' => TransactionCardStatus.accepted,
      'rejected' => TransactionCardStatus.rejected,
      _ => TransactionCardStatus.pending,
    };
  }
}
