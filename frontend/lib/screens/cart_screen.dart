// lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, i) {
                      final it = items[i];
                      return ListTile(
                        leading: it.imageUrl != null && it.imageUrl!.startsWith('http')
                            ? Image.network(it.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                            : const Icon(Icons.image_not_supported),
                        title: Text(it.produceName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${it.farmer} • ₹${it.pricePerUnit.toStringAsFixed(2)}/${it.unit}'),
                            const SizedBox(height: 6),
                            Text('Subtotal: ₹${it.subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 130,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // decrement
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  final newQty = (it.qty - 0.5).clamp(0.0, 9999.0);
                                  context.read<CartProvider>().updateQty(it, newQty);
                                },
                              ),
                              // qty display + editable via dialog
                              GestureDetector(
                                onTap: () async {
                                  final txt = await showDialog<String>(
                                        context: context,
                                        builder: (_) {
                                          final ctrl = TextEditingController(text: it.qty.toString());
                                          return AlertDialog(
                                            title: const Text('Edit quantity'),
                                            content: TextField(
                                              controller: ctrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(hintText: 'Enter quantity (e.g. 1.5)'),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
                                            ],
                                          );
                                        },
                                      ) ??
                                      '';
                                  if (txt.isNotEmpty) {
                                    final parsed = double.tryParse(txt);
                                    if (parsed != null) {
                                      context.read<CartProvider>().updateQty(it, parsed);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid number')));
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.grey[200]),
                                  child: Text('${it.qty.toStringAsFixed(2)} ${it.unit}'),
                                ),
                              ),
                              // increment
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  final newQty = (it.qty + 0.5).clamp(0.0, 9999.0);
                                  context.read<CartProvider>().updateQty(it, newQty);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total: ₹${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // push checkout screen with current cart snapshot
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                        },
                        child: const Text('Proceed to Checkout'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          context.read<CartProvider>().clear();
                        },
                        child: const Text('Clear cart', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
