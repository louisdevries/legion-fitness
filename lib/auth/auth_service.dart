import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


final supabase = Supabase.instance.client;

class AuthService {
  static const String registerNeedsConfirmation = '__needs_email_confirmation__';
  /// Register new user using Supabase Auth
  static Future<String?> register(String name, String email, String password) async {
    try {
      // 1️⃣ Create the auth user.
      final signUpRes = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpRes.user == null) {
        return "Failed to create account";
      }

      // 2️⃣ Try to sign in immediately. With email confirmation enabled,
      // this will throw 'email_not_confirmed' — that's not a failure,
      // it just means the user needs to verify their email.
      try {
        final loginRes = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (loginRes.session == null) {
          // Sign-in didn't error but also didn't produce a session.
          // Probably email confirmation is required.
          return registerNeedsConfirmation;
        }
      } on AuthApiException catch (e) {
        if (e.code == 'email_not_confirmed') {
          // Account was created, but sign-in is gated on email
          // confirmation. The user can verify their email and log in
          // normally afterwards. We can't create their row in `users`
          // here because RLS needs an authenticated session — that'll
          // have to happen on first login instead.
          return registerNeedsConfirmation;
        }
        // Any other auth error is a real failure.
        return e.message;
      }

      // 3️⃣ We're authenticated → create the users row.
      final user = supabase.auth.currentUser;
      if (user != null) {
        // upsert so re-running this after a manual confirm doesn't
        // duplicate-key on the existing auth.uid().
        await supabase.from('users').upsert({
          'id': user.id,
          'email': email,
          'name': name,
          'username': email.split('@')[0],
          'is_paid_user': false,
          'is_admin': false,
        });
      }

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
    final prefs = await SharedPreferences.getInstance();
    // In-progress workout: never makes sense to keep across users.
    await prefs.remove('active_session');
    // Clean up legacy non-namespaced keys so guests don't inherit them.
    // (Safe to remove these lines after every user has logged in once.)
    await prefs.remove('active_program_id');
    await prefs.remove('active_week_number');
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

  /// Change password — re-authenticates with current password first
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user?.email == null) return 'Not logged in';

      // Verify current password by re-signing in
      final res = await supabase.auth.signInWithPassword(
        email: user!.email!,
        password: currentPassword,
      );
      if (res.session == null) return 'Current password is incorrect';

      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthApiException catch (e) {
      if (e.message.toLowerCase().contains('invalid')) {
        return 'Current password is incorrect';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Change email — sends a confirmation to the new address
  static Future<String?> changeEmail(String newEmail) async {
    try {
      await supabase.auth.updateUser(UserAttributes(email: newEmail));
      final user = currentUser;
      if (user != null) {
        await supabase
            .from('users')
            .update({'email': newEmail}).eq('id', user.id);
      }
      return null;
    } on AuthApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
