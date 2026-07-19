// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(radius: 36, child: Text((user.name ?? 'U').substring(0, 1).toUpperCase())),
            const SizedBox(height: 12),
            Text(user.name ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(user.phone ?? ''),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await user.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text('Logout'),
            )
          ],
        ),
      ),
    );
  }
}
