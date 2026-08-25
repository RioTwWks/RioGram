import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../models/user_models.dart';
import '../tdlib/tdlib_client.dart';
import 'tdlib_user_parser.dart';

/// Список контактов, поиск и импорт из адресной книги.
class ContactManager extends ChangeNotifier {
  ContactManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _searchDebounce;

  final List<UserSummary> _contacts = [];
  final Map<int, UserSummary> _usersById = {};
  List<UserSummary> _filteredContacts = [];
  final Set<int> _pendingContactUserIds = {};
  final Set<int> _pendingSearchUserIds = {};

  var _isLoading = false;
  var _isSearching = false;
  var _isImporting = false;
  String _searchQuery = '';
  String? _lastError;
  ImportedContactsResult? _lastImportResult;

  List<UserSummary> get contacts =>
      _searchQuery.isEmpty ? _contacts : _filteredContacts;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  bool get isImporting => _isImporting;
  String get searchQuery => _searchQuery;
  String? get lastError => _lastError;
  ImportedContactsResult? get lastImportResult => _lastImportResult;

  UserSummary? userById(int userId) => _usersById[userId];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void loadContacts() {
    _isLoading = true;
    _lastError = null;
    _contacts.clear();
    _pendingContactUserIds.clear();
    notifyListeners();
    _client.send({
      '@type': 'getContacts',
      '@extra': 'contacts_load',
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _searchDebounce?.cancel();
    if (_searchQuery.isEmpty) {
      _filteredContacts = const [];
      notifyListeners();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _isSearching = true;
      _filteredContacts = const [];
      notifyListeners();
      _client.send({
        '@type': 'searchContacts',
        'query': _searchQuery,
        'limit': 50,
        '@extra': 'contacts_search',
      });
    });
  }

  void addContact(int userId, {String firstName = '', String lastName = ''}) {
    _client.send({
      '@type': 'addContact',
      'user_id': userId,
      'contact': {
        '@type': 'importedContact',
        'phone_number': '',
        'first_name': firstName,
        'last_name': lastName,
        'note': {
          '@type': 'formattedText',
          'text': '',
          'entities': [],
        },
      },
      'share_phone_number': false,
      '@extra': 'contacts_add_$userId',
    });
  }

  void removeContact(int userId) {
    _client.send({
      '@type': 'removeContacts',
      'user_ids': [userId],
      '@extra': 'contacts_remove_$userId',
    });
    _contacts.removeWhere((user) => user.id == userId);
    _filteredContacts.removeWhere((user) => user.id == userId);
    notifyListeners();
  }

  Future<ImportedContactsResult?> importFromPhoneBook() async {
    _isImporting = true;
    _lastError = null;
    notifyListeners();

    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        _lastError = 'Нет доступа к контактам устройства';
        return null;
      }

      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      final imported = <Map<String, dynamic>>[];
      for (final contact in deviceContacts) {
        if (contact.phones.isEmpty) {
          continue;
        }
        final phone = contact.phones.first.number.replaceAll(' ', '');
        imported.add({
          '@type': 'importedContact',
          'phone_number': phone,
          'first_name': contact.name.first,
          'last_name': contact.name.last,
          'note': {
            '@type': 'formattedText',
            'text': '',
            'entities': [],
          },
        });
        if (imported.length >= 500) {
          break;
        }
      }

      if (imported.isEmpty) {
        _lastError = 'В адресной книге нет телефонов';
        return null;
      }

      final completer = Completer<ImportedContactsResult?>();
      _pendingImportCompleter = completer;
      _client.send({
        '@type': 'importContacts',
        'contacts': imported,
        '@extra': 'contacts_import',
      });
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => null,
      );
    } catch (error) {
      _lastError = error.toString();
      return null;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Completer<ImportedContactsResult?>? _pendingImportCompleter;

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'users':
        _handleUsers(update);
      case 'user':
        _handleUser(update);
      case 'importedContacts':
        _handleImportedContacts(update);
      case 'ok':
        _handleOk(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handleUsers(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra != 'contacts_load' && extra != 'contacts_search') {
      return;
    }

    final inlineUsers = TdlibUserParser.parseUsersFromList(
      update['users'] as List<dynamic>?,
    );
    if (inlineUsers.isNotEmpty) {
      _mergeUsers(inlineUsers, extra, replace: extra == 'contacts_search');
      return;
    }

    final userIds = TdlibUserParser.parseUserIds(update);
    if (userIds.isEmpty) {
      if (extra == 'contacts_load') {
        _isLoading = false;
      } else {
        _isSearching = false;
      }
      notifyListeners();
      return;
    }

    if (extra == 'contacts_load') {
      _pendingContactUserIds
        ..clear()
        ..addAll(userIds);
    } else {
      _pendingSearchUserIds
        ..clear()
        ..addAll(userIds);
    }

    for (final id in userIds) {
      _client.send({
        '@type': 'getUser',
        'user_id': id,
        '@extra': extra == 'contacts_load'
            ? 'contacts_user_$id'
            : 'contacts_search_user_$id',
      });
    }
  }

  void _handleUser(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    final user = TdlibUserParser.parseUser(update);
    if (user == null || extra == null) {
      return;
    }

    if (extra.startsWith('contacts_user_')) {
      _usersById[user.id] = user;
      final index = _contacts.indexWhere((entry) => entry.id == user.id);
      if (index >= 0) {
        _contacts[index] = user;
      } else {
        _contacts.add(user);
      }
      _pendingContactUserIds.remove(user.id);
      if (_pendingContactUserIds.isEmpty) {
        _contacts.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ),
        );
        _isLoading = false;
      }
      notifyListeners();
    } else if (extra.startsWith('contacts_search_user_')) {
      _usersById[user.id] = user;
      if (!_filteredContacts.any((entry) => entry.id == user.id)) {
        _filteredContacts = [..._filteredContacts, user];
      }
      _pendingSearchUserIds.remove(user.id);
      if (_pendingSearchUserIds.isEmpty) {
        _filteredContacts.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              ),
        );
        _isSearching = false;
      }
      notifyListeners();
    }
  }

  void _mergeUsers(
    List<UserSummary> users,
    String? extra, {
    required bool replace,
  }) {
    for (final user in users) {
      _usersById[user.id] = user;
    }

    if (extra == 'contacts_load') {
      if (replace) {
        _contacts
          ..clear()
          ..addAll(users);
      } else {
        for (final user in users) {
          final index = _contacts.indexWhere((entry) => entry.id == user.id);
          if (index >= 0) {
            _contacts[index] = user;
          } else {
            _contacts.add(user);
          }
        }
      }
      _contacts.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
      );
      _isLoading = false;
    } else if (extra == 'contacts_search') {
      _filteredContacts = users;
      _isSearching = false;
    }
    notifyListeners();
  }

  void _handleImportedContacts(Map<String, dynamic> update) {
    if (update['@extra'] != 'contacts_import') {
      return;
    }
    _lastImportResult = TdlibUserParser.parseImportedContacts(update);
    _pendingImportCompleter?.complete(_lastImportResult);
    _pendingImportCompleter = null;
    loadContacts();
    notifyListeners();
  }

  void _handleOk(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == 'contacts_search') {
      _isSearching = false;
      notifyListeners();
    }
    if (extra?.startsWith('contacts_add_') == true ||
        extra?.startsWith('contacts_remove_') == true) {
      loadContacts();
    }
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null ||
        (!extra.startsWith('contacts_') && extra != 'contacts_import')) {
      return;
    }
    _lastError = update['message'] as String? ?? 'Ошибка контактов';
    _isLoading = false;
    _isSearching = false;
    _isImporting = false;
    _pendingContactUserIds.clear();
    _pendingImportCompleter?.complete(null);
    _pendingImportCompleter = null;
    notifyListeners();
  }
}
