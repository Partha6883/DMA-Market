// lib/screens/buyer_home.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/auth_service.dart';
import '../models/produce_model.dart';
import 'buyer_product_details.dart';
import '../widgets/app_topbar.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

const String backendUrl = "https://dma-backend.onrender.com";

class BuyerHome extends StatefulWidget {
  const BuyerHome({super.key});

  @override
  State<BuyerHome> createState() => _BuyerHomeState();
}

class _BuyerHomeState extends State<BuyerHome> {
  bool loading = true;
  List<ProduceItem> items = [];
  String query = "";
  bool grid = false;
  String sort = "latest";

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);
    try {
      final resp = await http.get(Uri.parse('$backendUrl/produce'));
      if (resp.statusCode == 200) {
        final Map body = json.decode(resp.body);
        final list = (body['data'] as List).map((e) => ProduceItem.fromJson(e)).toList();
        setState(() => items = list);
      } else {
        debugPrint('Fetch produce failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  num _numFromString(String v) {
    try {
      return num.parse(v);
    } catch (_) {
      return 0;
    }
  }

  int _ts(ProduceItem p) {
    try {
      final dyn = p as dynamic;
      if (dyn.createdAt != null) {
        final ca = dyn.createdAt;
        if (ca is DateTime) return ca.millisecondsSinceEpoch;
        if (ca is int) return ca;
        if (ca is String) {
          final parsed = DateTime.tryParse(ca);
          if (parsed != null) return parsed.millisecondsSinceEpoch;
          final asNum = int.tryParse(ca);
          if (asNum != null) return asNum;
        }
      }
    } catch (_) {}

    try {
      final map = p.toJson();
      if (map != null && map['createdAt'] != null) {
        final v = map['createdAt'];
        if (v is String) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null) return parsed.millisecondsSinceEpoch;
          final asNum = int.tryParse(v);
          if (asNum != null) return asNum;
        } else if (v is int) return v;
      }
    } catch (_) {}

    return 0;
  }

  List<ProduceItem> _filtered() {
    var filtered = items.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

    if (sort == 'price_asc') filtered.sort((a, b) => _numFromString(a.price).compareTo(_numFromString(b.price)));
    if (sort == 'price_desc') filtered.sort((a, b) => _numFromString(b.price).compareTo(_numFromString(a.price)));
    if (sort == 'latest') filtered.sort((a, b) => _ts(b).compareTo(_ts(a)));

    return filtered;
  }

  Future<void> _logoutAndBackToRole() async {
    await AuthService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered();
    final cartCount = context.select<CartProvider, int>((c) => c.itemCount);

    return Scaffold(
      appBar: AppTopBar(
        title: 'Buyer Home',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (Route<dynamic> route) => false);
          },
        ),
        actions: [
          IconButton(icon: Icon(grid ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => grid = !grid)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              tooltip: 'Cart',
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -8,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          cartCount.toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logoutAndBackToRole();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
              ? const Center(child: Text('No produce found'))
              : grid
                  ? GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.9),
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        final p = data[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BuyerProductDetails(product: p.toJson()))),
                          child: Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: p.imageUrl != null && p.imageUrl!.startsWith('http')
                                      ? Image.network(p.imageUrl!, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                      : const Icon(Icons.image_not_supported, size: 80),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('₹${p.price} • ${p.qty} ${p.unit}')),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        );
                      })
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        final p = data[i];
                        return Card(
                          child: ListTile(
                            leading: p.imageUrl != null && p.imageUrl!.startsWith('http')
                                ? Image.network(p.imageUrl!, width: 55, height: 55, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                                : const Icon(Icons.image_not_supported),
                            title: Text(p.name),
                            subtitle: Text('${p.qty} ${p.unit} • ₹${p.price}'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BuyerProductDetails(product: p.toJson()))),
                          ),
                        );
                      }),
    );
  }
}
