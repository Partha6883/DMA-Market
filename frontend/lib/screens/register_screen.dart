// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'buyer';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text;

    if (name.isEmpty || phone.isEmpty || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name, phone and password (min 6 chars)')),
      );
      return;
    }

    setState(() => _loading = true);

    // Correct call: use named parameters matching AuthService.register
    final resp = await AuthService.register(
      name: name,
      phone: phone,
      password: pass,
      role: _role,
    );

    setState(() => _loading = false);

    if (resp['ok'] == true) {
      // save into provider
      final userMap = resp['user'] as Map?;
      Provider.of<UserModel>(context, listen: false).setUser(
        userMap?['name']?.toString() ?? name,
        userMap?['phone']?.toString() ?? phone,
        userMap?['role']?.toString(),
        resp['token']?.toString() ?? '',
      );

      // navigate to root (role screen). Use '/' to match main.dart routes.
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else {
      final msg = resp['error']?.toString() ?? 'Register failed';
      final raw = resp['raw']?.toString();
      final message = raw != null && raw.isNotEmpty
          ? '$msg\nServer: ${raw.substring(0, raw.length > 300 ? 300 : raw.length)}'
          : msg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Role:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'farmer', child: Text('Farmer')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'buyer'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _register, child: const Text('Register')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
