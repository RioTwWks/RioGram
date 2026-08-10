---
command: Развернуть прокси-серверы на VPS
---

# Деплой прокси

## PhantomProxy (основной)
1. Подключиться по SSH к VPS в РФ.
2. Скопировать бинарник `phantomproxy` и конфиг `config.toml`.
3. Запустить через `systemd`:
   ```bash
   sudo systemctl start phantomproxy
   ```

## StealthGate (резервный + сплит-режим)
1. На Frontend VPS (РФ) запустить `stealthgate-front` с параметрами, указывающими на Backend в EU.
2. На Backend VPS (EU) запустить `stealthgate-back` с доступом к Telegram DC.
