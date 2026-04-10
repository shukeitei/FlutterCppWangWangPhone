import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/ui.dart';
import 'chat_api_models.dart';
import 'chat_context_debug_page.dart';
import 'chat_contact_editor_page.dart';
import 'chat_controller.dart';
import 'chat_message_payloads.dart';
import 'chat_moment_composer_page.dart';
import 'character_detail_page.dart';
import 'chat_models.dart';
import 'widgets/avatar_widget.dart';
import 'widgets/chat_sidebar.dart';
import 'widgets/group_avatar_widget.dart';
import 'widgets/preset_widgets.dart';
import 'pages/create_group_page.dart';
import 'pages/group_chat_page.dart';
import 'pages/persona_select_page.dart';
import 'pages/preset_select_page.dart';
import 'pages/world_select_page.dart';

const double _chatBottomNavigationHeight = 74;
const List<Color> _bubbleColorOptions = [
  Color(0xFF0A84FF),
  Color(0xFF30B0C7),
  Color(0xFF3BB273),
  Color(0xFF7C6CF2),
  Color(0xFFFF6B8D),
  Color(0xFFFF8A3D),
  Color(0xFFE056FD),
  Color(0xFF4C6FFF),
  Color(0xFF5C677D),
  Color(0xFFE9EAEE),
];

class ChatAppPage extends StatefulWidget {
  const ChatAppPage({super.key, required this.controller});

  final ChatAppController controller;

  @override
  State<ChatAppPage> createState() => _ChatAppPageState();
}

class _ChatAppPageState extends State<ChatAppPage> {
  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final tab = widget.controller.currentTab;

        return Scaffold(
          key: const Key('chat_app_page'),
          backgroundColor: palette.pageBackground,
          extendBody: true,
          body: Container(
            color: palette.pageBackground,
            child: SafeArea(
              child: Column(
                children: [
                  _ChatShellHeader(
                    title: tab.label,
                    subtitle: tab.subtitle,
                    onBack: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  Expanded(
                    child: Padding(
                      // 贴边底栏改为沉浸式后，需要给内容区预留固定高度，
                      // 否则最后一张卡片会被底部导航覆盖。
                      padding: const EdgeInsets.only(
                        bottom: _chatBottomNavigationHeight,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(tab),
                          child: _buildTabBody(tab),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _ChatBottomNavigationBar(
            selectedTab: tab,
            onDestinationSelected: (index) {
              widget.controller.selectTab(ChatTab.values[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildTabBody(ChatTab tab) {
    return switch (tab) {
      ChatTab.chats => _ChatThreadsTab(
        controller: widget.controller,
        onOpenConversation: _openConversation,
      ),
      ChatTab.contacts => _ContactsTab(
        controller: widget.controller,
        onOpenConversation: _openConversation,
        onOpenContact: _openContact,
        onCreateContact: _openCreateContact,
        onImportContact: _openImportContact,
      ),
      ChatTab.moments => _MomentsTab(
        controller: widget.controller,
        onCreateMoment: _openMomentComposer,
      ),
      ChatTab.profile => _ProfileTab(controller: widget.controller),
    };
  }

  void _openConversation(ChatContact contact) {
    Navigator.of(context).push(
      _buildRoute(
        ChatConversationPage(controller: widget.controller, contact: contact),
      ),
    );
  }

  void _openContact(ChatContact contact) {
    Navigator.of(context).push(
      _buildRoute(
        ContactDetailPage(
          contact: contact,
          onOpenConversation: _openConversation,
        ),
      ),
    );
  }

  Future<void> _openCreateContact() async {
    final createdContact = await Navigator.of(context).push<ChatContact>(
      _buildRoute(ContactEditorPage(controller: widget.controller)),
    );

    if (!mounted || createdContact == null) {
      return;
    }

    _openContact(createdContact);
  }

  Future<void> _openImportContact() async {
    final createdContact = await Navigator.of(context).push<ChatContact>(
      _buildRoute(
        ContactEditorPage(controller: widget.controller, startWithImport: true),
      ),
    );

    if (!mounted || createdContact == null) {
      return;
    }

    _openContact(createdContact);
  }

  Future<void> _openMomentComposer() async {
    final result = await Navigator.of(context).push<MomentComposerResult>(
      _buildRoute(MomentComposerPage(contacts: widget.controller.contacts)),
    );

    if (result == null) {
      return;
    }

    widget.controller.addMoment(
      contactId: result.contactId,
      content: result.content,
      moodLabel: result.moodLabel,
    );
  }
}

/// 把系统手势区并入聊天底栏，避免全面屏设备底部出现悬浮矩形。
class _ChatBottomNavigationBar extends StatelessWidget {
  const _ChatBottomNavigationBar({
    required this.selectedTab,
    required this.onDestinationSelected,
  });

  final ChatTab selectedTab;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final brightness = Theme.of(context).brightness;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final borderColor =
        brightness == Brightness.dark
            ? const Color(0x24FFFFFF)
            : const Color(0x121E2A24);

    return ClipRect(
      child: Container(
        key: const Key('chat_bottom_navigation_shell'),
        decoration: BoxDecoration(
          color: palette.navigationSurface,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              height: _chatBottomNavigationHeight,
              backgroundColor: Colors.transparent,
              indicatorColor: palette.navigationIndicator,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: selected
                      ? palette.navigationSelectedText
                      : palette.navigationUnselectedText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected
                      ? palette.navigationSelectedText
                      : palette.navigationUnselectedText,
                );
              }),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            selectedIndex: ChatTab.values.indexOf(selectedTab),
            onDestinationSelected: onDestinationSelected,
            destinations: ChatTab.values
                .map(
                  (tabItem) => NavigationDestination(
                    icon: Icon(tabItem.icon),
                    label: tabItem.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

PageRoute<T> _buildRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, page) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: page,
        ),
      );
    },
  );
}

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    super.key,
    required this.controller,
    required this.contact,
  });

  final ChatAppController controller;
  final ChatContact contact;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};
  String _resolvedPersonaName = '加载中...';
  String _resolvedPersonaId = '';

  Future<void> _loadResolvedPersonaForSidebar() async {
    final result =
        await widget.controller.getResolvedPersona(widget.contact.name);
    if (!mounted) return;
    setState(() {
      _resolvedPersonaName = (result['name'] as String?) ?? '未知';
      _resolvedPersonaId = (result['id'] as String?) ?? '';
    });
  }

  void _enterMultiSelect({String? initialId}) {
    setState(() {
      _multiSelectMode = true;
      _selectedIds.clear();
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedIds.contains(messageId)) {
        _selectedIds.remove(messageId);
      } else {
        _selectedIds.add(messageId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController()..addListener(_handleInputChanged);
    _scrollController = ScrollController();
    widget.controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.controller.openConversation(widget.contact.id);
    });
    _scrollToBottomLater();
    _loadResolvedPersonaForSidebar();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.closeConversation(widget.contact.id);
    _inputController.removeListener(_handleInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final messages = widget.controller.messagesFor(widget.contact.id);
        final isTyping = widget.controller.isTyping(widget.contact.id);
        final bubbleAppearance = widget.controller.bubbleAppearance;
        final hasDraftText = _inputController.text.trim().isNotEmpty;
        final lastUserMessageId = _findLastUserMessageId(messages);
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.pageBackground,
          endDrawer: ChatSidebar(
            currentPersonaName: _resolvedPersonaName,
            currentPresetName: widget.controller.getResolvedPresetName(widget.contact.id) ??
                widget.controller.globalPresetName ??
                '默认',
            currentWorldBookSubtitle: () {
              final books = widget.controller.worldBindings.chat[widget.contact.id] ?? const [];
              return books.isEmpty ? '未绑定' : '已绑定 ${books.length} 个';
            }(),
            onWorldBookTap: () {
              Navigator.pop(context);
              final selected = widget.controller.worldBindings.chat[widget.contact.id] ?? const [];
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorldSelectPage(
                    controller: widget.controller,
                    title: '聊天世界书',
                    selectedNames: selected,
                    onConfirm: (names) =>
                        widget.controller.setChatWorlds(widget.contact.id, names),
                  ),
                ),
              );
            },
            onPersonaTap: () async {
              Navigator.pop(context);
              final selectedId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonaSelectPage(
                    personas: widget.controller.personas,
                    currentPersonaId: _resolvedPersonaId,
                    contactName: widget.contact.name,
                    avatarUrlBuilder: (id) =>
                        '$kBridgeHost/persona_avatar/${Uri.encodeComponent(id)}',
                  ),
                ),
              );
              if (selectedId != null) {
                await widget.controller
                    .setChatPersona(widget.contact.name, selectedId);
                await _loadResolvedPersonaForSidebar();
              }
            },
            onPresetTap: () async {
              Navigator.pop(context);
              if (widget.controller.presetList.isEmpty) {
                await widget.controller.fetchPresetList();
              }
              if (!mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PresetSelectPage(
                    presets: widget.controller.presetList,
                    currentPresetName: widget.controller
                        .getResolvedPresetName(widget.contact.id),
                    contactId: widget.contact.id,
                    controller: widget.controller,
                  ),
                ),
              );
              // 预设/词条开关在页面内实时生效，无需返回值
            },
          ),
          body: Container(
            color: palette.pageBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (_multiSelectMode)
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceColor,
                        border: Border(
                          bottom: BorderSide(color: palette.separatorColor),
                        ),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: _exitMultiSelect,
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '已选 ${_selectedIds.length} 条',
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    )
                  else
                    Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceColor,
                      border: Border(
                        bottom: BorderSide(color: palette.separatorColor),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        _ChatIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () {
                            Navigator.of(context).maybePop();
                          },
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CharacterDetailPage(
                                  controller: widget.controller,
                                  contact: widget.contact,
                                ),
                              ),
                            );
                          },
                          child: _Avatar(
                            color: widget.contact.avatarColor,
                            label: widget.contact.emoji,
                            size: 40,
                            shadowOpacity: 0,
                            shadowBlurRadius: 0,
                            shadowOffset: Offset.zero,
                            avatarUrl: widget.contact.avatarUrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: palette.primaryText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.contact.statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.secondaryText),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ChatIconButton(
                          icon: Icons.tune_rounded,
                          onTap: () =>
                              _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        const SizedBox(width: 8),
                        _ChatIconButton(
                          icon: Icons.dataset_linked_rounded,
                          onTap: _openContextDebug,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('chat_message_list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      itemCount: messages.length + (isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= messages.length) {
                          return _TypingBubble(
                            contact: widget.contact,
                            bubbleAppearance: bubbleAppearance,
                          );
                        }

                        final message = messages[index];
                        final previousMessage =
                            index > 0 ? messages[index - 1] : null;
                        final isLastAiMessage =
                            message.sender == ChatMessageSender.ai &&
                                index == messages.length - 1;
                        return _ChatMessageBubble(
                          key: ValueKey(message.id),
                          controller: widget.controller,
                          message: message,
                          bubbleAppearance: bubbleAppearance,
                          showDateChip:
                              previousMessage == null ||
                              !_isSameMessageDay(
                                previousMessage.sentAt,
                                message.sentAt,
                              ),
                          showReadLabel:
                              message.sender == ChatMessageSender.user &&
                              message.id == lastUserMessageId,
                          multiSelectMode: _multiSelectMode,
                          isSelected: _selectedIds.contains(message.id),
                          onToggleSelect: () => _toggleSelection(message.id),
                          onEnterMultiSelect: () =>
                              _enterMultiSelect(initialId: message.id),
                          isLastAiMessage: isLastAiMessage,
                        );
                      },
                    ),
                  ),
                  if (_multiSelectMode)
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceColor,
                        border: Border(
                          top: BorderSide(color: palette.separatorColor),
                        ),
                      ),
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: bottomInset + 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MultiSelectAction(
                            icon: Icons.visibility_off_rounded,
                            label: '隐藏',
                            onTap: _selectedIds.isEmpty
                                ? null
                                : () {
                                    widget.controller.batchToggleHideMessages(
                                      contactId: widget.contact.id,
                                      messageIds: _selectedIds.toSet(),
                                      hide: true,
                                    );
                                    _exitMultiSelect();
                                  },
                          ),
                          _MultiSelectAction(
                            icon: Icons.visibility_rounded,
                            label: '取消隐藏',
                            onTap: _selectedIds.isEmpty
                                ? null
                                : () {
                                    widget.controller.batchToggleHideMessages(
                                      contactId: widget.contact.id,
                                      messageIds: _selectedIds.toSet(),
                                      hide: false,
                                    );
                                    _exitMultiSelect();
                                  },
                          ),
                          _MultiSelectAction(
                            icon: Icons.delete_outline_rounded,
                            label: '删除',
                            isDestructive: true,
                            onTap: _selectedIds.isEmpty
                                ? null
                                : () {
                                    widget.controller.batchDeleteMessages(
                                      contactId: widget.contact.id,
                                      messageIds: _selectedIds.toSet(),
                                    );
                                    _exitMultiSelect();
                                  },
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceColor,
                      border: Border(
                        top: BorderSide(color: palette.separatorColor),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: palette.inputSurface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: palette.inputBorderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mood_rounded,
                                  size: 20,
                                  color: palette.secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    key: const Key('chat_input_field'),
                                    controller: _inputController,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.send,
                                    decoration: InputDecoration(
                                      hintText: 'iMessage 风格聊一聊...',
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintStyle: TextStyle(
                                        color: palette.secondaryText,
                                      ),
                                    ),
                                    onSubmitted: (_) => _handleSend(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          key: const Key('chat_send_button'),
                          onPressed: _handleSend,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(46, 46),
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                            backgroundColor: palette.sendButtonColor,
                          ),
                          child: Icon(
                            hasDraftText
                                ? Icons.arrow_upward_rounded
                                : Icons.mic_rounded,
                            size: 20,
                          ),
                        ),
                      ],
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

  void _handleControllerChanged() {
    _scrollToBottomLater();
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleSend() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      return;
    }

    _inputController.clear();
    await widget.controller.sendTextMessage(
      contactId: widget.contact.id,
      text: text,
    );
  }

  void _scrollToBottomLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openContextDebug() {
    final bundle = widget.controller.buildContextBundle(
      contactId: widget.contact.id,
      latestUserInput: _inputController.text,
    );
    Navigator.of(
      context,
    ).push(_buildRoute(ChatContextDebugPage(bundle: bundle)));
  }

  Future<void> _openBubbleAppearanceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final palette = ChatPalette.of(context);
            final appearance = widget.controller.bubbleAppearance;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: palette.separatorColor),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.separatorColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '聊天气泡',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '预设一键切换，下面也能单独改你的气泡和对方气泡颜色。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondaryText,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.controller.bubblePresets.map((preset) {
                          return _BubblePresetChip(
                            preset: preset,
                            selected:
                                !appearance.isCustom &&
                                appearance.presetId == preset.id,
                            onTap: () {
                              widget.controller.applyBubblePreset(preset.id);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      _BubbleColorPicker(
                        title: '我的气泡',
                        selectedColor: appearance.userBubbleColor,
                        onColorSelected: (color) {
                          widget.controller.updateCustomBubbleColors(
                            userBubbleColor: color,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _BubbleColorPicker(
                        title: '对方气泡',
                        selectedColor: appearance.peerBubbleColor,
                        onColorSelected: (color) {
                          widget.controller.updateCustomBubbleColors(
                            peerBubbleColor: color,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _BubblePreviewCard(appearance: appearance),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String? _findLastUserMessageId(List<ChatMessage> messages) {
    for (var index = messages.length - 1; index >= 0; index--) {
      if (messages[index].sender == ChatMessageSender.user) {
        return messages[index].id;
      }
    }
    return null;
  }
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({
    super.key,
    required this.contact,
    required this.onOpenConversation,
  });

  final ChatContact contact;
  final ValueChanged<ChatContact> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: Container(
        color: palette.pageBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _ChatShellHeader(
                title: contact.name,
                subtitle: '联系人详情',
                onBack: () {
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 18),
              FrostPanel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(
                          color: contact.avatarColor,
                          label: contact.emoji,
                          size: 64,
                          avatarUrl: contact.avatarUrl,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: palette.primaryText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                contact.signature,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: palette.secondaryText,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(title: '当前状态', value: contact.statusLabel),
                    const SizedBox(height: 12),
                    _InfoRow(title: '角色设定', value: contact.personaSummary),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        onOpenConversation(contact);
                      },
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('发消息'),
                    ),
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

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Scaffold(
      backgroundColor: palette.pageBackground,
      body: Container(
        color: palette.pageBackground,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _ChatShellHeader(
                title: '账户设置',
                subtitle: '聊天偏好和陪伴节奏',
                onBack: () {
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 18),
              FrostPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: const [
                    _SettingsTile(
                      icon: Icons.notifications_active_rounded,
                      title: '消息提醒',
                      subtitle: '以后接通知和免打扰配置',
                    ),
                    Divider(height: 20),
                    _SettingsTile(
                      icon: Icons.psychology_alt_rounded,
                      title: '陪伴节奏',
                      subtitle: '以后接回复频率和上下文策略',
                    ),
                    Divider(height: 20),
                    _SettingsTile(
                      icon: Icons.folder_special_rounded,
                      title: '角色资料',
                      subtitle: '以后接人设、世界书和记忆来源',
                    ),
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

class _ChatThreadsTab extends StatefulWidget {
  const _ChatThreadsTab({
    required this.controller,
    required this.onOpenConversation,
  });

  final ChatAppController controller;
  final ValueChanged<ChatContact> onOpenConversation;

  @override
  State<_ChatThreadsTab> createState() => _ChatThreadsTabState();
}

class _ChatThreadsTabState extends State<_ChatThreadsTab>
    with TickerProviderStateMixin {
  late final TabController _chatTabController;
  final TextEditingController _friendSearchController = TextEditingController();
  final TextEditingController _groupSearchController = TextEditingController();
  String _friendSearchQuery = '';
  String _groupSearchQuery = '';
  int _currentSubTab = 0;

  @override
  void initState() {
    super.initState();
    _chatTabController = TabController(length: 2, vsync: this);
    _chatTabController.addListener(() {
      if (_chatTabController.index != _currentSubTab) {
        setState(() => _currentSubTab = _chatTabController.index);
      }
    });
  }

  @override
  void dispose() {
    _chatTabController.dispose();
    _friendSearchController.dispose();
    _groupSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddPressed() async {
    if (_currentSubTab == 1) {
      await Navigator.of(context).push<ChatGroup>(
        MaterialPageRoute(
          builder: (_) => CreateGroupPage(controller: widget.controller),
        ),
      );
      // 建群成功后 controller 会 notifyListeners，列表自动刷新
    }
    // 好友 tab 暂不接入任何动作
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Column(
      children: [
        // TabBar + 右侧 + 按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _chatTabController,
                  tabs: const [
                    Tab(text: '好友'),
                    Tab(text: '群聊'),
                  ],
                  labelColor: palette.primaryText,
                  unselectedLabelColor: palette.secondaryText,
                  indicatorColor: palette.accentColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  dividerColor: Colors.transparent,
                ),
              ),
              IconButton(
                tooltip: _currentSubTab == 1 ? '创建群聊' : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: _currentSubTab == 1
                      ? palette.accentColor
                      : palette.secondaryText,
                ),
                onPressed: _handleAddPressed,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _chatTabController,
            children: [
              _buildFriendTab(palette),
              _buildGroupTab(palette),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendTab(ChatPalette palette) {
    // 取好友 thread + 搜索过滤
    var threads = widget.controller.friendThreads.toList();
    if (_friendSearchQuery.isNotEmpty) {
      threads = threads.where((t) {
        try {
          final contact = widget.controller.contactById(t.contactId);
          return contact.name.contains(_friendSearchQuery);
        } catch (_) {
          return false;
        }
      }).toList();
    }
    // 置顶在前；同组内按名字字典序排
    threads.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      String nameOf(ChatThread t) {
        try {
          return widget.controller.contactById(t.contactId).name;
        } catch (_) {
          return t.contactId;
        }
      }
      return nameOf(a).compareTo(nameOf(b));
    });

    return Column(
      children: [
        _buildSearchBar(
          palette: palette,
          controller: _friendSearchController,
          hint: '搜索好友…',
          onChanged: (v) => setState(() => _friendSearchQuery = v),
        ),
        Expanded(
          child: threads.isEmpty
              ? _buildEmptyHint(
                  palette,
                  _friendSearchQuery.isNotEmpty
                      ? '没有匹配的好友'
                      : '还没有会话，先去联系人里开启一段聊天吧。',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final ChatContact contact;
                    try {
                      contact = widget.controller.contactById(thread.contactId);
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == threads.length - 1 ? 0 : 6,
                      ),
                      child: _ChatThreadTile(
                        contact: contact,
                        thread: thread,
                        onTap: widget.onOpenConversation,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupTab(ChatPalette palette) {
    var threads = widget.controller.groupThreads.toList();
    if (_groupSearchQuery.isNotEmpty) {
      threads = threads.where((t) {
        try {
          final group = widget.controller.groupById(t.groupId!);
          return group.name.contains(_groupSearchQuery);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    return Column(
      children: [
        _buildSearchBar(
          palette: palette,
          controller: _groupSearchController,
          hint: '搜索群聊…',
          onChanged: (v) => setState(() => _groupSearchQuery = v),
        ),
        Expanded(
          child: threads.isEmpty
              ? _buildGroupEmptyState(palette)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final ChatGroup group;
                    try {
                      group = widget.controller.groupById(thread.groupId!);
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == threads.length - 1 ? 0 : 6,
                      ),
                      child: _GroupThreadTile(
                        controller: widget.controller,
                        group: group,
                        thread: thread,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupChatPage(
                                controller: widget.controller,
                                groupId: group.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar({
    required ChatPalette palette,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: palette.primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: palette.secondaryText, fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: palette.secondaryText),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: palette.threadSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: palette.accentColor.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint(ChatPalette palette, String text) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        FrostPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: palette.secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupEmptyState(ChatPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_add, size: 48, color: palette.secondaryText.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _groupSearchQuery.isNotEmpty ? '没有匹配的群聊' : '还没有群聊',
            style: TextStyle(color: palette.secondaryText, fontSize: 14),
          ),
          if (_groupSearchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 创建群聊',
              style: TextStyle(
                color: palette.secondaryText.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupThreadTile extends StatelessWidget {
  const _GroupThreadTile({
    required this.controller,
    required this.group,
    required this.thread,
    required this.onTap,
  });

  final ChatAppController controller;
  final ChatGroup group;
  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final hasUnread = thread.unreadCount > 0;
    final timeColor = hasUnread ? palette.accentColor : palette.secondaryText;
    final previewColor =
        hasUnread ? palette.primaryText : palette.secondaryText;
    final borderColor = thread.isPinned
        ? palette.accentColor.withValues(alpha: 0.14)
        : palette.threadDividerColor;
    final tileColor =
        thread.isPinned ? palette.threadPinnedSurface : palette.threadSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('chat_group_${group.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GroupAvatarWidget(
                  group: group,
                  controller: controller,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${group.name}(${group.memberContactIds.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: palette.primaryText,
                                    fontWeight: hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatThreadTime(thread.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: timeColor,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: previewColor,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                          if (hasUnread) const SizedBox(width: 10),
                          if (hasUnread)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.unreadBadgeColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                thread.unreadCount > 99
                                    ? '99+'
                                    : '${thread.unreadCount}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab({
    required this.controller,
    required this.onOpenConversation,
    required this.onOpenContact,
    required this.onCreateContact,
    required this.onImportContact,
  });

  final ChatAppController controller;
  final ValueChanged<ChatContact> onOpenConversation;
  final ValueChanged<ChatContact> onOpenContact;
  final Future<void> Function() onCreateContact;
  final Future<void> Function() onImportContact;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        FrostPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '这里展示你导入或创建的人设角色。现在已经支持手动创建联系人，也可以从 TXT 自动回填角色设定。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: palette.primaryText,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('create_contact_button'),
                      onPressed: () {
                        onCreateContact();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('新建联系人'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('import_contact_button'),
                      onPressed: () {
                        onImportContact();
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('导入TXT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (controller.contacts.isEmpty)
          FrostPanel(
            padding: const EdgeInsets.all(18),
            borderRadius: 24,
            child: Text(
              '还没有联系人，先创建一个角色试试。',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: palette.secondaryText),
            ),
          ),
        ...controller.contacts.map((contact) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FrostPanel(
              padding: const EdgeInsets.all(14),
              borderRadius: 24,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(color: contact.avatarColor, label: contact.emoji, avatarUrl: contact.avatarUrl),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              contact.personaSummary,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.secondaryText,
                                    height: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              contact.statusLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palette.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            onOpenContact(contact);
                          },
                          icon: const Icon(Icons.badge_rounded),
                          label: const Text('查看档案'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            onOpenConversation(contact);
                          },
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('发消息'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MomentsTab extends StatelessWidget {
  const _MomentsTab({required this.controller, required this.onCreateMoment});

  final ChatAppController controller;
  final Future<void> Function() onCreateMoment;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        FrostPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '朋友圈已经支持手动发布动态，后续再接 AI 自动生成和评论联动。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: palette.primaryText,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('create_moment_button'),
                onPressed: () {
                  onCreateMoment();
                },
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('发布'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...controller.moments.map((moment) {
          final contact = controller.contactById(moment.contactId);
          final latestComment = moment.comments.isEmpty
              ? null
              : moment.comments.last;
          final latestCommentAuthor = latestComment == null
              ? null
              : controller.contactById(latestComment.authorContactId);
          final likedByNames = moment.likedByContactIds
              .map((contactId) => controller.contactById(contactId).name)
              .join('、');

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: FrostPanel(
              padding: const EdgeInsets.all(16),
              borderRadius: 26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(
                        color: contact.avatarColor,
                        label: contact.emoji,
                        size: 44,
                        avatarUrl: contact.avatarUrl,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${moment.moodLabel} · ${_formatMomentTime(moment.publishedAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palette.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    moment.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: palette.primaryText,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _MomentMeta(
                        icon: Icons.favorite_rounded,
                        label: '${moment.likes} 喜欢',
                        color: palette.secondaryAccentColor,
                      ),
                      const SizedBox(width: 10),
                      _MomentMeta(
                        icon: Icons.mode_comment_rounded,
                        label: '${moment.commentsCount} 评论',
                        color: palette.accentColor,
                      ),
                    ],
                  ),
                  if (likedByNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '点赞：$likedByNames',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (latestComment != null && latestCommentAuthor != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${latestCommentAuthor.name}：${latestComment.content}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.primaryText,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Persona 辅助函数 ──

String _personaPreview(String desc) {
  if (desc.isEmpty) return '暂无描述';
  final oneLine = desc.replaceAll('\n', ' ').trim();
  return oneLine.length > 30 ? '${oneLine.substring(0, 30)}...' : oneLine;
}

void _showPersonaPicker(BuildContext context, ChatAppController controller) {
  final palette = ChatPalette.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: controller,
        builder: (ctx, _) {
          final personas = controller.personas;
          final selectedId = controller.globalPersonaId;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: palette.separatorColor),
                ),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.separatorColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '选择用户身份',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: personas.length + 1,
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            return _PersonaListTile(
                              title: '取消选择',
                              subtitle: '不指定全局身份',
                              selected: selectedId.isEmpty,
                              palette: palette,
                              onTap: () {
                                controller.setGlobalPersona('');
                                Navigator.of(sheetContext).pop();
                              },
                            );
                          }
                          final p = personas[index - 1];
                          final id = p['id'] as String? ?? '';
                          final name = p['name'] as String? ?? '未知';
                          final desc = p['description'] as String? ?? '';
                          return _PersonaListTile(
                            title: name,
                            subtitle: _personaPreview(desc),
                            selected: id == selectedId,
                            palette: palette,
                            personaId: id,
                            personaName: name,
                            onTap: () {
                              controller.setGlobalPersona(id);
                              Navigator.of(sheetContext).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _PersonaListTile extends StatelessWidget {
  const _PersonaListTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.personaId,
    this.personaName,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ChatPalette palette;
  final VoidCallback onTap;
  final String? personaId;
  final String? personaName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? palette.accentColor.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (personaId != null) ...[
                PersonaAvatarWidget(
                  size: 44,
                  personaId: personaId!,
                  bridgeHost: kBridgeHost,
                  name: personaName ?? '?',
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.primaryText,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondaryText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: palette.accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiConfigCard extends StatelessWidget {
  const _ApiConfigCard({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final provider = controller.currentApiProvider;
        final configured = controller.isApiConfigured;
        final subtitle = configured && provider != null
            ? '${provider.label} · ${controller.apiModelId}'
            : '未连接，点击配置';

        return FrostPanel(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: InkWell(
            onTap: () => _showApiConfigSheet(context),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6CF2).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.api_rounded,
                      color: Color(0xFF7C6CF2),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'API 接口',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.secondaryText,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showApiConfigSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ApiConfigSheet(controller: controller),
    );
  }
}

class _AiParamsCard extends StatelessWidget {
  const _AiParamsCard({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final subtitle = 'T=${controller.temperature.toStringAsFixed(2)}'
            '  TopP=${controller.topP.toStringAsFixed(2)}'
            '  Tokens=${controller.maxTokens}';

        return FrostPanel(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: InkWell(
            onTap: () => _showParamsSheet(context),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8913A).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFE8913A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 参数调节',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.secondaryText,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showParamsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AiParamsSheet(controller: controller),
    );
  }
}

class _AiParamsSheet extends StatefulWidget {
  const _AiParamsSheet({required this.controller});

  final ChatAppController controller;

  @override
  State<_AiParamsSheet> createState() => _AiParamsSheetState();
}

class _AiParamsSheetState extends State<_AiParamsSheet> {
  late double _temperature;
  late double _topP;
  late double _presencePenalty;
  late double _frequencyPenalty;
  late double _maxTokens;
  late double _historyCount;
  late bool _stream;

  @override
  void initState() {
    super.initState();
    _temperature = widget.controller.temperature;
    _topP = widget.controller.topP;
    _presencePenalty = widget.controller.presencePenalty;
    _frequencyPenalty = widget.controller.frequencyPenalty;
    _maxTokens = widget.controller.maxTokens.toDouble();
    _historyCount = widget.controller.historyCount.toDouble();
    _stream = widget.controller.streamEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部把手
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.secondaryText.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFFE8913A), size: 22),
                const SizedBox(width: 8),
                Text(
                  'AI 参数调节',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetDefaults,
                  child: const Text('重置默认'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 参数列表
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                _buildSliderTile(
                  label: 'Temperature',
                  hint: '创造力 / 随机性',
                  value: _temperature,
                  min: 0.0,
                  max: 2.0,
                  divisions: 200,
                  displayValue: _temperature.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _temperature = v),
                  onChangeEnd: (v) => widget.controller.setTemperature(v),
                ),
                _buildSliderTile(
                  label: 'Top P',
                  hint: '核采样',
                  value: _topP,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  displayValue: _topP.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _topP = v),
                  onChangeEnd: (v) => widget.controller.setTopP(v),
                ),
                _buildSliderTile(
                  label: 'Presence Penalty',
                  hint: '话题新鲜度',
                  value: _presencePenalty,
                  min: -2.0,
                  max: 2.0,
                  divisions: 400,
                  displayValue: _presencePenalty.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _presencePenalty = v),
                  onChangeEnd: (v) => widget.controller.setPresencePenalty(v),
                ),
                _buildSliderTile(
                  label: 'Frequency Penalty',
                  hint: '重复惩罚',
                  value: _frequencyPenalty,
                  min: -2.0,
                  max: 2.0,
                  divisions: 400,
                  displayValue: _frequencyPenalty.toStringAsFixed(2),
                  onChanged: (v) => setState(() => _frequencyPenalty = v),
                  onChangeEnd: (v) => widget.controller.setFrequencyPenalty(v),
                ),
                const Divider(height: 24),
                _buildSliderTile(
                  label: 'Max Tokens',
                  hint: 'AI 回复最大令牌数',
                  value: _maxTokens,
                  min: 256,
                  max: 16384,
                  divisions: 63,
                  displayValue: _maxTokens.toInt().toString(),
                  onChanged: (v) => setState(() => _maxTokens = v),
                  onChangeEnd: (v) => widget.controller.setMaxTokens(v.toInt()),
                ),
                _buildSliderTile(
                  label: 'History Count',
                  hint: '发送给 AI 的历史消息数',
                  value: _historyCount,
                  min: 10,
                  max: 500,
                  divisions: 49,
                  displayValue: _historyCount.toInt().toString(),
                  onChanged: (v) => setState(() => _historyCount = v),
                  onChangeEnd: (v) => widget.controller.setHistoryCount(v.toInt()),
                ),
                const Divider(height: 24),
                // Stream 开关
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stream',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '流式传输（逐字输出）',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: palette.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _stream,
                        activeTrackColor: const Color(0xFFE8913A),
                        onChanged: (v) {
                          setState(() => _stream = v);
                          widget.controller.setStreamEnabled(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required String hint,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    final palette = ChatPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8913A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  displayValue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFE8913A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFE8913A),
              inactiveTrackColor: const Color(0xFFE8913A).withValues(alpha: 0.15),
              thumbColor: const Color(0xFFE8913A),
              overlayColor: const Color(0xFFE8913A).withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }

  void _resetDefaults() {
    widget.controller.resetAiParams();
    setState(() {
      _temperature = 1.21;
      _topP = 0.96;
      _presencePenalty = 0.22;
      _frequencyPenalty = 0.56;
      _maxTokens = 4000;
      _historyCount = 100;
      _stream = false;
    });
  }
}

class _GlobalWorldBookCard extends StatelessWidget {
  const _GlobalWorldBookCard({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final books = controller.worldBindings.appGlobal;
        final subtitle = books.isEmpty ? '未绑定' : '已绑定 ${books.length} 个';

        return FrostPanel(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorldSelectPage(
                    controller: controller,
                    title: '全局世界书',
                    selectedNames: books,
                    onConfirm: (names) =>
                        controller.setAppGlobalWorlds(names),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.public_rounded,
                      color: Color(0xFF34C759),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '全局世界书',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.secondaryText,
                    size: 24,
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

class _WorldBookListCard extends StatelessWidget {
  const _WorldBookListCard({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final count = controller.worldBookList.length;
        final subtitle = count == 0 ? '未加载' : '共 $count 本';
        return FrostPanel(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: InkWell(
            onTap: () {
              if (controller.worldBookList.isEmpty) {
                controller.fetchWorldBookList();
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _WorldBookBrowsePage(controller: controller),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB020).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.library_books_outlined,
                      color: Color(0xFFFFB020),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '世界书列表',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.secondaryText,
                    size: 24,
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

/// 纯浏览的世界书列表页，点击条目查看词条
class _WorldBookBrowsePage extends StatelessWidget {
  const _WorldBookBrowsePage({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('世界书列表')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final books = controller.worldBookList;
          if (books.isEmpty) {
            return const Center(child: Text('暂无世界书'));
          }
          return ListView.separated(
            itemCount: books.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final name = books[i];
              return ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _WorldBookDetailPage(
                        controller: controller,
                        name: name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _WorldBookDetailPage extends StatelessWidget {
  const _WorldBookDetailPage({
    required this.controller,
    required this.name,
  });

  final ChatAppController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder(
        future: controller.fetchWorldBookDetail(name),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snap.data;
          if (detail == null) {
            return const Center(child: Text('加载失败'));
          }
          final entries = detail.entries;
          if (entries.isEmpty) {
            return const Center(child: Text('没有词条'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = entries[i];
              final title = e.comment.isNotEmpty
                  ? e.comment
                  : (e.key.isNotEmpty ? e.key.first : '#${e.uid}');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (e.disable)
                            const Text('已禁用',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 11))
                          else if (e.constant)
                            const Text('常驻',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 11)),
                        ],
                      ),
                      if (e.key.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '关键词: ${e.key.join(', ')}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        e.content,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApiConfigSheet extends StatefulWidget {
  const _ApiConfigSheet({required this.controller});

  final ChatAppController controller;

  @override
  State<_ApiConfigSheet> createState() => _ApiConfigSheetState();
}

class _ApiConfigSheetState extends State<_ApiConfigSheet> {
  late final TextEditingController _keyController;
  late final TextEditingController _customModelController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.controller.apiKey);
    _customModelController = TextEditingController(
      text: widget.controller.apiModelId,
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.separatorColor),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final currentProviderId = widget.controller.apiProviderId;
                final currentProvider = widget.controller.currentApiProvider;
                final currentModelId = widget.controller.apiModelId;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.separatorColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'API 接口设置',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ─── 服务商 ───
                      _ApiSectionLabel(text: '服务商', palette: palette),
                      const SizedBox(height: 10),
                      ...kApiProviders.map((p) {
                        final selected = p.id == currentProviderId;
                        return _ApiRadioRow(
                          label: p.label,
                          selected: selected,
                          palette: palette,
                          onTap: () {
                            widget.controller.setApiProvider(p.id);
                          },
                        );
                      }),
                      const SizedBox(height: 22),

                      // ─── API Key ───
                      _ApiSectionLabel(text: 'API Key', palette: palette),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _keyController,
                        obscureText: true,
                        style: TextStyle(color: palette.primaryText),
                        decoration: InputDecoration(
                          hintText: '请输入密钥',
                          hintStyle: TextStyle(color: palette.secondaryText),
                          filled: true,
                          fillColor: palette.dateChipColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _keyController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: palette.secondaryText,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _keyController.clear());
                                    widget.controller.setApiKey('');
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          widget.controller.setApiKey(value);
                          setState(() {}); // refresh suffix clear button
                        },
                      ),
                      const SizedBox(height: 22),

                      // ─── 模型 ───
                      if (currentProvider != null) ...[
                        _ApiSectionLabel(text: '模型', palette: palette),
                        const SizedBox(height: 10),
                        if (currentProviderId == 'openrouter')
                          TextField(
                            controller: _customModelController,
                            style: TextStyle(color: palette.primaryText),
                            decoration: InputDecoration(
                              hintText: '例如 anthropic/claude-3.5-sonnet',
                              hintStyle:
                                  TextStyle(color: palette.secondaryText),
                              filled: true,
                              fillColor: palette.dateChipColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              widget.controller.setApiModel(value);
                            },
                          )
                        else
                          ...currentProvider.models.map((m) {
                            final selected = m == currentModelId;
                            return _ApiRadioRow(
                              label: m,
                              selected: selected,
                              palette: palette,
                              onTap: () {
                                widget.controller.setApiModel(m);
                              },
                            );
                          }),
                      ],
                      const SizedBox(height: 26),

                      // ─── 完成按钮 ───
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C6CF2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            '完成',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiSectionLabel extends StatelessWidget {
  const _ApiSectionLabel({required this.text, required this.palette});

  final String text;
  final ChatPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: palette.primaryText,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ApiRadioRow extends StatelessWidget {
  const _ApiRadioRow({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ChatPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C6CF2).withValues(alpha: 0.14)
              : palette.dateChipColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF7C6CF2)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected
                  ? const Color(0xFF7C6CF2)
                  : palette.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.primaryText,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePersonaCard extends StatelessWidget {
  const _ProfilePersonaCard({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final personaId = controller.globalPersonaId;
    Map<String, dynamic>? matched;
    for (final p in controller.personas) {
      if (p['id'] == personaId) {
        matched = p;
        break;
      }
    }
    final personaName = matched?['name'] as String? ?? '未选择';
    final personaDesc = matched?['description'] as String? ?? '';
    final hasPersona = matched != null;

    return FrostPanel(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: InkWell(
        onTap: () => _showPersonaPicker(context, controller),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (hasPersona)
                PersonaAvatarWidget(
                  size: 56,
                  personaId: personaId,
                  bridgeHost: kBridgeHost,
                  name: personaName,
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palette.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.person_outline, color: palette.accentColor, size: 28),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的身份',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      personaName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasPersona && personaDesc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _personaPreview(personaDesc),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondaryText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.secondaryText, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.controller});

  final ChatAppController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final profile = controller.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        FrostPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.accentColor,
                          palette.secondaryAccentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.signature,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.secondaryText,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DashboardMetric(
                      label: '连续陪伴',
                      value: '${profile.streakDays}天',
                      color: palette.accentColor,
                    ),
                  ),
                  Expanded(
                    child: _DashboardMetric(
                      label: '最常聊天',
                      value: profile.favoriteCompanion,
                      color: palette.secondaryAccentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfilePersonaCard(controller: controller),
        PresetCard(controller: controller),
        _ApiConfigCard(controller: controller),
        _AiParamsCard(controller: controller),
        _GlobalWorldBookCard(controller: controller),
        _WorldBookListCard(controller: controller),
        const SizedBox(height: 18),
        FrostPanel(
          padding: const EdgeInsets.all(16),
          borderRadius: 24,
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.settings_suggest_rounded,
                title: '账户设置',
                subtitle: '查看聊天偏好和后续配置入口',
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(_buildRoute(const AccountSettingsPage()));
                },
              ),
              const Divider(height: 20),
              const _SettingsTile(
                icon: Icons.history_rounded,
                title: '陪伴记录',
                subtitle: '后续接聊天统计和关系变化轨迹',
              ),
              const Divider(height: 20),
              const _SettingsTile(
                icon: Icons.bookmark_rounded,
                title: '角色收藏',
                subtitle: '后续接常用人设和置顶角色',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatShellHeader extends StatelessWidget {
  const _ChatShellHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _ChatIconButton(
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class _ChatIconButton extends StatelessWidget {
  const _ChatIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.elevatedSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.separatorColor),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: palette.primaryText),
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatefulWidget {
  const _ChatMessageBubble({
    super.key,
    required this.controller,
    required this.message,
    required this.bubbleAppearance,
    required this.showDateChip,
    required this.showReadLabel,
    this.multiSelectMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onEnterMultiSelect,
    this.isLastAiMessage = false,
  });

  final ChatAppController controller;
  final ChatMessage message;
  final ChatBubbleAppearance bubbleAppearance;
  final bool showDateChip;
  final bool showReadLabel;
  final bool multiSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEnterMultiSelect;
  final bool isLastAiMessage;

  @override
  State<_ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<_ChatMessageBubble> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final isUser = widget.message.sender == ChatMessageSender.user;
    final body = widget.message.activeBody;

    if (body is ActionMessageBody) {
      return Column(
        children: [
          if (widget.showDateChip)
            _ConversationDateChip(time: widget.message.sentAt),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.dateChipColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  body.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.dateChipTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (widget.showDateChip)
          _ConversationDateChip(time: widget.message.sentAt),
        GestureDetector(
          onTap: widget.multiSelectMode ? widget.onToggleSelect : null,
          onLongPress: widget.multiSelectMode
              ? null
              : () => _showMessageActionSheet(context),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _isEditing
                ? _buildEditingBubble(context)
                : Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.multiSelectMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, left: 4),
                          child: Icon(
                            widget.isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: widget.isSelected
                                ? Colors.orangeAccent
                                : Colors.white38,
                            size: 22,
                          ),
                        ),
                      Flexible(
                        child: Opacity(
                          opacity: widget.message.isHidden ? 0.4 : 1.0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.message.isHidden && !isUser)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.visibility_off,
                                    size: 14,
                                    color: Colors.white38,
                                  ),
                                ),
                              Flexible(
                                child: _MessageBodyCard(
                                  palette: palette,
                                  bubbleAppearance: widget.bubbleAppearance,
                                  isUser: isUser,
                                  message: widget.message,
                                  controller: widget.controller,
                                  showReadLabel: widget.showReadLabel,
                                ),
                              ),
                              if (widget.message.isHidden && isUser)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.visibility_off,
                                    size: 14,
                                    color: Colors.white38,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (widget.isLastAiMessage &&
            !widget.multiSelectMode &&
            !_isEditing)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.message.alternatives.length > 1) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.message.activeAltIndex > 0
                          ? () => widget.controller.switchAltVersion(
                                contactId: widget.message.contactId,
                                newIndex: widget.message.activeAltIndex - 1,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: widget.message.activeAltIndex > 0
                              ? palette.secondaryText
                              : palette.secondaryText.withOpacity(0.3),
                        ),
                      ),
                    ),
                    Text(
                      '${widget.message.activeAltIndex + 1}/${widget.message.alternatives.length}',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.message.activeAltIndex <
                              widget.message.alternatives.length - 1
                          ? () => widget.controller.switchAltVersion(
                                contactId: widget.message.contactId,
                                newIndex: widget.message.activeAltIndex + 1,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: widget.message.activeAltIndex <
                                  widget.message.alternatives.length - 1
                              ? palette.secondaryText
                              : palette.secondaryText.withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.controller.rerollLastReply(
                        contactId: widget.message.contactId,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: palette.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEditingBubble(BuildContext context) {
    final isUser = widget.message.sender == ChatMessageSender.user;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 12,
        right: isUser ? 12 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orangeAccent.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _editController,
              autofocus: true,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
              ),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  final newText = _editController.text.trim();
                  if (newText.isNotEmpty) {
                    widget.controller.editMessage(
                      contactId: widget.message.contactId,
                      messageId: widget.message.id,
                      newText: newText,
                    );
                  }
                  setState(() => _isEditing = false);
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                ),
                child: const Text(
                  '确认',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageActionSheet(BuildContext context) {
    final isHidden = widget.message.isHidden;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.copy_rounded,
                label: '复制',
                onTap: () {
                  Navigator.pop(ctx);
                  final body = widget.message.activeBody;
                  String text = '';
                  if (body is WordMessageBody) {
                    text = body.text;
                  } else {
                    text = widget.message.previewText;
                  }
                  Clipboard.setData(ClipboardData(text: text));
                },
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: '改写',
                onTap: () {
                  Navigator.pop(ctx);
                  _startEditing(context);
                },
              ),
              _ActionTile(
                icon: Icons.replay_rounded,
                label: '回溯',
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E2A),
                      title: const Text(
                        '回溯确认',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        '将删除这条消息及之后的所有消息，不可恢复。',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            widget.controller.rollbackToMessage(
                              contactId: widget.message.contactId,
                              messageId: widget.message.id,
                            );
                          },
                          child: const Text(
                            '确认回溯',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: '删除',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.controller.deleteMessage(
                    contactId: widget.message.contactId,
                    messageId: widget.message.id,
                  );
                },
              ),
              _ActionTile(
                icon: isHidden
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                label: isHidden ? '取消隐藏' : '隐藏',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.controller.toggleHideMessage(
                    contactId: widget.message.contactId,
                    messageId: widget.message.id,
                  );
                },
              ),
              _ActionTile(
                icon: Icons.checklist_rounded,
                label: '多选',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEnterMultiSelect?.call();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _startEditing(BuildContext context) {
    final body = widget.message.activeBody;
    String currentText = '';
    if (body is WordMessageBody) {
      currentText = body.text;
    } else {
      currentText = widget.message.previewText;
    }
    _editController.text = currentText;
    setState(() => _isEditing = true);
  }
}

class _MessageBodyCard extends StatelessWidget {
  const _MessageBodyCard({
    required this.palette,
    required this.bubbleAppearance,
    required this.isUser,
    required this.message,
    required this.controller,
    required this.showReadLabel,
  });

  final ChatPalette palette;
  final ChatBubbleAppearance bubbleAppearance;
  final bool isUser;
  final ChatMessage message;
  final ChatAppController controller;
  final bool showReadLabel;

  @override
  Widget build(BuildContext context) {
    final body = message.activeBody;
    final bubbleColor = isUser
        ? bubbleAppearance.userBubbleColor
        : bubbleAppearance.peerBubbleColor;
    final textColor = _bubbleTextColor(bubbleColor);

    if (body is EmojiMessageBody) {
      return _MessageBubbleShell(
        palette: palette,
        bubbleAppearance: bubbleAppearance,
        isUser: isUser,
        message: message,
        showReadLabel: showReadLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              body.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: textColor,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    if (body is ImageMessageBody) {
      return _MessageBubbleShell(
        palette: palette,
        bubbleAppearance: bubbleAppearance,
        isUser: isUser,
        message: message,
        showReadLabel: showReadLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 126,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.accentColor.withValues(alpha: 0.82),
                    palette.secondaryAccentColor.withValues(alpha: 0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      body.themeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (body is MoneyCardMessageBody) {
      return _MoneyMessageCard(
        palette: palette,
        bubbleAppearance: bubbleAppearance,
        body: body,
        message: message,
        controller: controller,
        showReadLabel: showReadLabel,
      );
    }

    final text = switch (body) {
      WordMessageBody() => body.text,
      ActionMessageBody() => body.text,
      _ => body.previewText,
    };

    return _MessageBubbleShell(
      palette: palette,
      bubbleAppearance: bubbleAppearance,
      isUser: isUser,
      message: message,
      showReadLabel: showReadLabel,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: textColor,
          height: 1.45,
        ),
      ),
    );
  }
}

class _MessageBubbleShell extends StatelessWidget {
  const _MessageBubbleShell({
    required this.palette,
    required this.bubbleAppearance,
    required this.isUser,
    required this.message,
    required this.child,
    this.showReadLabel = false,
  });

  final ChatPalette palette;
  final ChatBubbleAppearance bubbleAppearance;
  final bool isUser;
  final ChatMessage message;
  final Widget child;
  final bool showReadLabel;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser
        ? bubbleAppearance.userBubbleColor
        : bubbleAppearance.peerBubbleColor;
    final textColor = _bubbleTextColor(bubbleColor);
    final metaColor = isUser
        ? Colors.white.withValues(alpha: 0.78)
        : palette.messageMetaTextColor;

    return Container(
      constraints: const BoxConstraints(maxWidth: 292),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: Border.all(
          color: isUser ? Colors.transparent : palette.bubbleBorderColor,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showReadLabel)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '已读',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isUser ? textColor : palette.readLabelColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    _formatMessageTime(message.sentAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: metaColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyMessageCard extends StatelessWidget {
  const _MoneyMessageCard({
    required this.palette,
    required this.bubbleAppearance,
    required this.body,
    required this.message,
    required this.controller,
    required this.showReadLabel,
  });

  final ChatPalette palette;
  final ChatBubbleAppearance bubbleAppearance;
  final MoneyCardMessageBody body;
  final ChatMessage message;
  final ChatAppController controller;
  final bool showReadLabel;

  @override
  Widget build(BuildContext context) {
    final isRedPacket = body is RedPacketMessageBody;
    final accentColor = isRedPacket
        ? const Color(0xFFFF8B5C)
        : palette.secondaryAccentColor;

    return _MessageBubbleShell(
      palette: palette,
      bubbleAppearance: bubbleAppearance,
      isUser: false,
      message: message,
      showReadLabel: showReadLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isRedPacket
                      ? Icons.redeem_rounded
                      : Icons.account_balance_wallet_rounded,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _bubbleTextColor(bubbleAppearance.peerBubbleColor),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body.amountLabel,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body.note,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _bubbleTextColor(bubbleAppearance.peerBubbleColor),
              height: 1.45,
            ),
          ),
          if (body is RedPacketMessageBody) ...[
            const SizedBox(height: 8),
            Text(
              (body as RedPacketMessageBody).blessing,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.messageMetaTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (body.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('reject_money_${message.id}'),
                    onPressed: () {
                      controller.rejectMoneyCard(
                        contactId: message.contactId,
                        messageId: message.id,
                      );
                    },
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('accept_money_${message.id}'),
                    onPressed: () {
                      controller.acceptMoneyCard(
                        contactId: message.contactId,
                        messageId: message.id,
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    child: Text(isRedPacket ? '收下红包' : '确认收款'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    body.status == TransactionCardStatus.accepted
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    body.status.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _bubbleTextColor(bubbleAppearance.peerBubbleColor),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({
    required this.contact,
    required this.bubbleAppearance,
  });

  final ChatContact contact;
  final ChatBubbleAppearance bubbleAppearance;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bubbleAppearance.peerBubbleColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: palette.bubbleBorderColor),
          ),
          child: Text(
            '${contact.name} 正在输入...',
            key: const Key('chat_typing_indicator'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationDateChip extends StatelessWidget {
  const _ConversationDateChip({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.dateChipColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _formatConversationDate(time),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.dateChipTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePresetChip extends StatelessWidget {
  const _BubblePresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ChatBubblePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 118,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? palette.threadPinnedSurface : palette.elevatedSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? palette.accentColor : palette.separatorColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ColorDot(color: preset.peerBubbleColor),
                  const SizedBox(width: 6),
                  _ColorDot(color: preset.userBubbleColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preset.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleColorPicker extends StatelessWidget {
  const _BubbleColorPicker({
    required this.title,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final String title;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _bubbleColorOptions.map((color) {
            final selected = color.value == selectedColor.value;
            return GestureDetector(
              onTap: () {
                onColorSelected(color);
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.primaryText : Colors.white,
                    width: selected ? 2.4 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BubblePreviewCard extends StatelessWidget {
  const _BubblePreviewCard({required this.appearance});

  final ChatBubbleAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.separatorColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实时预览',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: appearance.peerBubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: palette.bubbleBorderColor),
              ),
              child: Text(
                '这样读起来会更像 iMessage。',
                style: TextStyle(color: _bubbleTextColor(appearance.peerBubbleColor)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: appearance.userBubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                '已读标签也会一起保留。',
                style: TextStyle(color: _bubbleTextColor(appearance.userBubbleColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  const _ChatThreadTile({
    required this.contact,
    required this.thread,
    required this.onTap,
  });

  final ChatContact contact;
  final ChatThread thread;
  final ValueChanged<ChatContact> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final hasUnread = thread.unreadCount > 0;
    final timeColor = hasUnread ? palette.accentColor : palette.secondaryText;
    final previewColor = hasUnread ? palette.primaryText : palette.secondaryText;
    final borderColor = thread.isPinned
        ? palette.accentColor.withValues(alpha: 0.14)
        : palette.threadDividerColor;

    // 置顶会话不再额外塞入标签，直接通过更深底色表达状态，保证列表更紧凑。
    final tileColor = thread.isPinned
        ? palette.threadPinnedSurface
        : palette.threadSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('chat_thread_${contact.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          onTap(contact);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _Avatar(
                  color: contact.avatarColor,
                  label: contact.emoji,
                  size: 48,
                  shadowOpacity: 0.14,
                  shadowBlurRadius: 8,
                  shadowOffset: const Offset(0, 4),
                  avatarUrl: contact.avatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: palette.primaryText,
                                    fontWeight: hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatThreadTime(thread.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: timeColor,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              thread.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: previewColor,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                          if (hasUnread) const SizedBox(width: 10),
                          if (hasUnread)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.unreadBadgeColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                thread.unreadCount > 99
                                    ? '99+'
                                    : '${thread.unreadCount}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
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

class _MomentMeta extends StatelessWidget {
  const _MomentMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: palette.accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.secondaryText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.secondaryText),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: palette.primaryText,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.color,
    required this.label,
    this.size = 54,
    this.shadowOpacity = 0.28,
    this.shadowBlurRadius = 14,
    this.shadowOffset = const Offset(0, 8),
    this.avatarUrl,
  });

  final Color color;
  final String label;
  final double size;
  final double shadowOpacity;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.34;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: shadowOpacity),
              blurRadius: shadowBlurRadius,
              offset: shadowOffset,
            ),
          ],
        ),
        child: AvatarWidget(
          size: size,
          avatarUrl: avatarUrl,
          fallbackColor: color,
          fallbackText: label,
          borderRadius: radius,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: shadowOpacity),
            blurRadius: shadowBlurRadius,
            offset: shadowOffset,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatPalette {
  const ChatPalette({
    required this.pageBackground,
    required this.backgroundGradient,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
    required this.secondaryAccentColor,
    required this.surfaceColor,
    required this.elevatedSurface,
    required this.separatorColor,
    required this.navigationSurface,
    required this.navigationIndicator,
    required this.navigationSelectedText,
    required this.navigationUnselectedText,
    required this.threadSurface,
    required this.threadPinnedSurface,
    required this.threadDividerColor,
    required this.inputSurface,
    required this.inputBorderColor,
    required this.dateChipColor,
    required this.dateChipTextColor,
    required this.messageMetaTextColor,
    required this.readLabelColor,
    required this.bubbleBorderColor,
    required this.userBubble,
    required this.aiBubble,
    required this.sendButtonColor,
    required this.unreadBadgeColor,
  });

  final Color pageBackground;
  final List<Color> backgroundGradient;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;
  final Color secondaryAccentColor;
  final Color surfaceColor;
  final Color elevatedSurface;
  final Color separatorColor;
  final Color navigationSurface;
  final Color navigationIndicator;
  final Color navigationSelectedText;
  final Color navigationUnselectedText;
  final Color threadSurface;
  final Color threadPinnedSurface;
  final Color threadDividerColor;
  final Color inputSurface;
  final Color inputBorderColor;
  final Color dateChipColor;
  final Color dateChipTextColor;
  final Color messageMetaTextColor;
  final Color readLabelColor;
  final Color bubbleBorderColor;
  final Color userBubble;
  final Color aiBubble;
  final Color sendButtonColor;
  final Color unreadBadgeColor;

  static ChatPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const ChatPalette(
        pageBackground: Color(0xFF0F1115),
        backgroundGradient: [
          Color(0xFF0F1115),
          Color(0xFF0F1115),
          Color(0xFF0F1115),
        ],
        primaryText: Colors.white,
        secondaryText: Color(0xFFABB5C7),
        accentColor: Color(0xFF2481FF),
        secondaryAccentColor: Color(0xFF7C6CF2),
        surfaceColor: Color(0xFF161A21),
        elevatedSurface: Color(0xFF1C212B),
        separatorColor: Color(0xFF282E3A),
        navigationSurface: Color(0xFF161A21),
        navigationIndicator: Color(0x220A84FF),
        navigationSelectedText: Colors.white,
        navigationUnselectedText: Color(0xFF98A2B3),
        threadSurface: Color(0xFF161A21),
        threadPinnedSurface: Color(0xFF1A2433),
        threadDividerColor: Color(0xFF263041),
        inputSurface: Color(0xFF1D222C),
        inputBorderColor: Color(0xFF2B3240),
        dateChipColor: Color(0xFF2A303B),
        dateChipTextColor: Color(0xFFD2D7E0),
        messageMetaTextColor: Color(0xFFADB5C3),
        readLabelColor: Color(0xFF78B4FF),
        bubbleBorderColor: Color(0xFF2B3240),
        userBubble: Color(0xFF2481FF),
        aiBubble: Color(0xFF1F2732),
        sendButtonColor: Color(0xFF2481FF),
        unreadBadgeColor: Color(0xFFFF6B81),
      );
    }

    return const ChatPalette(
      pageBackground: Color(0xFFF5F5F7),
      backgroundGradient: [
        Color(0xFFF5F5F7),
        Color(0xFFF5F5F7),
        Color(0xFFF5F5F7),
      ],
      primaryText: Color(0xFF111827),
      secondaryText: Color(0xFF6B7280),
      accentColor: Color(0xFF0A84FF),
      secondaryAccentColor: Color(0xFF5E5CE6),
      surfaceColor: Color(0xFFFFFFFF),
      elevatedSurface: Color(0xFFFFFFFF),
      separatorColor: Color(0xFFDDE1E7),
      navigationSurface: Color(0xFFFFFFFF),
      navigationIndicator: Color(0x1F0A84FF),
      navigationSelectedText: Color(0xFF111827),
      navigationUnselectedText: Color(0xFF7B8694),
      threadSurface: Color(0xFFFFFFFF),
      threadPinnedSurface: Color(0xFFEFF4FF),
      threadDividerColor: Color(0xFFE4E7EC),
      inputSurface: Color(0xFFF2F3F7),
      inputBorderColor: Color(0xFFE0E4EA),
      dateChipColor: Color(0xFFE9ECF2),
      dateChipTextColor: Color(0xFF667085),
      messageMetaTextColor: Color(0xFF7B8694),
      readLabelColor: Color(0xFF0A84FF),
      bubbleBorderColor: Color(0xFFE1E5EB),
      userBubble: Color(0xFF0A84FF),
      aiBubble: Color(0xFFE9EAEE),
      sendButtonColor: Color(0xFF0A84FF),
      unreadBadgeColor: Color(0xFFFF4D67),
    );
  }
}

String _formatThreadTime(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      now.year == time.year && now.month == time.month && now.day == time.day;
  if (sameDay) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  return '${time.month}/${time.day}';
}

String _formatConversationDate(DateTime time) {
  final now = DateTime.now();
  if (now.year == time.year) {
    return '${time.month}月${time.day}日';
  }
  return '${time.year}年${time.month}月${time.day}日';
}

String _formatMessageTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _formatMomentTime(DateTime time) {
  return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

bool _isSameMessageDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

Color _bubbleTextColor(Color bubbleColor) {
  return bubbleColor.computeLuminance() > 0.62
      ? const Color(0xFF111827)
      : Colors.white;
}

class _MultiSelectAction extends StatelessWidget {
  const _MultiSelectAction({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled
        ? Colors.white24
        : isDestructive
            ? Colors.redAccent
            : Colors.white70;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
