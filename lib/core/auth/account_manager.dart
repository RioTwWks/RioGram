import 'package:flutter/foundation.dart';

import '../../models/account_models.dart';
import 'account_store.dart';

/// Переключение аккаунтов и политика прокси.
class AccountManager extends ChangeNotifier {
  AccountManager({this.onAccountChanged});

  final VoidCallback? onAccountChanged;

  List<AccountSession> _accounts = const [];
  String? _activeAccountId;
  AccountProxyPolicy _proxyPolicy = AccountProxyPolicy.sharedEnv;
  var _isLoaded = false;

  List<AccountSession> get accounts => List.unmodifiable(_accounts);
  String? get activeAccountId => _activeAccountId;
  AccountProxyPolicy get proxyPolicy => _proxyPolicy;
  bool get isLoaded => _isLoaded;
  bool get hasMultipleAccounts => _accounts.length > 1;

  AccountSession? get activeAccount {
    if (_activeAccountId == null) {
      return _accounts.isNotEmpty ? _accounts.first : null;
    }
    for (final account in _accounts) {
      if (account.id == _activeAccountId) {
        return account;
      }
    }
    return null;
  }

  Future<void> load() async {
    _accounts = await AccountStore.loadAccounts();
    _activeAccountId = await AccountStore.loadActiveAccountId();
    _proxyPolicy = await AccountStore.loadProxyPolicy();
    if (_activeAccountId == null && _accounts.isNotEmpty) {
      _activeAccountId = _accounts.first.id;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> upsertCurrentAccount({
    required int userId,
    String phoneNumber = '',
    String displayName = '',
  }) async {
    final id = '$userId';
    final now = DateTime.now();
    final existingIndex = _accounts.indexWhere((item) => item.id == id);
    final updated = AccountSession(
      id: id,
      userId: userId,
      phoneNumber: phoneNumber.isNotEmpty
          ? phoneNumber
          : existingIndex >= 0
              ? _accounts[existingIndex].phoneNumber
              : '',
      displayName: displayName.isNotEmpty
          ? displayName
          : existingIndex >= 0
              ? _accounts[existingIndex].displayName
              : '',
      lastActiveAt: now,
    );

    if (existingIndex >= 0) {
      _accounts = [
        ..._accounts.sublist(0, existingIndex),
        updated,
        ..._accounts.sublist(existingIndex + 1),
      ];
    } else {
      _accounts = [..._accounts, updated];
    }

    _activeAccountId = id;
    await AccountStore.saveAccounts(_accounts);
    await AccountStore.saveActiveAccountId(id);
    notifyListeners();
  }

  Future<void> switchAccount(String accountId) async {
    if (_activeAccountId == accountId) {
      return;
    }
    if (!_accounts.any((item) => item.id == accountId)) {
      return;
    }
    _activeAccountId = accountId;
    await AccountStore.saveActiveAccountId(accountId);
    notifyListeners();
    onAccountChanged?.call();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts = _accounts.where((item) => item.id != accountId).toList();
    if (_activeAccountId == accountId) {
      _activeAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    }
    await AccountStore.saveAccounts(_accounts);
    await AccountStore.saveActiveAccountId(_activeAccountId);
    notifyListeners();
    if (_activeAccountId != accountId) {
      onAccountChanged?.call();
    }
  }

  Future<void> setProxyPolicy(AccountProxyPolicy policy) async {
    _proxyPolicy = policy;
    await AccountStore.saveProxyPolicy(policy);
    notifyListeners();
  }

  String directorySuffixFor(String? accountId) {
    if (accountId == null || accountId.isEmpty) {
      return '';
    }
    return accountId;
  }
}
