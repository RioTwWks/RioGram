# Продвинутый стелс и обход блокировок (§7.1)

Документация по техникам маскировки MTProto-трафика в RioGram: клиентские патчи TDLib и серверная инфраструктура прокси.

## Обзор

```
RioGram (TDLib + DPI_BYPASS)
  │ Fake TLS ClientHello (профиль по SNI-домену из ee-секрета)
  │ + фрагментация + DRS (в полном режиме)
  ▼
PhantomProxy / StealthGate Front (RU)
  │ Probe Resistance: DPI-зонд → реальный HTTPS-бэкенд
  │ MTProto-клиент → relay на EU back
  ▼
Telegram DC
```

Клиент и прокси работают в паре: **отпечаток TLS** формирует TDLib, **реакция на зонды** — прокси-сервер.

---

## 1. Маскировка под российские сервисы

### Как это работает

Секрет Fake TLS (`ee` + 16 байт ключа + домен в hex) задаёт SNI, под который маскируется соединение.  
TDLib выбирает **профиль ClientHello** по этому домену, а не случайный браузерный профиль.

| SNI-домен (примеры) | Семейство | Профиль ClientHello |
|---------------------|-----------|---------------------|
| `yandex.ru`, `ya.ru` | Yandex | Yandex (HTTP/1.1 ALPN, без ECH) |
| `vk.com`, `vk.ru`, `userapi.com` | VK | VK (Chrome-подобный, h2 ALPN, без ECH) |
| `gosuslugi.ru`, `gu.st` | Госуслуги | Gosuslugi (консервативный, HTTP/1.1, без ECH) |
| прочие | Generic | Chrome stable (совместимость с PhantomProxy) |

Реализация: `td/td/mtproto/dpi_bypass/DpiBypass.cpp` → `detect_service_family()`, `pick_profile_for_domain()`.

### Пример секрета

```env
# Маскировка под Яндекс
PROXY_PHANTOM_SECRET=ee<32_hex_байта>79616e6465782e7275

# Маскировка под VK (vk.com → 76726b2e636f6d)
PROXY_PHANTOM_SECRET=ee<32_hex_байта>76726b2e636f6d

# Маскировка под Госуслуги (gosuslugi.ru)
PROXY_PHANTOM_SECRET=ee<32_hex_байта>676f7375736c7567692e7275
```

Домен в hex можно получить: `echo -n 'yandex.ru' | xxd -p`.

### Режимы TDLib

В `td/td/mtproto/dpi_bypass/DpiBypass.h`:

| Флаг | Значение | Поведение |
|------|----------|-----------|
| `kDpiBypassStableProxyMode` | `true` (по умолчанию) | Профиль по домену, без фрагментации и DRS — совместимость с PhantomProxy/StealthGate |
| `kDpiBypassStableProxyMode` | `false` | Полный bypass: ротация профилей + фрагментация ClientHello + DRS |
| `kDpiBypassAutoRotateProfiles` | `true` | Автосмена отпечатка при ошибке handshake и по таймеру (30 мин) |
| `kProfileRotationIntervalSec` | `1800` | Интервал плановой ротации (секунды) |

После смены флагов пересобрать TDLib:

```bash
./scripts/build-tdlib.sh
./scripts/copy-tdlib.sh linux
```

---

## 2. Автосмена TLS-отпечатка

При `kDpiBypassAutoRotateProfiles = true` и `kDpiBypassStableProxyMode = false`:

1. **По ошибке handshake** — неверный ServerHello или hash mismatch → следующий профиль из пула семейства.
2. **По таймеру** — каждые 30 минут плановая ротация внутри пула.

Пулы ротации:

| Семейство | Порядок профилей |
|-----------|------------------|
| Yandex | Yandex → Chrome → Firefox |
| VK | VK → Chrome → Yandex |
| Госуслуги | Gosuslugi → Yandex → Chrome |
| Generic | Chrome → Firefox → Yandex → Safari |

API: `on_tls_handshake_failure()`, `maybe_rotate_profile_on_timer()` в `DpiBypass.h`.

---

## 3. Probe Resistance (серверная сторона)

**Probe Resistance** — способность прокси корректно отвечать на «проверочные» запросы DPI (браузер, сканер, неверный секрет), **не раскрывая** MTProto-природу сервиса.

### Принцип

Когда на порт 443 приходит соединение **без валидного MTProto-секрета**:

1. Прокси принимает TLS ClientHello.
2. Извлекает SNI (домен маскировки из секрета или клиента).
3. **Прозрачно проксирует** TCP-поток на реальный HTTPS-сервер этого домена.
4. DPI/сканер получает настоящий сертификат и ответ живого сайта.

Для внешнего наблюдателя VPS выглядит как обычный веб-сервер.

### Где реализовано

| Прокси | Механизм | Документация |
|--------|----------|--------------|
| **PhantomProxy** | Fake TLS + fallback на реальный backend по SNI | [PhantomProxy](https://github.com/RioTwWks/PhantomProxy) |
| **StealthGate** | Fake TLS + SGFB relay; front обрабатывает невалидные соединения | [StealthGate](https://github.com/RioTwWks/StealthGate) |
| **telemt** | `mask = true`, `tls_domain` → форвард на реальный сайт | [telemt censorship](https://github.com/telemt/telemt) |
| **teleproxy** | Fake-TLS + forward invalid connections | [teleproxy DPI](https://teleproxy.github.io/features/dpi-resistance/) |
| **mtproto_proxy** | Domain fronting для fake-TLS | [seriyps/mtproto_proxy](https://github.com/seriyps/mtproto_proxy/) |

### Рекомендации для RioGram

1. **Домен маскировки** в ee-секрете должен указывать на **реально доступный HTTPS-сайт** с валидным сертификатом.
2. На прокси включить **fallback/mask** на тот же домен, что в секрете клиентов.
3. Не менять `tls_domain` / домен в секрете после выдачи ссылок пользователям.
4. Для российских сервисов предпочтительны домены с устойчивой репутацией: `yandex.ru`, `vk.com`, `gosuslugi.ru`.

### Проверка Probe Resistance

```bash
# С машины вне клиента — имитация DPI-зонда (без секрета MTProto)
openssl s_client -connect <RU_VPS>:15443 -servername yandex.ru -brief </dev/null

# Ожидание: валидный TLS-сертификат yandex.ru (или домена из SNI), не RST
```

---

## 4. Интеграция с telemt / teleproxy

### telemt

[telemt](https://github.com/telemt/telemt) — MTProxy на Rust с продвинутой Fake TLS эмуляцией и маскировкой трафика.

**Возможности, релевантные RioGram:**

- Fake TLS (`ee`-секреты) с TLS-fronting
- `mask = true` — Probe Resistance (форвард на реальный сайт)
- Replay protection, квоты, IPv6
- Рекомендует клиент [tdlib-obf](https://github.com/telemt/tdlib-obf) для JA4-обхода

**Варианты интеграции:**

| Вариант | Описание | Сложность |
|---------|----------|-----------|
| **A. Замена back-end** | StealthGate Back / PhantomProxy Back → telemt как relay к DC | Средняя — нужен совместимый relay-протокол |
| **B. Параллельный прокси** | Добавить telemt Front как третий прокси в `.env` и failover | Низкая — стандартный MTProto `addProxy` |
| **C. Только клиент** | RioGram TDLib-патчи + telemt на VPS без StealthGate | Низкая — для одиночного VPS |

**Рекомендация:** начать с **варианта B** — развернуть telemt на отдельном RU VPS, добавить в `.env` как резервный прокси, сравнить стабильность с StealthGate.

Пример конфига telemt (секция `[censorship]`):

```toml
[censorship]
tls_domain = "yandex.ru"
mask = true
tls_emulation = true
```

### teleproxy

[teleproxy](https://github.com/teleproxy/teleproxy) — лёгкий MTProxy (C) с Fake-TLS, DRS и E2E-тестами.

- Direct-to-DC без middle-end
- Prometheus-метрики
- Подходит как альтернатива PhantomProxy для одиночного VPS

### Сравнение бэкендов

| | PhantomProxy | StealthGate | telemt | teleproxy |
|---|:---:|:---:|:---:|:---:|
| Front/Back split | PHRP | SGFB | Middle-End Pool | Нет |
| Probe Resistance | Да | Да | `mask` | Да |
| DRS | Через TDLib | Через TDLib | Сервер | Сервер |
| Язык | Go | Rust | Rust | C |
| RioGram интеграция | ✅ основной | ✅ резервный | 🔬 исследование | 🔬 исследование |

---

## 5. Связанные документы

- [TDLIB_PATCHES.md](TDLIB_PATCHES.md) — патчи ClientHello, фрагментация, DRS
- [PROXY.md](PROXY.md) — деплой PhantomProxy / StealthGate, failover
- [TODO.md §7.1](../TODO.md) — дорожная карта стелс-функций

## 6. Чеклист внедрения §7.1

- [x] Профили TLS для Yandex, VK, Госуслуги (выбор по SNI-домену)
- [x] Автосмена TLS-отпечатка по таймеру и при ошибках handshake
- [x] Документация Probe Resistance и рекомендации для прокси
- [x] Исследование интеграции telemt / teleproxy
- [ ] Полевое тестирование профилей на сетях провайдеров (§2.7)
- [ ] Развёртывание telemt как третьего прокси в failover (опционально)
