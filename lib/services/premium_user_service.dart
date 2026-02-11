import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paid_user_details.dart';

final supabase = Supabase.instance.client;

class PremiumUserService {
  /// Insert or update a premium user detail
  static Future<void> savePaidUserDetail(PaidUserDetail detail) async {
    await supabase.from('paid_user_details').insert(detail.toMap());
  }

  /// Optional: fetch detail for current user
  static Future<PaidUserDetail?> getPaidUserDetail(int userId) async {
    final data = await supabase
        .from('paid_user_details')
        .select()
        .eq('user_id', userId)
        .single();

    if (data != null) {
      return PaidUserDetail.fromMap(data);
    }
    return null;
  }
}
