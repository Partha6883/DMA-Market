// lib/models/cart_item.dart
import 'package:flutter/foundation.dart';

class CartItem {
  final String produceId;
  final String produceName;
  double qty; // in kg (or units) — mutable to allow easy qty update
  final String unit; // 'kg', 'packet', etc
  final double pricePerUnit; // ₹ per unit (kg)
  final String farmer; // farmer or state identifier
  final String? imageUrl;

  CartItem({
    required this.produceId,
    required this.produceName,
    required this.qty,
    required this.unit,
    required this.pricePerUnit,
    required this.farmer,
    this.imageUrl,
  });

  double get subtotal => qty * pricePerUnit;

  Map<String, dynamic> toJson() => {
        'produceId': produceId,
        'produceName': produceName,
        'qty': qty,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'farmer': farmer,
        'imageUrl': imageUrl,
      };
}
