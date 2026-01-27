import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AuthService {
  /// Register new user using Supabase Auth
  static Future<String?> register(String name, String email, String password) async {
    try {
      // 1️⃣ Create auth user
      final signUpRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpRes.user == null) {
        return "Failed to create account";
      }

      // 2️⃣ IMPORTANT: Sign in immediately to get a session
      final loginRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (loginRes.session == null) {
        return "Account created but login failed";
      }

      final user = loginRes.user!;

      // 3️⃣ Now we ARE authenticated → RLS allows insert
      await supabase.from('users').insert({
        'id': user.id,
        'email': email,
        'name': name,
        'username': email.split('@')[0],
        'is_paid_user': false,
        'is_admin': false,
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }


  /// Login using Supabase Auth
  static Future<String?> login(String email, String password) async {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session == null) return "Invalid email or password";

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Logout
  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  /// Current logged-in user
  static User? get currentUser => supabase.auth.currentUser;

  /// Get user name from 'users' table
  static Future<String?> getUserName() async {
    final user = currentUser;
    if (user == null) return null;

    final res = await supabase
        .from('users')
        .select('name')
        .eq('id', user.id)
        .maybeSingle();

    return res?['name'] as String?;
  }

  /// Get user email
  static String? getUserEmail() {
    final user = currentUser;
    return user?.email;
  }
}
