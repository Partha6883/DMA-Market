// lib/screens/buyer_product_details.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';

const String backendUrl = "https://dma-backend.onrender.com";

class BuyerProductDetails extends StatelessWidget {
  final Map<String, dynamic> product;

  const BuyerProductDetails({super.key, required this.product});

  Future<Map<String, String>> _authHeaders() async {
    return await AuthService.authHeaders();
  }

  Future<Map<String, dynamic>> _fetchComparisons(String produceName) async {
    final uri = Uri.parse('$backendUrl/compare-prices?produce=${Uri.encodeComponent(produceName)}');
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode == 200) {
      final m = json.decode(resp.body) as Map<String, dynamic>;
      if (m['ok'] == true) return m;
      throw Exception(m['error'] ?? 'Unexpected response');
    } else {
      throw Exception('Server ${resp.statusCode}: ${resp.body}');
    }
  }

  void _showOfferDialog(BuildContext context) {
    final buyerNameCtrl = TextEditingController();
    final buyerPhoneCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Offer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: buyerNameCtrl, decoration: const InputDecoration(labelText: 'Your Name')),
              TextField(controller: buyerPhoneCtrl, decoration: const InputDecoration(labelText: 'Your Phone'), keyboardType: TextInputType.phone),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Offer Price (₹)'), keyboardType: TextInputType.number),
              TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Message (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final buyerName = buyerNameCtrl.text.trim();
              final buyerPhone = buyerPhoneCtrl.text.trim();
              final offered = priceCtrl.text.trim();
              final message = msgCtrl.text.trim();

              if (buyerName.isEmpty || buyerPhone.isEmpty || offered.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, phone & price are required')));
                return;
              }

              final offerPriceNum = num.tryParse(offered);
              if (offerPriceNum == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid price')));
                return;
              }

              Navigator.pop(context);

              final headers = await _authHeaders();
              final produceId = product['_id']?.toString() ?? product['id']?.toString() ?? '';
              final produceName = product['name']?.toString() ?? '';

              if (produceId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product id missing. Refresh list.')));
                return;
              }

              final body = json.encode({
                "produceId": produceId,
                "produceName": produceName,
                "farmer": product['farmer']?.toString() ?? '',
                "buyerName": buyerName,
                "buyerPhone": buyerPhone,
                "offerPrice": offerPriceNum,
                "message": message,
              });

              try {
                final resp = await http.post(Uri.parse('$backendUrl/offers'), headers: {...headers, 'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 12));
                if (resp.statusCode == 200) {
                  final m = jsonDecode(resp.body);
                  if (m['ok'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent')));
                  } else {
                    final err = (m['error'] ?? m['message'] ?? resp.body).toString();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $err')));
                  }
                } else if (resp.statusCode == 401) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must login as buyer to send offers')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: ${resp.statusCode}')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send error: $e')));
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(BuildContext context) {
    final produceName = product['name']?.toString() ?? '';
    if (produceName.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchComparisons(produceName),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Price comparison unavailable: ${snap.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        final data = snap.data!;
        final List list = (data['data'] as List).cast();
        final num? localPrice = (product['price'] is num) ? product['price'] as num : num.tryParse(product['price']?.toString() ?? '');
        list.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const Text('State-wise Prices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Min: ₹${data['min']}  •  Max: ₹${data['max']}  •  Avg: ₹${data['avg']}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final row = list[i] as Map;
                  final price = (row['price'] as num).toDouble();
                  final state = row['state'] ?? 'Unknown';
                  String diffText = '';
                  if (localPrice != null) {
                    final diff = ((price - localPrice) / (localPrice == 0 ? 1 : localPrice)) * 100;
                    final sign = diff >= 0 ? '+' : '';
                    diffText = '$sign${diff.toStringAsFixed(1)}%';
                  }

                  final bool isMin = price == (data['min'] as num);
                  final bool isMax = price == (data['max'] as num);

                  return ListTile(
                    dense: true,
                    title: Text(state.toString()),
                    subtitle: diffText.isNotEmpty ? Text('Diff vs selected: $diffText') : null,
                    trailing: SizedBox(
                      width: 160,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              if (isMin) const Text('Lowest', style: TextStyle(fontSize: 11, color: Colors.green)),
                              if (isMax) const Text('Highest', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                            tooltip: 'Add ${product['name'] ?? ''} from $state at ₹${price.toStringAsFixed(2)}/kg to cart',
                            onPressed: () {
                              final cid = product['_id']?.toString() ?? product['id']?.toString() ?? '';
                              final pname = product['name']?.toString() ?? '';
                              if (cid.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product ID missing. Refresh list.')));
                                return;
                              }
                              final cart = Provider.of<CartProvider>(context, listen: false);
                              cart.addItem(CartItem(
                                produceId: cid,
                                produceName: pname,
                                farmer: state.toString(),
                                unit: 'kg',
                                pricePerUnit: price,
                                qty: 1.0,
                                imageUrl: product['imageUrl']?.toString(),
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $pname from $state at ₹${price.toStringAsFixed(2)}/kg to cart')));
                            },
                          ),
                        ],
                      ),
                    ),
                    leading: SizedBox(
                      width: 24,
                      height: 24,
                      child: isMin
                          ? const Icon(Icons.arrow_downward, color: Colors.green, size: 18)
                          : (isMax ? const Icon(Icons.arrow_upward, color: Colors.red, size: 18) : const Icon(Icons.circle, size: 10, color: Colors.grey)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Produce';
    final price = product['price']?.toString() ?? '0';
    final qty = product['qty']?.toString() ?? '0';
    final unit = product['unit']?.toString() ?? 'kg';
    final quality = product['quality']?.toString() ?? 'Good';
    final desc = product['description']?.toString() ?? '';
    final imageUrl = product['imageUrl']?.toString();

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (imageUrl != null && imageUrl.startsWith('http'))
              Image.network(imageUrl, height: 250, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 100))
            else
              const SizedBox(height: 250, child: Center(child: Icon(Icons.image_not_supported, size: 100))),
            const SizedBox(height: 20),

            Text("Name: $name", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Price: ₹$price", style: const TextStyle(fontSize: 18)),
            Text("Quantity: $qty $unit", style: const TextStyle(fontSize: 18)),
            Text("Quality: $quality", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text("Description:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(desc, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),

            _buildComparisonSection(context),

            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: () => _showOfferDialog(context), icon: const Icon(Icons.send), label: const Text('Send Offer to Farmer')),
          ],
        ),
      ),
    );
  }
}
