import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userName;
  String? userEmail;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final token = await AuthService.getToken(); // checks if logged in
    final name = await AuthService.getUserName();
    final email = await AuthService.getUserEmail();

    if (!mounted) return;
    setState(() {
      isLoggedIn = token != null;
      userName = name;
      userEmail = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoggedIn
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hello, $userName!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            userEmail ?? '',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await AuthService.logout();
              setState(() {
                isLoggedIn = false;
                userName = null;
                userEmail = null;
              });
            },
            child: const Text('Logout'),
          ),
        ],
      )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'You are not logged in.',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ).then((_) {
                // Reload profile after returning from login
                _loadUser();
              });
            },
            child: const Text('Login or Register'),
          ),
        ],
      ),
    );
  }
}
