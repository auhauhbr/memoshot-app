class Category {
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    this.parentId,
  });

  final int id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final int? parentId;
}

class CategoryPath {
  const CategoryPath(this.categories);

  final List<Category> categories;

  String get value => categories.map((category) => category.name).join('/');
}

class CategorySummary {
  const CategorySummary({required this.category, required this.mediaCount});

  final Category category;
  final int mediaCount;
}
