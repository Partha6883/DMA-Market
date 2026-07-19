// lib/screens/farmer_offers.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';

const String backendUrl = "http://10.89.104.115:3000";

class FarmerOffers extends StatefulWidget {
  final String farmerName;
  const FarmerOffers({super.key, required this.farmerName});

  @override
  State<FarmerOffers> createState() => _FarmerOffersState();
}

class _FarmerOffersState extends State<FarmerOffers> {
  bool loading = true;
  List offers = [];
  String error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$backendUrl/offers?farmer=${Uri.encodeComponent(widget.farmerName)}');
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final m = json.decode(resp.body);
        setState(() => offers = (m['data'] as List?) ?? []);
      } else if (resp.statusCode == 401) {
        setState(() => error = 'Not authenticated. Please login as farmer.');
      } else {
        setState(() => error = 'Load failed: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => error = 'Load error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    // confirm UI feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('$backendUrl/offers/$id');
      final resp = await http
          .put(uri, headers: headers, body: json.encode({'status': status}))
          .timeout(const Duration(seconds: 12));

      Navigator.pop(context); // remove progress dialog

      if (resp.statusCode == 200) {
        // a successful update — refresh list
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer updated')));
        await _load();
        return;
      }

      // handle common failure modes
      if (resp.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login again (auth)')));
        return;
      }
      if (resp.statusCode == 403) {
        // parse body for clearer error
        String msg = 'Forbidden';
        try {
          final parsed = json.decode(resp.body);
          msg = (parsed['error'] ?? parsed['message'] ?? resp.body).toString();
        } catch (_) {
          msg = resp.body;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $msg')));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${resp.statusCode}')));
    } catch (e) {
      Navigator.pop(context); // safety: close progress if still shown
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
    }
  }

  Widget _buildOfferTile(Map o) {
    final status = o['status']?.toString() ?? 'pending';
    final id = o['_id']?.toString() ?? o['id']?.toString() ?? '';
    final buyer = (o['buyerName'] ?? o['buyerPhone'] ?? 'Buyer').toString();
    final produceName = (o['produceName'] ?? 'Produce').toString();

    return Card(
      child: ListTile(
        title: Text('$produceName — ₹${o['offerPrice'] ?? ''}'),
        subtitle: Text('From: $buyer\n${o['message'] ?? ''}\nStatus: $status'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (status == 'pending')
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                if (id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer id missing')));
                  return;
                }
                await _updateStatus(id, 'accepted');
              },
            ),
          if (status == 'pending')
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                if (id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer id missing')));
                  return;
                }
                await _updateStatus(id, 'rejected');
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offers for ${widget.farmerName}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error.isNotEmpty
              ? Center(child: Text(error))
              : offers.isEmpty
                  ? const Center(child: Text('No offers yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: offers.length,
                        itemBuilder: (context, i) {
                          final o = offers[i] as Map;
                          return _buildOfferTile(o);
                        },
                      ),
                    )),
    );
  }
}
