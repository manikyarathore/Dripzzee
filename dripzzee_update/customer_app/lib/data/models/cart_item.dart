import '../../core/utils/parse.dart';
import 'product.dart';

class CartItem {
  const CartItem({
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.storeDeliveryFee,
    required this.name,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.unitPrice,
    required this.mrp,
    required this.quantity,
    required this.maxStock,
  });

  final String productId;
  final String storeId;
  final String storeName;
  final int storeDeliveryFee;
  final String name;
  final String? imageUrl;
  final String size;
  final String? color;
  final int unitPrice;
  final int? mrp;
  final int quantity;

  /// Last known stock for this size; re-checked against Firestore before
  /// checkout and enforced again on the server.
  final int maxStock;

  String get key => '$productId|$size|${color ?? ''}';
  int get lineTotal => unitPrice * quantity;

  factory CartItem.fromProduct(
    Product p, {
    required String size,
    String? color,
    int quantity = 1,
    int storeDeliveryFee = 49,
  }) =>
      CartItem(
        productId: p.id,
        storeId: p.storeId,
        storeName: p.storeName,
        storeDeliveryFee: storeDeliveryFee,
        name: p.name,
        imageUrl: p.primaryImage,
        size: size,
        color: color,
        unitPrice: p.price,
        mrp: p.mrp,
        quantity: quantity,
        maxStock: p.stockFor(size),
      );

  CartItem copyWith({int? quantity, int? unitPrice, int? maxStock, int? mrp}) =>
      CartItem(
        productId: productId,
        storeId: storeId,
        storeName: storeName,
        storeDeliveryFee: storeDeliveryFee,
        name: name,
        imageUrl: imageUrl,
        size: size,
        color: color,
        unitPrice: unitPrice ?? this.unitPrice,
        mrp: mrp ?? this.mrp,
        quantity: quantity ?? this.quantity,
        maxStock: maxStock ?? this.maxStock,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'storeId': storeId,
        'storeName': storeName,
        'storeDeliveryFee': storeDeliveryFee,
        'name': name,
        'imageUrl': imageUrl,
        'size': size,
        'color': color,
        'unitPrice': unitPrice,
        'mrp': mrp,
        'quantity': quantity,
        'maxStock': maxStock,
      };

  static CartItem? fromJson(Map<String, dynamic> j) {
    final productId = readString(j['productId']);
    final storeId = readString(j['storeId']);
    if (productId.isEmpty || storeId.isEmpty) return null;
    return CartItem(
      productId: productId,
      storeId: storeId,
      storeName: readString(j['storeName']),
      storeDeliveryFee: readInt(j['storeDeliveryFee'], 49),
      name: readString(j['name']),
      imageUrl: j['imageUrl'] is String ? j['imageUrl'] as String : null,
      size: readString(j['size']),
      color: j['color'] is String ? j['color'] as String : null,
      unitPrice: readInt(j['unitPrice']),
      mrp: readIntOrNull(j['mrp']),
      quantity: readInt(j['quantity'], 1),
      maxStock: readInt(j['maxStock']),
    );
  }
}
