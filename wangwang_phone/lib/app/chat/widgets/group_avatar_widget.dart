import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
import 'avatar_widget.dart';

/// 群头像：取群前 4 个成员头像拼成 2x2 网格。
/// 1 人 → 单格；2 人 → 左右；3 人 → 上 1 下 2；4 人及以上 → 2x2。
class GroupAvatarWidget extends StatelessWidget {
  const GroupAvatarWidget({
    super.key,
    required this.group,
    required this.controller,
    this.size = 48,
  });

  final ChatGroup group;
  final ChatAppController controller;
  final double size;

  static const double _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final memberIds = group.memberContactIds;
    final displayIds =
        memberIds.length > 4 ? memberIds.sublist(0, 4) : memberIds;
    final count = displayIds.length;

    final radius = size * 0.22;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: count == 0 ? _fallback() : _buildGrid(displayIds, count),
    );
  }

  Widget _buildGrid(List<String> ids, int count) {
    if (count == 1) {
      return _cell(ids[0], size);
    }

    if (count == 2) {
      final cell = (size - _gap) / 2;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: cell, height: size, child: _cell(ids[0], cell)),
          const SizedBox(width: _gap),
          SizedBox(width: cell, height: size, child: _cell(ids[1], cell)),
        ],
      );
    }

    if (count == 3) {
      final cell = (size - _gap) / 2;
      return Column(
        children: [
          SizedBox(
            height: cell,
            child: Center(
              child: SizedBox(
                width: cell,
                height: cell,
                child: _cell(ids[0], cell),
              ),
            ),
          ),
          const SizedBox(height: _gap),
          SizedBox(
            height: cell,
            child: Row(
              children: [
                Expanded(child: _cell(ids[1], cell)),
                const SizedBox(width: _gap),
                Expanded(child: _cell(ids[2], cell)),
              ],
            ),
          ),
        ],
      );
    }

    // count >= 4
    final cell = (size - _gap) / 2;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(ids[0], cell)),
              const SizedBox(width: _gap),
              Expanded(child: _cell(ids[1], cell)),
            ],
          ),
        ),
        const SizedBox(height: _gap),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(ids[2], cell)),
              const SizedBox(width: _gap),
              Expanded(child: _cell(ids[3], cell)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(String contactId, double cellSize) {
    final ChatContact contact;
    try {
      contact = controller.contactById(contactId);
    } catch (_) {
      return Container(color: Colors.black.withValues(alpha: 0.2));
    }
    return AvatarWidget(
      size: cellSize,
      fallbackColor: contact.avatarColor,
      fallbackText: contact.emoji,
      avatarUrl: contact.avatarUrl,
      borderRadius: 0, // 网格里用方形单元，外层容器统一裁圆角
    );
  }

  Widget _fallback() {
    return Icon(
      Icons.group,
      color: Colors.white.withValues(alpha: 0.5),
      size: size * 0.5,
    );
  }
}
