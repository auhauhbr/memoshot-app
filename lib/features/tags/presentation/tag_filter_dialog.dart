import 'package:flutter/material.dart';

import '../data/tag_repository.dart';
import '../domain/tag.dart';

class TagFilterSelection {
  const TagFilterSelection({this.tag});

  final Tag? tag;
}

class TagFilterDialog extends StatefulWidget {
  const TagFilterDialog({
    super.key,
    required this.repository,
    required this.selectedTagId,
  });

  final TagRepository repository;
  final int? selectedTagId;

  @override
  State<TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<TagFilterDialog> {
  List<TagSummary> _summaries = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final summaries = await widget.repository.loadTagSummaries();
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar por etiqueta'),
      content: SizedBox(width: 420, height: 360, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar as etiquetas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        ListTile(
          key: const Key('all-tags-filter-option'),
          selected: widget.selectedTagId == null,
          leading: const Icon(Icons.label_off_outlined),
          title: const Text('Todas as etiquetas'),
          trailing: widget.selectedTagId == null
              ? const Icon(Icons.check)
              : null,
          onTap: () => Navigator.of(context).pop(const TagFilterSelection()),
        ),
        if (_summaries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhuma etiqueta criada.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final summary in _summaries)
          ListTile(
            key: Key('tag-filter-option-${summary.tag.id}'),
            selected: widget.selectedTagId == summary.tag.id,
            leading: const Icon(Icons.label_outline),
            title: Text(
              summary.tag.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_countLabel(summary.mediaCount)),
            trailing: widget.selectedTagId == summary.tag.id
                ? const Icon(Icons.check)
                : null,
            onTap: () =>
                Navigator.of(context).pop(TagFilterSelection(tag: summary.tag)),
          ),
      ],
    );
  }

  String _countLabel(int count) {
    if (count == 0) return 'Nenhum screenshot';
    if (count == 1) return '1 screenshot';
    return '$count screenshots';
  }
}
