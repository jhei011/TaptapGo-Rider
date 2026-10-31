class Category {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int? parentId;
  final bool isActive;
  List<Category> children;

  Category({
    required this.id, required this.name, required this.slug,
    this.icon, this.parentId, this.isActive = true,
    this.children = const [],
  });

  bool get isParent => parentId == null;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id:       j['id'] ?? 0,
    name:     j['name'] ?? '',
    slug:     j['slug'] ?? '',
    icon:     j['icon'],
    parentId: j['parent_id'],
    isActive: j['is_active'] ?? true,
    children: [], // mutable list so buildTree can add to it
  );

  /// Build parent→children tree from flat list returned by API
  static List<Category> buildTree(List<Category> flat) {
    final Map<int, Category> map = {for (var c in flat) c.id: c};
    final List<Category> roots = [];
    for (final c in flat) {
      if (c.parentId == null) {
        roots.add(c);
      } else {
        map[c.parentId]?.children.add(c);
      }
    }
    return roots;
  }
}
