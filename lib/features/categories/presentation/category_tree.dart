import '../domain/category.dart';

class CategoryTreeEntry {
  const CategoryTreeEntry({
    required this.summary,
    required this.depth,
    required this.path,
  });

  final CategorySummary summary;
  final int depth;
  final String path;
}

List<CategoryTreeEntry> buildCategoryTreeEntries(
  List<CategorySummary> summaries,
) {
  final byParent = <int?, List<CategorySummary>>{};
  for (final summary in summaries) {
    byParent.putIfAbsent(summary.category.parentId, () => []).add(summary);
  }
  for (final children in byParent.values) {
    children.sort((first, second) {
      final name = first.category.normalizedName.compareTo(
        second.category.normalizedName,
      );
      return name != 0 ? name : first.category.id.compareTo(second.category.id);
    });
  }

  final entries = <CategoryTreeEntry>[];
  final visited = <int>{};
  final pending = <({CategorySummary summary, int depth, String parentPath})>[
    for (final root in (byParent[null] ?? const []).reversed)
      (summary: root, depth: 0, parentPath: ''),
  ];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (!visited.add(current.summary.category.id)) continue;
    final path = current.parentPath.isEmpty
        ? current.summary.category.name
        : '${current.parentPath}/${current.summary.category.name}';
    entries.add(
      CategoryTreeEntry(
        summary: current.summary,
        depth: current.depth,
        path: path,
      ),
    );
    final children = byParent[current.summary.category.id] ?? const [];
    for (final child in children.reversed) {
      pending.add((summary: child, depth: current.depth + 1, parentPath: path));
    }
  }

  for (final summary in summaries) {
    if (visited.add(summary.category.id)) {
      entries.add(
        CategoryTreeEntry(
          summary: summary,
          depth: 0,
          path: summary.category.name,
        ),
      );
    }
  }
  return entries;
}
