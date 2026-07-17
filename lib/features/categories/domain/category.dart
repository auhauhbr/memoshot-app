class Category {
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
}

class CategorySummary {
  const CategorySummary({required this.category, required this.mediaCount});

  final Category category;
  final int mediaCount;
}
