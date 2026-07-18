class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String normalizedName;
  final DateTime createdAt;
  final DateTime updatedAt;
}
