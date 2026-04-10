import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../character_detail_page.dart';
import '../chat_app_page.dart';
import '../chat_controller.dart';
import '../chat_message_payloads.dart';
import '../chat_models.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/group_avatar_widget.dart';
import 'persona_select_page.dart';
import 'preset_select_page.dart';
import 'world_select_page.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final ChatAppController controller;
  final String groupId;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _waitingForSummon = false; // 手动模式下，发完消息后等待召唤
  String? _editingMessageId;
  final TextEditingController _editController = TextEditingController();
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};

  void _enterMultiSelect(String initialId) {
    setState(() {
      _editingMessageId = null;
      _multiSelectMode = true;
      _selectedIds.clear();
      _selectedIds.add(initialId);
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

  ChatAppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.openConversation(widget.groupId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    controller.closeConversation(widget.groupId);
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // 切回随机模式时，召唤条不再有意义
    if (controller.isGroupRandomMode(widget.groupId) && _waitingForSummon) {
      _waitingForSummon = false;
    }
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMemberList(ChatGroup group) {
    final palette = ChatPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '群成员 (${group.memberContactIds.length})',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: palette.secondaryText,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              Divider(color: palette.separatorColor, height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: group.memberContactIds.length,
                  itemBuilder: (listCtx, index) {
                    final contactId = group.memberContactIds[index];
                    final ChatContact contact;
                    try {
                      contact = controller.contactById(contactId);
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      leading: AvatarWidget(
                        size: 40,
                        fallbackColor: contact.avatarColor,
                        fallbackText: contact.emoji,
                        avatarUrl: contact.avatarUrl,
                      ),
                      title: Text(
                        contact.name,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        contact.signature,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CharacterDetailPage(
                              controller: controller,
                              contact: contact,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final isManual = !controller.isGroupRandomMode(widget.groupId);
    controller.sendGroupMessage(groupId: widget.groupId, text: text);
    _inputController.clear();
    _scrollToBottom();
    if (isManual) {
      setState(() => _waitingForSummon = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // 群组可能在外部被删除，这里要安全 fallback
        final ChatGroup group;
        try {
          group = controller.groupById(widget.groupId);
        } catch (_) {
          return Scaffold(
            backgroundColor: palette.pageBackground,
            body: Center(
              child: Text(
                '群聊已不存在',
                style: TextStyle(color: palette.secondaryText),
              ),
            ),
          );
        }
        final messages = controller.messagesFor(widget.groupId);
        final hasDraftText = _inputController.text.trim().isNotEmpty;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: palette.pageBackground,
          endDrawer: _buildGroupDrawer(palette, group),
          body: Container(
            color: palette.pageBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (_multiSelectMode)
                    _buildMultiSelectHeader(palette)
                  else
                    _buildHeader(palette, group),
                  if (controller.getGroupError(widget.groupId) != null)
                    _buildErrorBanner(palette),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(
                              '还没有消息',
                              style: TextStyle(color: palette.secondaryText),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageItem(palette, messages[index]);
                            },
                          ),
                  ),
                  if (controller.isTyping(widget.groupId))
                    _buildTypingIndicator(palette),
                  if (_multiSelectMode)
                    _buildMultiSelectActionBar(palette)
                  else
                    _buildInputBar(palette, hasDraftText, group),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiSelectHeader(ChatPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        border: Border(
          bottom: BorderSide(color: palette.separatorColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }

  Widget _buildMultiSelectActionBar(ChatPalette palette) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hasSelection = _selectedIds.isNotEmpty;
    return Container(
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
          _GroupMultiSelectAction(
            icon: Icons.visibility_off_rounded,
            label: '隐藏',
            onTap: !hasSelection
                ? null
                : () {
                    controller.batchToggleHideMessages(
                      contactId: widget.groupId,
                      messageIds: _selectedIds.toSet(),
                      hide: true,
                    );
                    _exitMultiSelect();
                  },
          ),
          _GroupMultiSelectAction(
            icon: Icons.visibility_rounded,
            label: '取消隐藏',
            onTap: !hasSelection
                ? null
                : () {
                    controller.batchToggleHideMessages(
                      contactId: widget.groupId,
                      messageIds: _selectedIds.toSet(),
                      hide: false,
                    );
                    _exitMultiSelect();
                  },
          ),
          _GroupMultiSelectAction(
            icon: Icons.delete_outline_rounded,
            label: '删除',
            isDestructive: true,
            onTap: !hasSelection
                ? null
                : () {
                    controller.batchDeleteMessages(
                      contactId: widget.groupId,
                      messageIds: _selectedIds.toSet(),
                    );
                    _exitMultiSelect();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ChatPalette palette, ChatGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        border: Border(
          bottom: BorderSide(color: palette.separatorColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: palette.primaryText,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showMemberList(group),
              child: Row(
                children: [
                  GroupAvatarWidget(
                    group: group,
                    controller: controller,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.memberContactIds.length} 位成员',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: palette.secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: controller.isGroupRandomMode(widget.groupId)
                ? '随机接力模式'
                : '手动指定模式',
            icon: Icon(
              controller.isGroupRandomMode(widget.groupId)
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: controller.isGroupRandomMode(widget.groupId)
                  ? const Color(0xFFFFC65C)
                  : palette.secondaryText,
            ),
            onPressed: () {
              controller.toggleGroupMode(widget.groupId);
              final mode = controller.isGroupRandomMode(widget.groupId)
                  ? '随机接力'
                  : '手动指定';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已切换为 $mode 模式'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '群聊设置',
            icon: Icon(
              Icons.tune_rounded,
              color: palette.primaryText,
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatPalette palette, ChatMessage message) {
    final isUser = message.sender == ChatMessageSender.user;
    final body = message.activeBody;
    final text =
        body is WordMessageBody ? body.text : message.previewText;
    final bubble = controller.bubbleAppearance;

    // 是否系统消息（建群/重置提示）
    final isSystem = !isUser && message.contactId == widget.groupId;

    // 是否最后一条 AI 消息（用于显示 alt 切换 + reroll）
    final messages = controller.messagesFor(widget.groupId);
    final isLastAi = !isUser &&
        !isSystem &&
        !_multiSelectMode &&
        messages.isNotEmpty &&
        messages.last.id == message.id;

    // 编辑态（多选模式下忽略）
    if (_editingMessageId == message.id && !_multiSelectMode) {
      return _buildEditingBubble(palette, message, isUser);
    }

    Widget content;
    if (isUser) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 56),
            Flexible(
              child: Opacity(
                opacity: message.isHidden ? 0.4 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubble.userBubbleColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // AI/系统消息：左侧带角色头像 + 名字
      ChatContact? authorContact;
      if (!isSystem) {
        try {
          authorContact = controller.contactById(message.contactId);
        } catch (_) {}
      }
      final authorName = authorContact?.name ?? '群消息';

      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authorContact != null)
                  AvatarWidget(
                    size: 32,
                    fallbackColor: authorContact.avatarColor,
                    fallbackText: authorContact.emoji,
                    avatarUrl: authorContact.avatarUrl,
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.elevatedSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      size: 18,
                      color: palette.secondaryText,
                    ),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Opacity(
                    opacity: message.isHidden ? 0.4 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            authorName,
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bubble.peerBubbleColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
            if (isLastAi) _buildAltAndRerollBar(palette, message),
          ],
        ),
      );
    }

    // 多选模式：前面加勾选圆圈，tap 切换选中
    if (_multiSelectMode) {
      final selected = _selectedIds.contains(message.id);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSelection(message.id),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, top: 12),
              child: Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    selected ? Colors.orangeAccent : Colors.white38,
                size: 22,
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    // 系统消息不给长按菜单
    if (isSystem) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showMessageActionSheet(message),
      child: content,
    );
  }

  Widget _buildAltAndRerollBar(ChatPalette palette, ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.alternatives.length > 1) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: message.activeAltIndex > 0
                  ? () => controller.switchAltVersion(
                        contactId: widget.groupId,
                        newIndex: message.activeAltIndex - 1,
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: message.activeAltIndex > 0
                      ? palette.secondaryText
                      : palette.secondaryText.withValues(alpha: 0.3),
                ),
              ),
            ),
            Text(
              '${message.activeAltIndex + 1}/${message.alternatives.length}',
              style: TextStyle(color: palette.secondaryText, fontSize: 12),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: message.activeAltIndex < message.alternatives.length - 1
                  ? () => controller.switchAltVersion(
                        contactId: widget.groupId,
                        newIndex: message.activeAltIndex + 1,
                      )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: message.activeAltIndex <
                          message.alternatives.length - 1
                      ? palette.secondaryText
                      : palette.secondaryText.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                controller.rerollGroupLastReply(groupId: widget.groupId),
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
    );
  }

  Widget _buildEditingBubble(
      ChatPalette palette, ChatMessage message, bool isUser) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 12,
        right: isUser ? 12 : 48,
        top: 4,
        bottom: 4,
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
                color: Colors.orangeAccent.withValues(alpha: 0.6),
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
                onPressed: () => setState(() => _editingMessageId = null),
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
                    controller.editMessage(
                      contactId: widget.groupId,
                      messageId: message.id,
                      newText: newText,
                    );
                  }
                  setState(() => _editingMessageId = null);
                },
                style: TextButton.styleFrom(
                  backgroundColor:
                      Colors.orangeAccent.withValues(alpha: 0.2),
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

  void _showMessageActionSheet(ChatMessage message) {
    final palette = ChatPalette.of(context);
    final isHidden = message.isHidden;
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy_rounded, color: palette.primaryText),
              title:
                  Text('复制', style: TextStyle(color: palette.primaryText)),
              onTap: () {
                Navigator.pop(sheetCtx);
                final body = message.activeBody;
                final text = body is WordMessageBody
                    ? body.text
                    : message.previewText;
                Clipboard.setData(ClipboardData(text: text));
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: palette.primaryText),
              title:
                  Text('改写', style: TextStyle(color: palette.primaryText)),
              onTap: () {
                Navigator.pop(sheetCtx);
                final body = message.activeBody;
                final currentText = body is WordMessageBody
                    ? body.text
                    : message.previewText;
                setState(() {
                  _editingMessageId = message.id;
                  _editController.text = currentText;
                });
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.replay_rounded, color: Colors.orange),
              title:
                  Text('回溯', style: TextStyle(color: palette.primaryText)),
              subtitle: Text(
                '删除这条及之后所有消息',
                style:
                    TextStyle(color: palette.secondaryText, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: palette.surfaceColor,
                    title: Text(
                      '回溯确认',
                      style: TextStyle(color: palette.primaryText),
                    ),
                    content: Text(
                      '将删除这条消息及之后的所有消息，不可恢复。',
                      style: TextStyle(color: palette.secondaryText),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dCtx);
                          controller.rollbackToMessage(
                            contactId: widget.groupId,
                            messageId: message.id,
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
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title:
                  Text('删除', style: TextStyle(color: palette.primaryText)),
              onTap: () {
                Navigator.pop(sheetCtx);
                controller.deleteMessage(
                  contactId: widget.groupId,
                  messageId: message.id,
                );
              },
            ),
            ListTile(
              leading: Icon(
                isHidden
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: palette.primaryText,
              ),
              title: Text(
                isHidden ? '取消隐藏' : '隐藏',
                style: TextStyle(color: palette.primaryText),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                controller.toggleHideMessage(
                  contactId: widget.groupId,
                  messageId: message.id,
                );
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.checklist_rounded, color: palette.primaryText),
              title: Text('多选',
                  style: TextStyle(color: palette.primaryText)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _enterMultiSelect(message.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSummonBar(ChatPalette palette, ChatGroup group) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSummonPicker(group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.accentColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 18,
              color: palette.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              '点击召唤角色发言',
              style: TextStyle(
                color: palette.accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: palette.accentColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummonPicker(ChatGroup group) {
    final palette = ChatPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '召唤谁来发言？',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: palette.secondaryText,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              Divider(color: palette.separatorColor, height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: group.memberContactIds.length,
                  itemBuilder: (listCtx, index) {
                    final contactId = group.memberContactIds[index];
                    final ChatContact contact;
                    try {
                      contact = controller.contactById(contactId);
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      leading: AvatarWidget(
                        size: 36,
                        fallbackColor: contact.avatarColor,
                        fallbackText: contact.emoji,
                        avatarUrl: contact.avatarUrl,
                      ),
                      title: Text(
                        contact.name,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        controller.sendGroupMessage(
                          groupId: widget.groupId,
                          text: '',
                          targetContactId: contactId,
                          summonOnly: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupDrawer(ChatPalette palette, ChatGroup group) {
    final screenWidth = MediaQuery.of(context).size.width;
    final currentPresetName =
        controller.getResolvedPresetName(widget.groupId) ??
            controller.globalPresetName ??
            '默认';

    return SizedBox(
      width: screenWidth * 0.72,
      child: Drawer(
        backgroundColor: palette.surfaceColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  '群聊设置',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Divider(color: palette.separatorColor, height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF0A84FF),
                      ),
                      title: Text(
                        '用户身份',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: palette.secondaryText,
                      ),
                      onTap: () => _openPersonaSelect(group),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.layers_outlined,
                        color: Color(0xFFFFA56C),
                      ),
                      title: Text(
                        '对话预设',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        currentPresetName,
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: palette.secondaryText,
                      ),
                      onTap: () => _openPresetSelect(),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.auto_stories_outlined,
                        color: Colors.green.shade300,
                      ),
                      title: Text(
                        '群世界书',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        () {
                          final books = controller
                                  .worldBindings.group[widget.groupId] ??
                              const [];
                          return books.isEmpty
                              ? '未绑定'
                              : '已绑定 ${books.length} 个';
                        }(),
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: palette.secondaryText,
                      ),
                      onTap: () => _openWorldSelect(),
                    ),
                  ],
                ),
              ),
              Divider(color: palette.separatorColor, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.orange,
                ),
                title: const Text(
                  '重置对话',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _showResetDialog(group),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  '解散群聊',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _showDisbandDialog(group),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPersonaSelect(ChatGroup group) async {
    Navigator.pop(context);
    if (controller.personas.isEmpty) {
      await controller.fetchPersonas();
    }
    if (!mounted) return;
    final resolved = await controller.getResolvedPersona(group.name);
    if (!mounted) return;
    final currentId = (resolved['id'] as String?) ?? '';
    final selectedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonaSelectPage(
          personas: controller.personas,
          currentPersonaId: currentId,
          contactName: group.name,
          avatarUrlBuilder: (id) =>
              '$kBridgeHost/persona_avatar/${Uri.encodeComponent(id)}',
        ),
      ),
    );
    if (selectedId != null) {
      await controller.setChatPersona(group.name, selectedId);
    }
  }

  Future<void> _openPresetSelect() async {
    Navigator.pop(context);
    if (controller.presetList.isEmpty) {
      await controller.fetchPresetList();
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PresetSelectPage(
          presets: controller.presetList,
          currentPresetName:
              controller.getResolvedPresetName(widget.groupId),
          contactId: widget.groupId,
          controller: controller,
        ),
      ),
    );
  }

  void _openWorldSelect() {
    Navigator.pop(context);
    final selected =
        controller.worldBindings.group[widget.groupId] ?? const [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorldSelectPage(
          controller: controller,
          title: '群聊世界书',
          selectedNames: selected,
          onConfirm: (names) =>
              controller.setGroupWorlds(widget.groupId, names),
        ),
      ),
    );
  }

  void _showResetDialog(ChatGroup group) {
    Navigator.pop(context); // 关抽屉
    final palette = ChatPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '重置群聊对话',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Divider(color: palette.separatorColor, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.orange,
                ),
                title: Text(
                  '仅清空聊天',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '删除所有消息，保留群聊和记忆',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  controller.resetGroupChat(
                    groupId: widget.groupId,
                    clearMemory: false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                ),
                title: Text(
                  '清空聊天 + 记忆',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '删除所有消息和相关记忆',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  controller.resetGroupChat(
                    groupId: widget.groupId,
                    clearMemory: true,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.close_rounded,
                  color: palette.secondaryText,
                ),
                title: Text(
                  '取消',
                  style: TextStyle(color: palette.secondaryText),
                ),
                onTap: () => Navigator.pop(sheetCtx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showDisbandDialog(ChatGroup group) {
    Navigator.pop(context); // 关抽屉
    final palette = ChatPalette.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: palette.surfaceColor,
          title: Text(
            '解散群聊',
            style: TextStyle(color: palette.primaryText),
          ),
          content: Text(
            '确定要解散「${group.name}」吗？所有消息将被删除，此操作不可撤销。',
            style: TextStyle(color: palette.secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                '取消',
                style: TextStyle(color: palette.secondaryText),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                controller.disbandGroup(groupId: widget.groupId);
                Navigator.of(context).pop(); // 退出群聊页
              },
              child: const Text(
                '解散',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypingIndicator(ChatPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '角色正在回复…',
            style: TextStyle(color: palette.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ChatPalette palette) {
    final message = controller.getGroupError(widget.groupId)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.redAccent.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => controller.clearGroupError(widget.groupId),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatPalette palette, bool hasDraftText, ChatGroup group) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isManual = !controller.isGroupRandomMode(widget.groupId);

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        border: Border(
          top: BorderSide(color: palette.separatorColor),
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isManual && _waitingForSummon) _buildSummonBar(palette, group),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: palette.inputSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.inputBorderColor),
                  ),
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(color: palette.primaryText, fontSize: 15),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '发送消息…',
                      hintStyle: TextStyle(color: palette.secondaryText),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: hasDraftText
                    ? palette.accentColor
                    : palette.accentColor.withValues(alpha: 0.3),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: hasDraftText ? _send : null,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupMultiSelectAction extends StatelessWidget {
  const _GroupMultiSelectAction({
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
