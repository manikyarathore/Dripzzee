import '../../core/utils/parse.dart';

class ReturnRequestItem {
  const ReturnRequestItem({
    required this.productId,
    required this.name,
    required this.size,
    required this.quantity,
    this.exchangeSize,
  });

  final String productId;
  final String name;
  final String size;
  final int quantity;
  final String? exchangeSize;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'size': size,
        'quantity': quantity,
        'exchangeSize': exchangeSize,
      };

  factory ReturnRequestItem.fromMap(Map<String, dynamic> d) => ReturnRequestItem(
        productId: readString(d['productId']),
        name: readString(d['name']),
        size: readString(d['size']),
        quantity: readInt(d['quantity'], 1),
        exchangeSize:
            d['exchangeSize'] is String ? d['exchangeSize'] as String : null,
      );
}

class ReturnRequest {
  const ReturnRequest({
    required this.orderId,
    required this.customerId,
    required this.storeId,
    required this.storeName,
    required this.type,
    required this.items,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    this.resolutionNote,
  });

  /// Document id == order id (one request per order).
  final String orderId;
  final String customerId;
  final String storeId;
  final String storeName;

  /// 'RETURN' | 'EXCHANGE'
  final String type;
  final List<ReturnRequestItem> items;
  final String reason;
  final String details;

  /// 'REQUESTED' | 'APPROVED' | 'REJECTED' | 'COMPLETED'
  final String status;
  final DateTime? createdAt;
  final String? resolutionNote;

  bool get isExchange => type == 'EXCHANGE';

  String get statusLabel => switch (status) {
        'REQUESTED' => 'Under review',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Declined',
        'COMPLETED' => 'Completed',
        _ => status,
      };

  factory ReturnRequest.fromMap(String id, Map<String, dynamic> d) =>
      ReturnRequest(
        orderId: id,
        customerId: readString(d['customerId']),
        storeId: readString(d['storeId']),
        storeName: readString(d['storeName']),
        type: readString(d['type'], 'RETURN'),
        items: readMapList(d['items']).map(ReturnRequestItem.fromMap).toList(),
        reason: readString(d['reason']),
        details: readString(d['details']),
        status: readString(d['status'], 'REQUESTED'),
        createdAt: readDate(d['createdAt']),
        resolutionNote:
            d['resolutionNote'] is String ? d['resolutionNote'] as String : null,
      );
}
