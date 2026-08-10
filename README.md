# RioGram — Censorship‑Resistant Telegram Client

**RioGram** is a cross‑platform Telegram client built with Flutter and a heavily patched TDLib. It is designed to stay online even under aggressive Deep Packet Inspection (DPI) by:
- **Randomizing TLS ClientHello** (mimicking Chrome, Firefox, etc.)
- **Fragmenting** the first handshake packets
- **Dynamically varying** record sizes
- **Automatically switching** between your own proxies (PhantomProxy and StealthGate) with failover logic

Supports Windows, macOS, Linux, Android, and iOS.
