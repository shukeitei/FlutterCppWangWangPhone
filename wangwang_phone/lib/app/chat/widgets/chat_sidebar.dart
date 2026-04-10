import 'package:flutter/material.dart';

/// 聊天页右侧抽屉侧边栏，纯菜单列表，点击跳转到对应设置页
class ChatSidebar extends StatelessWidget {
  const ChatSidebar({
    super.key,
    required this.currentPersonaName,
    required this.currentPresetName,
    required this.currentWorldBookSubtitle,
    required this.onPersonaTap,
    required this.onPresetTap,
    required this.onWorldBookTap,
    // 未来扩展：onSummaryTap, onContextDebugTap
  });

  final String currentPersonaName;
  final String currentPresetName;
  final String currentWorldBookSubtitle;
  final VoidCallback onPersonaTap;
  final VoidCallback onPresetTap;
  final VoidCallback onWorldBookTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.67,
      child: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  '聊天设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),

              // 菜单列表
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _SidebarMenuItem(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF0A84FF),
                      title: '用户身份',
                      subtitle: currentPersonaName,
                      onTap: onPersonaTap,
                    ),
                    _SidebarMenuItem(
                      icon: Icons.layers_outlined,
                      iconColor: const Color(0xFFFF9500),
                      title: '对话预设',
                      subtitle: currentPresetName,
                      onTap: onPresetTap,
                    ),
                    _SidebarMenuItem(
                      icon: Icons.auto_stories_outlined,
                      iconColor: const Color(0xFF34C759),
                      title: '世界书',
                      subtitle: currentWorldBookSubtitle,
                      onTap: onWorldBookTap,
                    ),
                    // === 未来在这里追加新菜单项 ===
                    // _SidebarMenuItem(
                    //   icon: Icons.psychology_outlined,
                    //   iconColor: const Color(0xFFAF52DE),
                    //   title: '记忆摘要',
                    //   subtitle: '上次: 4月6日',
                    //   onTap: onSummaryTap,
                    // ),
                    // _SidebarMenuItem(
                    //   icon: Icons.bug_report_outlined,
                    //   iconColor: const Color(0xFFFF3B30),
                    //   title: '上下文日志',
                    //   subtitle: '1.2k tokens',
                    //   onTap: onContextDebugTap,
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 侧边栏单行菜单项
class _SidebarMenuItem extends StatelessWidget {
  const _SidebarMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
