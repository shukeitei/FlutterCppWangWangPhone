import 'package:flutter/material.dart';

import '../shared/ui.dart';
import 'chat_context.dart';

class ChatContextDebugPage extends StatelessWidget {
  const ChatContextDebugPage({super.key, required this.bundle});

  final ChatContextBundle bundle;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

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
              Row(
                children: [
                  RoundActionButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '上下文调试',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'System Prompt / User Prompt 拼装结果',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FrostPanel(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DebugMetric(
                      label: '选中消息',
                      value: '${bundle.selectedMessages.length}',
                    ),
                    _DebugMetric(
                      label: 'summary承接',
                      value: bundle.usedSummaryBridge ? '是' : '否',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(
                title: 'System Prompt',
                subtitle: '按固定顺序拼装的系统上下文',
              ),
              const SizedBox(height: 12),
              ...bundle.systemSections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DebugSectionCard(section: section),
                ),
              ),
              const SizedBox(height: 10),
              const SectionTitle(title: 'User Prompt', subtitle: '最近聊天记录和当前输入'),
              const SizedBox(height: 12),
              ...bundle.userSections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DebugSectionCard(section: section),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugMetric extends StatelessWidget {
  const _DebugMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Container(
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
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSectionCard extends StatelessWidget {
  const _DebugSectionCard({required this.section});

  final ChatContextSection section;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return FrostPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            section.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.primaryText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
