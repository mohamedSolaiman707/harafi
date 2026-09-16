import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/wallet_recharge.dart';

final walletRechargesStreamProvider = StreamProvider<List<WalletRecharge>>((ref) {
  return Supabase.instance.client
      .from('wallet_recharges')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data.map((json) => WalletRecharge.fromJson(json)).toList());
});

final techWalletRechargesStreamProvider = StreamProvider.family<List<WalletRecharge>, String>((ref, techId) {
  return Supabase.instance.client
      .from('wallet_recharges')
      .stream(primaryKey: ['id'])
      .eq('tech_id', techId)
      .order('created_at', ascending: false)
      .map((data) => data.map((json) => WalletRecharge.fromJson(json)).toList());
});
