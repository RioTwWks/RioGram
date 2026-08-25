import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/telegram_theme.dart';
import '../../core/user/profile_manager.dart';
import '../../widgets/telegram_settings_tile.dart';

class OwnProfileScreen extends StatefulWidget {
  const OwnProfileScreen({super.key});

  @override
  State<OwnProfileScreen> createState() => _OwnProfileScreenState();
}

class _OwnProfileScreenState extends State<OwnProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<ProfileManager>();
      manager.loadOwnProfile();
      _syncFromManager(manager);
    });
  }

  void _syncFromManager(ProfileManager manager) {
    final draft = manager.ownProfile;
    final user = manager.ownUser;
    if (draft == null && user == null) return;
    _firstNameController.text = draft?.firstName ?? user?.firstName ?? '';
    _lastNameController.text = draft?.lastName ?? user?.lastName ?? '';
    _usernameController.text = draft?.username ?? user?.username ?? '';
    _bioController.text = draft?.bio ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ProfileManager manager) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    final path = result?.files.single.path;
    if (path != null) manager.setProfilePhoto(path);
  }

  void _save(ProfileManager manager) {
    manager
      ..setName(firstName: _firstNameController.text, lastName: _lastNameController.text)
      ..setBio(_bioController.text)
      ..setUsername(_usernameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProfileManager>();
    final user = manager.ownUser;
    final draft = manager.ownProfile;

    if ((draft != null || user != null) && _firstNameController.text.isEmpty && !manager.isLoadingOwn) {
      _syncFromManager(manager);
    }

    if (manager.isLoadingOwn && user == null) {
      return Scaffold(
        backgroundColor: telegramSettingsPageBackground(context),
        appBar: AppBar(title: const Text('Мой профиль')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = draft?.displayName ?? user?.displayName ?? '?';
    final username = draft?.username.isNotEmpty == true ? draft!.username : user?.username;

    return Scaffold(
      backgroundColor: telegramSettingsPageBackground(context),
      appBar: AppBar(
        title: const Text('Мой профиль'),
        actions: [
          if (manager.isSavingOwn)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(onPressed: () => _save(manager), child: const Text('Сохранить')),
        ],
      ),
      body: TelegramSettingsListView(
        children: [
          TelegramProfileHeader(displayName: displayName, username: username, avatarLocalPath: user?.avatarLocalPath),
          TelegramSettingsGroup(
            children: [
              TelegramSettingsTile(
                title: 'Сменить фото',
                showChevron: false,
                showDivider: false,
                onTap: manager.isSavingOwn ? null : () => _pickPhoto(manager),
                leading: Icon(Icons.photo_camera_outlined, color: context.telegramTheme.accent),
              ),
            ],
          ),
          const TelegramSettingsSectionHeader('Информация'),
          TelegramSettingsGroup(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Имя'))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Фамилия'))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixText: '@'))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'О себе'), maxLines: 4, maxLength: 70)),
            ],
          ),
          if (manager.lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(manager.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
