import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    String? error;

    if (isLogin) {
      error = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      error = await AuthService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
      errorMessage = error;
    });

    if (error == null) {
      // ✅ DO NOTHING — AuthGate will rebuild automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Login" : "Create Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!isLogin)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 10),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? "Login" : "Register"),
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                  errorMessage = null;
                });
              },
              child: Text(
                isLogin
                    ? "Don't have an account? Register"
                    : "Already have an account? Login",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
