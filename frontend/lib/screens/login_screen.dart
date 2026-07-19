// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    phoneCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // hide keyboard
    FocusScope.of(context).unfocus();

    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone & password required')));
      return;
    }

    setState(() => loading = true);

    // AuthService.login should return a Map (or null on network failure)
    final resp = await AuthService.login(phone, pass);

    setState(() => loading = false);

    if (resp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No response from server. Check network or server.')));
      return;
    }

    // successful login -> save to provider + navigate to correct dashboard
    if (resp['ok'] == true) {
      final user = resp['user'] as Map? ?? {};
      final token = resp['token']?.toString() ?? '';

      Provider.of<UserModel>(context, listen: false).setUser(
        user['name']?.toString() ?? '',
        user['phone']?.toString() ?? '',
        user['role']?.toString(),
        token,
      );

      final role = (user['role']?.toString() ?? '').toLowerCase();
      if (role == 'farmer') {
        // clear back stack and show farmer dashboard only
        Navigator.pushNamedAndRemoveUntil(context, '/farmer', (route) => false);
      } else {
        // default to buyer dashboard
        Navigator.pushNamedAndRemoveUntil(context, '/buyer', (route) => false);
      }
      return;
    }

    // show helpful error (include short raw preview if available)
    final err = resp['error']?.toString() ?? 'Login failed';
    final raw = resp['raw']?.toString();
    final message = (raw != null && raw.isNotEmpty) ? '$err\nServer: ${raw.length > 400 ? raw.substring(0, 400) : raw}' : err;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _login, child: const Text("Login")),
                  ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Create account')),
          ],
        ),
      ),
    );
  }
}
