import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 通用圆形头像组件
/// 有 avatarUrl 时显示网络图片，没有时 fallback 到颜色圆圈+文字
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.size,
    required this.fallbackColor,
    required this.fallbackText,
    this.avatarUrl,
    this.borderRadius,
  });

  final double size;
  final Color fallbackColor;
  final String fallbackText;
  final String? avatarUrl;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size / 2;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _fallbackCircle(),
          errorWidget: (context, url, error) => _fallbackCircle(),
        ),
      );
    }

    return _fallbackCircle();
  }

  Widget _fallbackCircle() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(borderRadius ?? size / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Persona 头像组件（用于 persona 选择列表）
class PersonaAvatarWidget extends StatelessWidget {
  const PersonaAvatarWidget({
    super.key,
    required this.size,
    required this.personaId,
    required this.bridgeHost,
    required this.name,
  });

  final double size;
  final String personaId;
  final String bridgeHost;
  final String name;

  @override
  Widget build(BuildContext context) {
    final url = personaId.isNotEmpty
        ? '$bridgeHost/persona_avatar/${Uri.encodeComponent(personaId)}'
        : null;

    return AvatarWidget(
      size: size,
      avatarUrl: url,
      fallbackColor: const Color(0xFF7E8DFF),
      fallbackText: name.isNotEmpty ? String.fromCharCode(name.runes.first) : '?',
      borderRadius: size / 2,
    );
  }
}
