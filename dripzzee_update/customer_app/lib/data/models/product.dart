import '../../core/utils/parse.dart';

const kSizeOrder = [
  'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', 'FREE SIZE', 'FREE',
];

/// Orders sizes as a shopper expects: XS < S < M …, then numeric sizes.
int compareSizes(String a, String b) {
  final ia = kSizeOrder.indexOf(a.toUpperCase());
  final ib = kSizeOrder.indexOf(b.toUpperCase());
  if (ia >= 0 && ib >= 0) return ia - ib;
  if (ia >= 0) return -1;
  if (ib >= 0) return 1;
  final na = double.tryParse(a.replaceAll(RegExp(r'[^0-9.]'), ''));
  final nb = double.tryParse(b.replaceAll(RegExp(r'[^0-9.]'), ''));
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.price,
    required this.mrp,
    required this.images,
    required this.tags,
    required this.colors,
    required this.sizes,
    required this.active,
    required this.createdAt,
    required this.trendingScore,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String name;
  final String brand;
  final String description;
  final String category;
  final int price;
  final int? mrp;
  final List<String> images;
  final List<String> tags;
  final List<String> colors;

  /// size label → units in stock
  final Map<String, int> sizes;
  final bool active;
  final DateTime? createdAt;
  final double trendingScore;

  List<String> get sizeLabels => sizes.keys.toList()..sort(compareSizes);
  int stockFor(String size) => sizes[size] ?? 0;
  int get totalStock => sizes.values.fold(0, (sum, q) => sum + (q > 0 ? q : 0));
  bool get inStock => active && totalStock > 0;
  String? get primaryImage => images.isEmpty ? null : images.first;

  int get discountPercent {
    final original = mrp;
    if (original == null || original <= price || original <= 0) return 0;
    return (((original - price) / original) * 100).round();
  }

  bool get isNewArrival =>
      createdAt != null && DateTime.now().difference(createdAt!).inDays <= 21;

  /// Everything searchable, lower-cased.
  String get searchText => [
        name,
        brand,
        category,
        storeName,
        description,
        ...tags,
        ...colors,
      ].join(' ').toLowerCase();

  factory Product.fromMap(String id, Map<String, dynamic> d) {
    final rawSizes = readMap(d['sizes']);
    return Product(
      id: id,
      storeId: readString(d['storeId']),
      storeName: readString(d['storeName']),
      name: readString(d['name'], 'Untitled'),
      brand: readString(d['brand']),
      description: readString(d['description']),
      category: readString(d['category']).toLowerCase(),
      price: readInt(d['price']),
      mrp: readIntOrNull(d['mrp']),
      images: readStringList(d['images']),
      tags: readStringList(d['tags']).map((t) => t.toLowerCase()).toList(),
      colors: readStringList(d['colors']),
      sizes: {
        for (final e in rawSizes.entries) e.key: readInt(e.value),
      },
      active: readBool(d['active'], true),
      createdAt: readDate(d['createdAt']),
      trendingScore: readDouble(d['trendingScore']),
    );
  }
}
