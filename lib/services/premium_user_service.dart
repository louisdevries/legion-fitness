import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paid_user_details.dart';
import 'dart:developer' as developer;

final supabase = Supabase.instance.client;

class PremiumUserService {
  /// Insert or update a premium user detail
  static Future<void> savePaidUserDetail(PaidUserDetail detail) async {
    try {
      await supabase.from('paid_user_details').insert(detail.toMap());
    } catch (e) {
      developer.log("Error saving premium user detail", error: e);
      rethrow;
    }
  }

  /// Optional: fetch detail for current user
  static Future<PaidUserDetail?> getPaidUserDetail(String userId) async {
    try {
      final data = await supabase
          .from('paid_user_details')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        return PaidUserDetail.fromMap(data);
      }
    } catch (e) {
      developer.log("Error fetching premium user detail", error: e);
    }
    return null;
  }
}
