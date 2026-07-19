// lib/models/produce_model.dart
import 'dart:convert';

class ProduceItem {
  String name;
  String qty;      // stored as string for UI simplicity
  String unit;
  String price;    // stored as string for UI simplicity
  String quality;
  String description;

  String? imagePath; // local file path
  String? imageUrl;  // server URL
  String? id;
  String? farmer;
  DateTime? createdAt;

  ProduceItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.quality,
    required this.description,
    this.imagePath,
    this.imageUrl,
    this.id,
    this.farmer,
    this.createdAt,
  });

  /// Create ProduceItem from a JSON-like map (server or local)
  factory ProduceItem.fromJson(Map<String, dynamic> m) {
    // helper to convert possibly numeric values to string
    String _toString(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        // try ISO parse or milliseconds string
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
        final asInt = int.tryParse(v);
        if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return null;
    }

    return ProduceItem(
      name: _toString(m['name'] ?? m['produceName'] ?? ''),
      qty: _toString(m['qty'] ?? m['quantity'] ?? ''),
      unit: _toString(m['unit'] ?? 'kg'),
      price: _toString(m['price'] ?? m['offerPrice'] ?? ''),
      quality: _toString(m['quality'] ?? 'Good'),
      description: _toString(m['description'] ?? ''),
      imagePath: _toString(m['imagePath'] ?? '') == '' ? null : _toString(m['imagePath']),
      imageUrl: _toString(m['imageUrl'] ?? '') == '' ? null : _toString(m['imageUrl']),
      id: _toString(m['_id'] ?? m['id'] ?? ''),
      farmer: _toString(m['farmer'] ?? ''),
      createdAt: _parseDate(m['createdAt'] ?? m['created_at'] ?? m['timestamp']),
    );
  }

  /// Convert to a JSON-friendly map (used when navigating / sending to other screens)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'qty': qty,
      'unit': unit,
      'price': price,
      'quality': quality,
      'description': description,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'id': id,
      '_id': id,
      'farmer': farmer,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}
