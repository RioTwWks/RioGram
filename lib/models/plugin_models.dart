/// Возможности, которые плагин может объявить.
enum PluginCapability {
  messageDisplayTransform,
  outgoingMessageTransform,
}

/// Манифест плагина (совместим с JSON-манифестом community-плагинов).
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    this.capabilities = const [],
    this.homepage,
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final List<PluginCapability> capabilities;
  final String? homepage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'author': author,
        'capabilities': capabilities.map((c) => c.name).toList(),
        if (homepage != null) 'homepage': homepage,
      };

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'] as List<dynamic>? ?? [];
    return PluginManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      homepage: json['homepage'] as String?,
      capabilities: rawCapabilities
          .whereType<String>()
          .map(_capabilityFromName)
          .whereType<PluginCapability>()
          .toList(),
    );
  }

  static PluginCapability? _capabilityFromName(String name) {
    return switch (name) {
      'messageDisplayTransform' => PluginCapability.messageDisplayTransform,
      'outgoingMessageTransform' => PluginCapability.outgoingMessageTransform,
      _ => null,
    };
  }
}

/// Контекст сообщения для хуков плагинов.
class PluginMessageContext {
  const PluginMessageContext({
    required this.chatId,
    required this.messageId,
    required this.isOutgoing,
  });

  final int chatId;
  final int messageId;
  final bool isOutgoing;
}

/// Состояние плагина в настройках пользователя.
class PluginUserState {
  const PluginUserState({
    required this.enabled,
    this.config = const {},
  });

  final bool enabled;
  final Map<String, String> config;

  PluginUserState copyWith({
    bool? enabled,
    Map<String, String>? config,
  }) {
    return PluginUserState(
      enabled: enabled ?? this.enabled,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'config': config,
      };

  factory PluginUserState.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    final config = <String, String>{};
    if (rawConfig is Map) {
      for (final entry in rawConfig.entries) {
        config['${entry.key}'] = '${entry.value}';
      }
    }
    return PluginUserState(
      enabled: json['enabled'] as bool? ?? false,
      config: config,
    );
  }
}

/// Описание зарегистрированного плагина для UI.
class PluginDescriptor {
  const PluginDescriptor({
    required this.manifest,
    required this.state,
    required this.isBuiltin,
  });

  final PluginManifest manifest;
  final PluginUserState state;
  final bool isBuiltin;
}
