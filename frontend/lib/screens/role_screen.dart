// lib/screens/role_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../widgets/app_topbar.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  void _goTo(BuildContext context, String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _handleRoleTap(BuildContext context, String targetRole) async {
    final user = Provider.of<UserModel>(context, listen: false);

    // Logged in
    if (user.isLoggedIn) {
      // Same role -> go directly
      if ((user.role ?? '') == targetRole) {
        _goTo(context, targetRole == 'farmer' ? '/farmer' : '/buyer');
        return;
      }

      // Different role -> ask to switch role locally
      final accept = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Switch role?'),
          content: Text(
              'You are currently "${user.role ?? 'unknown'}". Switch to "$targetRole"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Switch')),
          ],
        ),
      );

      if (accept == true) {
        user.setRole(targetRole);
        _goTo(context, targetRole == 'farmer' ? '/farmer' : '/buyer');
      }
      return;
    }

    // Not logged in -> go to login
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel>();

    return Scaffold(
      appBar: const AppTopBar(title: 'Choose Role'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Who are you?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            RoleCard(
              title: 'Farmer',
              subtitle: 'List produce, manage inventory',
              badge: (user.role == 'farmer') ? 'Signed in' : null,
              onTap: () => _handleRoleTap(context, 'farmer'),
            ),

            const SizedBox(height: 16),

            RoleCard(
              title: 'Buyer / Retailer',
              subtitle: 'Browse produce & place orders',
              badge: (user.role == 'buyer') ? 'Signed in' : null,
              onTap: () => _handleRoleTap(context, 'buyer'),
            ),

            const Spacer(),

            if (user.isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Text(
                      'Signed in as: ${user.name ?? user.phone ?? "Unknown"}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Role: ${user.role ?? "not set"}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Login or register using the top-right icon to access full features.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  const RoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.green),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
