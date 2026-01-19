import 'package:flutter/material.dart';
import '../main.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isRegister = false; // toggle login/register

  void _submit() async {
    setState(() => isLoading = true);

    if (isRegister) {
      await AuthService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
      );
    } else {
      await AuthService.login(
        emailController.text.trim(),
        passwordController.text,
      );
    }

    setState(() => isLoading = false);

    if (!mounted) return;

    // Go to main app
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRegister ? 'Register' : 'Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRegister)
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            if (isRegister) const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text(isRegister ? 'Register' : 'Login'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => isRegister = !isRegister);
              },
              child: Text(
                isRegister
                    ? 'Already have an account? Login'
                    : 'Don’t have an account? Register',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
