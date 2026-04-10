import 'package:flutter/material.dart';
import '../chat_controller.dart';

/// 世界书多选页面，三个入口复用
class WorldSelectPage extends StatefulWidget {
  const WorldSelectPage({
    super.key,
    required this.controller,
    required this.title,
    required this.selectedNames,
    required this.onConfirm,
  });

  final ChatAppController controller;
  final String title;
  final List<String> selectedNames;
  final ValueChanged<List<String>> onConfirm;

  @override
  State<WorldSelectPage> createState() => _WorldSelectPageState();
}

class _WorldSelectPageState extends State<WorldSelectPage> {
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedNames);
    if (widget.controller.worldBookList.isEmpty) {
      widget.controller.fetchWorldBookList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              widget.onConfirm(_selected.toList()..sort());
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final allBooks = widget.controller.worldBookList;
          final filtered = _searchQuery.isEmpty
              ? allBooks
              : allBooks.where((n) => n.contains(_searchQuery)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索世界书...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '已选 ${_selected.length} 个',
                    style:
                        TextStyle(color: Colors.orange[700], fontSize: 13),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final name = filtered[index];
                    final isSelected = _selected.contains(name);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(name, style: const TextStyle(fontSize: 14)),
                      activeColor: Colors.orange,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(name);
                          } else {
                            _selected.remove(name);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
