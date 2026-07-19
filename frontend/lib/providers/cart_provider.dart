// lib/providers/cart_provider.dart
import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  // Unmodifiable view for UI
  List<CartItem> get items => List.unmodifiable(_items);

  // number of distinct line items
  int get itemCount => _items.length;

  // total quantity across items (sum of qty)
  double get totalQty => _items.fold(0.0, (s, i) => s + i.qty);

  // total price
  double get total {
    double t = 0;
    for (final i in _items) {
      t += i.subtotal;
    }
    return t;
  }

  // Add item: if same produceId + farmer present, add qty, else push new
  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.produceId == item.produceId && i.farmer == item.farmer);
    if (idx >= 0) {
      _items[idx].qty = (_items[idx].qty + item.qty);
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  // update quantity for an item (by produceId+farmer)
  void updateQty(CartItem item, double newQty) {
    final idx = _items.indexWhere((i) => i.produceId == item.produceId && i.farmer == item.farmer);
    if (idx >= 0) {
      if (newQty <= 0.0) {
        _items.removeAt(idx);
      } else {
        _items[idx].qty = newQty;
      }
      notifyListeners();
    }
  }

  // remove a specific item
  void removeItem(CartItem item) {
    _items.removeWhere((i) => i.produceId == item.produceId && i.farmer == item.farmer);
    notifyListeners();
  }

  // remove at index
  void removeAt(int idx) {
    if (idx >= 0 && idx < _items.length) {
      _items.removeAt(idx);
      notifyListeners();
    }
  }

  // clear cart
  void clear() {
    _items.clear();
    notifyListeners();
  }

  // prepare payload suitable for server /checkout
  List<Map<String, dynamic>> toOrderItems() => _items.map((i) => {
        'produceId': i.produceId,
        'produceName': i.produceName,
        'qty': i.qty,
        'unit': i.unit,
        'pricePerUnit': i.pricePerUnit,
        'farmer': i.farmer,
        'imageUrl': i.imageUrl ?? '',
      }).toList();
}
