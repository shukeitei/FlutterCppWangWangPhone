import 'package:flutter/material.dart';

import '../chat_app_page.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import '../widgets/avatar_widget.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key, required this.controller});

  final ChatAppController controller;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  static const int _memberLimit = 20;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  String _searchQuery = '';

  ChatAppController get controller => widget.controller;

  List<ChatContact> get _filteredContacts {
    final list = List<ChatContact>.from(controller.contacts)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_searchQuery.isEmpty) return list;
    return list.where((c) => c.name.contains(_searchQuery)).toList();
  }

  bool get _canCreate =>
      _selectedIds.length >= 2 && _nameController.text.trim().isNotEmpty;

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群名')),
      );
      return;
    }
    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少选择 2 位成员')),
      );
      return;
    }
    final group = controller.createGroup(
      name: name,
      memberContactIds: _selectedIds.toList(),
    );
    Navigator.of(context).pop(group);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ChatPalette.of(context);
    final contacts = _filteredContacts;

    return Scaffold(
      backgroundColor: palette.pageBackground,
      appBar: AppBar(
        backgroundColor: palette.pageBackground,
        foregroundColor: palette.primaryText,
        elevation: 0,
        title: const Text('新建群聊'),
        actions: [
          TextButton(
            onPressed: _canCreate ? _create : null,
            child: Text(
              '完成(${_selectedIds.length})',
              style: TextStyle(
                color: _canCreate
                    ? palette.accentColor
                    : palette.secondaryText.withValues(alpha: 0.4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 群名输入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: palette.primaryText, fontSize: 16),
              decoration: InputDecoration(
                hintText: '输入群名',
                hintStyle: TextStyle(color: palette.secondaryText),
                filled: true,
                fillColor: palette.inputSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.inputBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.accentColor),
                ),
              ),
            ),
          ),

          // 已选成员预览
          if (_selectedIds.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _selectedIds.length,
                itemBuilder: (context, index) {
                  final contactId = _selectedIds.elementAt(index);
                  final ChatContact contact;
                  try {
                    contact = controller.contactById(contactId);
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedIds.remove(contactId)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarWidget(
                            size: 40,
                            fallbackColor: contact.avatarColor,
                            fallbackText: contact.emoji,
                            avatarUrl: contact.avatarUrl,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 48,
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 计数
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Text(
                  '选择成员 (${_selectedIds.length}/$_memberLimit)',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: palette.primaryText, fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索好友…',
                hintStyle: TextStyle(color: palette.secondaryText),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: palette.secondaryText,
                ),
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
                  borderSide: BorderSide(
                    color: palette.accentColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),

          // 好友列表
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty ? '没有匹配的好友' : '暂无好友',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final selected = _selectedIds.contains(contact.id);
                      final atLimit =
                          _selectedIds.length >= _memberLimit && !selected;

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
                            color: atLimit
                                ? palette.secondaryText.withValues(alpha: 0.4)
                                : palette.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Checkbox(
                          value: selected,
                          onChanged: atLimit
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(contact.id);
                                    } else {
                                      _selectedIds.remove(contact.id);
                                    }
                                  });
                                },
                          activeColor: palette.accentColor,
                          checkColor: Colors.white,
                        ),
                        onTap: () {
                          if (atLimit) return;
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(contact.id);
                            } else {
                              _selectedIds.add(contact.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
