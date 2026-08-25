import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account_models.dart';

/// Хранилище списка аккаунтов и активного аккаунта.
class AccountStore {
  AccountStore._();

  static const _accountsKey = 'riogram_accounts_v1';
  static const _activeAccountKey = 'riogram_active_account_id';
  static const _proxyPolicyKey = 'riogram_account_proxy_policy';

  static Future<List<AccountSession>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AccountSession.fromJson)
          .toList(growable: false);
    } catch (error) {
      debugPrint('AccountStore: parse error $error');
      return const [];
    }
  }

  static Future<String?> loadActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeAccountKey);
  }

  static Future<AccountProxyPolicy> loadProxyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_proxyPolicyKey);
    return AccountProxyPolicy.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AccountProxyPolicy.sharedEnv,
    );
  }

  static Future<void> saveAccounts(List<AccountSession> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(accounts.map((item) => item.toJson()).toList());
    await prefs.setString(_accountsKey, encoded);
  }

  static Future<void> saveActiveAccountId(String? accountId) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null || accountId.isEmpty) {
      await prefs.remove(_activeAccountKey);
      return;
    }
    await prefs.setString(_activeAccountKey, accountId);
  }

  static Future<void> saveProxyPolicy(AccountProxyPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyPolicyKey, policy.name);
  }
}
