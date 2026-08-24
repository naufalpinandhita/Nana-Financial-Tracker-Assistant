class Category {
  final String id;
  final String name;
  final String type; // 'income' | 'expense' | 'transfer'
  final String icon;
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'expense',
      icon: json['icon'] ?? 'category',
      color: json['color'] ?? '#064e3b',
    );
  }
}
