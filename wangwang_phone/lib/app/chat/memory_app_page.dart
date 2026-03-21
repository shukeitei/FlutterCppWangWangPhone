import 'package:flutter/material.dart';

import '../shared/ui.dart';
import 'chat_controller.dart';
import 'chat_models.dart';

class MemoryAppPage extends StatelessWidget {
  const MemoryAppPage({super.key, required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final summaries = controller.summaries;
        final memories = controller.memories;
        final thoughts = controller.thoughts;
        final systems = controller.systemEntries;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.backgroundGradient,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _RecordHeader(
                    title: '记忆',
                    subtitle: 'summary、memory、thought 和 system 记录',
                    onBack: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(height: 18),
                  _MetricOverview(
                    items: [
                      _MetricItem(label: '总结', value: '${summaries.length}'),
                      _MetricItem(label: '记忆', value: '${memories.length}'),
                      _MetricItem(label: '思考', value: '${thoughts.length}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(
                    title: '动态总结',
                    subtitle: '每位角色最近一条 summary',
                  ),
                  const SizedBox(height: 12),
                  ...summaries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SummaryCard(
                        contact: controller.contactById(entry.contactId),
                        entry: entry,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SectionTitle(
                    title: '长期记忆',
                    subtitle: 'memory 会保存在这里，供后续上下文注入',
                  ),
                  const SizedBox(height: 12),
                  ...memories.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MemoryCard(
                        contact: controller.contactById(entry.contactId),
                        title: entry.title,
                        content: entry.content,
                        timestamp: entry.createdAt,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SectionTitle(
                    title: '思考与系统',
                    subtitle: 'thought 和 system 不直接进聊天气泡，但会保留调试痕迹',
                  ),
                  const SizedBox(height: 12),
                  ...thoughts.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordCard(
                        icon: Icons.psychology_alt_rounded,
                        accentColor: const Color(0xFF7D8BFF),
                        contact: controller.contactById(entry.contactId),
                        title: '思考记录',
                        content: entry.content,
                        footer: _formatRecordTime(entry.createdAt),
                      ),
                    ),
                  ),
                  ...systems.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordCard(
                        icon: Icons.settings_suggest_rounded,
                        accentColor: const Color(0xFFFFA25A),
                        contact: controller.contactById(entry.contactId),
                        title: '系统日志 · ${entry.level}',
                        content: entry.content,
                        footer: _formatRecordTime(entry.createdAt),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DiaryAppPage extends StatelessWidget {
  const DiaryAppPage({super.key, required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final diaries = controller.diaries;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.backgroundGradient,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _RecordHeader(
                    title: '日记',
                    subtitle: 'AI 角色写下的 diary 会沉淀在这里',
                    onBack: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(height: 18),
                  _MetricOverview(
                    items: [
                      _MetricItem(label: '日记数', value: '${diaries.length}'),
                      _MetricItem(
                        label: '最近角色',
                        value: diaries.isEmpty
                            ? '--'
                            : controller
                                  .contactById(diaries.first.contactId)
                                  .name,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...diaries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordCard(
                        icon: Icons.menu_book_rounded,
                        accentColor: const Color(0xFFEF7FB0),
                        contact: controller.contactById(entry.contactId),
                        title: '${entry.title} · ${entry.moodLabel}',
                        content: entry.content,
                        footer: _formatRecordTime(entry.createdAt),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Row(
      children: [
        RoundActionButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricOverview extends StatelessWidget {
  const _MetricOverview({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map(
              (item) => Container(
                width: 120,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.iconSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.contact, required this.entry});

  final ChatContact contact;
  final ChatSummaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return _RecordCard(
      icon: Icons.summarize_rounded,
      accentColor: const Color(0xFF56B26F),
      contact: contact,
      title: '对话摘要',
      content: entry.content,
      footer: '更新于 ${_formatRecordTime(entry.updatedAt)}',
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.contact,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  final ChatContact contact;
  final String title;
  final String content;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return _RecordCard(
      icon: Icons.favorite_rounded,
      accentColor: const Color(0xFFFF8B5C),
      contact: contact,
      title: title,
      content: content,
      footer: _formatRecordTime(timestamp),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.icon,
    required this.accentColor,
    required this.contact,
    required this.title,
    required this.content,
    required this.footer,
  });

  final IconData icon;
  final Color accentColor;
  final ChatContact contact;
  final String title;
  final String content;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.primaryText,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            footer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.secondaryText),
          ),
        ],
      ),
    );
  }
}

String _formatRecordTime(DateTime time) {
  return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
