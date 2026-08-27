import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.logout();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.email}'),
            const SizedBox(height: 16),
            const Text('(Logged in successfully!)'),
          ],
        ),
      ),
    );
  }
}