# Иконка приложения RioGram

## Требования (§9.9 TODO)

- Узнаваемый мессенджер, **без копирования** официального логотипа Telegram (бумажный самолётик, круг с градиентом TG).
- Акцентный цвет: `#3390EC` ([TelegramColors.accent](../lib/core/theme/telegram_theme.dart)).
- Рабочие размеры: 48×48 (Android adaptive), 1024×1024 (iOS App Store), 256×256 (desktop).

## Концепт (placeholder)

Пока полный pipeline иконок не настроен (`flutter_launcher_icons` / ручные mipmap):

- **Форма:** скруглённый квадрат или круг.
- **Символ:** стилизованная буква **R** или волна/река (от «Rio»), outline, без самолётика.
- **Фон:** сплошной `#3390EC` или тёмный `#17212B` с синим символом.

Референс-заготовка: `assets/icons/riogram_icon_concept.svg` (вектор для дизайнера, не подключена к launcher).

## Внедрение launcher-иконок

1. Экспорт PNG из SVG (1024, 512, 192, 48).
2. Android: `android/app/src/main/res/mipmap-*/ic_launcher.png` + adaptive `ic_launcher_foreground`.
3. iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
4. Linux/macOS/Windows: соответствующие `Runner` / `data` каталоги.
5. Опционально: пакет `flutter_launcher_icons` в `pubspec.yaml`.

## Юридическое

Не использовать торговые марки Telegram LLC. RioGram — независимый клиент; иконка должна отличаться от [брендбука Telegram](https://telegram.org/tour/screenshots).
