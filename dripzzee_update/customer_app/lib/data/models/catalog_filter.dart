import 'product.dart';
import 'store.dart';

enum ProductSort { popular, newest, priceLowHigh, priceHighLow, nearest }

extension ProductSortLabel on ProductSort {
  String get label => switch (this) {
        ProductSort.popular => 'Popular',
        ProductSort.newest => 'Newest',
        ProductSort.priceLowHigh => 'Price: low to high',
        ProductSort.priceHighLow => 'Price: high to low',
        ProductSort.nearest => 'Nearest',
      };
}

/// Describes a product listing (category, campaign collection, store tab…).
class ProductFilter {
  const ProductFilter({
    required this.title,
    this.subtitle,
    this.category,
    this.tag,
    this.storeId,
    this.initialColor,
    this.newArrivalsOnly = false,
    this.sort = ProductSort.popular,
  });

  final String title;
  final String? subtitle;
  final String? category;
  final String? tag;
  final String? storeId;
  final String? initialColor;
  final bool newArrivalsOnly;
  final ProductSort sort;

  bool matches(Product p) {
    if (!p.active) return false;
    if (category != null && p.category != category) return false;
    if (tag != null && !p.tags.contains(tag)) return false;
    if (storeId != null && p.storeId != storeId) return false;
    if (newArrivalsOnly && !p.isNewArrival) return false;
    return true;
  }
}

List<Product> sortProducts(
  Iterable<Product> input,
  ProductSort sort, {
  Map<String, double> storeDistances = const {},
}) {
  final list = input.toList();
  int stockFirst(Product a, Product b) =>
      (b.inStock ? 1 : 0) - (a.inStock ? 1 : 0);
  switch (sort) {
    case ProductSort.popular:
      list.sort((a, b) {
        final s = stockFirst(a, b);
        return s != 0 ? s : b.trendingScore.compareTo(a.trendingScore);
      });
    case ProductSort.newest:
      list.sort((a, b) {
        final da = a.createdAt ?? DateTime(2000);
        final db = b.createdAt ?? DateTime(2000);
        return db.compareTo(da);
      });
    case ProductSort.priceLowHigh:
      list.sort((a, b) => a.price.compareTo(b.price));
    case ProductSort.priceHighLow:
      list.sort((a, b) => b.price.compareTo(a.price));
    case ProductSort.nearest:
      list.sort((a, b) {
        final da = storeDistances[a.storeId] ?? double.infinity;
        final db = storeDistances[b.storeId] ?? double.infinity;
        return da.compareTo(db);
      });
  }
  return list;
}

enum StoreSort { nearest, topRated, fastest }

extension StoreSortLabel on StoreSort {
  String get label => switch (this) {
        StoreSort.nearest => 'Nearest',
        StoreSort.topRated => 'Top rated',
        StoreSort.fastest => 'Fastest',
      };
}

class StoreFilter {
  const StoreFilter({
    required this.title,
    this.subtitle,
    this.tag,
    this.category,
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final String? category;

  bool matches(Store s) {
    if (!s.active) return false;
    if (tag != null && !s.tags.contains(tag)) return false;
    if (category != null && !s.categories.contains(category)) return false;
    return true;
  }
}

List<Store> sortStores(Iterable<Store> input, StoreSort sort) {
  final list = input.toList();
  switch (sort) {
    case StoreSort.nearest:
      list.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
    case StoreSort.topRated:
      list.sort((a, b) => b.rating.compareTo(a.rating));
    case StoreSort.fastest:
      list.sort((a, b) => a.minDeliveryMinutes.compareTo(b.minDeliveryMinutes));
  }
  return list;
}
