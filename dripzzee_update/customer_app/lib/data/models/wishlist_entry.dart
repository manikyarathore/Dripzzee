import '../../core/utils/parse.dart';
import 'product.dart';

/// Snapshot of a saved product so the wishlist renders even when the product
/// is outside the current nearby radius. Tapping always loads live data.
class WishlistEntry {
  const WishlistEntry({
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.addedAt,
  });

  final String productId;
  final String storeId;
  final String storeName;
  final String name;
  final String? imageUrl;
  final int price;
  final DateTime? addedAt;

  factory WishlistEntry.fromProduct(Product p) => WishlistEntry(
        productId: p.id,
        storeId: p.storeId,
        storeName: p.storeName,
        name: p.name,
        imageUrl: p.primaryImage,
        price: p.price,
        addedAt: DateTime.now(),
      );

  factory WishlistEntry.fromMap(String id, Map<String, dynamic> d) =>
      WishlistEntry(
        productId: id,
        storeId: readString(d['storeId']),
        storeName: readString(d['storeName']),
        name: readString(d['name']),
        imageUrl: d['imageUrl'] is String ? d['imageUrl'] as String : null,
        price: readInt(d['price']),
        addedAt: readDate(d['addedAt']),
      );
}
