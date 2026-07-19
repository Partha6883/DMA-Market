// lib/models/produce_provider.dart
import 'package:flutter/material.dart';
import 'produce_model.dart';

class ProduceProvider extends ChangeNotifier {
  final List<ProduceItem> _items = [];

  List<ProduceItem> get items => List.unmodifiable(_items);

  void addItem(ProduceItem item) {
    // avoid duplicates by id (if id exists)
    if (item.id != null && item.id!.isNotEmpty) {
      final existing = _items.indexWhere((e) => e.id == item.id);
      if (existing != -1) {
        _items[existing] = item;
        notifyListeners();
        return;
      }
    }
    _items.add(item);
    notifyListeners();
  }

  /// Remove item. Works with id or exact object match.
  void removeItem(ProduceItem item) {
    if (item.id != null && item.id!.isNotEmpty) {
      _items.removeWhere((e) => e.id == item.id);
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  /// Replace current list with server-provided list.
  /// Use this when you fetched fresh list from backend.
  void setItemsFromServer(List<ProduceItem> list) {
    _items
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// Clear provider (useful on logout)
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
