// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/user_model.dart';
import 'models/produce_provider.dart';

// Use the CartProvider that lives under lib/models (as you mentioned)
import '../providers/cart_provider.dart';
// ignore: unused_import
import '../models/cart_item.dart';

import 'screens/role_screen.dart';
import 'screens/farmer_dashboard.dart';
import 'screens/buyer_home.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/cart_screen.dart';
// ignore: unused_import
import 'screens/checkout_screen.dart';
// If you have a cart screen, import it and add the route below:
// import 'screens/cart_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => ProduceProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Small widget that checks user role and shows `child` only if user's role
/// matches one of allowedRoles. Otherwise it redirects to RoleScreen (/).
class AuthGuard extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;
  const AuthGuard({super.key, required this.child, required this.allowedRoles});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);
    // if not logged in — redirect to Role selection (or login)
    if (!user.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final r = (user.role ?? '').toLowerCase();
    final allowed = allowedRoles.map((e) => e.toLowerCase()).toList();

    if (!allowed.contains(r)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access denied for your role')));
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // allowed
    return child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMA Market App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),

      // initial route shows role selection (user can also login/register)
      initialRoute: '/',
      routes: {
        '/': (_) => const RoleScreen(),
        // Wrap FarmerDashboard so only 'farmer' role can access it
        '/farmer': (ctx) => const AuthGuard(
              allowedRoles: ['farmer'],
              child: FarmerDashboard(),
            ),
        // Wrap BuyerHome so only 'buyer' role can access it
        '/buyer': (ctx) => const AuthGuard(
              allowedRoles: ['buyer'],
              child: BuyerHome(),
            ),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/profile': (_) => const ProfileScreen(),
        // If you add a CartScreen file, uncomment and register it here:
        // '/cart': (_) => const CartScreen(),
        '/cart': (_) => const CartScreen(),
      },
    );
  }
}
