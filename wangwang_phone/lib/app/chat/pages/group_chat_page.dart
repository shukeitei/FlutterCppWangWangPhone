import 'package:flutter/material.dart';

import '../character_detail_page.dart';
import '../chat_app_page.dart';
import '../chat_controller.dart';
import '../chat_message_payloads.dart';
import '../chat_models.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/group_avatar_widget.dart';

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
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
    controller.sendGroupMessage(groupId: widget.groupId, text: text);
    _inputController.clear();
    _scrollToBottom();
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
          endDrawer: ChatSidebar(
            currentPersonaName: '默认',
            currentPresetName:
                controller.globalPresetName ?? '默认',
            onPersonaTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('群聊用户身份 - 开发中'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onPresetTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('群聊预设 - 开发中'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          body: Container(
            color: palette.pageBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(palette, group),
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
                  _buildInputBar(palette, hasDraftText),
                ],
              ),
            ),
          ),
        );
      },
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

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 56),
            Flexible(
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI/系统消息：左侧带角色头像 + 名字
    // 当前 message.contactId 有两种情况：
    //   1) 系统消息：contactId == groupId（建群提示）
    //   2) 后续多角色回复：contactId == 具体角色 id
    ChatContact? authorContact;
    if (message.contactId != widget.groupId) {
      try {
        authorContact = controller.contactById(message.contactId);
      } catch (_) {}
    }
    final authorName = authorContact?.name ?? '群消息';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatPalette palette, bool hasDraftText) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceColor,
        border: Border(
          top: BorderSide(color: palette.separatorColor),
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 10),
      child: Row(
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
    );
  }
}
