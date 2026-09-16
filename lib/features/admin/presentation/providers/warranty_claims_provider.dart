import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/warranty_claim.dart';

final warrantyClaimsStreamProvider = StreamProvider<List<WarrantyClaim>>((ref) {
  return Supabase.instance.client
      .from('warranty_claims')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data.map((json) => WarrantyClaim.fromJson(json)).toList());
});
