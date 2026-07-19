// lib/screens/add_produce_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import '../models/produce_provider.dart';
import '../models/produce_model.dart';
import '../services/auth_service.dart';
import 'package:http_parser/http_parser.dart';

const String backendUrl = "https://dma-backend.onrender.com";

class AddProduceScreen extends StatefulWidget {
  const AddProduceScreen({super.key});

  @override
  State<AddProduceScreen> createState() => _AddProduceScreenState();
}

class _AddProduceScreenState extends State<AddProduceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String _unit = 'kg';
  String _quality = 'Good';
  File? _imageFile;
  String? _imageUrlFromServer;

  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        setState(() => _imageFile = File(result.files.single.path!));
      }
    } catch (e) {
      _show('File pick error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _imageFile = File(picked.path));
    } catch (e) {
      _show('Gallery pick error: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) setState(() => _imageFile = File(picked.path));
    } catch (e) {
      _show('Camera pick error: $e');
    }
  }

  Future<String?> _showUrlDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter image URL"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "https://example.com/photo.jpg"),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text("Download")),
        ],
      ),
    );
  }

  Future<void> _downloadFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        _show('Failed to download image (${resp.statusCode})');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filenameBase = p.basename(uri.path).trim();
      final filename = filenameBase.isEmpty ? 'img_${DateTime.now().millisecondsSinceEpoch}.jpg' : filenameBase;
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$filename');
      await file.writeAsBytes(resp.bodyBytes);
      setState(() => _imageFile = file);
    } catch (e) {
      _show('Download error: $e');
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _imagePreview() {
    if (_imageFile == null) {
      if (_imageUrlFromServer != null) {
        // show server image if available
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(_imageUrlFromServer!, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
            const SizedBox(height: 6),
            Text('Image from server', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        );
      }
      return const SizedBox(height: 140, child: Center(child: Text("No image selected")));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.file(_imageFile!, height: 140, fit: BoxFit.cover),
        const SizedBox(height: 6),
        Text('Selected: ${p.basename(_imageFile!.path)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Prepare multipart request
      final uri = Uri.parse('$backendUrl/produce');
      final req = http.MultipartRequest('POST', uri);

      // add auth header if available
      final authHeaders = await _authHeaders();
      req.headers.addAll(authHeaders);

      // add text fields
      req.fields['name'] = _nameCtrl.text.trim();
      req.fields['qty'] = _qtyCtrl.text.trim();
      req.fields['unit'] = _unit;
      req.fields['price'] = _priceCtrl.text.trim();
      req.fields['quality'] = _quality;
      req.fields['description'] = _descCtrl.text.trim();
      // farmer name can be set by backend using token; optional here
      // req.fields['farmer'] = 'unknown';

      // attach image file if present
      if (_imageFile != null && _imageFile!.existsSync()) {
        final mimeType = lookupMimeType(_imageFile!.path) ?? 'image/jpeg';
        final parts = mimeType.split('/');
        final stream = http.ByteStream(_imageFile!.openRead());
        final length = await _imageFile!.length();
        final multipartFile = http.MultipartFile('image', stream, length, filename: p.basename(_imageFile!.path), contentType: MediaType(parts[0], parts[1]));
        req.files.add(multipartFile);
      }

      // send
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body['ok'] == true && body['data'] != null) {
          final doc = body['data'];

          // create ProduceItem and add to provider
          final newItem = ProduceItem(
            name: doc['name']?.toString() ?? _nameCtrl.text.trim(),
            qty: doc['qty']?.toString() ?? _qtyCtrl.text.trim(),
            unit: doc['unit']?.toString() ?? _unit,
            price: doc['price']?.toString() ?? _priceCtrl.text.trim(),
            quality: doc['quality']?.toString() ?? _quality,
            description: doc['description']?.toString() ?? _descCtrl.text.trim(),
            imagePath: null,
            imageUrl: doc['imageUrl']?.toString(),
            id: doc['_id']?.toString(),
          );

          Provider.of<ProduceProvider>(context, listen: false).addItem(newItem);

          // store server image url for preview
          setState(() => _imageUrlFromServer = newItem.imageUrl);

          _show('Produce uploaded successfully');
          Navigator.pop(context, true);
          return;
        } else {
          _show('Server responded but did not return data: ${resp.body}');
        }
      } else {
        _show('Upload failed (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      _show('Upload error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Produce')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Produce Name"),
              validator: (v) => v == null || v.trim().isEmpty ? "Enter name" : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(labelText: "Quantity"),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.trim().isEmpty ? "Enter qty" : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  items: ["kg", "quintal", "tonne", "packet"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _unit = v ?? 'kg'),
                  decoration: const InputDecoration(labelText: "Unit"),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: "Price (₹)"),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.trim().isEmpty ? "Enter price" : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _quality,
              items: ["Good", "Average", "Low"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _quality = v ?? 'Good'),
              decoration: const InputDecoration(labelText: "Quality"),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
            const SizedBox(height: 20),
            Text("Image", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _imagePreview(),
            const SizedBox(height: 8),
            Wrap(spacing: 12, children: [
              ElevatedButton.icon(onPressed: _pickLocalFile, icon: const Icon(Icons.folder_open), label: const Text('Choose file')),
              ElevatedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library), label: const Text('Gallery')),
              ElevatedButton.icon(onPressed: _pickFromCamera, icon: const Icon(Icons.camera_alt), label: const Text('Camera')),
              ElevatedButton.icon(
                onPressed: () async {
                  final url = await _showUrlDialog();
                  if (url != null && url.isNotEmpty) await _downloadFromUrl(url);
                },
                icon: const Icon(Icons.link),
                label: const Text('From web'),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _onSubmit, child: const Text("Submit")),
            ),
          ]),
        ),
      ),
    );
  }
}

// Add this import for MediaType

