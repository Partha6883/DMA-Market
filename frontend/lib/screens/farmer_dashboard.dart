// lib/screens/farmer_dashboard.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/produce_provider.dart';
import '../models/produce_model.dart';
import 'add_produce_screen.dart';
import 'farmer_offers.dart';
import '../widgets/app_topbar.dart';

const String backendUrl = "https://dma-backend.onrender.com";

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndSync();
  }

  Future<void> _fetchAndSync() async {
    setState(() => loading = true);
    try {
      final resp = await http.get(Uri.parse('$backendUrl/produce'));
      if (resp.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(resp.body);
        final List data = body['data'] as List;
        final list = data
            .map((e) => ProduceItem.fromJson(e as Map<String, dynamic>))
            .toList();

        Provider.of<ProduceProvider>(context, listen: false)
            .setItemsFromServer(list);
      } else {
        debugPrint(
            'Fetch produce failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Fetch produce error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildImage(ProduceItem p) {
    try {
      if (p.imageUrl != null && p.imageUrl!.startsWith('http')) {
        return Image.network(
          p.imageUrl!,
          width: 55,
          height: 55,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 40),
        );
      }
      if (p.imagePath != null && p.imagePath!.isNotEmpty) {
        final file = File(p.imagePath!);
        if (file.existsSync()) {
          return Image.file(file,
              width: 55, height: 55, fit: BoxFit.cover);
        }
      }
    } catch (_) {}
    return const Icon(Icons.image_not_supported, size: 40);
  }

  Future<void> _confirmDelete(
      BuildContext context, ProduceItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to delete this item permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      await _deleteFromBackend(context, item);
    }
  }

  Future<void> _deleteFromBackend(
      BuildContext context, ProduceItem item) async {
    try {
      final id = item.id ?? '';
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Item ID missing. Please refresh list.')));
        return;
      }

      final resp =
          await http.delete(Uri.parse('$backendUrl/produce/$id'));

      if (resp.statusCode == 200) {
        Provider.of<ProduceProvider>(context, listen: false)
            .removeItem(item);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted successfully')));
      } else {
        String msg = resp.body;
        try {
          final m = json.decode(resp.body);
          if (m['error'] != null) msg = m['error'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $msg')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e')));
    } finally {
      await _fetchAndSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final produceList = context.watch<ProduceProvider>().items;
    final farmerName = produceList.isNotEmpty
        ? (produceList.first.farmer ?? 'unknown')
        : 'unknown';

    return Scaffold(
      appBar: AppTopBar(
        title: "Farmer Dashboard",
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Offers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FarmerOffers(farmerName: farmerName),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAndSync,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddProduceScreen(),
            ),
          );
          if (res == true) await _fetchAndSync();
        },
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: produceList.isEmpty
                  ? const Center(child: Text("No produce added yet"))
                  : ListView.builder(
                      itemCount: produceList.length,
                      itemBuilder: (context, index) {
                        final p = produceList[index];
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _buildImage(p),
                            ),
                            title: Text(p.name),
                            subtitle:
                                Text("${p.qty} ${p.unit} • ₹${p.price}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  _confirmDelete(context, p),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                      content: Text('Tapped ${p.name}')));
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
