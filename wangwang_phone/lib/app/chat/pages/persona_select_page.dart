import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Persona 选择页，从侧边栏点击进入
/// 选择后 Navigator.pop(selectedPersonaId)
class PersonaSelectPage extends StatelessWidget {
  const PersonaSelectPage({
    super.key,
    required this.personas,
    required this.currentPersonaId,
    required this.contactName,
    required this.avatarUrlBuilder,
  });

  /// persona 列表，每项是 {'id': xxx, 'name': xxx, 'description': xxx}
  final List<Map<String, dynamic>> personas;
  final String? currentPersonaId;
  final String contactName;
  /// 根据 persona id 构建头像 URL 的函数
  final String Function(String personaId) avatarUrlBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择用户身份'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: personas.isEmpty
          ? const Center(child: Text('没有可用的身份'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: personas.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final p = personas[index];
                final id = p['id'] as String? ?? '';
                final name = p['name'] as String? ?? '未知';
                final desc = p['description'] as String? ?? '';
                final isSelected = id == currentPersonaId;

                return ListTile(
                  leading: ClipOval(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CachedNetworkImage(
                        imageUrl: avatarUrlBuilder(id),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? String.fromCharCode(name.runes.first)
                                : '?',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? String.fromCharCode(name.runes.first)
                                : '?',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: desc.isNotEmpty
                      ? Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF0A84FF))
                      : null,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
    );
  }
}
