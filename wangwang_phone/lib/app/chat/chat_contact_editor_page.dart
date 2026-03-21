import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../shared/ui.dart';
import 'chat_controller.dart';
import 'chat_models.dart';

class ContactEditorPage extends StatefulWidget {
  const ContactEditorPage({
    super.key,
    required this.controller,
    this.startWithImport = false,
  });

  final ChatAppController controller;
  final bool startWithImport;

  @override
  State<ContactEditorPage> createState() => _ContactEditorPageState();
}

class _ContactEditorPageState extends State<ContactEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _signatureController;
  late final TextEditingController _personaController;
  late final TextEditingController _greetingController;
  final _formKey = GlobalKey<FormState>();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _signatureController = TextEditingController();
    _personaController = TextEditingController();
    _greetingController = TextEditingController();

    if (widget.startWithImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleImportTxt();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    _personaController.dispose();
    _greetingController.dispose();
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
                          '添加联系人',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '支持直接输入人设，也支持从 TXT 自动回填',
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
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('contact_import_txt_button'),
                        onPressed: _isImporting ? null : _handleImportTxt,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.description_rounded),
                        label: Text(_isImporting ? '导入中...' : '导入TXT'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearFields,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('清空表单'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FrostPanel(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EditorField(
                        fieldKey: const Key('contact_name_field'),
                        controller: _nameController,
                        label: '角色名称',
                        hint: '例如：小雨 / 阿梨 / 月见',
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return '请先填写角色名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _EditorField(
                        fieldKey: const Key('contact_signature_field'),
                        controller: _signatureController,
                        label: '签名',
                        hint: '一句能体现角色气质的话',
                      ),
                      const SizedBox(height: 14),
                      _EditorField(
                        fieldKey: const Key('contact_persona_field'),
                        controller: _personaController,
                        label: '人设',
                        hint: '直接粘贴或输入角色设定、说话风格、关系定位',
                        minLines: 5,
                        maxLines: 8,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return '请填写角色人设';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _EditorField(
                        fieldKey: const Key('contact_greeting_field'),
                        controller: _greetingController,
                        label: '开场白（可选）',
                        hint: '新联系人创建后发出的第一条消息',
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('contact_save_button'),
                          onPressed: _handleSave,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('保存联系人'),
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

  Future<void> _handleImportTxt() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: true,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final content = await _readPickedFile(file);
      if (!mounted) {
        return;
      }

      final draft = widget.controller.draftFromImportedText(
        fileName: file.name,
        content: content,
      );
      _applyDraft(draft);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已从 ${file.name} 回填联系人内容')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TXT 导入失败，请检查文件内容后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<String> _readPickedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    throw const FormatException('无法读取文件内容');
  }

  void _applyDraft(ChatContactDraft draft) {
    _nameController.text = draft.name;
    _signatureController.text = draft.signature;
    _personaController.text = draft.personaSummary;
    _greetingController.text = draft.initialGreeting;
  }

  void _clearFields() {
    _nameController.clear();
    _signatureController.clear();
    _personaController.clear();
    _greetingController.clear();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final contact = widget.controller.addContact(
      name: _nameController.text,
      signature: _signatureController.text,
      personaSummary: _personaController.text,
      initialGreeting: _greetingController.text,
    );

    Navigator.of(context).pop(contact);
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.hint,
    this.fieldKey,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Key? fieldKey;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: palette.iconSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
