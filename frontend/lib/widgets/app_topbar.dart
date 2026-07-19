// lib/widgets/app_topbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel>();

    return AppBar(
      leading: leading,
      title: Text(title),
      actions: [
        if (actions != null) ...actions!,

        // Profile/Login icon
        IconButton(
          tooltip: user.isLoggedIn ? 'Profile' : 'Login',
          icon: CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            child: user.isLoggedIn
                ? Text(
                    (user.name?.isNotEmpty == true
                            ? user.name![0].toUpperCase()
                            : '?'),
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  )
                : const Icon(Icons.person_outline, size: 18, color: Colors.white),
          ),
          onPressed: () {
            if (user.isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}
