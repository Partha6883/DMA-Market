// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/auth_service.dart';

const String backendUrl = "https://dma-backend.onrender.com"; // keep in sync with server

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool loading = false;
  String buyerPhone = '';
  String resultMessage = '';

  Future<void> _doCheckout() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    setState(() {
      loading = true;
      resultMessage = '';
    });

    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

      final body = json.encode({
        'buyerPhone': buyerPhone,
        'items': cart.toOrderItems(),
      });

      final resp = await http.post(Uri.parse('$backendUrl/checkout'), headers: headers, body: body).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final m = json.decode(resp.body) as Map<String, dynamic>;
        if (m['ok'] == true && m['data'] != null) {
          // Success. You may want to clear cart now
          cart.clear();
          setState(() {
            resultMessage = 'Order created (id: ${m['data']['_id'] ?? m['data']['id'] ?? 'unknown'})';
          });
        } else {
          setState(() {
            resultMessage = 'Checkout failed: ${m['error'] ?? resp.body}';
          });
        }
      } else if (resp.statusCode == 401) {
        setState(() => resultMessage = 'Unauthorized. Please login as buyer.');
      } else {
        setState(() => resultMessage = 'Server error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      setState(() => resultMessage = 'Checkout error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (c, i) {
                  final it = cart.items[i];
                  return ListTile(
                    leading: it.imageUrl != null && it.imageUrl!.startsWith('http')
                        ? Image.network(it.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                        : const Icon(Icons.image_not_supported),
                    title: Text(it.produceName),
                    subtitle: Text('${it.qty.toStringAsFixed(2)} ${it.unit} × ₹${it.pricePerUnit.toStringAsFixed(2)}'),
                    trailing: Text('₹${it.subtotal.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text('Total: ₹${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Phone (for order/contact)', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              onChanged: (v) => buyerPhone = v.trim(),
            ),
            const SizedBox(height: 12),
            loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _doCheckout, child: const Text('Pay / Create Order')),
            if (resultMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(resultMessage, style: const TextStyle(color: Colors.green)),
            ]
          ],
        ),
      ),
    );
  }
}
