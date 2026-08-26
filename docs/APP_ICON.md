# Иконка приложения RioGram

## Актуальный ассет

- **Мастер (launcher):** [`assets/icons/app_icon_1024.png`](../assets/icons/app_icon_1024.png) (1024×1024)
- **Adaptive foreground:** [`assets/icons/app_icon_foreground.png`](../assets/icons/app_icon_foreground.png)
- **Концепт (устаревший placeholder):** `assets/icons/riogram_icon_concept.svg`

Символ: металлическая **R** + бумажный самолётик с огненным следом (мессенджер + «пробой»), без копирования официального логотипа Telegram.

## Генерация launcher-иконок

Конфиг в `pubspec.yaml` (`flutter_launcher_icons`):

```yaml
flutter_launcher_icons:
  image_path: assets/icons/app_icon_1024.png
  adaptive_icon_background: '#3390EC'
  adaptive_icon_foreground: assets/icons/app_icon_foreground.png
  web:
    background_color: '#3390EC'
    theme_color: '#3390EC'
```

Пересборка:

```bash
dart run flutter_launcher_icons
```

Покрывает:

| Платформа | Куда пишется |
|-----------|----------------|
| Android | `mipmap-*/ic_launcher.png` + adaptive `drawable-*/ic_launcher_foreground.png` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Windows | `windows/runner/resources/app_icon.ico` (256×256) |
| Web | `web/favicon.png`, `web/icons/` |

## Требования (§9.9 TODO)

- Узнаваемый мессенджер, **без копирования** официального логотипа Telegram.
- Акцент темы: `#3390EC` (классический Telegram blue).
- Рабочие размеры: 48×48 (Android mdpi), 1024×1024 (iOS App Store), 256×256 (desktop).

## Юридическое

Не использовать торговые марки Telegram LLC. RioGram — независимый клиент; иконка должна отличаться от [брендбука Telegram](https://telegram.org/tour/screenshots).
