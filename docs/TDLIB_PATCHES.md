# TDLib DPI Patches (RioGram)

Модификации официального TDLib для обхода DPI. Все изменения помечены `// DPI_BYPASS:`.

## Новые файлы

- `td/td/mtproto/dpi_bypass/DpiBypass.h` — API модуля, флаги режимов, профили TLS
- `td/td/mtproto/dpi_bypass/DpiBypass.cpp` — фрагментация, DRS, выбор профиля по домену, ротация

### Режим `kDpiBypassStableProxyMode`

В `DpiBypass.h`:

```cpp
constexpr bool kDpiBypassStableProxyMode = true;
```

| Значение | Поведение |
|----------|-----------|
| `true` | Профиль ClientHello по SNI-домену (Yandex/VK/Gosuslugi/Chrome), без фрагментации и DRS |
| `false` | Полный DPI bypass: ротация профилей + фрагментация ClientHello + DRS |

### Автосмена TLS-отпечатка

```cpp
constexpr bool kDpiBypassAutoRotateProfiles = true;
constexpr int kProfileRotationIntervalSec = 1800;  // 30 минут
```

При `kDpiBypassStableProxyMode = false` и `kDpiBypassAutoRotateProfiles = true`:

- ротация профиля при ошибке Fake TLS handshake;
- плановая ротация каждые 30 минут внутри пула семейства сервиса.

См. [STEALTH.md](STEALTH.md).

### Профили маскировки

| Профиль | Назначение |
|---------|------------|
| `Chrome` | Generic / stable proxy mode |
| `Firefox` | Альтернативный JA3 в пуле ротации |
| `Yandex` | SNI `*.yandex.ru`, `ya.ru` |
| `Vk` | SNI `*.vk.com`, `vk.ru`, `userapi.com` |
| `Gosuslugi` | SNI `*.gosuslugi.ru`, `gu.st` |
| `Safari` | Generic пул ротации |

Выбор: `detect_service_family(domain)` → `pick_profile_for_domain(domain)`.

## Изменённые файлы

### `td/mtproto/TlsInit.cpp`
- 6 профилей ClientHello: Chrome, Firefox, Yandex, Safari, VK, Gosuslugi
- Выбор профиля по SNI из ee-секрета (`get_for_request(domain)`)
- Фрагментация ClientHello на 2–3 TCP-сегмента в `send_hello()`
- Вызов `on_tls_handshake_failure()` при ошибке handshake

### `td/mtproto/TcpTransport.cpp` / `.h`
- Динамический размер TLS Application Data записей (1024–2878 байт)

### `CMakeLists.txt`
- Добавлен `dpi_bypass/DpiBypass.cpp` в `TD_MTPROTO_SOURCE`

## Сборка

```bash
./scripts/build-tdlib.sh
```

## Референсы

- [STEALTH.md](STEALTH.md) — Probe Resistance, telemt, российские профили
- [telemt/tdlib-obf](https://github.com/telemt/tdlib-obf) — продвинутая маскировка
- [ZaStoGram_desktop](https://github.com/youtubediscord/ZaStoGram_desktop) — Fake TLS + фрагментация
