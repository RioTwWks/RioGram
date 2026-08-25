# Иконка приложения RioGram

## Актуальный ассет

- **Мастер:** [`assets/icons/riogram_icon.png`](../assets/icons/riogram_icon.png) (1024×1024)
- **Концепт (устаревший placeholder):** `assets/icons/riogram_icon_concept.svg`

Символ: металлическая **R** + бумажный самолётик с огненным следом (мессенджер + «пробой»), без копирования официального логотипа Telegram.

## Генерация launcher-иконок

Конфиг в `pubspec.yaml` (`flutter_launcher_icons`). Пересборка:

```bash
dart run flutter_launcher_icons
```

Покрывает:

| Платформа | Куда пишется |
|-----------|----------------|
| Android | `mipmap-*/ic_launcher.png` + adaptive `drawable-*/ic_launcher_foreground.png` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Windows | `windows/runner/resources/app_icon.ico` |
| Web | `web/favicon.png`, `web/icons/` |

Фон adaptive / web: `#060A15`. Accent theme web: `#3390EC`.

## Требования (§9.9 TODO)

- Узнаваемый мессенджер, **без копирования** официального логотипа Telegram.
- Рабочие размеры: 48×48 (Android mdpi), 1024×1024 (iOS App Store), 256×256 (desktop).

## Юридическое

Не использовать торговые марки Telegram LLC. RioGram — независимый клиент; иконка должна отличаться от [брендбука Telegram](https://telegram.org/tour/screenshots).
