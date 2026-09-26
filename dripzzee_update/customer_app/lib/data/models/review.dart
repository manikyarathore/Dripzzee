import '../../core/utils/parse.dart';

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String customerName;
  final DateTime? createdAt;

  factory Review.fromMap(String id, Map<String, dynamic> d) => Review(
        id: id,
        rating: readInt(d['rating']).clamp(1, 5).toInt(),
        comment: readString(d['comment']),
        customerName: readString(d['customerName'], 'Shopper'),
        createdAt: readDate(d['createdAt']),
      );
}
