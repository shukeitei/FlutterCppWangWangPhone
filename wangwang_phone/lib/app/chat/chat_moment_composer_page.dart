import 'package:flutter/material.dart';

import '../shared/ui.dart';
import 'chat_models.dart';

class MomentComposerPage extends StatefulWidget {
  const MomentComposerPage({super.key, required this.contacts});

  final List<ChatContact> contacts;

  @override
  State<MomentComposerPage> createState() => _MomentComposerPageState();
}

class _MomentComposerPageState extends State<MomentComposerPage> {
  late final TextEditingController _contentController;
  late final TextEditingController _moodController;
  late String _selectedContactId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _moodController = TextEditingController(text: '今日分享');
    _selectedContactId = widget.contacts.first.id;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _moodController.dispose();
    super.dispose();
  }

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
                          '发布动态',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '选择一个角色，把今天的碎片发到朋友圈',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布身份',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: const Key('moment_contact_selector'),
                        initialValue: _selectedContactId,
                        items: widget.contacts
                            .map(
                              (contact) => DropdownMenuItem(
                                value: contact.id,
                                child: Text(contact.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedContactId = value;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: palette.iconSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '主题标签',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('moment_mood_field'),
                        controller: _moodController,
                        decoration: InputDecoration(
                          hintText: '例如：日常碎片 / 晚风 / 今日分享',
                          filled: true,
                          fillColor: palette.iconSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '动态内容',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('moment_content_field'),
                        controller: _contentController,
                        minLines: 5,
                        maxLines: 8,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return '请填写动态内容';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: '把今天想发的内容写在这里...',
                          filled: true,
                          fillColor: palette.iconSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('moment_publish_button'),
                          onPressed: _handlePublish,
                          icon: const Icon(Icons.send_time_extension_rounded),
                          label: const Text('发布到朋友圈'),
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
    );
  }

  void _handlePublish() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      MomentComposerResult(
        contactId: _selectedContactId,
        content: _contentController.text,
        moodLabel: _moodController.text,
      ),
    );
  }
}

class MomentComposerResult {
  const MomentComposerResult({
    required this.contactId,
    required this.content,
    required this.moodLabel,
  });

  final String contactId;
  final String content;
  final String moodLabel;
}
