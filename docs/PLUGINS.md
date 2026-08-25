# RioGram Plugin API (§7.6)

RioGram поддерживает **community-плагины** через стабильный Dart API и JSON-манифесты.
В v1 плагины регистрируются compile-time (`PluginRegistry`), но контракт совместим с
будущей загрузкой из каталога `~/.riogram/plugins/`.

## Манифест

```json
{
  "id": "com.example.hello",
  "name": "Hello Plugin",
  "version": "1.0.0",
  "description": "Демонстрационный плагин",
  "author": "Community",
  "homepage": "https://example.com",
  "capabilities": [
    "messageDisplayTransform",
    "outgoingMessageTransform"
  ]
}
```

## Capabilities

| Capability | Описание |
|------------|----------|
| `messageDisplayTransform` | Изменение текста сообщения при отображении |
| `outgoingMessageTransform` | Изменение исходящего текста перед отправкой |

## Реализация плагина

```dart
import 'package:riogram/core/plugins/plugin_api.dart';
import 'package:riogram/models/plugin_models.dart';

final class HelloPlugin implements RioGramPlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'com.example.hello',
    name: 'Hello Plugin',
    version: '1.0.0',
    description: 'Adds greeting',
    author: 'You',
    capabilities: [PluginCapability.outgoingMessageTransform],
  );

  @override
  bool supports(PluginCapability capability) =>
      capability == PluginCapability.outgoingMessageTransform;

  @override
  String? transformOutgoingMessage(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    return 'Hello!\n$text';
  }
}
```

## Регистрация

```dart
PluginRegistry.register(const HelloPlugin());
```

## Конфигурация

Пользовательские настройки хранятся в `PluginManager` (`SharedPreferences`) как
`Map<String, String>` per plugin id. UI настроек: **Настройки → Плагины**.

## Встроенные плагины

- `riogram.builtin.reading_time` — время чтения длинных сообщений
- `riogram.builtin.signature` — подпись исходящих текстов

## Ограничения v1

- Нет динамической загрузки Dart-кода на mobile/desktop (только compile-time)
- Плагины не получают прямой доступ к TDLib — только через хуки
- Трансформация display-текста сбрасывает TDLib entities (plain text)

## Roadmap

1. **v1.1** — каталог плагинов из JSON + подпись манифеста
2. **v1.2** — sandbox isolate для declarative plugins (JSON rules)
3. **v2** — подписанные plugin bundles для desktop
