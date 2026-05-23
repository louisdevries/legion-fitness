import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final bool showSkip;
  const LoginScreen({super.key, this.showSkip = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(isGuest: true)),
    );
  }

  Future<void> _submit() async {
    if (!isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      setState(() => errorMessage = 'Passwords do not match');
      return;
    }

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

    setState(() => isLoading = false);

    if (error == null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    if (error == AuthService.registerNeedsConfirmation) {
      setState(() {
        isLogin = true;
        errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created! Check your email to confirm, then sign in.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => errorMessage = error);
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = null;
      _passwordVisible = false;
      _confirmPasswordVisible = false;
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Create Account'),
        automaticallyImplyLeading: !widget.showSkip,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Image.asset('assets/images/logo.png', height: 260),
            const SizedBox(height: 32),
            if (!isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: isLogin
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: isLogin ? (_) => _submit() : null,
            ),
            if (!isLogin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(() =>
                        _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                ),
                obscureText: !_confirmPasswordVisible,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
            const SizedBox(height: 24),
            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(isLogin ? 'Login' : 'Register'),
                    ),
            ),
            TextButton(
              onPressed: _toggleMode,
              child: Text(
                isLogin
                    ? "Don't have an account? Register"
                    : 'Already have an account? Login',
              ),
            ),
            if (widget.showSkip) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _skip,
                child: const Text('Skip for now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
