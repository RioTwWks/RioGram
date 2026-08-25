import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/user/contact_manager.dart';
import '../../core/user/profile_manager.dart';
import '../../widgets/contact_list_tile.dart';
import '../../widgets/empty_state.dart';
import '../profile/user_profile_screen.dart';

/// Список контактов Telegram с поиском и импортом.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactManager>().loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importContacts(ContactManager manager) async {
    final result = await manager.importFromPhoneBook();
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (result != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано контактов: ${result.importedCount}',
          ),
        ),
      );
    } else if (manager.lastError != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(manager.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactManager>();
    final profile = context.watch<ProfileManager>();

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск контактов',
              prefixIcon: const Icon(Icons.search_outlined),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_outlined),
                      onPressed: () {
                        _searchController.clear();
                        contacts.setSearchQuery('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: contacts.setSearchQuery,
          ),
        ),
        if (contacts.lastError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              contacts.lastError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: _ContactsBody(
            contacts: contacts,
            profile: profile,
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [
          IconButton(
            tooltip: 'Импорт из адресной книги',
            onPressed: contacts.isImporting
                ? null
                : () => _importContacts(contacts),
            icon: contacts.isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.contact_phone_outlined),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ContactsBody extends StatelessWidget {
  const _ContactsBody({
    required this.contacts,
    required this.profile,
  });

  final ContactManager contacts;
  final ProfileManager profile;

  @override
  Widget build(BuildContext context) {
    if (contacts.isLoading || contacts.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final users = contacts.contacts;
    if (users.isEmpty) {
      return EmptyStateWidget(
        icon: contacts.searchQuery.isEmpty
            ? Icons.contacts_outlined
            : Icons.search_off_outlined,
        title: contacts.searchQuery.isEmpty
            ? 'Контактов пока нет'
            : 'Ничего не найдено',
        subtitle: contacts.searchQuery.isEmpty
            ? 'Добавьте контакты или импортируйте из адресной книги'
            : 'Попробуйте другой запрос',
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final displayUser = profile.userById(user.id) ?? user;
        return ContactListTile(
          user: displayUser,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UserProfileScreen(userId: user.id),
              ),
            );
          },
        );
      },
    );
  }
}
