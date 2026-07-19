// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.loadFromStorage();
    // short delay for UX
    await Future.delayed(const Duration(milliseconds: 350));
    if (userModel.isLoggedIn) {
      // route to appropriate screen based on role
      final r = userModel.role == 'farmer' ? '/farmer' : '/buyer';
      Navigator.pushReplacementNamed(context, r);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
