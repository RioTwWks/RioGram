# TDLib DPI Patches (RioGram)

Модификации официального TDLib для обхода DPI. Все изменения помечены `// DPI_BYPASS:`.

## Новые файлы

- `td/td/mtproto/dpi_bypass/DpiBypass.h` — API модуля
- `td/td/mtproto/dpi_bypass/DpiBypass.cpp` — фрагментация, DRS, выбор профиля

## Изменённые файлы

### `td/mtproto/TlsInit.cpp`
- 4 браузерных профиля ClientHello: Chrome, Firefox, Yandex, Safari
- Случайный выбор профиля при каждом подключении (`pick_random_profile()`)
- Фрагментация ClientHello на 2–3 TCP-сегмента в `send_hello()`

### `td/mtproto/TcpTransport.cpp` / `.h`
- Динамический размер TLS Application Data записей (1024–2878 байт)

### `CMakeLists.txt`
- Добавлен `dpi_bypass/DpiBypass.cpp` в `TD_MTPROTO_SOURCE`

## Сборка

```bash
./scripts/build-tdlib.sh
```

## Референсы

- [telemt/tdlib-obf](https://github.com/telemt/tdlib-obf) — продвинутая маскировка
- [ZaStoGram_desktop](https://github.com/youtubediscord/ZaStoGram_desktop) — Fake TLS + фрагментация
