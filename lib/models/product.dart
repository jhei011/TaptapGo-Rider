import 'category.dart';

class ProductRef {
  final int id; final String name;
  const ProductRef({required this.id, required this.name});
  factory ProductRef.fromJson(Map<String, dynamic> j) =>
      ProductRef(id: j['id'] ?? 0, name: j['name'] ?? '');
}

class Product {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final double price;
  final int stock;
  final String? image; // full URL from Laravel url('storage/...')
  final String status;
  final Category? category;
  final ProductRef? seller;
  final String? createdAt;

  const Product({
    required this.id, required this.name, required this.slug,
    this.description, required this.price, required this.stock,
    this.image, required this.status,
    this.category, this.seller, this.createdAt,
  });

  bool get isActive  => status == 'active';
  bool get inStock   => stock > 0;
  bool get lowStock  => stock > 0 && stock <= 5;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id:          j['id'] ?? 0,
    name:        j['name'] ?? '',
    slug:        j['slug'] ?? '',
    description: j['description'],
    price:       (j['price'] as num?)?.toDouble() ?? 0,
    stock:       j['stock'] ?? 0,
    image:       j['image'],
    status:      j['status'] ?? 'active',
    category:    j['category'] != null ? Category.fromJson(j['category']) : null,
    seller:      j['seller']   != null ? ProductRef.fromJson(j['seller']) : null,
    createdAt:   j['created_at'],
  );
}
