import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/user/profile_manager.dart';
import '../../widgets/chat_avatar.dart';

/// Редактирование собственного профиля.
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
    if (draft == null && user == null) {
      return;
    }
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null) {
      manager.setProfilePhoto(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProfileManager>();
    final user = manager.ownUser;
    final draft = manager.ownProfile;

    if ((draft != null || user != null) &&
        _firstNameController.text.isEmpty &&
        !manager.isLoadingOwn) {
      _syncFromManager(manager);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой профиль'),
        actions: [
          if (manager.isSavingOwn)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () {
                manager
                  ..setName(
                    firstName: _firstNameController.text,
                    lastName: _lastNameController.text,
                  )
                  ..setBio(_bioController.text)
                  ..setUsername(_usernameController.text);
              },
              child: const Text('Сохранить'),
            ),
        ],
      ),
      body: manager.isLoadingOwn && user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      ChatAvatar(
                        title: draft?.displayName ?? user?.displayName ?? '?',
                        localPath: user?.avatarLocalPath,
                        radius: 48,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: manager.isSavingOwn
                            ? null
                            : () => _pickPhoto(manager),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Сменить фото'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Фамилия',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'О себе',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 70,
                ),
                if (manager.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    manager.lastError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
